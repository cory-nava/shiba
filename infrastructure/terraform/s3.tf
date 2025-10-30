# S3 Buckets for Static Assets and Documents

# Static Assets Bucket (CSS, JS, Images)
resource "aws_s3_bucket" "static_assets" {
  bucket = "${local.full_name}-static-assets"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-static-assets"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Documents Bucket (User-uploaded PDFs and generated documents)
resource "aws_s3_bucket" "documents" {
  bucket = "${local.full_name}-documents"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-documents"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy for documents
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "archive-old-documents"
    status = "Enabled"

    filter {}

    transition {
      days          = var.document_lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# CORS configuration for documents bucket (for direct uploads from browser if needed)
resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["https://${var.domain_name}"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudWatch metric alarms for S3
resource "aws_cloudwatch_metric_alarm" "documents_4xx_errors" {
  alarm_name          = "${local.full_name}-s3-documents-4xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This metric monitors S3 4xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    BucketName = aws_s3_bucket.documents.id
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}
