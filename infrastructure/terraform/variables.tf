variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "whoosh-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "django_node_min_size" {
  description = "Minimum number of Django nodes"
  type        = number
  default     = 2
}

variable "django_node_max_size" {
  description = "Maximum number of Django nodes"
  type        = number
  default     = 10
}

variable "go_node_min_size" {
  description = "Minimum number of Go nodes"
  type        = number
  default     = 2
}

variable "go_node_max_size" {
  description = "Maximum number of Go nodes"
  type        = number
  default     = 20
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 128
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.r7g.large"
}

variable "redis_num_nodes" {
  description = "Number of Redis nodes"
  type        = number
  default     = 3
}

