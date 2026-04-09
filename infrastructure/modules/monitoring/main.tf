resource "aws_cloudwatch_dashboard" "glue_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-glue-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      #############################################
      # Glue Job Success Count
      #############################################
      {
        type = "metric"
        x    = 0
        y    = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for job in var.glue_job_names :
            ["AWS/Glue", "Succeeded", "JobName", job]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Glue Job Success Count"
        }
      },

      #############################################
      # Glue Job Failure Count
      #############################################
      {
        type = "metric"
        x    = 12
        y    = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for job in var.glue_job_names :
            ["AWS/Glue", "Failed", "JobName", job]
          ]
          period = 300
          stat   = "Sum"
          region = "us-east-1"
          title  = "Glue Job Failures"
        }
      },

      #############################################
      # Job Duration
      #############################################
      {
        type = "metric"
        x    = 0
        y    = 6
        width  = 24
        height = 6

        properties = {
          metrics = [
            for job in var.glue_job_names :
            ["AWS/Glue", "ExecutionTime", "JobName", job]
          ]
          period = 300
          stat   = "Average"
          region = "us-east-1"
          title  = "Glue Job Execution Time"
        }
      }
    ]
  })
}




#############################################
# SNS TOPIC FOR ALERTS
#############################################
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

#############################################
# EMAIL SUBSCRIPTION
#############################################
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

#############################################
# EVENTBRIDGE RULE FOR GLUE FAILURES
#############################################
resource "aws_cloudwatch_event_rule" "glue_failure_rule" {
  name        = "${var.project_name}-${var.environment}-glue-failure-rule"
  description = "Capture Glue job failures"

  event_pattern = jsonencode({
    "source": ["aws.glue"],
    "detail-type": ["Glue Job State Change"],
    "detail": {
      "state": ["FAILED", "TIMEOUT", "STOPPED"]
    }
  })
}


#CONNECT TO SNS

#############################################
# EVENT TARGET → SNS
#############################################
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.glue_failure_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}


#EALLOW EVENTBRIDGE TO PUBLISH TO SNS

#############################################
# SNS POLICY FOR EVENTBRIDGE
#############################################
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sns:Publish",
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}
