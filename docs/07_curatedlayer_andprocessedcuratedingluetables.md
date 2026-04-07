
# Curated Layer Implementation + Glue Catalog (Processed & Curated)

---

# 1. Overview

This stage implements the **Curated Layer of the data pipeline** and completes the **metadata layer for processed and curated datasets** using Terraform.

At this point, the pipeline evolves from:

Raw → Processed → Curated → Query (Athena)

This stage focuses on:

* Building **business-ready datasets**
* Performing **multi-table joins and aggregations**
* Enforcing **data governance rules**
* Creating **Glue Catalog tables for processed and curated layers via Terraform**
* Enabling **Athena querying for all layers**

---

# 2. Objectives

The following objectives were achieved:

* Implement curated datasets using AWS Glue ETL (PySpark)
* Perform joins across multiple processed tables
* Apply business transformations and aggregations
* Enforce governance rules (masking, restriction)
* Resolve schema conflicts during joins
* Register processed and curated datasets in Glue Catalog using Terraform
* Enable Athena querying for all datasets

---

# 3. Architecture Context

This stage extends the architecture as follows:

S3 (Raw CSV)
→ Glue ETL
→ S3 (Processed Parquet)
→ Glue ETL (Curated Transformations)
→ S3 (Curated Layer)
→ Glue Catalog (Terraform)
→ Athena Queries

---

# 4. Curated Layer Design

The curated layer provides **business-ready datasets** derived from processed data.

---

## 4.1 Datasets Created

### 1. customer_orders_summary

Purpose:

* Customer-level analytics

Includes:

* customer_id
* total_orders
* total_spent
* avg_order_value

---

### 2. order_details_enriched

Purpose:

* Order-level detailed analytics

Includes:

* order_id
* customer_id
* product details
* pricing information

---

### 3. sales_metrics

Purpose:

* Aggregated business metrics

Includes:

* revenue
* total orders
* average order value

Partitioned by:

* order_year
* order_month

---

# 5. Governance Enforcement

This stage strictly enforces governance rules defined earlier:

---

## 5.1 Data Masking

* customer_city → replaced with "REDACTED"

---

## 5.2 Sensitive Data Restriction

* payment_value removed from curated datasets

---

## 5.3 Access Control Alignment

* Only curated datasets are intended for analysts
* Raw and processed layers remain restricted

---

# 6. Implementation — Glue ETL (Curated Layer)

---

## 6.1 File Structure

```
glue_jobs/scripts/curated/
  ├── customer_orders_summary.py
  ├── order_details_enriched.py
  └── sales_metrics.py
```

---

## 6.2 customer_orders_summary.py

```python
customers = spark.read.parquet(f"{processed_bucket}/customers/")
orders = spark.read.parquet(f"{processed_bucket}/orders/")
payments = spark.read.parquet(f"{processed_bucket}/payments/")

df = customers.join(orders, "customer_id") \
              .join(payments, "order_id")

df = df.groupBy("customer_id").agg(
    F.countDistinct("order_id").alias("total_orders"),
    F.sum("payment_value").alias("total_spent"),
    F.avg("payment_value").alias("avg_order_value")
)

df.write.parquet(f"{curated_bucket}/customer_orders_summary/")
```

What this achieves:

* Joins customer, order, and payment data
* Produces aggregated metrics per customer

---

## 6.3 order_details_enriched.py (FINAL FIXED VERSION)

```python
df = orders.alias("o") \
    .join(items.alias("i"), "order_id") \
    .join(products.alias("p"), "product_id") \
    .join(payments.alias("pay"), "order_id", "left")

df = df.select(
    "o.order_id",
    "o.customer_id",
    "o.order_purchase_timestamp",
    "i.product_id",
    "i.price",
    "i.freight_value",
    "p.product_category_name"
)

df = df.withColumn(
    "total_price",
    F.col("price") + F.col("freight_value")
)

df.write.parquet(f"{curated_bucket}/order_details_enriched/")
```

What this achieves:

* Prevents duplicate column conflicts
* Produces enriched order-level dataset

---

## 6.4 sales_metrics.py

```python
df = orders.join(payments, "order_id")

df = df.withColumn("order_year", F.year("order_purchase_timestamp"))
df = df.withColumn("order_month", F.month("order_purchase_timestamp"))

df = df.groupBy("order_year", "order_month").agg(
    F.sum("payment_value").alias("total_revenue"),
    F.countDistinct("order_id").alias("total_orders"),
    F.avg("payment_value").alias("avg_order_value")
)

df.write.partitionBy("order_year", "order_month") \
  .parquet(f"{curated_bucket}/sales_metrics/")
```

What this achieves:

* Creates time-based aggregated metrics
* Enables partition-based querying

---

# 7. Terraform — Glue Job Deployment

---

## File Location

```
infrastructure/modules/glue_jobs/main.tf
```

---

## Key Implementation

```hcl
resource "aws_glue_job" "this" {
  name     = "${var.project_name}-${var.environment}-${var.job_name}"
  role_arn = var.glue_role_arn

  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  command {
    name            = "glueetl"
    script_location = var.script_location
    python_version  = "3"
  }

  default_arguments = merge(
    {
      "--job-language" = "python"
      "--enable-glue-datacatalog" = "true"
      "--enable-continuous-cloudwatch-log" = "true"
      "--enable-metrics" = "true"
      "--raw_bucket"       = var.raw_bucket
      "--processed_bucket" = var.processed_bucket
    },
    var.extra_arguments
  )
}
```

---

## Environment Integration

```
infrastructure/environments/dev/main.tf
```

Curated jobs created dynamically:

```hcl
module "glue_jobs_curated" {
  for_each = local.curated_jobs

  extra_arguments = {
    "--curated_bucket" = module.data_lake.curated_bucket_name
  }
}
```

---

# 8. Glue Catalog — Terraform Implementation

---

## File Location

```
infrastructure/modules/glue_catalog/main.tf
```

---

## Processed Tables

* customers
* orders (partitioned)
* order_items
* payments
* products

---

## Curated Tables

* customer_orders_summary
* order_details_enriched
* sales_metrics (partitioned)

---

## Example Resource

```hcl
resource "aws_glue_catalog_table" "curated_tables" {
  for_each = local.curated_tables

  name          = each.key
  database_name = aws_glue_catalog_database.curated.name

  storage_descriptor {
    location = "s3://${var.curated_bucket}/${each.key}/"
  }
}
```

---

# 9. Challenges Faced and Solutions

---

## 9.1 Duplicate Columns After Joins

Problem:

* Multiple ingestion_date columns caused failure

Error:

* AnalysisException: duplicate column

Solution:

* Use alias + explicit select()

Lesson:

* Never rely on implicit columns after joins

---

## 9.2 Tables Not Visible in Athena

Problem:

* Data existed but tables missing

Cause:

* Glue ETL writes to S3 only

Solution:

* Create Glue Catalog tables via Terraform

---

## 9.3 Schema Mismatch Risks

Problem:

* Incorrect schema definitions break queries

Solution:

* Align schema with data model document

---

## 9.4 Manual vs Terraform Conflict

Problem:

* Tables created manually vs Terraform

Solution:

* Delete manual tables
* Use Terraform only

---

# 10. Key Learnings

* Glue does not automatically create catalog tables
* Schema-first approach is critical
* Joins must be followed by explicit column selection
* Terraform ensures reproducibility
* Partitioning improves performance and cost

---

# 11. Final Outcome

At the end of this stage:

* Curated datasets created successfully
* Processed and curated tables registered in Glue
* Athena queries working across all layers
* Governance rules enforced
* Pipeline fully production-aligned

---

# 12. Next Step

Lake Formation Implementation

This will introduce:

* Fine-grained access control
* Column-level security
* Role-based data governance

---

# 13. Conclusion

This stage transforms the pipeline into a **business-ready data platform** by:

* Delivering curated datasets
* Enforcing governance at transformation layer
* Establishing complete metadata management via Terraform
* Enabling secure and efficient analytics

---

This marks the transition from **data engineering pipeline → governed data platform**.

---
