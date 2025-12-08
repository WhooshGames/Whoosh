#!/bin/bash
# Script to resume all AWS services

set -e

REGION="us-east-1"
PROFILE="Whoosh"

echo "=== Resuming Whoosh AWS Services ==="
echo ""

# 1. Start RDS instance
echo "1. Starting RDS database instance..."
aws rds start-db-instance \
    --db-instance-identifier whoosh-postgres \
    --region $REGION \
    --profile $PROFILE 2>/dev/null && echo "  ✓ RDS instance starting (takes ~5-10 minutes)..." || echo "  - RDS instance already running or not found"
echo ""

# 2. Wait for RDS to be available (optional, can skip)
echo "2. Waiting for RDS to be available..."
echo "  (This may take 5-10 minutes. You can skip this and continue.)"
read -p "  Wait for RDS? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  Waiting for RDS to be available..."
    aws rds wait db-instance-available \
        --db-instance-identifier whoosh-postgres \
        --region $REGION \
        --profile $PROFILE
    echo "  ✓ RDS is available"
else
    echo "  Skipping wait. Make sure RDS is available before scaling up nodes."
fi
echo ""

# 3. Recreate ElastiCache (if deleted)
echo "3. ElastiCache Redis cluster"
echo "  Note: If ElastiCache was deleted, you need to recreate it with Terraform:"
echo "    cd infrastructure/terraform"
echo "    terraform apply -target=aws_elasticache_replication_group.whoosh"
echo "  Or recreate the entire infrastructure:"
echo "    terraform apply"
echo ""

# 4. Scale up EKS node groups
echo "4. Scaling up EKS node groups..."
aws eks update-nodegroup-config \
    --cluster-name whoosh-cluster \
    --nodegroup-name django-nodes \
    --scaling-config minSize=2,maxSize=10,desiredSize=2 \
    --region $REGION \
    --profile $PROFILE 2>/dev/null && echo "  ✓ django-nodes scaling up..." || echo "  - django-nodes not found"

aws eks update-nodegroup-config \
    --cluster-name whoosh-cluster \
    --nodegroup-name go-nodes \
    --scaling-config minSize=2,maxSize=20,desiredSize=2 \
    --region $REGION \
    --profile $PROFILE 2>/dev/null && echo "  ✓ go-nodes scaling up..." || echo "  - go-nodes not found"
echo ""

# 5. Wait for nodes to be ready
echo "5. Waiting for nodes to be ready..."
echo "  (This may take 3-5 minutes)"
sleep 30
kubectl wait --for=condition=Ready nodes --all --timeout=300s 2>/dev/null || echo "  - Some nodes may still be starting"
echo ""

# 6. Scale up Kubernetes deployments
echo "6. Scaling up Kubernetes deployments..."
kubectl scale deployment django-api --replicas=2 2>/dev/null && echo "  ✓ django-api scaling up..." || echo "  - django-api not found"
kubectl scale deployment go-game-edge --replicas=2 2>/dev/null && echo "  ✓ go-game-edge scaling up..." || echo "  - go-game-edge not found"
echo ""

echo "=== Services Resumed ==="
echo ""
echo "Note: It may take a few minutes for all services to be fully operational."
echo "Check status with:"
echo "  kubectl get pods"
echo "  kubectl get nodes"

