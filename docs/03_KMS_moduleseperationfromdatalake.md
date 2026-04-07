# KMS Module

## Module Location
```
infrastructure/modules/kms/
```

## Purpose
This module creates a customer-managed AWS KMS key for centralized encryption management across the entire data platform. The key is used by S3 data lake buckets, Glue ETL jobs, and CloudWatch Logs.

## Implementation Details

### 1. Customer-Managed KMS Key Creation
```hcl
resource "aws_kms_key" "this" {
  description             = "${var.project_name}-${var.environment}-kms-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}
```
**What it creates:** A customer-managed KMS key with ID like `1234abcd-12ab-34cd-56ef-1234567890ab`

**Purpose:**
- **Customer-managed key (CMK)** - Full lifecycle control vs AWS-managed keys
- **Automatic rotation** - Keys rotate every 365 days without downtime
- **7-day deletion window** - Protection against accidental key deletion
- **Descriptive naming** - Easy identification in AWS Console and CLI

### 2. KMS Key Policy
```hcl
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Sid    = "EnableRootPermissions"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action   = "kms:*"
      Resource = "*"
    },
    {
      Sid    = "AllowAWSServiceUsage"
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
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      Resource = "*"
    }
  ]
})
```

**Statement 1 - Root Permissions:**
```
Sid = "EnableRootPermissions"
Principal = { AWS = "arn:aws:iam::ACCOUNT:root" }
Action = "kms:*"
```
**Purpose:** Grants the AWS account root full administrative control over the key (AWS mandatory requirement for CMKs)

**Statement 2 - AWS Service Permissions:**
```
Principal = { Service = ["s3.amazonaws.com", "glue.amazonaws.com", "logs.amazonaws.com"] }
Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
```
**Purpose:** 
- **S3 service** - Encrypt/decrypt data lake objects
- **Glue service** - Encrypt ETL job data and temporary storage
- **CloudWatch Logs** - Encrypt log data from Glue jobs
- **Least-privilege actions** - Only encryption operations, no key management

### 3. KMS Key Alias
```hcl
resource "aws_kms_alias" "this" {
  name          = "alias/${var.project_name}-${var.environment}-key"
  target_key_id = aws_kms_key.this.key_id
}
```
**What it creates:** `alias/project-dev-key` (human-readable reference)

**Purpose:**
- **Developer-friendly reference** - Use `alias/project-dev-key` instead of 36-character key ID
- **Cross-module integration** - Easy reference in S3 data lake module
- **Environment isolation** - Separate aliases per environment (dev/staging/prod)
- **AWS Console navigation** - Clickable alias in Console UI

## Outputs
```hcl
output "kms_key_id" {
  value = aws_kms_key.this.key_id
}

output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "kms_alias_name" {
  value = aws_kms_alias.this.name
}
```
**Usage in other modules:**
```hcl
# In data_lake module
kms_key_arn = module.kms.kms_key_arn
```

## Requirements Alignment

| Requirement | Implementation Status |
|-------------|----------------------|
| Centralized encryption management | Single customer-managed KMS key |
| Automatic key rotation | Enabled (365-day cycle) |
| S3 integration | Service principal with encrypt/decrypt permissions |
| Glue ETL integration | Service principal with encrypt/decrypt permissions |
| CloudWatch Logs encryption | Service principal with encrypt/decrypt permissions |
| Secure key administration | Root-only full access |
| Developer-friendly references | KMS alias with descriptive naming |
| Key deletion protection | 7-day soft delete window |

***



This KMS module provides production-grade encryption infrastructure used by data lake, Glue ETL, and logging components with proper least-privilege access and automatic key rotation.