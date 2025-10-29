# Development Environment Configuration

environment = "dev"
aws_region  = "us-east-1"
state_code  = "MN"

# Domain Configuration
domain_name    = ""  # Use CloudFront default domain for dev
hosted_zone_id = ""

# Lambda Configuration
lambda_memory               = 2048  # Lower memory for dev
lambda_timeout              = 60
lambda_reserved_concurrency = -1

# Database Configuration
db_instance_class       = "db.t3.micro"
db_allocated_storage    = 20
db_max_allocated_storage = 30
db_backup_retention_days = 1
db_multi_az             = false

# Redis Configuration
redis_node_type         = "cache.t3.micro"
redis_num_cache_nodes   = 1
redis_enable_auth_token = false

# Monitoring
enable_enhanced_monitoring   = false
cloudwatch_log_retention_days = 3

# S3 Lifecycle
document_lifecycle_glacier_days = 30

# CloudFront
enable_cloudfront_invalidation = false

# CI/CD
create_cicd_user = false

# Tags
additional_tags = {
  CostCenter = "Engineering"
  Owner      = "Dev Team"
}
