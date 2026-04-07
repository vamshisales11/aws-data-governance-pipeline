output "glue_role_arn" {
  description = "IAM Role ARN for AWS Glue"
  value       = aws_iam_role.glue_role.arn
}