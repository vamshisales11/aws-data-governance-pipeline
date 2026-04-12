# Automation & Orchestration — Event-Driven Data Pipeline

## Overview

This stage implements **end-to-end automation and orchestration** for the AWS Data Governance Pipeline.

The system transitions from a **manually triggered ETL pipeline** to a **fully automated, event-driven architecture** using:

* Amazon S3 (event source)
* Amazon EventBridge (event routing)
* AWS Lambda (validation + trigger layer)
* AWS Step Functions (central orchestration engine)
* AWS Glue (ETL execution)

---

## Why This Stage Matters

Before this stage:

* Glue jobs were executed manually
* No orchestration or dependency control
* No real-time processing capability

After this stage:

* Pipeline is **fully automated**
* Execution is **event-driven**
* Dependencies are **strictly enforced**
* Failures are **controlled and observable**

This aligns with production best practices:

> Event-driven, loosely coupled, and centrally orchestrated systems

---

## Final Architecture

```
S3 (Raw Data Upload)
        ↓
EventBridge (Object Created Event)
        ↓
Lambda (Validation + Trigger)
        ↓
Step Functions (Orchestration)
        ↓
Glue ETL Jobs (Sequential Execution)
        ↓
S3 (Processed + Curated)
        ↓
Athena / Analytics
```

---

## Key Components

### 1. AWS Step Functions — Orchestration Layer

#### Purpose

* Centralized pipeline control
* Sequential execution of Glue jobs
* Retry and failure handling

---

### Implementation

**File Location:**

```
infrastructure/modules/step_function/main.tf
```

```hcl
resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    StartAt = "Customers ETL"

    States = {
      "Customers ETL" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = var.customers_job_name
        }
        Next = "Products ETL"
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
        End = true
      }
    }
  })
}
```

---

### Key Design Decision

**Synchronous Execution**

```
arn:aws:states:::glue:startJobRun.sync
```

This ensures:

* Step waits for job completion
* Failures stop pipeline
* Enables retry logic

---

## 2. AWS Lambda — Validation & Trigger Layer

### Purpose

* Receive S3 events
* Validate input (e.g., skip empty files)
* Trigger Step Function execution

---

### Implementation

**File Location:**

```
glue_jobs/lambda/start_step_function.py
```

```python
import json
import boto3
import os

s3 = boto3.client("s3")
stepfunctions = boto3.client("stepfunctions")

def lambda_handler(event, context):
    bucket = event["detail"]["bucket"]["name"]
    key = event["detail"]["object"]["key"]

    # Validate file size
    response = s3.head_object(Bucket=bucket, Key=key)
    size = response["ContentLength"]

    if size == 0:
        return {"statusCode": 200, "body": "Empty file skipped"}

    response = stepfunctions.start_execution(
        stateMachineArn=os.environ["STEP_FUNCTION_ARN"],
        input=json.dumps(event)
    )

    return {
        "statusCode": 200,
        "executionArn": response["executionArn"]
    }
```

---

### Key Feature

**Pre-ingestion validation**

Prevents:

* Empty file processing
* Unnecessary Glue job execution
* Cost wastage

---

## 3. EventBridge — Event Routing Layer

### Purpose

* Capture S3 object creation events
* Route events to Lambda

---

### Implementation

**File Location:**

```
infrastructure/modules/lambda_trigger/main.tf
```

```hcl
resource "aws_cloudwatch_event_rule" "s3_trigger" {
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
```

---

## 4. Lambda Permissions

### Problem Encountered

Lambda failed with:

```
403 Forbidden (HeadObject)
```

### Root Cause

Missing S3 permissions

---

### Solution

```hcl
{
  Effect = "Allow"
  Action = [
    "s3:GetObject",
    "s3:HeadObject"
  ]
  Resource = "arn:aws:s3:::${var.raw_bucket_name}/*"
}
```

---

## 5. IAM — Security Model

### Principles Applied

* Least privilege access
* Explicit permissions
* Service isolation

---

### Lambda Role Capabilities

| Capability            | Permission                  |
| --------------------- | --------------------------- |
| Trigger Step Function | states:StartExecution       |
| Read S3 metadata      | s3:GetObject, s3:HeadObject |
| Logging               | CloudWatch Logs             |

---

## Execution Flow

### End-to-End Process

1. File uploaded to S3
2. S3 emits event to EventBridge
3. EventBridge triggers Lambda
4. Lambda:

   * Validates file
   * Starts Step Function
5. Step Function:

   * Executes Glue jobs sequentially
6. Data written to processed/curated layers

---

## Challenges Faced

### 1. EventBridge Not Triggering

**Issue:**
Lambda not invoked

**Root Cause:**
S3 EventBridge integration disabled

**Solution:**
Enabled:

```
S3 → Properties → EventBridge → ON
```

---

### 2. Lambda Not Starting Step Function

**Issue:**
No Step Function execution

**Root Cause:**
Lambda failed silently due to S3 permission

---

### 3. 403 Forbidden Error

**Issue:**

```
HeadObject → Forbidden
```

**Root Cause:**
Missing S3 permissions

**Solution:**
Added least-privilege S3 read access

---

### 4. Event Pattern Mismatch

**Issue:**
EventBridge rule not firing

**Cause:**
Incorrect `detail-type`

**Fix:**
Include multiple types:

* Object Created
* Object Created:Put

---

## Future Challenges (Production Considerations)

### 1. Duplicate Event Processing

S3 may emit multiple events for same object

**Solution:**

* Idempotency handling
* Deduplication logic

---

### 2. Large File Handling

Lambda may not scale for large metadata checks

**Solution:**

* Use batch processing
* Introduce queue (SQS)

---

### 3. Alert Noise

Multiple failures → excessive alerts

**Solution:**

* Alert aggregation
* Severity filtering

---

### 4. Schema Evolution

Incoming data format changes

**Solution:**

* Schema validation layer
* Glue schema enforcement

---

### 5. Cost Optimization

Frequent triggers may increase cost

**Solution:**

* Intelligent filtering in Lambda
* Batch ingestion

---

## Key Learnings

* Event-driven architecture is superior to scheduled pipelines
* AWS services are loosely coupled and require explicit permissions
* Step Functions provide centralized orchestration and control
* Validation should occur before processing (Lambda layer)
* Observability must be verified end-to-end

---

## Final Outcome

This stage successfully delivers:

* Fully automated pipeline
* Event-driven architecture
* Centralized orchestration
* Secure, scalable design
* Production-ready system

---

## What This Demonstrates

This implementation reflects:

* Real-world data engineering practices
* Deep understanding of AWS event-driven systems
* Strong governance and security design
* Production-grade architecture thinking

---

## Next Step, we could do a complete CI/CD

CI/CD Implementation using GitHub Actions

---

**This marks the transition from:**

```
Data Pipeline → Production-Grade Data Platform
```
