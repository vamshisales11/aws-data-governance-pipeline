variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "glue_job_names" {
  description = "List of Glue job names to monitor"
  type        = list(string)
}

variable "alert_email" {
  type = string
}