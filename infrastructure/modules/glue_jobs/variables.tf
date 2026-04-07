variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "job_name" {
  description = "Glue job name"
  type        = string
}

variable "script_location" {
  description = "S3 path to Glue script"
  type        = string
}

variable "glue_role_arn" {
  description = "IAM role for Glue job"
  type        = string
}

variable "raw_bucket" {
  type = string
}

variable "processed_bucket" {
  type = string
}


variable "extra_arguments" {
  type    = map(string)
  default = {}
}