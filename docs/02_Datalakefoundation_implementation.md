# Data Lake Module

## Module Location
```
infrastructure/modules/data_lake/
```

## Purpose
This module creates a secure, multi-layered Amazon S3 data lake with three distinct layers: raw, processed, and curated. Each layer is implemented as a separate S3 bucket to provide isolation, governance, and lifecycle management.

## Implementation Details

### 1. Data Lake Layers Definition
```hcl
locals {
  layers = ["raw", "processed", "curated"]
}
```
**Purpose:** Defines the three logical data lake layers that will be used to create separate S3 buckets for strong physical isolation.

### 2. S3 Buckets Creation
```hcl
resource "aws_s3_bucket" "data_lake" {
  for_each = toset(local.layers)

  bucket = "${var.project_name}-${each.key}-${var.environment}"

  tags = {
    Project        = var.project_name
    Environment    = var.environment
    DataLayer      = each.key
    ManagedBy      = "Terraform"
    Classification = lookup(
      {
        raw       = "Confidential"
        processed = "Internal"
        curated   = "Public"
      },
      each.key
    )
  }
}
```
**What it creates:** Three separate S3 buckets:
- `project-raw-environment`
- `project-processed-environment` 
- `project-curated-environment`

**Purpose:** 
- Physical isolation between data layers prevents cross-contamination
- Enables layer-specific access controls and retention policies
- Automatic classification tagging based on data sensitivity levels

### 3. Bucket Versioning
```hcl
resource "aws_s3_bucket_versioning" "versioning" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}
```
**Purpose:** Enables versioning on all data lake buckets to protect against accidental deletion and support data recovery/audit trails.

### 4. Server-Side Encryption with KMS
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}
```
**Purpose:** Encrypts all objects at rest using customer-managed KMS keys for centralized encryption control and compliance.

### 5. Public Access Block
```hcl
resource "aws_s3_bucket_public_access_block" "block_public" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
**Purpose:** Prevents all forms of public access to ensure data security by default and prevent accidental exposure.

### 6. Lifecycle Management
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  rule {
    id     = "retention-policy"
    status = "Enabled"

    filter {}

    expiration {
      days = lookup(
        {
          raw       = 30
          processed = 90
          curated   = 365
        },
        each.key
      )
    }
  }
}
```
**Purpose:** Implements automatic data retention policies:
- Raw layer: 30 days
- Processed layer: 90 days  
- Curated layer: 365 days

Reduces storage costs and enforces governance requirements.

### 7. HTTPS-Only Access Policy
```hcl
resource "aws_s3_bucket_policy" "secure_transport" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```
**Purpose:** Enforces HTTPS/TLS encryption for all data in transit, denying unencrypted HTTP access.

## Requirements Alignment

| Requirement | Implementation Status |
|-------------|----------------------|
| Layered data lake storage | Three isolated S3 buckets per layer |
| Data classification & tagging | Automatic classification tags per layer |
| Encryption at rest | KMS encryption on all buckets |
| Encryption in transit | HTTPS-only bucket policy |
| Data lifecycle management | Layer-specific retention policies (30/90/365 days) |
| Secure access controls | Public access blocks on all buckets |

***

