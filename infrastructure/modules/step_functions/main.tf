#############################################
# IAM ROLE FOR STEP FUNCTIONS
#############################################

resource "aws_iam_role" "step_function_role" {
  name = "${var.project_name}-${var.environment}-stepfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}


#############################################
# POLICY: ALLOW STEP FUNCTION TO RUN GLUE
#############################################

resource "aws_iam_policy" "stepfn_glue_policy" {
  name = "${var.project_name}-${var.environment}-stepfn-glue-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:GetJob"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_glue_policy" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.stepfn_glue_policy.arn
}





#############################################
# STEP FUNCTION STATE MACHINE
#############################################

resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "Data Pipeline Orchestration"

    StartAt = "Customers ETL"

    States = {

      "Customers ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.customers_job_name
        }
        Next = "Products ETL"
        Retry = [{
          ErrorEquals = ["States.ALL"]
          IntervalSeconds = 30
          MaxAttempts = 2
        }]
      }

      "Products ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.products_job_name
        }
        Next = "Orders ETL"
      }

      "Orders ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.orders_job_name
        }
        Next = "Order Items ETL"
      }

      "Order Items ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.order_items_job_name
        }
        Next = "Payments ETL"
      }

      "Payments ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.payments_job_name
        }
        End = true
      }
    }
  })
}