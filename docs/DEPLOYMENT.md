# Whoosh Deployment Guide

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- kubectl >= 1.29
- AWS CLI configured
- Docker installed
- Access to GitHub repository

## Infrastructure Setup

### 1. Configure Terraform Backend

Edit `infrastructure/terraform/main.tf` and configure the S3 backend:

```hcl
backend "s3" {
  bucket = "whoosh-terraform-state"
  key    = "whoosh/terraform.tfstate"
  region = "us-east-1"
}
```

### 2. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

### 3. Create Terraform Variables File

Create `terraform.tfvars`:

```hcl
aws_region = "us-east-1"
cluster_name = "whoosh-cluster"
environment = "production"

django_node_min_size = 2
django_node_max_size = 10

go_node_min_size = 2
go_node_max_size = 20

aurora_min_capacity = 0.5
aurora_max_capacity = 128

redis_node_type = "cache.r7g.large"
redis_num_nodes = 3
```

### 4. Plan and Apply Infrastructure

```bash
terraform plan
terraform apply
```

This will create:
- VPC with public/private subnets
- EKS cluster with node groups
- Aurora PostgreSQL Serverless v2
- ElastiCache Redis cluster
- Global Accelerator
- IAM roles and policies

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --name whoosh-cluster --region us-east-1
```

### 6. Install AWS Load Balancer Controller

```bash
kubectl apply -f infrastructure/k8s/ingress/alb-controller.yaml
```

Update the IAM role ARN in the service account annotation.

## Application Deployment

### 1. Create ECR Repositories

```bash
aws ecr create-repository --repository-name whoosh-django-api --region us-east-1
aws ecr create-repository --repository-name whoosh-go-game-edge --region us-east-1
```

### 2. Build and Push Docker Images

**Django API:**
```bash
cd services/django-api
docker build -t whoosh-django-api:latest .
docker tag whoosh-django-api:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/whoosh-django-api:latest
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/whoosh-django-api:latest
```

**Go Game Edge:**
```bash
cd services/go-game-edge
docker build -t whoosh-go-game-edge:latest .
docker tag whoosh-go-game-edge:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/whoosh-go-game-edge:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/whoosh-go-game-edge:latest
```

### 3. Configure Kubernetes Secrets

Create secrets for database and Redis:

```bash
kubectl create secret generic django-secrets \
  --from-literal=db-host=<AURORA_ENDPOINT> \
  --from-literal=db-name=whoosh \
  --from-literal=db-user=postgres \
  --from-literal=db-password=<DB_PASSWORD>

kubectl create secret generic go-game-secrets \
  --from-literal=jwt-public-key="<JWT_PUBLIC_KEY>"
```

### 4. Update Kubernetes Manifests

Update the following files with actual values:
- `infrastructure/k8s/django/configmap.yaml` - Redis endpoint
- `infrastructure/k8s/go-game/configmap.yaml` - Redis endpoint
- `infrastructure/k8s/django/deployment.yaml` - ECR repository URL
- `infrastructure/k8s/go-game/deployment.yaml` - ECR repository URL

### 5. Deploy to Kubernetes

```bash
kubectl apply -f infrastructure/k8s/django/
kubectl apply -f infrastructure/k8s/go-game/
kubectl apply -f infrastructure/k8s/ingress/
```

### 6. Verify Deployment

```bash
kubectl get pods
kubectl get services
kubectl get ingress
```

### 7. Update Global Accelerator

After the ALB is created, get its ARN and update the Global Accelerator endpoint group:

```bash
ALB_ARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `whoosh`)].LoadBalancerArn' --output text)
ACCELERATOR_ARN=$(aws globalaccelerator list-accelerators --query 'Accelerators[?Name==`whoosh-accelerator`].AcceleratorArn' --output text)
LISTENER_ARN=$(aws globalaccelerator list-listeners --accelerator-arn $ACCELERATOR_ARN --query 'Listeners[0].ListenerArn' --output text)

aws globalaccelerator create-endpoint-group \
  --listener-arn $LISTENER_ARN \
  --endpoint-group-region us-east-1 \
  --endpoint-configurations EndpointId=$ALB_ARN
```

## CI/CD Setup

### 1. Create GitHub Connection

The Terraform will create a CodeStar connection. You need to complete it in the AWS Console:
1. Go to CodePipeline → Settings → Connections
2. Click on the connection
3. Click "Update pending connection"
4. Authorize GitHub

### 2. Create CodePipeline

The Terraform will create the pipeline, but you may need to trigger it manually the first time:

```bash
aws codepipeline start-pipeline-execution --name whoosh-pipeline
```

## Database Migrations

Run Django migrations:

```bash
kubectl exec -it deployment/django-api -- python manage.py migrate
```

## Monitoring

### View Logs

```bash
# Django API logs
kubectl logs -f deployment/django-api

# Go Game Edge logs
kubectl logs -f deployment/go-game-edge
```

### Check Metrics

```bash
# Pod metrics
kubectl top pods

# Node metrics
kubectl top nodes
```

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Database Connection Issues

Check security groups and ensure EKS nodes can reach Aurora.

### Redis Connection Issues

Verify Redis endpoint in ConfigMap and security group rules.

### ALB Not Created

Check AWS Load Balancer Controller logs:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment django-api --replicas=5
kubectl scale deployment go-game-edge --replicas=10
```

### Auto-scaling

HPA is configured automatically. Monitor with:
```bash
kubectl get hpa
```

## Updates

To update the application:

1. Push code to GitHub
2. CodePipeline will automatically build and deploy
3. Or manually trigger:
   ```bash
   aws codepipeline start-pipeline-execution --name whoosh-pipeline
   ```

## Rollback

To rollback to a previous version:

```bash
kubectl rollout undo deployment/django-api
kubectl rollout undo deployment/go-game-edge
```

