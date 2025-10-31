# Application Load Balancer for Lambda

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${local.full_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-alb-sg"
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.full_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.environment == "production" ? true : false
  enable_http2               = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-alb"
    }
  )
}

# Target Group for Lambda
resource "aws_lb_target_group" "lambda" {
  name        = "${local.full_name}-lambda-tg"
  target_type = "lambda"

  # Lambda target groups don't use traditional health checks
  # Health check configuration is ignored for Lambda targets

  # Enable multi-value headers - SpringBootLambdaContainerHandler requires this to properly set Content-Type
  # See: https://github.com/awslabs/aws-serverless-java-container/issues/347
  lambda_multi_value_headers_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.full_name}-lambda-tg"
    }
  )
}

# Attach Lambda to Target Group
resource "aws_lb_target_group_attachment" "lambda" {
  target_group_arn = aws_lb_target_group.lambda.arn
  target_id        = aws_lambda_function.app.arn
  depends_on       = [aws_lambda_permission.alb]
}

# HTTP Listener
# Note: For internal CloudFront->ALB communication, HTTP is acceptable
# Users still connect to CloudFront via HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda.arn
  }

  tags = local.common_tags
}

# Lambda permission for ALB
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda.arn
}

# Output the ALB URL
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Application Load Balancer DNS name"
}

output "alb_url" {
  value       = "http://${aws_lb.main.dns_name}"
  description = "Application Load Balancer URL"
}
