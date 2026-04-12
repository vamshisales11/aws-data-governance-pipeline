terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "vamshi-terraform-state-datgovframework"   #  backend bucket name
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
##data_lake
module "data_lake" {
  source = "../../modules/data_lake"

  project_name = var.project_name
  environment  = var.environment
  region       = var.region

  kms_key_arn  = module.kms.kms_key_arn
  
  common_tags = {
  Project     = var.project_name
  Environment = var.environment
  ManagedBy   = "Terraform"
}
}

# -----------------------------
# Security Layer (NEW)
# -----------------------------
module "kms" {
  source = "../../modules/kms"

  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "../../modules/iam"

  project_name   = var.project_name
  environment    = var.environment

  # From S3 module
  s3_bucket_arns = module.data_lake.bucket_arns

  # From KMS module
  kms_key_arn    = module.kms.kms_key_arn
}



module "glue_catalog" {
  source = "../../modules/glue_catalog"

  project_name = var.project_name
  environment  = var.environment

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
  curated_bucket   = module.data_lake.curated_bucket_name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

###customers ETL job
module "glue_job_customers" {
  source = "../../modules/glue_jobs"

  project_name = var.project_name
  environment  = var.environment

  job_name = "customers-etl"

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/customers_etl.py"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
}


##orders ETL job

module "glue_job_orders" {
  source = "../../modules/glue_jobs"

  project_name = var.project_name
  environment  = var.environment

  job_name = "orders-etl"

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/orders_etl.py"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
}


##order-items-etl job


module "glue_job_order_items" {
  source = "../../modules/glue_jobs"

  project_name = var.project_name
  environment  = var.environment

  job_name = "order-items-etl"

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/order_items_etl.py"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
}

#payments-etl job

module "glue_job_payments" {
  source = "../../modules/glue_jobs"

  project_name = var.project_name
  environment  = var.environment

  job_name = "payments-etl"

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/payments_etl.py"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
}


#products-etl job
module "glue_job_products" {
  source = "../../modules/glue_jobs"

  project_name = var.project_name
  environment  = var.environment

  job_name = "products-etl"

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/products_etl.py"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
}


#############################################
# CURATED LAYER JOBS
#############################################

locals {
  curated_jobs = {
    customer_orders_summary = {
      script = "curated/customer_orders_summary.py"
    }

    order_details_enriched = {
      script = "curated/order_details_enriched.py"
    }

    sales_metrics = {
      script = "curated/sales_metrics.py"
    }
  }
}

module "glue_jobs_curated" {
  source = "../../modules/glue_jobs"

  for_each = local.curated_jobs

  project_name = var.project_name
  environment  = var.environment

  job_name = each.key

  script_location = "s3://${module.data_lake.raw_bucket_name}/scripts/${each.value.script}"

  glue_role_arn = module.iam.glue_role_arn

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name


  extra_arguments = {
    "--curated_bucket" = module.data_lake.curated_bucket_name
  }
}




module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment

  glue_job_names = [
    "customers-etl",
    "orders-etl",
    "order-items-etl",
    "payments-etl",
    "products-etl"
  ]

  alert_email = "vamshisales11@gmail.com"
}






module "step_function" {
  source = "../../modules/step_functions"

  project_name = var.project_name
  environment  = var.environment

  customers_job_name   = "datagov-dev-customers-etl"
  products_job_name    = "datagov-dev-products-etl"
  orders_job_name      = "datagov-dev-orders-etl"
  order_items_job_name = "datagov-dev-order-items-etl"
  payments_job_name    = "datagov-dev-payments-etl"
}





module "lambda_trigger" {
  source = "../../modules/lambda_trigger"

  project_name = var.project_name
  environment  = var.environment

  step_function_arn = module.step_function.step_function_arn
  lambda_zip_path   = "../../../glue_jobs/lambda/function.zip"

  raw_bucket_name = module.data_lake.raw_bucket_name
}