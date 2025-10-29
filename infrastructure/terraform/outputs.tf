# Terraform Outputs for SHIBA Infrastructure

# CloudFront
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "application_url" {
  description = "Public URL to access the application"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.main.domain_name}"
}

# Lambda
output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.app.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.app.arn
}

output "lambda_function_url" {
  description = "Lambda Function URL (direct access, bypasses CloudFront)"
  value       = aws_lambda_function_url.app.function_url
  sensitive   = true
}

output "lambda_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_exec.arn
}

# RDS
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Redis
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_replication_group.session_cache.configuration_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = 6379
}

# S3
output "s3_documents_bucket" {
  description = "S3 bucket for user documents"
  value       = aws_s3_bucket.documents.id
}

output "s3_static_assets_bucket" {
  description = "S3 bucket for static assets"
  value       = aws_s3_bucket.static_assets.id
}

# Secrets Manager
output "db_credentials_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "application_secrets_arn" {
  description = "ARN of the application secrets"
  value       = aws_secretsmanager_secret.application_secrets.arn
}

# VPC
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = aws_subnet.database[*].id
}

# Security Groups
output "lambda_security_group_id" {
  description = "Lambda security group ID"
  value       = aws_security_group.lambda.id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

# SNS (Production only)
output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  value       = var.environment == "production" ? aws_sns_topic.alerts[0].arn : null
}

# CI/CD IAM User (if created)
output "github_actions_access_key_id" {
  description = "Access key ID for GitHub Actions user"
  value       = var.create_cicd_user ? aws_iam_access_key.github_actions[0].id : null
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret access key for GitHub Actions user"
  value       = var.create_cicd_user ? aws_iam_access_key.github_actions[0].secret : null
  sensitive   = true
}

# CloudWatch Log Groups
output "lambda_log_group_name" {
  description = "CloudWatch Log Group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "state_code" {
  description = "State code"
  value       = var.state_code
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Cost Estimation (approximate monthly costs)
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    lambda = "~$30 (10K requests/day)"
    rds    = var.db_instance_class == "db.t3.small" ? "~$25" : "varies"
    redis  = var.redis_node_type == "cache.t3.micro" ? "~$12" : "varies"
    nat_gateway = "~$32"
    cloudfront  = "~$10 (1TB transfer)"
    s3          = "~$5 (50GB storage)"
    total       = "~$158/month (dev/staging)"
  }
}
