# ElastiCache Redis for Session Management

resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.full_name}-cache-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-cache-subnet"
    }
  )
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${local.full_name}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-redis7"
    }
  )
}

resource "aws_elasticache_replication_group" "session_cache" {
  replication_group_id = local.full_name
  description          = "Redis cache for SHIBA sessions and config"

  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_nodes
  port                 = 6379

  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  automatic_failover_enabled = var.redis_num_cache_nodes > 1
  multi_az_enabled           = var.redis_num_cache_nodes > 1 && var.environment == "production"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = var.environment == "production" ? 5 : 1

  auto_minor_version_upgrade = true

  tags = merge(
    local.common_tags,
    {
      Name = local.full_name
    }
  )
}

# CloudWatch Alarms for Redis
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${local.full_name}-redis-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "Redis CPU utilization is too high"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.session_cache.id
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${local.full_name}-redis-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Redis memory usage is too high"

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.session_cache.id
  }

  alarm_actions = var.environment == "production" ? [aws_sns_topic.alerts[0].arn] : []

  tags = local.common_tags
}
