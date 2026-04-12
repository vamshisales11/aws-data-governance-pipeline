variable "project_name" { type = string }
variable "environment" { type = string }
variable "step_function_arn" { type = string }
variable "lambda_zip_path" { type = string }
variable "raw_bucket_name" {
  type = string
}