locals {
  layers = ["raw", "processed", "curated"]
}

##############################################
# S3 BUCKETS (DATA LAKE LAYERS)
##############################################

resource "aws_s3_bucket" "data_lake" {
  for_each = toset(local.layers)

  bucket = "${var.project_name}-${each.key}-${var.environment}"

  tags = merge(
  var.common_tags,
  {
    DataLayer = each.key
    Classification = lookup(
      {
        raw       = "Confidential"
        processed = "Internal"
        curated   = "Public"
      },
      each.key
    )
  }
)
}

##############################################
# VERSIONING
##############################################

resource "aws_s3_bucket_versioning" "versioning" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

##############################################
# ENCRYPTION (KMS)
##############################################

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

##############################################
# BLOCK PUBLIC ACCESS
##############################################

resource "aws_s3_bucket_public_access_block" "block_public" {
  for_each = aws_s3_bucket.data_lake

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##############################################
# LIFECYCLE (RETENTION POLICY)
##############################################

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

##############################################
# ENFORCE HTTPS (SECURE TRANSPORT)
##############################################

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




##############################################
# ATHENA QUERY RESULTS BUCKET
##############################################

resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${var.environment}"

  tags = merge(
    var.common_tags,
    {
      Purpose = "athena-query-results"
    }
  )
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "athena_block_public" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}