#############################################
# Terraform Backend Infrastructure
# Creates:
# 1. S3 bucket for storing Terraform state
# 2. DynamoDB table for state locking
#############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#############################################
# AWS Provider Configuration
#############################################

provider "aws" {
  region = var.aws_region
}

#############################################
# S3 Bucket for Terraform State
#############################################

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  tags = {
    Name        = "terraform-state-bucket"
    Environment = var.environment
  }
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning (CRITICAL)
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access (SECURITY BEST PRACTICE)
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# DynamoDB Table for State Locking
#############################################

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-lock-table"
    Environment = var.environment
  }

  lifecycle {
    prevent_destroy = true
  }
}