'use strict';

const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const Redis = require('ioredis');

const PORT = Number.parseInt(process.env.PORT || '3000', 10);
const HOST = process.env.HOST || '0.0.0.0';
const BACKEND_ID = (process.env.BACKEND_ID || 'A').trim() || 'A';
const LEADERBOARD_TTL_SECONDS = 3600;
const LEADERBOARD_LIMIT = 10;

const INDEX_HTML_PATH = path.join(__dirname, '..', 'public', 'index.html');
const INDEX_HTML = fs.readFileSync(INDEX_HTML_PATH, 'utf8');

// Process-local RAM storage for store=memory baseline
const memoryRooms = new Map();

// ElastiCache configuration (reused single client per process)
const valkeyUrl = (process.env.VALKEY_URL || '').trim();
const valkeyHost = (process.env.VALKEY_HOST || '').trim();
const valkeyPort = Number.parseInt(process.env.VALKEY_PORT || '6379', 10);
const valkeyUsername = (process.env.VALKEY_USERNAME || '').trim();
const valkeyPassword = process.env.VALKEY_PASSWORD || '';
const valkeyTls = (process.env.VALKEY_TLS || 'true').toLowerCase() !== 'false';
const valkeyRejectUnauthorized =
  (process.env.VALKEY_TLS_REJECT_UNAUTHORIZED || 'true').toLowerCase() !== 'false';

const cacheConfigured = Boolean(valkeyUrl || valkeyHost);

let redisClient = null;
let lastCacheError = null;

if (cacheConfigured) {
  const commonOptions = {
    enableReadyCheck: false,
    enableOfflineQueue: false,
    maxRetriesPerRequest: 1,
    connectTimeout: 4000,
    commandTimeout: 3000,
    retryStrategy(times) {
      return Math.min(times * 500, 5000);
    },
  };

  if (valkeyUrl) {
    const tlsOpts = valkeyUrl.startsWith('rediss://')
      ? { rejectUnauthorized: valkeyRejectUnauthorized }
      : undefined;
    redisClient = new Redis(valkeyUrl, {
      ...commonOptions,
      ...(tlsOpts ? { tls: tlsOpts } : {}),
    });
  } else {
    redisClient = new Redis({
      host: valkeyHost,
      port: Number.isFinite(valkeyPort) ? valkeyPort : 6379,
      ...(valkeyUsername ? { username: valkeyUsername } : {}),
      ...(valkeyPassword ? { password: valkeyPassword } : {}),
      ...(valkeyTls ? { tls: { rejectUnauthorized: valkeyRejectUnauthorized } } : {}),
      ...commonOptions,
    });
  }

  redisClient.on('ready', () => {
    lastCacheError = null;
  });

  redisClient.on('error', (err) => {
    lastCacheError = err && err.message ? err.message : 'Cache client error';
  });
}

function stripLabPrefix(pathname) {
  for (const prefix of ['/lab/a', '/lab/b']) {
    if (pathname === prefix || pathname === `${prefix}/`) {
      return '/';
    }
    if (pathname.startsWith(`${prefix}/`)) {
      return pathname.slice(prefix.length);
    }
  }
  return pathname;
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function sendHtml(res, statusCode, html) {
  res.writeHead(statusCode, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(html),
  });
  res.end(html);
}

function isValidIdentifier(value) {
  return typeof value === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(value);
}

function parseStoreMode(urlObj) {
  const raw = urlObj.searchParams.get('store');
  if (raw === 'memory' || raw === 'elasticache') {
    return raw;
  }
  return null;
}

function leaderboardKey(roomId) {
  return `quizlab:room:${roomId}:leaderboard`;
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;
    const maxBytes = 16 * 1024;

    req.on('data', (chunk) => {
      totalBytes += chunk.length;
      if (totalBytes > maxBytes) {
        reject(Object.assign(new Error('Request body too large'), { statusCode: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8').trim();
      if (!raw) {
        reject(Object.assign(new Error('Request body is required'), { statusCode: 400 }));
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(Object.assign(new Error('Invalid JSON body'), { statusCode: 400 }));
      }
    });

    req.on('error', (err) => reject(err));
  });
}

function getMemoryLeaderboard(roomId) {
  const room = memoryRooms.get(roomId);
  if (!room) {
    return [];
  }
  return Array.from(room.entries())
    .map(([playerId, score]) => ({ playerId, score }))
    .sort((a, b) => b.score - a.score || a.playerId.localeCompare(b.playerId))
    .slice(0, LEADERBOARD_LIMIT);
}

function parseZrangeWithScores(flat) {
  const items = [];
  for (let i = 0; i < flat.length; i += 2) {
    items.push({
      playerId: flat[i],
      score: Number(flat[i + 1]),
    });
  }
  return items;
}

function sanitizeCacheError(err) {
  const raw = (err && err.message) || lastCacheError || 'ElastiCache connection failed';
  return raw.replace(/rediss?:\/\/[^@\s]+@/gi, 'rediss://<redacted>@');
}

async function ensureCacheReady() {
  if (!cacheConfigured || !redisClient) {
    const err = new Error('ElastiCache is not configured on this backend');
    err.statusCode = 503;
    throw err;
  }
}

async function handleRequest(req, res) {
  const method = (req.method || 'GET').toUpperCase();
  const urlObj = new URL(req.url || '/', 'http://localhost');
  const pathname = stripLabPrefix(urlObj.pathname);

  if (method === 'GET' && pathname === '/') {
    sendHtml(res, 200, INDEX_HTML);
    return;
  }

  // Health probe is independent of ElastiCache so ALB demo stays isolated
  if (method === 'GET' && pathname === '/health') {
    sendJson(res, 200, {
      status: 'ok',
      backendId: BACKEND_ID,
      timestamp: new Date().toISOString(),
    });
    return;
  }

  if (method === 'GET' && pathname === '/api/whoami') {
    sendJson(res, 200, {
      backendId: BACKEND_ID,
      requestId: crypto.randomUUID(),
      timestamp: new Date().toISOString(),
    });
    return;
  }

  if (method === 'GET' && pathname === '/api/cache-status') {
    if (!cacheConfigured || !redisClient) {
      sendJson(res, 503, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        configured: false,
        connected: false,
        tls: valkeyTls,
        error: 'ElastiCache is not configured on this backend',
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const start = Date.now();
    try {
      const pong = await redisClient.ping();
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        configured: true,
        connected: pong === 'PONG',
        tls: valkeyTls,
        ping: pong,
        latencyMs: Date.now() - start,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      sendJson(res, 503, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        configured: true,
        connected: false,
        tls: valkeyTls,
        latencyMs: Date.now() - start,
        error: sanitizeCacheError(err),
        timestamp: new Date().toISOString(),
      });
    }
    return;
  }

  // PUT /api/rooms/:roomId/scores/:playerId?store=memory|elasticache
  const putScoreMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/scores\/([^/]+)$/);
  if (method === 'PUT' && putScoreMatch) {
    const roomId = decodeURIComponent(putScoreMatch[1]);
    const playerId = decodeURIComponent(putScoreMatch[2]);
    const storeMode = parseStoreMode(urlObj);

    if (!isValidIdentifier(roomId) || !isValidIdentifier(playerId)) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: storeMode || null,
        roomId,
        status: 'error',
        error: 'roomId and playerId must match ^[a-zA-Z0-9_-]{1,64}$',
      });
      return;
    }

    if (!storeMode) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: null,
        roomId,
        status: 'error',
        error: 'Query parameter store must be "memory" or "elasticache"',
      });
      return;
    }

    let body;
    try {
      body = await readJsonBody(req);
    } catch (err) {
      sendJson(res, err.statusCode || 400, {
        backendId: BACKEND_ID,
        storeMode,
        roomId,
        status: 'error',
        error: err.message || 'Invalid body',
      });
      return;
    }

    const score = body && typeof body.score === 'number' ? body.score : Number.NaN;
    if (!Number.isFinite(score) || score < 0) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode,
        roomId,
        status: 'error',
        error: 'Body must contain a finite non-negative numeric "score"',
      });
      return;
    }

    if (storeMode === 'memory') {
      let room = memoryRooms.get(roomId);
      if (!room) {
        room = new Map();
        memoryRooms.set(roomId, room);
      }
      room.set(playerId, score);
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'memory',
        roomId,
        playerId,
        score,
        status: 'ok',
        leaderboard: getMemoryLeaderboard(roomId),
      });
      return;
    }

    try {
      await ensureCacheReady();
      const key = leaderboardKey(roomId);
      await redisClient.zadd(key, score, playerId);
      await redisClient.expire(key, LEADERBOARD_TTL_SECONDS);
      const raw = await redisClient.zrange(key, 0, LEADERBOARD_LIMIT - 1, 'REV', 'WITHSCORES');
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        playerId,
        score,
        status: 'ok',
        leaderboard: parseZrangeWithScores(raw),
      });
    } catch (err) {
      sendJson(res, err.statusCode || 503, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        status: 'error',
        error: sanitizeCacheError(err),
      });
    }
    return;
  }

  // GET /api/rooms/:roomId/leaderboard?store=memory|elasticache
  const getLeaderboardMatch = pathname.match(/^\/api\/rooms\/([^/]+)\/leaderboard$/);
  if (method === 'GET' && getLeaderboardMatch) {
    const roomId = decodeURIComponent(getLeaderboardMatch[1]);
    const storeMode = parseStoreMode(urlObj);

    if (!isValidIdentifier(roomId)) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: storeMode || null,
        roomId,
        status: 'error',
        error: 'roomId must match ^[a-zA-Z0-9_-]{1,64}$',
      });
      return;
    }

    if (!storeMode) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: null,
        roomId,
        status: 'error',
        error: 'Query parameter store must be "memory" or "elasticache"',
      });
      return;
    }

    if (storeMode === 'memory') {
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'memory',
        roomId,
        status: 'ok',
        leaderboard: getMemoryLeaderboard(roomId),
      });
      return;
    }

    try {
      await ensureCacheReady();
      const key = leaderboardKey(roomId);
      const raw = await redisClient.zrange(key, 0, LEADERBOARD_LIMIT - 1, 'REV', 'WITHSCORES');
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        status: 'ok',
        leaderboard: parseZrangeWithScores(raw),
      });
    } catch (err) {
      sendJson(res, err.statusCode || 503, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        status: 'error',
        error: sanitizeCacheError(err),
      });
    }
    return;
  }

  // DELETE /api/lab/rooms/:roomId?store=memory|elasticache
  const deleteRoomMatch = pathname.match(/^\/api\/lab\/rooms\/([^/]+)$/);
  if (method === 'DELETE' && deleteRoomMatch) {
    const roomId = decodeURIComponent(deleteRoomMatch[1]);
    const storeMode = parseStoreMode(urlObj);

    if (!isValidIdentifier(roomId)) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: storeMode || null,
        roomId,
        status: 'error',
        error: 'roomId must match ^[a-zA-Z0-9_-]{1,64}$',
      });
      return;
    }

    if (!storeMode) {
      sendJson(res, 400, {
        backendId: BACKEND_ID,
        storeMode: null,
        roomId,
        status: 'error',
        error: 'Query parameter store must be "memory" or "elasticache"',
      });
      return;
    }

    if (storeMode === 'memory') {
      const existed = memoryRooms.delete(roomId);
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'memory',
        roomId,
        status: 'reset',
        deleted: existed ? 1 : 0,
      });
      return;
    }

    try {
      await ensureCacheReady();
      const deleted = await redisClient.del(leaderboardKey(roomId));
      sendJson(res, 200, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        status: 'reset',
        deleted,
      });
    } catch (err) {
      sendJson(res, err.statusCode || 503, {
        backendId: BACKEND_ID,
        storeMode: 'elasticache',
        roomId,
        status: 'error',
        error: sanitizeCacheError(err),
      });
    }
    return;
  }

  sendJson(res, 404, {
    backendId: BACKEND_ID,
    status: 'error',
    error: `Route not found: ${method} ${pathname}`,
  });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((err) => {
    sendJson(res, 500, {
      backendId: BACKEND_ID,
      status: 'error',
      error: err && err.message ? err.message : 'Internal server error',
    });
  });
});

server.listen(PORT, HOST, () => {
  console.log(
    JSON.stringify({
      msg: 'quizlab server listening',
      host: HOST,
      port: PORT,
      backendId: BACKEND_ID,
      cacheConfigured,
      valkeyTls,
    })
  );
});

function shutdown(signal) {
  console.log(JSON.stringify({ msg: 'shutting down', signal, backendId: BACKEND_ID }));
  server.close(() => {
    if (redisClient) {
      redisClient.disconnect();
    }
    process.exit(0);
  });
  setTimeout(() => {
    if (redisClient) {
      redisClient.disconnect();
    }
    process.exit(0);
  }, 1500).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
