#!/bin/bash
# Script to pause all AWS services to save costs

set -e

REGION="us-east-1"
PROFILE="Whoosh"

echo "=== Pausing Whoosh AWS Services ==="
echo ""

# 1. Scale down Kubernetes deployments to 0
echo "1. Scaling down Kubernetes deployments..."
kubectl scale deployment django-api --replicas=0 2>/dev/null || echo "  - django-api already scaled or not found"
kubectl scale deployment go-game-edge --replicas=0 2>/dev/null || echo "  - go-game-edge already scaled or not found"
echo "  ✓ Kubernetes deployments scaled to 0"
echo ""

# 2. Scale down EKS node groups to 0
echo "2. Scaling down EKS node groups..."
aws eks update-nodegroup-config \
    --cluster-name whoosh-cluster \
    --nodegroup-name django-nodes \
    --scaling-config minSize=0,maxSize=0,desiredSize=0 \
    --region $REGION \
    --profile $PROFILE 2>/dev/null || echo "  - django-nodes already scaled or not found"

aws eks update-nodegroup-config \
    --cluster-name whoosh-cluster \
    --nodegroup-name go-nodes \
    --scaling-config minSize=0,maxSize=0,desiredSize=0 \
    --region $REGION \
    --profile $PROFILE 2>/dev/null || echo "  - go-nodes already scaled or not found"
echo "  ✓ EKS node groups scaled to 0"
echo ""

# 3. Stop RDS instance (keeps data, can restart later)
echo "3. Stopping RDS database instance..."
aws rds stop-db-instance \
    --db-instance-identifier whoosh-postgres \
    --region $REGION \
    --profile $PROFILE 2>/dev/null && echo "  ✓ RDS instance stopping..." || echo "  - RDS instance already stopped or not found"
echo ""

# 4. Delete ElastiCache cluster (can recreate later)
echo "4. Deleting ElastiCache Redis cluster..."
aws elasticache delete-replication-group \
    --replication-group-id whoosh-redis \
    --region $REGION \
    --profile $PROFILE 2>/dev/null && echo "  ✓ ElastiCache cluster deletion initiated..." || echo "  - ElastiCache cluster already deleted or not found"
echo ""

# 5. Note about ALB (minimal cost when idle, but can be deleted)
echo "5. ALB (Application Load Balancer)"
echo "  Note: ALB has minimal cost when idle (~$16/month)."
echo "  To delete ALB, you would need to delete the Ingress resource:"
echo "    kubectl delete ingress whoosh-ingress"
echo ""

echo "=== Services Paused ==="
echo ""
echo "To resume services later, run: ./scripts/resume-services.sh"
echo ""
echo "Estimated cost savings:"
echo "  - EKS Nodes (4x t3.small): ~$60/month"
echo "  - RDS (db.t3.small): ~$30/month (stopped, storage only: ~$2/month)"
echo "  - ElastiCache (cache.t3.small): ~$15/month"
echo "  Total: ~$103/month saved (RDS storage ~$2/month still charged)"

