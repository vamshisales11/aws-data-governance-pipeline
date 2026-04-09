# Observability & Alerting Implementation (Phase 1)

## Overview



"I used cloudwatch to build monitoring, but drawn into wrong assumption that glue would emit status changes in job but it was not emiting any changes to cloudwatch. So, I resorted to evenbridge >> SNS >>email alerts. This will alert in real-time of the failure

here, I observed that cloudwatch is better option for infra level monitoring like CPU/resourace usage where we can draw insight about performace and tuning"


This stage implements **production-grade observability and alerting** for the AWS Data Governance Data Pipeline.

The goal of this phase is to make the system:

* Observable (understand system behavior)
* Reliable (detect failures immediately)
* Production-ready (event-driven monitoring)

This aligns with the project principle:

Observe → Protect → Automate → Audit → Improve

---

## What Was Implemented

### 1. CloudWatch Dashboard (Initial Attempt)

A CloudWatch dashboard was created to monitor AWS Glue job metrics such as:

* Job success count
* Job failure count
* Execution time

#### Implementation

**File Location:**

```
infrastructure/modules/monitoring/main.tf
```

**Code:**

```hcl
resource "aws_cloudwatch_dashboard" "glue_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-glue-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            for job in var.glue_job_names :
            ["AWS/Glue", "Succeeded", "JobName", job]
          ]
          stat   = "Sum"
          period = 300
          region = "us-east-1"
          title  = "Glue Job Success"
        }
      }
    ]
  })
}
```

#### Outcome

* Dashboard was successfully deployed
* However, **no useful job-level metrics appeared**

---

## Critical Learning

### CloudWatch Metrics Limitation

AWS Glue does **not reliably expose job success/failure metrics** via CloudWatch Metrics.

Only these were available:

* ResourceUsage (CPU/infra usage)

Missing:

* Succeeded
* Failed
* ExecutionTime

#### Conclusion

CloudWatch Metrics is **not a reliable mechanism for Glue job monitoring**

---

## Correct Approach: Event-Driven Monitoring

We redesigned the system using:

```
Glue → EventBridge → SNS → Email
```

---

## 2. SNS Alerting System

### Purpose

Send real-time notifications when Glue jobs fail.

---

### Implementation

#### SNS Topic

```hcl
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}
```

#### Email Subscription

```hcl
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
```

---

### Important Note

Email subscription must be **manually confirmed**.

Until confirmed:

* No alerts will be delivered

---

## 3. EventBridge Rule (Glue Failure Detection)

### Purpose

Capture Glue job failure events in real-time.

---

### Implementation

```hcl
resource "aws_cloudwatch_event_rule" "glue_failure_rule" {
  name = "${var.project_name}-${var.environment}-glue-failure-rule"

  event_pattern = jsonencode({
    source = ["aws.glue"]
    "detail-type" = ["Glue Job State Change"]
    detail = {
      state = ["FAILED", "TIMEOUT", "STOPPED"]
    }
  })
}
```

---

## 4. EventBridge → SNS Integration

```hcl
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.glue_failure_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alerts.arn
}
```

---

## 5. SNS Topic Policy (Critical)

Allows EventBridge to publish messages to SNS.

```hcl
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
        Action   = "sns:Publish",
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}
```

---

## Deployment Steps

### 1. Apply Terraform

```bash
terraform plan
terraform apply
```

---

### 2. Confirm Email Subscription

Check inbox and confirm SNS subscription.

---

### 3. Test Failure Scenario

Modify Glue script:

```python
raise Exception("FORCED FAILURE FOR TESTING")
```

Upload to S3:

```bash
aws s3 cp scripts/orders_etl.py s3://datagov-scripts-dev/scripts/orders_etl.py
```

Run job:

```bash
aws glue start-job-run --job-name datagov-dev-orders-etl
```

---

### 4. Expected Result

* Glue job fails
* EventBridge captures event
* SNS sends email
* Email contains full failure details

---

## Example Alert Payload

```json
{
  "detail-type": "Glue Job State Change",
  "detail": {
    "jobName": "datagov-dev-orders-etl",
    "state": "FAILED",
    "message": "FORCED FAILURE FOR TESTING"
  }
}
```

---

## Challenges Faced

### 1. CloudWatch Dashboard Showing No Data

**Issue:**
Dashboard was empty despite successful jobs.

**Root Cause:**
Glue does not emit required metrics.

**Solution:**
Switched to EventBridge-based monitoring.

---

### 2. Incorrect Metric Names

Initially used:

```
SuccessfulRuns / FailedRuns
```

Correct values:

```
Succeeded / Failed
```

However, metrics were still unavailable.

---

### 3. IAM Permissions (Earlier Issue)

Glue jobs failed with:

```
Failed to delete key
```

**Cause:**
Missing `s3:DeleteObject`

**Solution:**
Updated IAM policy.

---

### 4. EventBridge Rule Not Triggering

**Cause:**
Over-filtering using jobName

**Solution:**
Removed jobName filter temporarily.

---

### 5. SNS Not Sending Emails

**Cause:**
Subscription not confirmed

**Solution:**
Manual confirmation required.

---

## Expected Future Challenges

### 1. Too Many Alerts

As system grows:

* Multiple failures → alert noise

**Solution:**

* Add filtering
* Use severity levels
* Aggregate alerts

---

### 2. Lack of Context in Alerts

Default SNS message is raw JSON.

**Solution:**

* Use Lambda to format alerts
* Add human-readable messages

---

### 3. Monitoring Success Metrics

Current system only tracks failures.

**Solution:**

* Use logs or custom metrics
* Add pipeline KPIs

---

### 4. Dashboard Improvements

Current dashboard only shows resource usage.

**Future Enhancements:**

* Log-based metrics
* Data quality metrics
* Throughput metrics

---

## Final Architecture

```
Glue Job Failure
        ↓
EventBridge Rule
        ↓
SNS Topic
        ↓
Email Notification
```

---

## Key Takeaways

1. CloudWatch Metrics is not reliable for Glue job status
2. Event-driven monitoring is the correct approach
3. SNS requires manual subscription confirmation
4. Always test alerting systems with forced failures
5. Observability must be validated end-to-end

---

## Current System Status

| Capability        | Status                    |
| ----------------- | ------------------------- |
| Dashboard         | Implemented (limited use) |
| Alerting          | Fully operational         |
| Failure detection | Real-time                 |
| Production ready  | Yes                       |

---

## Next Step

Proceed to:

Data Governance Reporting using Athena

---


