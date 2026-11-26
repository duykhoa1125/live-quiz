#!/usr/bin/env bash
set -euo pipefail

# Automated AWS deployment script for the ALB & ElastiCache seminar lab.
# Reproduces the verified architecture from docs/AWS_CONFIG_COST_CLEANUP.md.
# Does NOT store any secrets in files or Git; generates Valkey RBAC password at
# runtime into SSM Parameter Store (SecureString) and /etc/quizlab/env (0600).
#
# Usage:
#   ./deploy-aws.sh
# Optional environment overrides:
#   AWS_REGION=ap-southeast-2
#   PRESENTER_CIDR=<your-ip>/32
#   OWNER_TAG=khoa-cli

export PATH="$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-ap-southeast-2}"
OWNER_TAG="${OWNER_TAG:-khoa-cli}"
PROJECT_TAG="quiz-service-seminar"
STATE_FILE="$SCRIPT_DIR/.deploy-state.env"

for bin in aws python3 tar base64 curl; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing required tool: $bin" >&2
    exit 1
  fi
done

echo "[1/8] Checking AWS identity and region ($REGION)..."
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
aws ec2 describe-availability-zones --region "$REGION" --query "AvailabilityZones[0].ZoneName" --output text >/dev/null

if [[ -n "${PRESENTER_CIDR:-}" ]]; then
  CIDR_ALLOW="$PRESENTER_CIDR"
else
  MY_IP=$(curl -fsSL https://checkip.amazonaws.com | tr -d '[:space:]')
  CIDR_ALLOW="${MY_IP}/32"
fi
echo "Account=$ACCOUNT_ID | Region=$REGION | ALB allowed CIDR=$CIDR_ALLOW"

# Fail fast if a previous lab deployment still exists
if aws elbv2 describe-load-balancers --region "$REGION" --names quizlab-alb >/dev/null 2>&1; then
  echo "quizlab-alb already exists in $REGION. Run ./cleanup-aws.sh --yes first." >&2
  exit 1
fi
if aws elasticache describe-replication-groups --region "$REGION" --replication-group-id quizlab-valkey >/dev/null 2>&1; then
  echo "quizlab-valkey already exists in $REGION. Run ./cleanup-aws.sh --yes first." >&2
  exit 1
fi

echo "[2/8] Creating IAM Role and Instance Profile for SSM..."
TRUST_FILE=$(mktemp)
cat > "$TRUST_FILE" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
aws iam create-role \
  --role-name quizlab-ec2-ssm-role \
  --assume-role-policy-document "file://$TRUST_FILE" \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null
rm -f "$TRUST_FILE"

aws iam attach-role-policy \
  --role-name quizlab-ec2-ssm-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

POLICY_FILE=$(mktemp)
cat > "$POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:${REGION}:${ACCOUNT_ID}:parameter/quizlab/*"
    }
  ]
}
EOF
aws iam put-role-policy \
  --role-name quizlab-ec2-ssm-role \
  --policy-name quizlab-read-valkey-param \
  --policy-document "file://$POLICY_FILE"
rm -f "$POLICY_FILE"

aws iam create-instance-profile \
  --instance-profile-name quizlab-ec2-ssm-profile \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null
aws iam add-role-to-instance-profile \
  --instance-profile-name quizlab-ec2-ssm-profile \
  --role-name quizlab-ec2-ssm-role

echo "[3/8] Creating VPC, Subnets, IGW, Route Tables, and Security Groups..."
AZ1="${REGION}a"
AZ2="${REGION}b"

VPC_ID=$(aws ec2 create-vpc --region "$REGION" --cidr-block 10.20.0.0/16 \
  --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=quizlab-vpc},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Vpc.VpcId" --output text)
aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'

IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" \
  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=quizlab-igw},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 attach-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"

PUB_2A=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" --cidr-block 10.20.1.0/24 --availability-zone "$AZ1" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=quizlab-public-2a},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Subnet.SubnetId" --output text)
PUB_2B=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" --cidr-block 10.20.2.0/24 --availability-zone "$AZ2" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=quizlab-public-2b},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Subnet.SubnetId" --output text)
aws ec2 modify-subnet-attribute --region "$REGION" --subnet-id "$PUB_2A" --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --region "$REGION" --subnet-id "$PUB_2B" --map-public-ip-on-launch

PRIV_2A=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" --cidr-block 10.20.11.0/24 --availability-zone "$AZ1" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=quizlab-private-2a},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Subnet.SubnetId" --output text)
PRIV_2B=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC_ID" --cidr-block 10.20.12.0/24 --availability-zone "$AZ2" \
  --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=quizlab-private-2b},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Subnet.SubnetId" --output text)

RT_PUB=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=quizlab-rt-public},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --region "$REGION" --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PUB" --subnet-id "$PUB_2A" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PUB" --subnet-id "$PUB_2B" >/dev/null

RT_PRIV=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=quizlab-rt-private},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "RouteTable.RouteTableId" --output text)
aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PRIV" --subnet-id "$PRIV_2A" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$RT_PRIV" --subnet-id "$PRIV_2B" >/dev/null

SG_ALB=$(aws ec2 create-security-group --region "$REGION" --group-name quizlab-sg-alb \
  --description "ALB SG for quizlab demo" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=quizlab-sg-alb},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ALB" \
  --protocol tcp --port 80 --cidr "$CIDR_ALLOW" >/dev/null

SG_BACKEND=$(aws ec2 create-security-group --region "$REGION" --group-name quizlab-sg-backend \
  --description "Backend EC2 SG for quizlab demo" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=quizlab-sg-backend},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_BACKEND" \
  --protocol tcp --port 3000 --source-group "$SG_ALB" >/dev/null

SG_CACHE=$(aws ec2 create-security-group --region "$REGION" --group-name quizlab-sg-cache \
  --description "ElastiCache Valkey SG for quizlab demo" --vpc-id "$VPC_ID" \
  --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=quizlab-sg-cache},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "GroupId" --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_CACHE" \
  --protocol tcp --port 6379 --source-group "$SG_BACKEND" >/dev/null

echo "[4/8] Creating ElastiCache Valkey RBAC and single-node replication group..."
aws elasticache create-cache-subnet-group \
  --region "$REGION" \
  --cache-subnet-group-name quizlab-cache-subnet-group \
  --cache-subnet-group-description "Private subnets for quizlab Valkey" \
  --subnet-ids "$PRIV_2A" "$PRIV_2B" \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null

python3 - <<PYEOF
import secrets, string, subprocess

AWS = 'aws'
REGION = '$REGION'
PROJECT_TAG = '$PROJECT_TAG'
OWNER_TAG = '$OWNER_TAG'

def gen_pw(n=28):
    chars = string.ascii_letters + string.digits
    return ''.join(secrets.choice(chars) for _ in range(n))

def run_safe(args, msg):
    res = subprocess.run([AWS, '--region', REGION, *args], text=True, capture_output=True)
    if res.returncode != 0:
        raise RuntimeError(f"{msg}: {res.stderr.strip()}")

dummy_pw = gen_pw()
app_pw = gen_pw()

run_safe([
    'elasticache', 'create-user',
    '--user-id', 'quizlab-default-off', '--user-name', 'default', '--engine', 'valkey',
    '--passwords', dummy_pw, '--access-string', 'off -@all',
    '--tags', f'Key=Project,Value={PROJECT_TAG}', f'Key=Owner,Value={OWNER_TAG}'
], 'create default-off user')

run_safe([
    'elasticache', 'create-user',
    '--user-id', 'quizlab-app', '--user-name', 'quizlab', '--engine', 'valkey',
    '--passwords', app_pw,
    '--access-string', 'on ~quizlab:* +@connection +zadd +zrange +zrevrange +get +set +expire +ttl +del',
    '--tags', f'Key=Project,Value={PROJECT_TAG}', f'Key=Owner,Value={OWNER_TAG}'
], 'create quizlab-app user')

run_safe([
    'ssm', 'put-parameter',
    '--name', '/quizlab/valkey_password', '--type', 'SecureString',
    '--value', app_pw, '--overwrite'
], 'store valkey password in SSM')

run_safe([
    'ssm', 'add-tags-to-resource',
    '--resource-type', 'Parameter', '--resource-id', '/quizlab/valkey_password',
    '--tags', f'Key=Project,Value={PROJECT_TAG}', f'Key=Owner,Value={OWNER_TAG}'
], 'tag SSM parameter')
PYEOF

for _ in $(seq 1 20); do
  U1=$(aws elasticache describe-users --region "$REGION" --user-id quizlab-default-off --query "Users[0].Status" --output text)
  U2=$(aws elasticache describe-users --region "$REGION" --user-id quizlab-app --query "Users[0].Status" --output text)
  [[ "$U1" == "active" && "$U2" == "active" ]] && break
  sleep 3
done

aws elasticache create-user-group \
  --region "$REGION" \
  --user-group-id quizlab-user-group \
  --engine valkey \
  --user-ids quizlab-default-off quizlab-app \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null

for _ in $(seq 1 20); do
  UG=$(aws elasticache describe-user-groups --region "$REGION" --user-group-id quizlab-user-group --query "UserGroups[0].Status" --output text)
  [[ "$UG" == "active" ]] && break
  sleep 4
done

aws elasticache create-replication-group \
  --region "$REGION" \
  --replication-group-id quizlab-valkey \
  --replication-group-description "Seminar lab Valkey single primary node" \
  --engine valkey \
  --engine-version 8.2 \
  --cache-node-type cache.t4g.micro \
  --num-cache-clusters 1 \
  --preferred-cache-cluster-azs "$AZ1" \
  --cache-subnet-group-name quizlab-cache-subnet-group \
  --security-group-ids "$SG_CACHE" \
  --transit-encryption-enabled \
  --user-group-ids quizlab-user-group \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null

echo "[5/8] Launching EC2 A and B (AL2023 x86_64 t3.micro)..."
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameter.Value" --output text)

USERDATA_FILE=$(mktemp)
cat > "$USERDATA_FILE" <<'EOF'
#!/bin/bash
set -euxo pipefail
dnf install -y docker
systemctl enable --now docker
usermod -aG docker ec2-user || true
mkdir -p /opt/quizlab /etc/quizlab
chmod 700 /etc/quizlab
EOF

sleep 8
EC2_A=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --subnet-id "$PUB_2A" \
  --security-group-ids "$SG_BACKEND" \
  --iam-instance-profile Name=quizlab-ec2-ssm-profile \
  --user-data "file://$USERDATA_FILE" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=quizlab-ec2-a},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" "ResourceType=volume,Tags=[{Key=Name,Value=quizlab-ec2-a-root},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Instances[0].InstanceId" --output text)

EC2_B=$(aws ec2 run-instances \
  --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --subnet-id "$PUB_2B" \
  --security-group-ids "$SG_BACKEND" \
  --iam-instance-profile Name=quizlab-ec2-ssm-profile \
  --user-data "file://$USERDATA_FILE" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=quizlab-ec2-b},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" "ResourceType=volume,Tags=[{Key=Name,Value=quizlab-ec2-b-root},{Key=Project,Value=$PROJECT_TAG},{Key=Owner,Value=$OWNER_TAG}]" \
  --query "Instances[0].InstanceId" --output text)
rm -f "$USERDATA_FILE"

echo "[6/8] Creating ALB, Target Groups, and Listener Rules..."
ALB_OUT=$(aws elbv2 create-load-balancer \
  --region "$REGION" \
  --name quizlab-alb \
  --subnets "$PUB_2A" "$PUB_2B" \
  --security-groups "$SG_ALB" \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" \
  --query "LoadBalancers[0].[LoadBalancerArn,DNSName]" --output text)
ALB_ARN=$(echo "$ALB_OUT" | awk '{print $1}')
ALB_DNS=$(echo "$ALB_OUT" | awk '{print $2}')

TG_MAIN=$(aws elbv2 create-target-group --region "$REGION" --name quizlab-tg-main \
  --protocol HTTP --port 3000 --vpc-id "$VPC_ID" --target-type instance \
  --health-check-protocol HTTP --health-check-path /health --health-check-port traffic-port \
  --health-check-interval-seconds 5 --health-check-timeout-seconds 2 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 --matcher HttpCode=200 \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" \
  --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 modify-target-group-attributes --region "$REGION" --target-group-arn "$TG_MAIN" \
  --attributes Key=stickiness.enabled,Value=false Key=load_balancing.algorithm.type,Value=round_robin >/dev/null

TG_A=$(aws elbv2 create-target-group --region "$REGION" --name quizlab-tg-a \
  --protocol HTTP --port 3000 --vpc-id "$VPC_ID" --target-type instance \
  --health-check-protocol HTTP --health-check-path /health --health-check-port traffic-port \
  --health-check-interval-seconds 5 --health-check-timeout-seconds 2 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 --matcher HttpCode=200 \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" \
  --query "TargetGroups[0].TargetGroupArn" --output text)

TG_B=$(aws elbv2 create-target-group --region "$REGION" --name quizlab-tg-b \
  --protocol HTTP --port 3000 --vpc-id "$VPC_ID" --target-type instance \
  --health-check-protocol HTTP --health-check-path /health --health-check-port traffic-port \
  --health-check-interval-seconds 5 --health-check-timeout-seconds 2 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 2 --matcher HttpCode=200 \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" \
  --query "TargetGroups[0].TargetGroupArn" --output text)

LISTENER_ARN=$(aws elbv2 create-listener --region "$REGION" --load-balancer-arn "$ALB_ARN" \
  --protocol HTTP --port 80 --default-actions "Type=forward,TargetGroupArn=$TG_MAIN" \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" \
  --query "Listeners[0].ListenerArn" --output text)

aws elbv2 create-rule --region "$REGION" --listener-arn "$LISTENER_ARN" --priority 10 \
  --conditions '[{"Field":"path-pattern","PathPatternConfig":{"Values":["/lab/a","/lab/a/*"]}}]' \
  --actions "Type=forward,TargetGroupArn=$TG_A" \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null

aws elbv2 create-rule --region "$REGION" --listener-arn "$LISTENER_ARN" --priority 20 \
  --conditions '[{"Field":"path-pattern","PathPatternConfig":{"Values":["/lab/b","/lab/b/*"]}}]' \
  --actions "Type=forward,TargetGroupArn=$TG_B" \
  --tags "Key=Project,Value=$PROJECT_TAG" "Key=Owner,Value=$OWNER_TAG" >/dev/null

# Persist state right away so cleanup-aws.sh can tear down even if a later step fails
cat > "$STATE_FILE" <<EOF
REGION="$REGION"
ALB_ARN="$ALB_ARN"
TG_MAIN="$TG_MAIN"
TG_A="$TG_A"
TG_B="$TG_B"
EC2_A="$EC2_A"
EC2_B="$EC2_B"
VPC_ID="$VPC_ID"
IGW_ID="$IGW_ID"
SUBNETS=("$PUB_2A" "$PUB_2B" "$PRIV_2A" "$PRIV_2B")
ROUTE_TABLES=("$RT_PUB" "$RT_PRIV")
SG_CACHE="$SG_CACHE"
SG_BACKEND="$SG_BACKEND"
SG_ALB="$SG_ALB"
EOF

aws ec2 wait instance-running --region "$REGION" --instance-ids "$EC2_A" "$EC2_B"
aws elbv2 register-targets --region "$REGION" --target-group-arn "$TG_MAIN" --targets "Id=$EC2_A" "Id=$EC2_B"
aws elbv2 register-targets --region "$REGION" --target-group-arn "$TG_A" --targets "Id=$EC2_A"
aws elbv2 register-targets --region "$REGION" --target-group-arn "$TG_B" --targets "Id=$EC2_B"

echo "[7/8] Waiting for SSM Online and Valkey available (~4-5 min)..."
for _ in $(seq 1 30); do
  CNT=$(aws ssm describe-instance-information --region "$REGION" \
    --filters "Key=InstanceIds,Values=${EC2_A},${EC2_B}" \
    --query "length(InstanceInformationList[?PingStatus=='Online'])" --output text)
  [[ "$CNT" == "2" ]] && break
  sleep 10
done

VALKEY_ENDPOINT=""
for i in $(seq 1 60); do
  OUT=$(aws elasticache describe-replication-groups --region "$REGION" --replication-group-id quizlab-valkey \
    --query "[ReplicationGroups[0].Status, ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address, ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Port]" \
    --output text)
  STATUS=$(echo "$OUT" | awk '{print $1}')
  ADDR=$(echo "$OUT" | awk '{print $2}')
  PORT=$(echo "$OUT" | awk '{print $3}')
  if [[ "$STATUS" == "available" && "$ADDR" != "None" && -n "$ADDR" ]]; then
    VALKEY_ENDPOINT="$ADDR"
    VALKEY_PORT="$PORT"
    break
  fi
  echo "  Valkey status=$STATUS (${i}0s)..."
  sleep 10
done

if [[ -z "$VALKEY_ENDPOINT" ]]; then
  echo "Timed out waiting for Valkey endpoint." >&2
  exit 1
fi

echo "[8/8] Deploying app container to EC2 A and B via SSM..."
TAR_FILE=$(mktemp --suffix=.tar.gz)
tar -czf "$TAR_FILE" -C "$SCRIPT_DIR" package.json Dockerfile .dockerignore src public

python3 - <<PYEOF
import base64, json, subprocess, time, urllib.request

AWS = 'aws'
REGION = '$REGION'
ALB_DNS = '$ALB_DNS'
EC2_A = '$EC2_A'
EC2_B = '$EC2_B'
TG_MAIN = '$TG_MAIN'
TG_A = '$TG_A'
TG_B = '$TG_B'
VALKEY_HOST = '$VALKEY_ENDPOINT'
VALKEY_PORT = '$VALKEY_PORT'

with open('$TAR_FILE', 'rb') as f:
    tar_b64 = base64.b64encode(f.read()).decode('ascii')

cmd_ids = []
for instance_id, backend_id in [(EC2_A, 'A'), (EC2_B, 'B')]:
    script = [
        "set -euo pipefail",
        "for i in \$(seq 1 40); do if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker; then break; fi; sleep 3; done",
        "systemctl is-active --quiet docker",
        "mkdir -p /opt/quizlab /etc/quizlab",
        "chmod 700 /etc/quizlab",
        f"echo '{tar_b64}' | base64 -d | tar -xzf - -C /opt/quizlab",
        f"PW=\$(aws ssm get-parameter --region {REGION} --name /quizlab/valkey_password --with-decryption --query Parameter.Value --output text)",
        "umask 077",
        "cat > /etc/quizlab/env <<ENVEOF",
        "PORT=3000",
        f"BACKEND_ID={backend_id}",
        f"VALKEY_HOST={VALKEY_HOST}",
        f"VALKEY_PORT={VALKEY_PORT}",
        "VALKEY_TLS=true",
        "VALKEY_USERNAME=quizlab",
        "VALKEY_PASSWORD=\${PW}",
        "VALKEY_TLS_REJECT_UNAUTHORIZED=true",
        "ENVEOF",
        "unset PW",
        "chmod 600 /etc/quizlab/env",
        "docker build -t quizlab:latest /opt/quizlab",
        "docker rm -f quizlab || true",
        "docker run -d --name quizlab --restart unless-stopped -p 3000:3000 --env-file /etc/quizlab/env quizlab:latest",
        "sleep 3",
        "curl -fsS http://127.0.0.1:3000/health",
        "echo ''",
        "curl -fsS http://127.0.0.1:3000/api/cache-status"
    ]
    out = subprocess.check_output([
        AWS, 'ssm', 'send-command', '--region', REGION,
        '--instance-ids', instance_id,
        '--document-name', 'AWS-RunShellScript',
        '--parameters', json.dumps({'commands': script}),
        '--query', 'Command.CommandId', '--output', 'text'
    ], text=True).strip()
    cmd_ids.append((instance_id, backend_id, out))

for instance_id, backend_id, cid in cmd_ids:
    for _ in range(45):
        res = json.loads(subprocess.check_output([
            AWS, 'ssm', 'get-command-invocation', '--region', REGION,
            '--command-id', cid, '--instance-id', instance_id, '--output', 'json'
        ], text=True))
        if res['Status'] in ('Success', 'Failed', 'TimedOut', 'Cancelled'):
            print(f"Deploy {backend_id}: {res['Status']}")
            if res['Status'] != 'Success':
                print(res.get('StandardErrorContent', '')[-800:])
                raise SystemExit(1)
            break
        time.sleep(5)

for _ in range(45):
    alb_st = json.loads(subprocess.check_output([
        AWS, 'elbv2', 'describe-load-balancers', '--region', REGION,
        '--load-balancer-arns', '$ALB_ARN', '--output', 'json'
    ], text=True))['LoadBalancers'][0]['State']['Code']
    def tg_st(arn):
        r = json.loads(subprocess.check_output([
            AWS, 'elbv2', 'describe-target-health', '--region', REGION,
            '--target-group-arn', arn, '--output', 'json'
        ], text=True))
        return {t['Target']['Id']: t['TargetHealth']['State'] for t in r['TargetHealthDescriptions']}
    m, a, b = tg_st(TG_MAIN), tg_st(TG_A), tg_st(TG_B)
    if alb_st == 'active' and m.get(EC2_A) == 'healthy' and m.get(EC2_B) == 'healthy' and a.get(EC2_A) == 'healthy' and b.get(EC2_B) == 'healthy':
        print("ALB active and all target groups healthy.")
        break
    time.sleep(5)

for path in ['/', '/health', '/lab/a/api/cache-status', '/lab/b/api/cache-status']:
    with urllib.request.urlopen(f"http://{ALB_DNS}{path}", timeout=6) as r:
        print(f"GET {path} -> HTTP {r.status}")
PYEOF
rm -f "$TAR_FILE"

echo ""
echo "========================================================"
echo "Deployment complete!"
echo "Web URL : http://$ALB_DNS/"
echo "EC2 A   : $EC2_A"
echo "EC2 B   : $EC2_B"
echo "Valkey  : ${VALKEY_ENDPOINT}:${VALKEY_PORT}"
echo "SSM A   : aws ssm start-session --region $REGION --target $EC2_A"
echo "Cleanup : $SCRIPT_DIR/cleanup-aws.sh --yes"
echo "========================================================"
