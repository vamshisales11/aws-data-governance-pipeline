# Terraform Backend Infrastructure Documentation
## Overview
This module provisions the Terraform backend infrastructure required to store and manage Terraform state in a secure, scalable, and production-grade manner.

**Creates:**
- Amazon S3 bucket → stores Terraform state file (.tfstate)
- Amazon DynamoDB table → enables state locking to prevent concurrent modifications

## Why This Matters
**Without proper backend:**
- State stored locally → Risk of corruption
- No collaboration support
- No version history

**With this backend:**
- Remote, centralized state storage
- Safe concurrent operations via locking
- Version history of infrastructure changes
- Secure storage with encryption

## Architecture
```
Terraform CLI
      ↓
S3 Bucket (State Storage)
      ↓
DynamoDB (State Locking)
```

## File Structure
```
infrastructure/backend/
│
├── main.tf                 # Core infrastructure resources
├── variables.tf            # Input variables
├── terraform.tfvars        # Variable values
└── backend.tf              # Remote backend configuration
```

## main.tf — Detailed Explanation

### 1. Terraform Block
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```
**Purpose:** Ensures consistent Terraform version and AWS provider stability.

### 2. AWS Provider Configuration
```hcl
provider "aws" {
  region = var.aws_region
}
```
**Purpose:** Connects Terraform to AWS using dynamic region configuration.

### 3. S3 Bucket (Terraform State Storage)
```hcl
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
```
**Key Features:**
| Feature | Explanation |
|---------|-------------|
| Unique name | S3 bucket names globally unique |
| Tags | Cost tracking & governance |
| prevent_destroy | Prevents accidental deletion |

### 4. S3 Versioning (CRITICAL)
```hcl
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
```
**Purpose:** Maintains history of state file versions for rollback capability.

### 5. S3 Encryption
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```
**Purpose:** Encrypts state file at rest (contains sensitive ARNs/IDs).

### 6. Block Public Access
```hcl
resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```
**Purpose:** Prevents accidental public exposure of state files.

### 7. DynamoDB Table (State Locking)
```hcl
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
```
**Key Configurations:**
| Setting | Explanation |
|---------|-------------|
| PAY_PER_REQUEST | Cost-efficient for low usage |
| LockID | Partition key for state locks |
| prevent_destroy | Protects locking mechanism |

## backend.tf — Remote State Configuration
```hcl
terraform {
  backend "s3" {
    bucket         = "vamshi-terraform-state-datgovframework"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```
**Purpose:** Configures Terraform to store state remotely instead of local files.

**Parameters:**
| Parameter | Value | Purpose |
|-----------|-------|---------|
| bucket | vamshi-terraform-state-datgovframework | S3 bucket for state storage |
| key | dev/terraform.tfstate | Path to state file |
| region | us-east-1 | AWS region |
| dynamodb_table | terraform-locks | State locking table |
| encrypt | true | Server-side encryption |

## variables.tf Summary
| Variable | Purpose |
|----------|---------|
| aws_region | Deployment region |
| bucket_name | Unique S3 bucket name |
| dynamodb_table_name | Lock table name |
| environment | Dev/Prod tagging |

## terraform.tfvars Example
```hcl
aws_region           = "us-east-1"
bucket_name          = "vamshi-terraform-state-datgovframework"
dynamodb_table_name  = "terraform-locks"
environment          = "dev"
```

## Execution Workflow
1. `terraform init` — Initialize providers and backend
2. `terraform plan` — Preview changes  
3. `terraform apply` — Create resources

## State Migration (Local → Remote)
```
terraform init -migrate-state
```
**Prompt:** `Do you want to copy existing state to the new backend?`
**Answer:** `yes`

## Verification Checklist
**S3 Bucket:**
- [x] Versioning: Enabled
- [x] Encryption: Enabled  
- [x] Public access: Blocked
- [x] Tags: Name=terraform-state-bucket, Environment=dev

**DynamoDB Table:**
- [x] Table exists
- [x] Partition key: LockID (String)
- [x] Tags: Name=terraform-lock-table, Environment=dev

**Remote Backend:**
- [ ] State file in S3: `dev/terraform.tfstate`
- [ ] Locking works during `terraform apply`

## Common Issues & Fixes
| Issue | Fix |
|-------|-----|
| Bucket exists | `terraform import aws_s3_bucket.terraform_state <bucket>` |
| Table exists | Delete table or import |
| Region mismatch | Match `aws_region` everywhere |
| State lock error | `terraform force-unlock <ID>` |
| No migration prompt | Normal if no local state exists |

## Key Learning Takeaways
1. **Terraform State is CRITICAL** — Never lose it, always protect it
2. **Remote Backend = Production Standard** — Local state only for learning
3. **State Locking Prevents Corruption** — DynamoDB essential for teams
4. **Security First** — Encryption + no public access + versioning
5. **Separate `backend.tf`** — Production best practice
6. **State migration** — Safe local → remote transition

## Production Backend Status
```
✅ LIVE: S3 = vamshi-terraform-state-datgovframework (us-east-1)
✅ LIVE: DynamoDB = terraform-locks (us-east-1) 
✅ READY: Remote state + locking for all future phases
```

## Next Steps
datalake foundations

**This completes production-grade Terraform backend setup.**