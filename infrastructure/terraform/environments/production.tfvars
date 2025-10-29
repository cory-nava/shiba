# Production Environment Configuration

environment = "production"
aws_region  = "us-east-1"
state_code  = "MN"

# Domain Configuration
domain_name    = "apply.mnbenefits.org"  # Update with actual domain
hosted_zone_id = ""                      # Update with Route53 hosted zone ID

# Lambda Configuration
lambda_memory               = 3008  # Maximum for Java
lambda_timeout              = 60
lambda_reserved_concurrency = 100   # Reserve capacity for production

# Database Configuration
db_instance_class       = "db.t3.medium"
db_allocated_storage    = 50
db_max_allocated_storage = 200
db_backup_retention_days = 30
db_multi_az             = true  # High availability

# Redis Configuration
redis_node_type         = "cache.t3.small"
redis_num_cache_nodes   = 2           # Multi-node for failover
redis_enable_auth_token = true        # Enhanced security

# Monitoring
enable_enhanced_monitoring   = true
cloudwatch_log_retention_days = 30

# S3 Lifecycle
document_lifecycle_glacier_days = 90

# CloudFront
enable_cloudfront_invalidation = true

# CI/CD
create_cicd_user = true

# Tags
additional_tags = {
  CostCenter  = "Operations"
  Owner       = "Platform Team"
  Compliance  = "PII"
  Criticality = "High"
}
