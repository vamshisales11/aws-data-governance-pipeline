#############################################
# IAM ROLE FOR LAMBDA
#############################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}




resource "aws_iam_policy" "lambda_policy" {
  name = "${var.project_name}-${var.environment}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Step Function permission
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = var.step_function_arn
      },

      # 🔥 ADD THIS BLOCK (S3 READ PERMISSION)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:HeadObject"
        ]
        Resource = "arn:aws:s3:::${var.raw_bucket_name}/*"
      },

      # CloudWatch logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}



resource "aws_lambda_function" "trigger" {
  function_name = "${var.project_name}-${var.environment}-trigger"

  filename         = var.lambda_zip_path
  handler          = "start_step_function.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256(var.lambda_zip_path)

  environment {
    variables = {
      STEP_FUNCTION_ARN = var.step_function_arn
    }
  }
}



#############################################
# EVENTBRIDGE RULE - S3 OBJECT CREATE
#############################################
#ANY file uploaded to raw bucket
resource "aws_cloudwatch_event_rule" "s3_trigger" {
  name = "${var.project_name}-${var.environment}-s3-trigger"

  event_pattern = jsonencode({
    source = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = {
        name = [var.raw_bucket_name]
      }
    }
  })
}


#############################################
#CONNECT EVENTBRIDGE → LAMBDA
# EVENT TARGET - LAMBDA
#############################################

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_trigger.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.trigger.arn
}



#############################################
# ALLOW EVENTBRIDGE TO INVOKE LAMBDA

#PERMISSION (CRITICAL)

#Without this, it WILL FAIL.
#############################################

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_trigger.arn
}