#!/usr/bin/env bash
set -euo pipefail

# Cleanup script strictly for resources created for Project=quiz-service-seminar in ap-southeast-2.
# Usage: ./cleanup-aws.sh --yes

if [[ "${1:-}" != "--yes" ]]; then
  echo "Refusing to delete AWS resources without --yes flag."
  echo "Usage: $0 --yes"
  exit 1
fi

export PATH="$HOME/.local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="ap-southeast-2"

ALB_ARN="arn:aws:elasticloadbalancing:ap-southeast-2:493093379780:loadbalancer/app/quizlab-alb/52483b687e167356"
TG_MAIN="arn:aws:elasticloadbalancing:ap-southeast-2:493093379780:targetgroup/quizlab-tg-main/f05fa96a666f818f"
TG_A="arn:aws:elasticloadbalancing:ap-southeast-2:493093379780:targetgroup/quizlab-tg-a/f27311f773a7ea92"
TG_B="arn:aws:elasticloadbalancing:ap-southeast-2:493093379780:targetgroup/quizlab-tg-b/e1b0d17d40afe658"

EC2_A="i-0cca77524a1964c16"
EC2_B="i-0ccf80b64328d1526"

VPC_ID="vpc-0ef86bf0b601de975"
IGW_ID="igw-038e8ffb953796db9"
SUBNETS=("subnet-073c999af56a95c0b" "subnet-0644bedb5397a6153" "subnet-07949064af01a3939" "subnet-093534aa4d586dc05")
ROUTE_TABLES=("rtb-02a64f7cdd79309b9" "rtb-06c6510df171026dd")
SG_CACHE="sg-0d62598f5f395beb9"
SG_BACKEND="sg-04448c78b976fe9d4"
SG_ALB="sg-0e4de45ba1e80ee23"

if [[ -f "$SCRIPT_DIR/.deploy-state.env" ]]; then
  echo "Loading resource IDs from $SCRIPT_DIR/.deploy-state.env..."
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.deploy-state.env"
fi

echo "[1/5] Deleting ALB and Target Groups..."
aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ALB_ARN" 2>/dev/null || true
aws elbv2 wait load-balancers-deleted --region "$REGION" --load-balancer-arns "$ALB_ARN" 2>/dev/null || sleep 15
for tg in "$TG_MAIN" "$TG_A" "$TG_B"; do
  aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg" 2>/dev/null || true
done

echo "[2/5] Deleting ElastiCache Valkey replication group, RBAC, and SSM parameter..."
aws elasticache delete-replication-group --region "$REGION" --replication-group-id quizlab-valkey 2>/dev/null || true
aws ssm delete-parameter --region "$REGION" --name /quizlab/valkey_password 2>/dev/null || true

echo "[3/5] Terminating EC2 instances A and B..."
aws ec2 terminate-instances --region "$REGION" --instance-ids "$EC2_A" "$EC2_B" 2>/dev/null || true

echo "Waiting for Valkey replication group deletion..."
for _ in $(seq 1 60); do
  if ! aws elasticache describe-replication-groups --region "$REGION" --replication-group-id quizlab-valkey >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

aws elasticache delete-cache-subnet-group --region "$REGION" --cache-subnet-group-name quizlab-cache-subnet-group 2>/dev/null || true
aws elasticache delete-user-group --region "$REGION" --user-group-id quizlab-user-group 2>/dev/null || true
for _ in $(seq 1 20); do
  if ! aws elasticache describe-user-groups --region "$REGION" --user-group-id quizlab-user-group >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
aws elasticache delete-user --region "$REGION" --user-id quizlab-app 2>/dev/null || true
aws elasticache delete-user --region "$REGION" --user-id quizlab-default-off 2>/dev/null || true

echo "Waiting for EC2 A and B termination..."
aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$EC2_A" "$EC2_B" 2>/dev/null || true

echo "[4/5] Deleting Security Groups, Subnets, Route Tables, IGW, and VPC..."
# Wait a bit for ALB/ElastiCache ENIs to be fully released
sleep 15
for sg in "$SG_CACHE" "$SG_BACKEND" "$SG_ALB"; do
  for _ in $(seq 1 10); do
    if aws ec2 delete-security-group --region "$REGION" --group-id "$sg" 2>/dev/null; then
      break
    fi
    sleep 5
  done
done

aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" 2>/dev/null || true
aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID" 2>/dev/null || true

for sn in "${SUBNETS[@]}"; do
  aws ec2 delete-subnet --region "$REGION" --subnet-id "$sn" 2>/dev/null || true
done

for rt in "${ROUTE_TABLES[@]}"; do
  ASSOCS=$(aws ec2 describe-route-tables --region "$REGION" --route-table-ids "$rt" --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" --output text 2>/dev/null || true)
  for assoc in $ASSOCS; do
    aws ec2 disassociate-route-table --region "$REGION" --association-id "$assoc" 2>/dev/null || true
  done
  aws ec2 delete-route-table --region "$REGION" --route-table-id "$rt" 2>/dev/null || true
done

aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID" 2>/dev/null || true

echo "[5/5] Deleting IAM instance profile and role..."
aws iam remove-role-from-instance-profile --instance-profile-name quizlab-ec2-ssm-profile --role-name quizlab-ec2-ssm-role 2>/dev/null || true
aws iam delete-instance-profile --instance-profile-name quizlab-ec2-ssm-profile 2>/dev/null || true
aws iam delete-role-policy --role-name quizlab-ec2-ssm-role --policy-name quizlab-read-valkey-param 2>/dev/null || true
aws iam detach-role-policy --role-name quizlab-ec2-ssm-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>/dev/null || true
aws iam delete-role --role-name quizlab-ec2-ssm-role 2>/dev/null || true

rm -f "$SCRIPT_DIR/.deploy-state.env"

echo "Cleanup completed. Verify no quizlab resources remain in $REGION:"
echo "aws ec2 describe-vpcs --region $REGION --filters Name=tag:Project,Values=quiz-service-seminar"
echo "aws elbv2 describe-load-balancers --region $REGION"
echo "aws elasticache describe-replication-groups --region $REGION"
