

---

# AWS Data Governance Data Pipeline

## Athena Governance Reporting Layer Documentation

---

# 1. Overview

This stage implements the **Governance Reporting Layer** using **Amazon Athena** to enable **measurement, validation, and monitoring of data governance policies**.

Until this point, the system ensured:

* Secure data storage (S3 + KMS)
* Controlled access (IAM + Lake Formation)
* Data transformation (Glue ETL)
* Observability (EventBridge + SNS alerts)

However, governance is incomplete without **measurable insights**.

This stage introduces:

> A **query-based reporting layer** that evaluates data quality, freshness, volume, and compliance.

---

# 2. Objectives

The primary objectives of this stage:

* Build a **Governance Reporting Layer** using Athena
* Create **persistent governance reports** using CTAS (Create Table As Select)
* Ensure **reports are stored, queryable, and reusable**
* Align reporting with governance policies defined earlier
* Integrate reporting into the governed data lake architecture

---

# 3. Architecture Context

This stage extends the existing architecture:

```
S3 (Processed + Curated Data)
        ↓
Glue Data Catalog (Metadata Layer)
        ↓
Athena (Query Engine)
        ↓
Governance Reporting Tables (S3 + Glue)
```

---

# 4. Key Design Decisions

---

## 4.1 Use Athena for Reporting

### Decision

Use **Amazon Athena** as the governance reporting engine.

### Why

* Serverless (no infrastructure)
* Cost-efficient (pay-per-query)
* Native integration with S3 and Glue
* Works seamlessly with Lake Formation

### Alternatives Considered

| Option    | Reason Not Chosen                    |
| --------- | ------------------------------------ |
| Redshift  | Overkill for reporting               |
| EMR       | High operational overhead            |
| Glue Jobs | Not suitable for analytical querying |

---

## 4.2 Use CTAS (Create Table As Select)

### Decision

Use CTAS queries to create **persistent reporting tables**

### Why

* Converts query results into **stored datasets**
* Enables reuse and auditing
* Improves performance (Parquet format)
* Aligns with production analytics patterns

---

## 4.3 Separate Reporting Database

### Decision

Create a dedicated database:

```
datagov_reporting_db
```

### Why

* Logical separation of concerns
* Avoid mixing reporting with curated data
* Supports governance and access control

---

## 4.4 Terraform for Metadata Infrastructure

### Decision

Manage reporting database using Terraform

### Why

* Ensures reproducibility
* Avoids manual drift
* Enables CI/CD integration

---

# 5. Infrastructure Implementation

---

## 5.1 Glue Reporting Database (Terraform)

### File Location

```
infrastructure/modules/glue_catalog/main.tf
```

### Code

```hcl
resource "aws_glue_catalog_database" "reporting" {
  name = "${var.project_name}_reporting_db"

  description = "Governance reporting database for Athena queries"

  tags = merge(var.common_tags, {
    Layer = "reporting"
    Purpose = "governance-reporting"
  })
}
```

### Explanation

* Creates a **Glue Data Catalog database**
* Used by Athena for storing reporting tables
* Tagged for governance classification

---

## 5.2 Athena Query Results Bucket

### File Location

```
infrastructure/modules/data_lake/main.tf
```

### Code

```hcl
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${var.environment}"
}
```

### Additional Security Configuration

* KMS encryption enabled
* Public access blocked

### Why This Is Required

* Athena **must write query results to S3**
* Enables auditability of query outputs
* Keeps reporting data isolated

---

# 6. Governance Reports Implementation

---

# 6.1 Data Quality Report

### Query

```sql
CREATE TABLE datagov_reporting_db.customer_data_quality
WITH (
    format = 'PARQUET',
    external_location = 's3://datagov-athena-results-dev/customer_data_quality/',
    write_compression = 'SNAPPY'
)
AS
SELECT
    CURRENT_DATE AS report_date,
    COUNT(*) AS total_records,
    COUNT(customer_id) AS non_null_customer_id,
    COUNT(*) - COUNT(customer_id) AS null_customer_id
FROM datagov_processed_db.customers;
```

### What It Does

* Counts total records
* Identifies NULL values
* Validates data quality rules

### Why It Matters

* Ensures **data integrity**
* Detects ingestion or transformation issues

---

# 6.2 Data Freshness Report

### Query

```sql
CREATE TABLE datagov_reporting_db.data_freshness
WITH (
    format = 'PARQUET',
    external_location = 's3://datagov-athena-results-dev/data_freshness/',
    write_compression = 'SNAPPY'
)
AS
SELECT
    CURRENT_DATE AS report_date,
    MAX(order_purchase_timestamp) AS latest_order_time
FROM datagov_processed_db.orders;
```

### What It Does

* Identifies most recent data timestamp

### Why It Matters

* Detects stale pipelines
* Supports SLA monitoring

---

# 6.3 Data Volume Report

### Query

```sql
CREATE TABLE datagov_reporting_db.orders_volume
WITH (
    format = 'PARQUET',
    external_location = 's3://datagov-athena-results-dev/orders_volume/',
    write_compression = 'SNAPPY'
)
AS
SELECT
    order_year,
    order_month,
    COUNT(*) AS total_orders
FROM datagov_processed_db.orders
GROUP BY order_year, order_month;
```

### What It Does

* Tracks data volume trends
* Uses partitioned columns

### Why It Matters

* Detects anomalies
* Supports capacity planning

---

# 7. How It Works (End-to-End)

---

## Step-by-Step Flow

1. Athena executes CTAS query
2. Query reads data from S3 via Glue Catalog
3. Lake Formation enforces access control
4. KMS decrypts data (if permitted)
5. Results written to S3 (Parquet format)
6. Glue registers table metadata
7. Table becomes queryable

---

# 8. Governance Alignment

This stage fulfills key governance requirements:

---

## Data Quality

* Null validation
* Duplicate detection (via queries)

---

## Data Freshness

* Latest timestamp tracking

---

## Data Completeness

* Volume monitoring

---

## Metadata Management

* Glue Catalog integration

---

## Security

* Lake Formation enforced access
* KMS encryption

---

# 9. Challenges Faced and Solutions

---

## 9.1 KMS Decryption Error (Critical)

### Issue

```
kms:Decrypt not authorized
```

### Root Cause

Lake Formation service role lacked KMS permissions.

### Solution

Updated KMS key policy:

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT_ID:role/aws-service-role/lakeformation.amazonaws.com/AWSServiceRoleForLakeFormationDataAccess"
  },
  "Action": ["kms:Decrypt", "kms:DescribeKey"],
  "Resource": "*"
}
```

### Lesson

> KMS is an independent security layer and must be explicitly configured.

---

## 9.2 Athena Query Failure Cleanup

### Issue

Athena does not delete failed query output.

### Solution

* Manually delete failed S3 path

---

## 9.3 Lake Formation Permissions

### Issue

Access denied for reporting queries

### Solution

* Grant SELECT access to reporting DB

---

## 9.4 Table Already Exists

### Issue

CTAS fails if table exists

### Solution

```sql
DROP TABLE table_name;
```

---

# 10. Expected Future Challenges

---

## 10.1 High Query Costs

### Cause

Full table scans

### Solution

* Use partition filters
* Optimize queries

---

## 10.2 Schema Drift

### Cause

Mismatch between Glue schema and data

### Solution

* Maintain schema-first approach
* Avoid manual changes

---

## 10.3 Data Growth

### Cause

Increasing dataset size

### Solution

* Partition aggressively
* Use Parquet format

---

## 10.4 Governance Gaps

### Cause

Untracked data issues

### Solution

* Expand reporting queries
* Add more validation rules

---

# 11. Key Learnings

* Governance must be **measurable, not assumed**
* Athena + CTAS is powerful for reporting
* KMS is a separate security layer from IAM/Lake Formation
* Persistent reporting tables enable auditability
* Infrastructure must be managed via Terraform

---

# 12. Final Outcome

At the end of this stage:

* Governance reporting layer implemented
* Reports stored as persistent datasets
* Data quality, freshness, and volume measurable
* Fully integrated with Lake Formation and KMS
* Production-aligned architecture achieved

---

# 13. Design Decision: No Automation (Intentional)

Reporting automation (EventBridge + Lambda) was **intentionally not implemented** to:

* Reduce cost during development
* Allow controlled execution
* Keep system simple during learning phase

The architecture supports future automation if required.

---

# 14. Next Steps

* CI/CD implementation (GitHub Actions)
* Optional report automation
* Dashboard integration (e.g., QuickSight)

---

# 15. Conclusion

This stage transforms the platform from:

> A governed data pipeline

To:

> A **measurable, auditable, and production-grade data governance system**

By introducing Athena-based reporting, the system now provides:

* Visibility into data quality
* Confidence in data reliability
* Evidence of governance enforcement

This is a critical milestone in building a **real-world data platform**.

---
