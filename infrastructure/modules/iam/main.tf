#############################################
# IAM ROLE FOR AWS GLUE
#############################################

resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-${var.environment}-glue-role"

  # Trust policy defines who can assume this role
  # Here: AWS Glue service
  assume_role_policy = file("${path.module}/policies/glue_trust_policy.json")
}

#############################################
# S3 ACCESS POLICY
#############################################

resource "aws_iam_policy" "s3_policy" {
  name = "${var.project_name}-${var.environment}-s3-policy"

  policy = templatefile("${path.module}/policies/s3_policy.tpl", {
    all_bucket_arns = jsonencode(
      flatten([
        var.s3_bucket_arns,
        [for arn in var.s3_bucket_arns : "${arn}/*"]
      ])
    )
  })
}

#############################################
# KMS ACCESS POLICY
#############################################

resource "aws_iam_policy" "kms_policy" {
  name = "${var.project_name}-${var.environment}-kms-policy"

  policy = templatefile("${path.module}/policies/kms_policy.json", {
    kms_key_arn = var.kms_key_arn
  })
}

#############################################
# CLOUDWATCH LOGGING POLICY
#############################################

resource "aws_iam_policy" "cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-cloudwatch-policy"

  # No variables → direct file read
  policy = file("${path.module}/policies/cloudwatch_policy.json")
}

#############################################
# ATTACH POLICIES TO GLUE ROLE
#############################################

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "kms_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

#############################################
# DATA ENGINEER ROLE
#############################################

resource "aws_iam_role" "data_engineer_role" {
  name = "${var.project_name}-${var.environment}-data-engineer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "data_engineer_s3_policy" {
  name = "${var.project_name}-${var.environment}-data-engineer-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:*"]
      Resource = flatten([
        var.s3_bucket_arns,
        [for arn in var.s3_bucket_arns : "${arn}/*"]
      ])
    }]
  })
}

resource "aws_iam_role_policy_attachment" "data_engineer_attach" {
  role       = aws_iam_role.data_engineer_role.name
  policy_arn = aws_iam_policy.data_engineer_s3_policy.arn
}

#############################################
# DATA ANALYST ROLE
#############################################

resource "aws_iam_role" "data_analyst_role" {
  name = "${var.project_name}-${var.environment}-data-analyst-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "data_analyst_s3_policy" {
  name = "${var.project_name}-${var.environment}-data-analyst-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = flatten([
        var.s3_bucket_arns,
        [for arn in var.s3_bucket_arns : "${arn}/*"]
      ])
    }]
  })
}

resource "aws_iam_role_policy_attachment" "data_analyst_attach" {
  role       = aws_iam_role.data_analyst_role.name
  policy_arn = aws_iam_policy.data_analyst_s3_policy.arn
}