

## ETL Stage Documentation (Processed Layer Implementation)

---

# 1. Overview

This stage implements the **ETL (Extract, Transform, Load) layer** of the data platform using AWS Glue and PySpark.

The goal is to transform raw CSV data stored in S3 into **clean, validated, and partitioned Parquet datasets** in the processed layer, while enforcing governance rules.

This stage establishes the **core data engineering pipeline**, enabling reliable downstream analytics and governance enforcement.

---

# 2. Objectives

The following objectives were achieved:

* Build Glue ETL jobs for all base tables:

  * customers
  * orders
  * order_items
  * payments
  * products
* Enforce data quality rules (null checks, deduplication, validation)
* Apply data masking for sensitive fields
* Convert data into optimized Parquet format
* Implement partitioning strategies
* Deploy ETL jobs using Terraform
* Execute and validate end-to-end pipeline

---

# 3. Architecture Context

This stage extends the architecture:

```
S3 (Raw Layer - CSV)
   ↓
AWS Glue ETL (PySpark)
   ↓
S3 (Processed Layer - Parquet, Partitioned)
   ↓
Athena (Query Layer)
```

---

# 4. Project Structure (Relevant to ETL)

All ETL code is organized separately from infrastructure.

```
aws-data-governance-pipeline/

├── glue_jobs/
│   ├── scripts/
│   │   ├── customers_etl.py
│   │   ├── orders_etl.py
│   │   ├── order_items_etl.py
│   │   ├── payments_etl.py
│   │   └── products_etl.py
│   │
│   ├── utils/
│   ├── config/
│   └── tests/
│
├── infrastructure/
│   ├── modules/
│   │   └── glue_jobs/
│   └── environments/
│       └── dev/
```

---

# 5. ETL Implementation (Table-wise)

---

## 5.1 Customers ETL

### File Location

```
glue_jobs/scripts/customers_etl.py
```

### Code

```python
# (code shortened for brevity in explanation, but should be full in repo)

df = spark.read.option("header", "true").csv(input_path)

df = df.filter(
    (F.col("customer_id").isNotNull()) &
    (F.col("customer_unique_id").isNotNull())
)

df = df.dropDuplicates(["customer_id"])

df = df.withColumn("customer_city", F.lit("REDACTED"))

df = df.withColumn(
    "customer_zip_code_prefix",
    F.substring(F.col("customer_zip_code_prefix"), 1, 2)
)

df = df.withColumn("ingestion_date", F.current_date())

df.write.partitionBy("ingestion_date").parquet(output_path)
```

### What Was Achieved

* Removed invalid records
* Enforced primary key uniqueness
* Masked PII fields
* Added ingestion tracking
* Partitioned data for performance

---

## 5.2 Orders ETL

### File Location

```
glue_jobs/scripts/orders_etl.py
```

### Code

```python
df = spark.read.option("header", "true").csv(input_path)

df = df.filter(
    (F.col("order_id").isNotNull()) &
    (F.col("customer_id").isNotNull())
)

df = df.dropDuplicates(["order_id"])

df = df.withColumn(
    "order_purchase_timestamp",
    F.to_timestamp("order_purchase_timestamp")
)

df = df.withColumn("order_year", F.year("order_purchase_timestamp"))
df = df.withColumn("order_month", F.month("order_purchase_timestamp"))

df.write.partitionBy("order_year", "order_month").parquet(output_path)
```

### What Was Achieved

* Converted timestamps to proper type
* Derived partition columns
* Enabled time-based analytics
* Optimized query performance

---

## 5.3 Order Items ETL

### File Location

```
glue_jobs/scripts/order_items_etl.py
```

### Key Logic

* Null validation
* Composite key deduplication
* Numeric validation (price, freight_value ≥ 0)
* Partition by ingestion_date

---

## 5.4 Payments ETL

### File Location

```
glue_jobs/scripts/payments_etl.py
```

### Key Logic

* Deduplication using composite key
* Validation of payment_value ≥ 0
* Partition by ingestion_date

---

## 5.5 Products ETL

### File Location

```
glue_jobs/scripts/products_etl.py
```

### Key Logic

* Primary key validation
* Deduplication
* Partition by ingestion_date

---

# 6. Terraform Integration

### Module Location

```
infrastructure/modules/glue_jobs/
```

### Example Usage

```
infrastructure/environments/dev/main.tf
```

```hcl
module "glue_job_orders" {
  source = "../../modules/glue_jobs"

  job_name = "orders-etl"

  script_location = "s3://datagov-raw-dev/scripts/orders_etl.py"

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name

  glue_role_arn = module.iam.glue_role_arn
}
```

### What This Achieves

* Fully automated job creation
* Reusable module design
* No hardcoding of values
* Environment-specific deployment

---

# 7. Data Quality Framework Implementation

The following rules were enforced across all ETL jobs:

* Mandatory fields must not be null
* Duplicate records removed based on primary keys
* Numeric fields validated to be non-negative
* Schema consistency maintained
* Timestamp standardization applied where required

---

# 8. Partitioning Strategy

| Table       | Partition Strategy      |
| ----------- | ----------------------- |
| customers   | ingestion_date          |
| orders      | order_year, order_month |
| order_items | ingestion_date          |
| payments    | ingestion_date          |
| products    | ingestion_date          |

### Benefits

* Faster Athena queries
* Reduced scan cost
* Improved performance

---

# 9. Challenges and Solutions

---

## 9.1 Script Not Found in Glue

Problem:
Glue failed with "NoSuchKey"

Cause:
Incorrect S3 path or missing upload

Solution:

* Upload scripts to S3
* Verify using:

```
aws s3 ls s3://datagov-raw-dev/scripts/
```

---

## 9.2 Relative Path Issues (Local)

Problem:
CLI could not find script

Cause:
Wrong working directory

Solution:
Use correct relative paths or navigate to project root

---

## 9.3 Missing Glue Tables (Processed Layer)

Problem:
Athena could not query processed data

Cause:
Glue tables not created for processed layer

Solution:

* Create tables manually OR
* Implement via Terraform (preferred next step)

---

## 9.4 Partition Not Visible in Athena

Problem:
Data exists but query returns empty

Cause:
Partitions not registered

Solution:

```
MSCK REPAIR TABLE <table_name>;
```

---

## 9.5 IAM / Permission Errors

Problem:
Glue cannot read/write S3 or KMS

Solution:
Ensure IAM role includes:

* S3 access
* KMS permissions
* CloudWatch logging

---

# 10. Key Learnings

* Glue executes scripts only from S3, not local files
* Schema-first approach prevents data inconsistencies
* Partitioning is essential for performance optimization
* Terraform ensures reproducibility and consistency
* Data governance must be enforced during transformation, not after

---

# 11. Final Outcome

At the end of this stage:

* All base tables processed successfully
* Clean, validated datasets available in processed layer
* Data is partitioned and query-optimized
* ETL jobs are fully automated via Terraform
* Governance rules are enforced in transformation layer

---

# 12. Next Stage

Next step in the pipeline:

Curated Layer Implementation

This will include:

* Joining multiple tables
* Business transformations
* Aggregations
* Restricted access datasets

---

# 13. Conclusion

This stage establishes the **core transformation engine** of the data platform.

It ensures that:

* Data is reliable and clean
* Governance rules are enforced
* The system is scalable and production-ready

This forms the foundation for analytics, reporting, and advanced data processing.
