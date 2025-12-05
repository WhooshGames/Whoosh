# ElastiCache Redis Cluster
resource "aws_elasticache_subnet_group" "whoosh" {
  name       = "${local.name}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Redis from EKS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_elasticache_replication_group" "whoosh" {
  replication_group_id       = "${local.name}-redis"
  description                = "Redis cluster for Whoosh game state"
  
  engine                      = "redis"
  engine_version              = "7.1"
  node_type                   = var.redis_node_type
  port                        = 6379
  parameter_group_name        = "default.redis7"
  
  num_cache_clusters          = var.redis_num_nodes
  
  subnet_group_name           = aws_elasticache_subnet_group.whoosh.name
  security_group_ids          = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled  = true
  transit_encryption_enabled   = true
  auth_token                  = random_password.redis_auth_token.result
  
  automatic_failover_enabled  = true
  multi_az_enabled            = true
  
  snapshot_retention_limit    = 5
  snapshot_window             = "03:00-05:00"
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format      = "text"
    log_type        = "slow-log"
  }

  tags = local.tags
}

# Random auth token for Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

# Store Redis auth token in Secrets Manager
resource "aws_secretsmanager_secret" "redis_auth_token" {
  name = "${local.name}/redis/auth-token"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth_token.result
}

# CloudWatch Log Group for Redis
resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/elasticache/redis/${local.name}"
  retention_in_days = 7
  tags              = local.tags
}

# Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.whoosh.configuration_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.whoosh.port
}

