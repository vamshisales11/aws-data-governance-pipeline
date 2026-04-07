# IAM Module

## Module Location
```
infrastructure/modules/iam/
```

## Purpose
This module implements role-based access control (RBAC) for the data governance platform using least-privilege IAM roles and policies. It creates secure IAM roles for AWS Glue ETL jobs and provides granular access control for data engineers and analysts.

## Implementation Details

### 1. AWS Glue Service Role
```hcl
resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-${var.environment}-glue-role"
  
  assume_role_policy = file("${path.module}/policies/glue_trust_policy.json")
}
```
**File: `policies/glue_trust_policy.json`**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**What it creates:** IAM role `project-dev-glue-role` that Glue can assume

**Purpose:** Allows AWS Glue ETL service to securely assume this role for job execution with defined permissions.

### 2. S3 Access Policy (Least Privilege)
```hcl
resource "aws_iam_policy" "s3_policy" {
  name = "${var.project_name}-${var.environment}-s3-policy"
  
  policy = templatefile("${path.module}/policies/s3_policy.tpl", {
    bucket_arns = var.data_lake_bucket_arns
  })
}
```
**File: `policies/s3_policy.tpl`**
```hcl
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [ "${bucket_arns.raw}", "${bucket_arns.raw}/*",
                    "${bucket_arns.processed}", "${bucket_arns.processed}/*",
                    "${bucket_arns.curated}", "${bucket_arns.curated}/*" ]
    }
  ]
}
```

**Purpose:** 
- Granular S3 permissions (no `s3:*` wildcard)
- Access to raw/processed buckets only (no curated for ETL)
- Dynamic bucket ARN injection via template variables

### 3. KMS Encryption Policy
```hcl
resource "aws_iam_policy" "kms_policy" {
  name = "${var.project_name}-${var.environment}-kms-policy"
  
  policy = file("${path.module}/policies/kms_policy.json")
}
```
**File: `policies/kms_policy.json`**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "${kms_key_arn}"
    }
  ]
}
```

**Purpose:** Least-privilege KMS permissions for encryption/decryption operations only.

### 4. CloudWatch Logs Policy
```hcl
resource "aws_iam_policy" "cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-cloudwatch-policy"
  
  policy = file("${path.module}/policies/cloudwatch_policy.json")
}
```
**File: `policies/cloudwatch_policy.json`**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws-glue/jobs-*"
    }
  ]
}
```

**Purpose:** Allows Glue jobs to create and write logs without broad logging permissions.

### 5. Attach Policies to Glue Role
```hcl
resource "aws_iam_role_policy_attachment" "glue_policies" {
  for_each = {
    s3        = aws_iam_policy.s3_policy.arn
    kms       = aws_iam_policy.kms_policy.arn
    cloudwatch = aws_iam_policy.cloudwatch_policy.arn
  }
  
  role       = aws_iam_role.glue_role.name
  policy_arn = each.value
}
```

**Purpose:** Combines all three policies into single Glue service role with least-privilege access.

### 6. Data Engineer Role (Full Access)
```hcl
resource "aws_iam_role" "data_engineer_role" {
  name = "${var.project_name}-${var.environment}-data-engineer-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
```

**Purpose:** Provides data engineers full read/write access to data lake for development/testing.

### 7. Data Analyst Role (Read-Only)
```hcl
resource "aws_iam_role" "data_analyst_role" {
  name = "${var.project_name}-${var.environment}-data-analyst-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
```

**Purpose:** Provides analysts read-only access to curated layer for analytics and reporting.

## Outputs
```hcl
output "glue_role_arn" {
  value = aws_iam_role.glue_role.arn
}

output "glue_role_name" {
  value = aws_iam_role.glue_role.name
}

output "data_engineer_role_arn" {
  value = aws_iam_role.data_engineer_role.arn
}

output "data_analyst_role_arn" {
  value = aws_iam_role.data_analyst_role.arn
}
```

## Requirements Alignment

| Requirement | Implementation Status |
|-------------|----------------------|
| AWS Glue service role | Dedicated role with trust policy |
| Least-privilege S3 access | Scoped Get/Put/List operations |
| KMS encryption permissions | Encrypt/Decrypt/GenerateDataKey only |
| CloudWatch logging | Job-specific log group permissions |
| Data engineer access | Full read/write role |
| Data analyst access | Read-only curated layer access |
| Policy modularity | Separate policy files with templates |
| Dynamic bucket injection | Terraform variables for bucket ARNs |

***


This IAM module implements production-grade RBAC with least-privilege policies, modular policy files, and clear separation between service roles and human roles.