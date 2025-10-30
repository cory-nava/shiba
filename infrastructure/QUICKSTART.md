# SHIBA AWS Deployment - Quick Start Guide

## ✅ Prerequisites Completed

The following AWS resources have been created in your account (`381684480739`):

- ✅ S3 bucket for Terraform state: `shiba-tf-state-381684480739`
- ✅ S3 bucket versioning enabled
- ✅ DynamoDB table for state locking: `shiba-terraform-locks`
- ✅ AWS Profile configured: `nava-proto-cory`

## 🚀 Deploy SHIBA Infrastructure

### Step 1: Initialize Terraform

```bash
cd infrastructure/terraform

# Option A: Use the helper script (recommended)
./terraform.sh init

# Option B: Run terraform directly with profile
export AWS_PROFILE=nava-proto-cory
terraform init
```

### Step 2: Choose Your Environment

Edit the appropriate environment file:

**For Development/Testing:**
```bash
vim environments/dev.tfvars
```

**Key settings to update:**
```hcl
environment = "dev"
domain_name = ""  # Leave empty to use CloudFront default domain
hosted_zone_id = ""  # Not needed for dev
```

### Step 3: Plan the Deployment

```bash
# Using helper script
./terraform.sh plan -var-file="environments/dev.tfvars"

# Or with direct terraform
export AWS_PROFILE=nava-proto-cory
terraform plan -var-file="environments/dev.tfvars"
```

This will show you all resources that will be created:
- VPC with subnets
- Lambda function
- RDS PostgreSQL database
- ElastiCache Redis
- S3 buckets
- CloudFront distribution
- IAM roles
- Security groups
- CloudWatch alarms

### Step 4: Apply the Infrastructure

```bash
# Using helper script
./terraform.sh apply -var-file="environments/dev.tfvars"

# Or with direct terraform
export AWS_PROFILE=nava-proto-cory
terraform apply -var-file="environments/dev.tfvars"
```

**⏱️ This will take approximately 15-20 minutes** (RDS creation is the slowest)

### Step 5: Get the Outputs

```bash
./terraform.sh output -json > outputs.json
cat outputs.json | jq
```

Key outputs:
- `application_url` - Your CloudFront URL
- `lambda_function_name` - Lambda function name
- `cloudfront_distribution_id` - CloudFront distribution ID

## 📦 Deploy Application Code

### Option 1: Manual Deployment

```bash
# From the project root
./gradlew clean buildLambda

# Get the Lambda function name from Terraform
export AWS_PROFILE=nava-proto-cory
FUNCTION_NAME=$(cd infrastructure/terraform && terraform output -raw lambda_function_name)

# Update Lambda code
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://build/distributions/shiba-lambda-0.0.1-SNAPSHOT.zip \
  --publish \
  --profile nava-proto-cory

# Upload static assets
BUCKET_NAME=$(cd infrastructure/terraform && terraform output -raw s3_static_assets_bucket)
aws s3 sync src/main/resources/static s3://$BUCKET_NAME/ \
  --profile nava-proto-cory
```

### Option 2: GitHub Actions (Recommended)

1. Add GitHub Secrets:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

2. Push to main branch to trigger deployment

## 🧪 Test Your Deployment

```bash
export AWS_PROFILE=nava-proto-cory

# Get the application URL
cd infrastructure/terraform
APP_URL=$(terraform output -raw application_url)

echo "Testing: $APP_URL"
curl -I $APP_URL

# View Lambda logs
FUNCTION_NAME=$(terraform output -raw lambda_function_name)
aws logs tail /aws/lambda/$FUNCTION_NAME --follow --profile nava-proto-cory
```

## 💰 Cost Estimate

**Dev Environment:** ~$100/month
- Lambda: $20 (low usage)
- RDS db.t3.micro: $15
- ElastiCache t3.micro: $12
- NAT Gateway: $32
- CloudFront: $5
- S3: $3
- Other: $13

## 🔧 Useful Commands

### View Current Infrastructure

```bash
cd infrastructure/terraform
./terraform.sh show
```

### Update Infrastructure

```bash
# Make changes to .tf files or .tfvars
./terraform.sh plan -var-file="environments/dev.tfvars"
./terraform.sh apply -var-file="environments/dev.tfvars"
```

### Destroy Everything (Be Careful!)

```bash
./terraform.sh destroy -var-file="environments/dev.tfvars"
```

### Check Lambda Function

```bash
export AWS_PROFILE=nava-proto-cory

# Get function info
aws lambda get-function --function-name shiba-dev --profile nava-proto-cory

# Invoke function
aws lambda invoke \
  --function-name shiba-dev \
  --payload '{}' \
  response.json \
  --profile nava-proto-cory

cat response.json
```

### Check Database

```bash
export AWS_PROFILE=nava-proto-cory

# Get RDS endpoint
cd infrastructure/terraform
DB_ENDPOINT=$(terraform output -raw rds_endpoint)

echo "Database endpoint: $DB_ENDPOINT"

# Get database credentials from Secrets Manager
SECRET_ARN=$(terraform output -raw db_credentials_secret_arn)
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --profile nava-proto-cory \
  | jq -r .SecretString | jq
```

## 🐛 Troubleshooting

### Terraform Init Fails

```bash
# Make sure you're using the right profile
export AWS_PROFILE=nava-proto-cory
aws sts get-caller-identity

# Clear Terraform cache and retry
rm -rf .terraform .terraform.lock.hcl
./terraform.sh init
```

### Lambda Can't Connect to RDS

Check security groups allow traffic:
```bash
export AWS_PROFILE=nava-proto-cory
cd infrastructure/terraform

# Get security group IDs
terraform output lambda_security_group_id
terraform output rds_security_group_id

# Check RDS security group allows Lambda
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw rds_security_group_id) \
  --profile nava-proto-cory
```

### CloudFront Takes Forever

CloudFront distributions take 15-30 minutes to deploy. Check status:
```bash
export AWS_PROFILE=nava-proto-cory
cd infrastructure/terraform

DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront get-distribution --id $DIST_ID --profile nava-proto-cory
```

## 📚 Next Steps

1. **Configure Application Secrets:**
   ```bash
   SECRET_ARN=$(cd infrastructure/terraform && terraform output -raw application_secrets_arn)

   aws secretsmanager put-secret-value \
     --secret-id $SECRET_ARN \
     --secret-string '{
       "mailgun_api_key": "your-key",
       "smarty_streets_auth_id": "your-id"
     }' \
     --profile nava-proto-cory
   ```

2. **Set Up Custom Domain** (optional):
   - Update `domain_name` in tfvars
   - Update `hosted_zone_id` with your Route53 zone
   - Run `terraform apply` again

3. **Enable Monitoring:**
   - View CloudWatch dashboard
   - Set up SNS topic for alarms (production)

4. **Review Costs:**
   - Go to AWS Cost Explorer
   - Filter by tag: `Project = SHIBA`

## 🆘 Need Help?

- Check [infrastructure/README.md](./README.md) for detailed documentation
- View [DISCOVERY/11-AWS-SERVERLESS-DEPLOYMENT.md](../DISCOVERY/11-AWS-SERVERLESS-DEPLOYMENT.md) for architecture details
- Review Terraform logs: `./terraform.sh show`
- Check AWS CloudWatch Logs for Lambda output
