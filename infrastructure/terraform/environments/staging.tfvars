# Staging Environment Configuration

environment = "staging"
aws_region  = "us-east-1"
state_code  = "MN"

# Domain Configuration
domain_name    = "staging.mnbenefits.org"  # Update with actual domain
hosted_zone_id = ""                        # Update with Route53 hosted zone ID

# Lambda Configuration
lambda_memory               = 3008  # Maximum for Java
lambda_timeout              = 60
lambda_reserved_concurrency = -1    # Unreserved

# Database Configuration
db_instance_class       = "db.t3.small"
db_allocated_storage    = 20
db_max_allocated_storage = 50
db_backup_retention_days = 7
db_multi_az             = false

# Redis Configuration
redis_node_type         = "cache.t3.micro"
redis_num_cache_nodes   = 1
redis_enable_auth_token = false

# Monitoring
enable_enhanced_monitoring   = false
cloudwatch_log_retention_days = 7

# S3 Lifecycle
document_lifecycle_glacier_days = 90

# CloudFront
enable_cloudfront_invalidation = true

# CI/CD
create_cicd_user = true

# Tags
additional_tags = {
  CostCenter = "Engineering"
  Owner      = "Platform Team"
}
