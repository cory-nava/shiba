#!/bin/bash

# SHIBA Terraform Helper Script
# This script ensures Terraform always uses the correct AWS profile

set -e

AWS_PROFILE="nava-proto-cory"
AWS_REGION="us-east-1"

echo "🔧 Using AWS Profile: $AWS_PROFILE"
echo "📍 Region: $AWS_REGION"
echo ""

# Set AWS profile environment variable
export AWS_PROFILE=$AWS_PROFILE
export AWS_REGION=$AWS_REGION

# Verify AWS credentials
echo "Verifying AWS credentials..."
aws sts get-caller-identity --profile $AWS_PROFILE

echo ""
echo "✅ AWS credentials verified"
echo ""

# Run terraform command
echo "Running: terraform $@"
echo ""

terraform "$@"
