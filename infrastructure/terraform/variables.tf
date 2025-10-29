# SHIBA Terraform Variables

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production"
  }
}

variable "aws_region" {
  description = "AWS region for main resources"
  type        = string
  default     = "us-east-1"
}

variable "state_code" {
  description = "State code (e.g., MN, CA, TX)"
  type        = string
  default     = "MN"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  # Example: "staging.mnbenefits.org" or "apply.mnbenefits.org"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
  default     = ""
}

# Lambda Configuration
variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 3008  # Maximum for Java
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 60  # Max for Lambda Function URL
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions"
  type        = number
  default     = -1  # -1 means unreserved
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Initial database storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum database storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# Redis/ElastiCache Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_enable_auth_token" {
  description = "Enable Redis AUTH token"
  type        = bool
  default     = false
}

# Monitoring
variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring for RDS"
  type        = bool
  default     = false
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

# S3 Lifecycle
variable "document_lifecycle_glacier_days" {
  description = "Days before moving documents to Glacier"
  type        = number
  default     = 90
}

# Cost Optimization
variable "use_fargate_spot" {
  description = "Use Fargate Spot for cost savings (if using ECS)"
  type        = bool
  default     = false
}

# CloudFront Configuration
variable "enable_cloudfront_invalidation" {
  description = "Enable Lambda to invalidate CloudFront cache"
  type        = bool
  default     = false
}

# CI/CD Configuration
variable "create_cicd_user" {
  description = "Create IAM user for CI/CD (GitHub Actions)"
  type        = bool
  default     = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
