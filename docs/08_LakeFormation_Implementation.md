Here is your **production-grade README.md documentation for the Lake Formation stage** — written clean, structured, and suitable for GitHub.

---

# Lake Formation Implementation (Data Governance Layer)

## Overview

This stage implements **fine-grained data governance** on top of the existing AWS data lake using **AWS Lake Formation**.

The objective is to transition from basic IAM-based access control to **enterprise-grade governance**, enabling:

* Role-based access control (RBAC)
* Table-level and column-level permissions
* Elimination of IAM-based access bypass
* Secure, governed access to curated data

---

## Why Lake Formation?

Before this stage:

* Access to S3 + Glue Catalog was controlled via IAM
* No fine-grained control over columns or tables
* No centralized governance layer

Problems:

* Over-permissioned access (security risk)
* No ability to restrict sensitive fields (e.g., financial data)
* No separation of roles (analyst vs engineer)

Solution:

Lake Formation introduces:

* Centralized permission management
* Column-level security
* Data governance aligned with enterprise standards

---

## Architecture Decision

We adopted:

* **Lake Formation as the governance layer**
* **Glue Data Catalog as metadata store**
* **S3 as storage layer**
* **KMS for encryption**
* **IAM roles for identity**

### Key Design Choices

| Decision                 | Reason                            |
| ------------------------ | --------------------------------- |
| Disable IAM-only access  | Enforce Lake Formation governance |
| Register S3 buckets      | Bring data lake under LF control  |
| Use service-linked role  | Managed, secure access to S3      |
| RBAC with IAM roles      | Separation of responsibilities    |
| Column-level permissions | Protect sensitive data            |

---

## Step 1 — Disable IAM-Only Access

### What

Disabled IAM-based access enforcement in Lake Formation.

### Why

To ensure:

* Lake Formation becomes the **single source of truth**
* IAM policies do not bypass governance

### How (Console)

Lake Formation → Settings:

* Uncheck:

  * "Use only IAM access control for new databases"
  * "Use only IAM access control for new tables"

---

## Step 2 — Register S3 Buckets

### What

Registered all data lake buckets with Lake Formation.

### Why

Lake Formation cannot govern data unless S3 locations are registered.

### Buckets

* `datagov-raw-dev`
* `datagov-processed-dev`
* `datagov-curated-dev`

---

### CLI Command

```bash
aws lakeformation register-resource \
  --resource-arn arn:aws:s3:::datagov-raw-dev \
  --use-service-linked-role
```

Repeat for:

* processed
* curated

---

### Verification

```bash
aws lakeformation list-resources
```

---

## Step 3 — Remove IAM Override (Critical)

### What

Removed default access granted to:

```text
IAM_ALLOWED_PRINCIPALS
```

### Why

This group bypasses Lake Formation and gives full access.

---

### Challenge

Lake Formation **does not support wildcard revoke for tables**

---

### Solution

Revoke permissions per table:

```bash
aws lakeformation revoke-permissions \
  --principal DataLakePrincipalIdentifier=IAM_ALLOWED_PRINCIPALS \
  --permissions ALL \
  --resource '{ 
    "Table": { 
      "DatabaseName": "datagov_curated_db", 
      "Name": "customer_orders_summary"
    } 
  }'
```

Repeat for all tables across:

* raw DB
* processed DB
* curated DB

---

### Verification

```bash
aws lakeformation list-permissions
```

Expected:

* No entries for `IAM_ALLOWED_PRINCIPALS`

---

## Step 4 — Role-Based Access Control (RBAC)

### Roles

* `datagov-dev-data-engineer-role`
* `datagov-dev-data-analyst-role`

---

### Permissions Strategy

| Role          | Access            |
| ------------- | ----------------- |
| Data Engineer | Full access       |
| Data Analyst  | Restricted access |

---

## Step 5 — Column-Level Security

### Objective

Restrict access to sensitive financial data.

---

### Example Table

`customer_orders_summary`

Columns:

* customer_id
* total_orders
* total_spent (sensitive)
* avg_order_value (sensitive)

---

### Grant Partial Access

```bash
aws lakeformation grant-permissions \
  --principal DataLakePrincipalIdentifier=arn:aws:iam::ACCOUNT_ID:role/datagov-dev-data-analyst-role \
  --permissions SELECT \
  --resource '{ 
    "TableWithColumns": { 
      "DatabaseName": "datagov_curated_db", 
      "Name": "customer_orders_summary",
      "ColumnNames": [
        "customer_id",
        "total_orders"
      ]
    } 
  }'
```

---

### Grant Full Access (Safe Table)

```bash
aws lakeformation grant-permissions \
  --principal DataLakePrincipalIdentifier=arn:aws:iam::ACCOUNT_ID:role/datagov-dev-data-analyst-role \
  --permissions SELECT \
  --resource '{ 
    "TableWithColumns": { 
      "DatabaseName": "datagov_curated_db", 
      "Name": "sales_metrics",
      "ColumnWildcard": {}
    } 
  }'
```

---

## Step 6 — KMS Integration (Critical Fix)

### Problem

Athena queries failed with:

```text
kms:Decrypt not allowed
```

---

### Root Cause

Lake Formation uses:

```text
AWSServiceRoleForLakeFormationDataAccess
```

This role lacked KMS permissions.

---

### Solution

Update KMS Key Policy:

```json
{
  "Sid": "AllowLakeFormationDecrypt",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT_ID:role/aws-service-role/lakeformation.amazonaws.com/AWSServiceRoleForLakeFormationDataAccess"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

---

## Step 7 — Validation Using Athena

### Role Assumption

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/datagov-dev-data-analyst-role \
  --role-session-name analyst-session
```

---

### Set Credentials

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN="..."
```

---

### Tests

#### Test 1 — Full Access

```sql
SELECT * FROM datagov_curated_db.sales_metrics;
```

Expected:

* Full data access

---

#### Test 2 — Column-Level Security

```sql
SELECT * FROM datagov_curated_db.customer_orders_summary;
```

Expected:

* Only:

  * customer_id
  * total_orders

---

#### Test 3 — Restricted Table

```sql
SELECT * FROM datagov_curated_db.order_details_enriched;
```

Expected:

* Access denied OR data read failure (depending on schema issues)

---

## Challenges Faced

### 1. IAM Override

* Default access bypassed governance
* Required manual revoke per table

---

### 2. Lake Formation Limitations

* No wildcard revoke support
* Required explicit table-level operations

---

### 3. KMS Permission Errors

* Lake Formation role lacked decrypt permissions
* Caused Athena query failures

---

### 4. Credential Management Issues

* Temporary credentials expired
* Caused `InvalidClientTokenId` errors

---

### 5. Misleading Errors

* Data errors appeared before access denial
* Required deeper debugging

---

### 6. Schema Mismatch (Parquet)

* Glue schema vs actual data mismatch
* Caused `HIVE_BAD_DATA` errors

---

## Key Learnings

* Lake Formation does not replace IAM — it works with it
* KMS is a separate control layer and must be configured
* Column-level security requires exact schema alignment
* Debugging AWS requires understanding service interactions

---

## Final Outcome

Successfully implemented:

* Fine-grained access control
* Column-level data masking
* Role-based governance
* Secure integration with KMS
* Fully governed data lake

---

## What This Demonstrates

This stage reflects:

* Real-world enterprise data governance
* Secure data access patterns
* Production-grade AWS architecture
* Strong understanding of AWS security layers

---




