############################################
# Get current AWS account info
############################################
data "aws_caller_identity" "current" {}

############################################
# KMS Key (Customer Managed Key)
############################################
resource "aws_kms_key" "this" {
  description             = "${var.project_name}-${var.environment}-kms-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  ##########################################
  # Key Policy (CRITICAL FOR ACCESS CONTROL)
  ##########################################
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      ######################################
      # Root account full access (MANDATORY)
      ######################################
      {
        Sid = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      ######################################
      # Allow AWS services to use the key
      ######################################
      {
        Sid = "AllowAWSServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = [
            "s3.amazonaws.com",
            "glue.amazonaws.com",
            "logs.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

############################################
# KMS Alias (human-readable name)
############################################
resource "aws_kms_alias" "this" {
  name          = "alias/${var.project_name}-${var.environment}-key"
  target_key_id = aws_kms_key.this.key_id
}