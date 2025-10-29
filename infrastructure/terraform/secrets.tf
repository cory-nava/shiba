# AWS Secrets Manager for Sensitive Configuration

# Database Credentials Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.full_name}-db-credentials"
  description = "Database credentials for SHIBA ${var.environment}"

  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-db-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.db_password.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
    url      = "jdbc:postgresql://${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
  })
}

# Application Secrets (API keys, encryption keys, etc.)
resource "aws_secretsmanager_secret" "application_secrets" {
  name        = "${local.full_name}-application-secrets"
  description = "Application secrets for SHIBA ${var.environment}"

  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-application-secrets"
    }
  )
}

resource "aws_secretsmanager_secret_version" "application_secrets" {
  secret_id = aws_secretsmanager_secret.application_secrets.id
  secret_string = jsonencode({
    # Encryption key for JSONB PII data
    encryption_key = random_password.encryption_key.result

    # CloudFront origin verification
    cloudfront_secret = random_password.cloudfront_secret.result

    # Client secret for encryption (used in Spring Boot)
    client_secret = random_password.client_secret.result

    # Redis auth token (if enabled)
    redis_auth_token = ""

    # Mailgun API key (to be set manually or via CI/CD)
    mailgun_api_key = ""

    # Smarty Streets API key (to be set manually or via CI/CD)
    smarty_streets_auth_id = ""
    smarty_streets_auth_token = ""

    # Document submission API credentials (to be set manually)
    document_submission_username = ""
    document_submission_password = ""

    # Any other sensitive configuration
    session_secret = random_password.session_secret.result
  })

  lifecycle {
    ignore_changes = [
      # Allow manual updates to API keys without Terraform overwriting
      secret_string
    ]
  }
}

# Random passwords for various secrets
resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

resource "random_password" "client_secret" {
  length  = 64
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "session_secret" {
  length  = 32
  special = false
}

# Redis Configuration (if auth token is needed)
resource "aws_secretsmanager_secret" "redis_config" {
  count       = var.redis_enable_auth_token ? 1 : 0
  name        = "${local.full_name}-redis-config"
  description = "Redis configuration for SHIBA ${var.environment}"

  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-redis-config"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis_config" {
  count     = var.redis_enable_auth_token ? 1 : 0
  secret_id = aws_secretsmanager_secret.redis_config[0].id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth_token[0].result
    endpoint   = aws_elasticache_replication_group.session_cache.configuration_endpoint_address
    port       = 6379
  })
}

resource "random_password" "redis_auth_token" {
  count   = var.redis_enable_auth_token ? 1 : 0
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# CloudWatch Log Group for Secrets Manager audit
resource "aws_cloudwatch_log_group" "secrets_audit" {
  name              = "/aws/secretsmanager/${local.full_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-secrets-audit"
    }
  )
}
