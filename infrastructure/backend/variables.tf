#############################################
# Variables for Backend Infrastructure
#############################################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "bucket_name" {
  description = "Unique S3 bucket name for Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform locking"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}