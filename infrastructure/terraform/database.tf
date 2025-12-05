# Random password for database
resource "random_password" "db_master_password" {
  length  = 16
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.name}/database/password"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_master_password.result
}

# Aurora PostgreSQL Serverless v2
resource "aws_rds_cluster" "whoosh" {
  cluster_identifier      = "${local.name}-aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "16.1"
  database_name           = "whoosh"
  master_username         = "postgres"
  master_password         = random_password.db_master_password.result
  db_subnet_group_name    = aws_db_subnet_group.whoosh.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  
  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot    = false
  final_snapshot_identifier = "${local.name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.tags
}

resource "aws_rds_cluster_instance" "whoosh" {
  identifier         = "${local.name}-aurora-instance-1"
  cluster_identifier = aws_rds_cluster.whoosh.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.whoosh.engine
  engine_version     = aws_rds_cluster.whoosh.engine_version

  tags = local.tags
}

resource "aws_db_subnet_group" "whoosh" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
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

# Outputs
output "db_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.whoosh.endpoint
  sensitive   = true
}

output "db_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.whoosh.reader_endpoint
  sensitive   = true
}

