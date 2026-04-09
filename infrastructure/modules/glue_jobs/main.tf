#############################################
# AWS Glue Job
#############################################

resource "aws_glue_job" "this" {
  name     = "${var.project_name}-${var.environment}-${var.job_name}"
  role_arn = var.glue_role_arn

  ##########################################
  # Glue Version & Capacity
  ##########################################
  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  ##########################################
  # Command (SCRIPT LOCATION)
  ##########################################
  command {
    name            = "glueetl"
    script_location = var.script_location
    python_version  = "3"
  }

  ##########################################
  # Default Arguments
  ##########################################
  default_arguments = merge(
  {
    "--job-language" = "python"
    "--enable-glue-datacatalog" = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics" = "true"
    "--enable-observability-metrics"        = "true"

    "--raw_bucket"       = var.raw_bucket
    "--processed_bucket" = var.processed_bucket
  },
  var.extra_arguments
)

  ##########################################
  # Retry & Timeout
  ##########################################
  max_retries = 1
  timeout     = 10

  ##########################################
  # Tags
  ##########################################
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}