# Lambda Function Configuration

# Lambda function
resource "aws_lambda_function" "app" {
  function_name = local.full_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "org.codeforamerica.shiba.StreamLambdaHandler::handleRequest"
  runtime       = "java17"

  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout

  # Placeholder - will be updated by CI/CD
  filename = "${path.module}/placeholder-lambda.zip"

  # Ephemeral storage (512MB is max when SnapStart is enabled)
  ephemeral_storage {
    size = 512 # Maximum allowed with SnapStart
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = var.environment
      AWS_REGION_NAME        = var.aws_region
      STATE_CODE             = var.state_code

      # Database connection
      DB_SECRET_ARN = aws_secretsmanager_secret.db_credentials.arn
      DATABASE_URL  = "jdbc:postgresql://${aws_db_instance.main.endpoint}/shiba?user=${jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]}&password=${urlencode(jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"])}"

      # S3 buckets
      S3_DOCUMENTS_BUCKET     = aws_s3_bucket.documents.id
      S3_STATIC_ASSETS_BUCKET = aws_s3_bucket.static_assets.id

      # Redis
      REDIS_ENDPOINT = aws_elasticache_replication_group.session_cache.configuration_endpoint_address

      # CloudFront (will be empty on first apply, can be updated later)
      CLOUDFRONT_DOMAIN = ""

      # Application secrets from Secrets Manager
      ENCRYPTION_KEY          = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["encryption_key"]
      MAILGUN_API_KEY         = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["mailgun_api_key"]
      SMARTY_STREET_AUTHTOKEN = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["smarty_streets_auth_token"]
      SMARTY_STREET_AUTHID    = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["smarty_streets_auth_id"]
      MNIT_FILENET_USERNAME   = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["document_submission_username"]
      MNIT_FILENET_PASSWORD   = jsondecode(aws_secretsmanager_secret_version.application_secrets.secret_string)["document_submission_password"]

      # Demo/placeholder values for OAuth (update these in production)
      GOOGLE_CLIENT_ID       = "demo-client-id"
      GOOGLE_CLIENT_SECRET   = "demo-client-secret"
      AZURE_AD_CLIENT_ID     = "demo-azure-id"
      AZURE_AD_CLIENT_SECRET = "demo-azure-secret"
      AZURE_AD_TENANT_ID     = "demo-tenant-id"
      MIXPANEL_API_KEY       = "demo-mixpanel-key"

      # Application URL - use ALB for now
      MNBENEFITS_ENV_URL = "http://${aws_lb.main.dns_name}"

      # Keystore configuration
      CLIENT_KEYSTORE            = "shiba-keystore.jks"
      CLIENT_TRUSTSTORE          = "shiba-truststore.jks"
      CLIENT_KEYSTORE_PASSWORD   = "changeit"
      CLIENT_TRUSTSTORE_PASSWORD = "changeit"

      # Java options
      JAVA_TOOL_OPTIONS = "-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # Enable SnapStart for faster cold starts (Java 11+)
  snap_start {
    apply_on = "PublishedVersions"
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.full_name
    }
  )

  # Ignore changes made by CI/CD
  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      last_modified,
      qualified_arn,
      version
    ]
  }
}

# Publish new version for SnapStart
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.app.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# Lambda Function URL (simpler than ALB for this use case)
resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = var.domain_name != "" ? ["https://${var.domain_name}"] : ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 86400
  }
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.full_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-logs"
    }
  )
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.full_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors Lambda function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.full_name}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors Lambda function throttling"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${local.full_name}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 50000 # 50 seconds
  alarm_description   = "This metric monitors Lambda function duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}

# SNS Topic for Alerts (production only)
resource "aws_sns_topic" "alerts" {
  count = var.environment == "production" ? 1 : 0
  name  = "${local.full_name}-alerts"

  tags = local.common_tags
}

# Create placeholder Lambda zip for initial deployment
resource "null_resource" "create_placeholder_lambda" {
  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.module}
cat > ${path.module}/placeholder.txt << 'PLACEHOLDER'
This is a placeholder Lambda package.
It will be replaced by the actual application package during CI/CD deployment.
PLACEHOLDER
cd ${path.module}
zip placeholder-lambda.zip placeholder.txt
rm placeholder.txt
EOF
  }

  triggers = {
    always_run = timestamp()
  }
}
