# SHIBA Serverless Infrastructure - Main Configuration
# This deploys SHIBA as a serverless application using Lambda + CloudFront

terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket         = "shiba-tf-state-381684480739"
    key            = "shiba/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "shiba-terraform-locks"
    profile        = "nava-proto-cory"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "nava-proto-cory"

  default_tags {
    tags = {
      Project     = "SHIBA"
      Environment = var.environment
      ManagedBy   = "Terraform"
      StateCode   = var.state_code
    }
  }
}

# CloudFront requires ACM certificates in us-east-1
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "nava-proto-cory"

  default_tags {
    tags = {
      Project     = "SHIBA"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  app_name  = "shiba"
  full_name = "${local.app_name}-${var.environment}"

  common_tags = {
    Application = "SHIBA"
    Environment = var.environment
    StateCode   = var.state_code
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
