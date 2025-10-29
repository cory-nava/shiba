# SHIBA AWS Lambda Infrastructure

This directory contains the Terraform infrastructure code and deployment documentation for deploying SHIBA to AWS Lambda with CloudFront.

## Architecture Overview

The serverless architecture uses:

- **AWS Lambda** with Java 17 runtime for application hosting
- **Amazon CloudFront** for CDN and global content delivery
- **Amazon RDS** PostgreSQL 15 for database
- **Amazon ElastiCache** Redis 7.0 for session management
- **Amazon S3** for static assets and document storage
- **AWS Secrets Manager** for secure credential management
- **VPC** with NAT Gateway for Lambda networking

## Directory Structure

```
infrastructure/
├── terraform/
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Variable definitions
│   ├── vpc.tf                   # VPC and networking
│   ├── lambda.tf                # Lambda function
│   ├── rds.tf                   # PostgreSQL database
│   ├── elasticache.tf           # Redis cache
│   ├── s3.tf                    # S3 buckets
│   ├── cloudfront.tf            # CloudFront distribution
│   ├── iam.tf                   # IAM roles and policies
│   ├── secrets.tf               # Secrets Manager
│   ├── outputs.tf               # Terraform outputs
│   └── environments/
│       ├── dev.tfvars           # Dev environment config
│       ├── staging.tfvars       # Staging environment config
│       └── production.tfvars    # Production environment config
└── README.md                    # This file
```

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **AWS CLI** >= 2.0
- **Java 17** (for building Lambda package)
- **Gradle** (included via wrapper)

### AWS Setup

1. **Create S3 bucket for Terraform state:**
   ```bash
   aws s3 mb s3://shiba-terraform-state --region us-east-1
   ```

2. **Create DynamoDB table for state locking:**
   ```bash
   aws dynamodb create-table \
     --table-name shiba-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
     --region us-east-1
   ```

3. **Enable S3 versioning:**
   ```bash
   aws s3api put-bucket-versioning \
     --bucket shiba-terraform-state \
     --versioning-configuration Status=Enabled
   ```

### GitHub Secrets

Configure the following secrets in your GitHub repository:

**For Staging:**
- `AWS_ACCESS_KEY_ID` - AWS access key for staging
- `AWS_SECRET_ACCESS_KEY` - AWS secret key for staging

**For Production:**
- `AWS_ACCESS_KEY_ID_PROD` - AWS access key for production
- `AWS_SECRET_ACCESS_KEY_PROD` - AWS secret key for production

## Initial Deployment

### Step 1: Configure Environment

Edit the appropriate tfvars file in `terraform/environments/`:

```hcl
# Example: staging.tfvars
environment = "staging"
domain_name = "staging.mnbenefits.org"
hosted_zone_id = "Z1234567890ABC"  # Your Route53 zone ID
```

### Step 2: Deploy Infrastructure

```bash
cd infrastructure/terraform

# Initialize Terraform
terraform init \
  -backend-config="bucket=shiba-terraform-state" \
  -backend-config="key=shiba-staging/terraform.tfstate" \
  -backend-config="region=us-east-1"

# Plan the deployment
terraform plan -var-file="environments/staging.tfvars"

# Apply the infrastructure
terraform apply -var-file="environments/staging.tfvars"
```

This will create:
- VPC with public, private, and database subnets
- Lambda function (with placeholder code)
- RDS PostgreSQL database
- ElastiCache Redis cluster
- S3 buckets for documents and static assets
- CloudFront distribution
- IAM roles and policies
- Secrets Manager secrets

### Step 3: Get Infrastructure Outputs

```bash
terraform output -json > outputs.json
```

Key outputs:
- `application_url` - CloudFront URL for the application
- `lambda_function_name` - Lambda function name
- `cloudfront_distribution_id` - CloudFront distribution ID
- `s3_static_assets_bucket` - S3 bucket for static files

### Step 4: Deploy Application Code

Use GitHub Actions to deploy the application:

1. **Trigger deployment workflow:**
   - Go to Actions tab in GitHub
   - Select "Deploy to AWS Lambda (Staging)"
   - Click "Run workflow"

2. **Or deploy manually:**
   ```bash
   # Build Lambda package
   ./gradlew clean buildLambda

   # Get Lambda function name
   FUNCTION_NAME=$(terraform output -raw lambda_function_name)

   # Update Lambda code
   aws lambda update-function-code \
     --function-name $FUNCTION_NAME \
     --zip-file fileb://build/distributions/shiba-lambda-0.0.1-SNAPSHOT.zip \
     --publish

   # Upload static assets
   BUCKET_NAME=$(terraform output -raw s3_static_assets_bucket)
   aws s3 sync src/main/resources/static s3://$BUCKET_NAME/
   ```

### Step 5: Run Database Migrations

Database migrations run automatically on Lambda startup via Flyway. Monitor CloudWatch Logs:

```bash
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
aws logs tail "/aws/lambda/$FUNCTION_NAME" --follow
```

### Step 6: Configure Secrets

Update application secrets in AWS Secrets Manager:

```bash
# Get secret ARN
SECRET_ARN=$(terraform output -raw application_secrets_arn)

# Update secret with actual values
aws secretsmanager put-secret-value \
  --secret-id $SECRET_ARN \
  --secret-string '{
    "mailgun_api_key": "your-mailgun-key",
    "smarty_streets_auth_id": "your-smarty-id",
    "smarty_streets_auth_token": "your-smarty-token"
  }'
```

## Deployment Workflows

### Staging Deployment

Automatically triggers on push to `main` branch:

```yaml
# .github/workflows/deploy-lambda-staging.yml
on:
  push:
    branches: [main]
```

Workflow steps:
1. Run full test suite (10 parallel jobs)
2. Build Lambda package
3. Deploy to Lambda
4. Upload static assets to S3
5. Invalidate CloudFront cache
6. Run smoke tests

### Production Deployment

Manual trigger with confirmation:

```yaml
# .github/workflows/deploy-lambda-production.yml
on:
  workflow_dispatch:
    inputs:
      confirm-production:
        required: true
```

Additional production safeguards:
- Requires typing "deploy-to-production" to confirm
- Creates backup of current Lambda version
- Automatic rollback on smoke test failure
- Creates git tags for deployments

### Terraform Infrastructure Updates

Update infrastructure via GitHub Actions:

1. Go to Actions → "Terraform Apply"
2. Select environment (dev/staging/production)
3. Select action (plan/apply/destroy)
4. Run workflow

## Cost Optimization

### Estimated Monthly Costs

**Staging/Dev Environment:** ~$158/month
- Lambda: $30 (10K requests/day)
- RDS db.t3.small: $25
- ElastiCache t3.micro: $12
- NAT Gateway: $32
- CloudFront: $10
- S3: $5
- Other: $44

**Production Environment:** ~$280/month
- Lambda: $60 (20K requests/day)
- RDS db.t3.medium Multi-AZ: $100
- ElastiCache t3.small x2: $48
- NAT Gateway: $32
- CloudFront: $20
- S3: $10
- Other: $10

### Cost Reduction Tips

1. **Use AWS Free Tier** (first year):
   - Lambda: 1M requests/month free
   - S3: 5GB storage free
   - CloudFront: 1TB transfer free

2. **Remove NAT Gateway** for dev:
   - Remove Lambda VPC config
   - Use public subnet for Lambda
   - Saves $32/month

3. **Use Aurora Serverless v2** for production:
   - Scales down to 0.5 ACU when idle
   - Potentially cheaper for variable workloads

4. **Enable S3 Intelligent Tiering**:
   - Automatically moves infrequently accessed objects to cheaper tiers

## Monitoring

### CloudWatch Dashboards

View Lambda metrics:
```bash
aws cloudwatch get-dashboard --dashboard-name shiba-staging
```

Key metrics:
- Lambda invocations
- Lambda errors
- Lambda duration
- RDS CPU utilization
- RDS database connections
- Redis CPU utilization
- CloudFront cache hit ratio

### Alarms

Production environment includes alarms for:
- Lambda errors > 10 in 5 minutes
- Lambda throttles > 5 in 5 minutes
- Lambda duration > 50 seconds
- RDS CPU > 80%
- RDS storage < 5GB
- RDS connections > 80
- Redis CPU > 75%
- Redis memory > 90%

Alarms send notifications to SNS topic (production only).

### Logs

View Lambda logs:
```bash
aws logs tail /aws/lambda/shiba-staging --follow
```

View RDS logs:
```bash
aws rds describe-db-log-files --db-instance-identifier shiba-staging
aws rds download-db-log-file-portion \
  --db-instance-identifier shiba-staging \
  --log-file-name error/postgresql.log.2024-01-20-00
```

## Troubleshooting

### Lambda Cold Starts

If cold starts are too slow (>5 seconds):

1. **Enable SnapStart** (already configured):
   ```hcl
   snap_start {
     apply_on = "PublishedVersions"
   }
   ```

2. **Increase Lambda memory** (already at max 3GB):
   ```hcl
   memory_size = 3008
   ```

3. **Use Provisioned Concurrency** (costs extra):
   ```bash
   aws lambda put-provisioned-concurrency-config \
     --function-name shiba-staging \
     --provisioned-concurrent-executions 2 \
     --qualifier live
   ```

### Database Connection Issues

If Lambda can't connect to RDS:

1. **Check security group rules**:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids $(terraform output -raw rds_security_group_id)
   ```

2. **Verify Lambda is in correct VPC**:
   ```bash
   aws lambda get-function-configuration \
     --function-name shiba-staging \
     --query 'VpcConfig'
   ```

3. **Test connectivity** from Lambda:
   ```bash
   # Add to Lambda environment for testing
   aws lambda update-function-configuration \
     --function-name shiba-staging \
     --environment Variables={DB_HOST=your-rds-endpoint}
   ```

### High Costs

If costs are higher than expected:

1. **Check NAT Gateway usage**:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/NATGateway \
     --metric-name BytesOutToDestination \
     --dimensions Name=NatGatewayId,Value=nat-xxx \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum
   ```

2. **Review Lambda invocations**:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Invocations \
     --dimensions Name=FunctionName,Value=shiba-staging \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum
   ```

3. **Check CloudFront data transfer**:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/CloudFront \
     --metric-name BytesDownloaded \
     --dimensions Name=DistributionId,Value=your-dist-id \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum
   ```

## Rollback Procedures

### Rollback Lambda Deployment

```bash
# List recent versions
aws lambda list-versions-by-function \
  --function-name shiba-staging \
  --max-items 5

# Get current version
CURRENT_VERSION=$(aws lambda get-alias \
  --function-name shiba-staging \
  --name live \
  --query 'FunctionVersion' --output text)

# Rollback to previous version
aws lambda update-alias \
  --function-name shiba-staging \
  --name live \
  --function-version $PREVIOUS_VERSION
```

### Rollback Infrastructure

```bash
cd infrastructure/terraform

# Checkout previous Terraform state
git checkout HEAD~1

# Apply previous configuration
terraform apply -var-file="environments/staging.tfvars"
```

## Security

### Secrets Management

Never commit secrets to git. Use:
- AWS Secrets Manager for application secrets
- GitHub Secrets for CI/CD credentials
- Environment variables for runtime config

### Network Security

- Lambda runs in private subnets
- RDS is in isolated database subnets (no internet access)
- Security groups restrict traffic to necessary ports
- CloudFront enforces HTTPS only

### Data Encryption

- S3 buckets use AES-256 encryption at rest
- RDS uses encryption at rest
- ElastiCache Redis uses encryption in transit and at rest
- JSONB PII data encrypted with AES256_GCM in application

## Support

For issues or questions:

1. Check [DISCOVERY documentation](/DISCOVERY/)
2. Review CloudWatch Logs
3. Check GitHub Actions logs
4. Open GitHub issue

## Additional Resources

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Spring Cloud Function](https://spring.io/projects/spring-cloud-function)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
