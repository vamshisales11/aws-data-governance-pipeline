

---



## (Glue Catalog + Raw Data Validation Stage)

---

# 1. Overview

This stage focuses on building the **metadata and discovery layer** of the data platform using AWS Glue Data Catalog and validating raw data ingestion through Amazon Athena.

The implementation follows the governance-first approach defined in the project requirements , ensuring that **schema control, metadata management, and data discoverability** are established before processing begins.

---

# 2. Objectives of This Stage

The goals achieved in this stage:

* Create **Glue Data Catalog databases** for all data lake layers
* Define **schema-first Glue tables** (no crawlers)
* Implement **dynamic table creation using Terraform**
* Register and query raw data using Athena
* Validate **end-to-end data flow: S3 → Glue → Athena**
* Maintain governance alignment (classification, structure, metadata)

---

# 3. Architecture Context

This stage fits into the overall architecture:

```text
S3 (Raw Layer) → Glue Data Catalog → Athena (Query Layer)
```

As defined in the architecture document :

* S3 = Storage layer
* Glue Catalog = Metadata layer
* Athena = Query layer

---

# 4. Key Design Decisions

---

## 4.1 Schema-First Approach (CRITICAL)

Instead of using Glue Crawlers:

❌ Auto schema inference
✅ Explicit schema definition via Terraform

### Why?

* Ensures reproducibility
* Prevents schema drift
* Enables governance enforcement

This aligns with:

> “Schemas are explicitly defined instead of inferred” 

---

## 4.2 Dynamic Table Creation (for_each)

Instead of:

```hcl
customers {}
orders {}
```

We implemented:

```hcl
for_each = local.raw_tables
```

### Why?

* Eliminates duplication
* Scales easily
* Centralizes schema definition

---

## 4.3 Raw Layer Principles

Raw layer is:

* Immutable
* Unprocessed
* Source of truth

As defined in governance framework:

> “Raw layer stores original data without modification” 

---

# 5. Infrastructure Implementation

---

# 5.1 Glue Catalog Module

### File:

```bash
infrastructure/modules/glue_catalog/main.tf
```

---

## 5.1.1 Glue Databases

```hcl
resource "aws_glue_catalog_database" "raw" {
  name = "${var.project_name}_raw_db"

  description = "Raw layer database"

  tags = merge(var.common_tags, {
    Layer = "raw"
  })
}
```

### Explanation

* Creates logical grouping for raw data
* Enables Athena queries
* Adds governance tags (Layer)

---

## 5.1.2 Schema Registry (locals)

```hcl
locals {
  raw_tables = {
    customers = {
      columns = [
        { name = "customer_id", type = "string" },
        ...
      ]
    }
  }
}
```

### Explanation

* Central definition of all schemas
* Acts as **single source of truth**
* Derived from data model 

---

## 5.1.3 Dynamic Table Creation

```hcl
resource "aws_glue_catalog_table" "raw_tables" {
  for_each = local.raw_tables

  name          = each.key
  database_name = aws_glue_catalog_database.raw.name
```

### Explanation

* Creates one table per entry in `raw_tables`
* Eliminates manual duplication
* Ensures consistency across tables

---

## 5.1.4 Storage Descriptor

```hcl
storage_descriptor {
  location = "s3://${var.raw_bucket}/${each.key}/"
```

### Explanation

* Links Glue table to S3 path
* Enables Athena to query data
* No data stored in Glue itself

---

## 5.1.5 Dynamic Columns

```hcl
dynamic "columns" {
  for_each = each.value.columns
```

### Explanation

* Iterates schema definition
* Automatically creates column definitions
* Ensures alignment with data model

---

## 5.1.6 Partition Strategy

```hcl
partition_keys {
  name = "ingestion_date"
  type = "string"
}
```

### Explanation

* Enables partition pruning in Athena
* Reduces query cost
* Aligns with design 

---

# 5.2 Environment Integration

### File:

```bash
infrastructure/environments/dev/main.tf
```

```hcl
module "glue_catalog" {
  source = "../../modules/glue_catalog"

  raw_bucket       = module.data_lake.raw_bucket_name
  processed_bucket = module.data_lake.processed_bucket_name
  curated_bucket   = module.data_lake.curated_bucket_name
}
```

### Explanation

* Connects Glue to S3 buckets
* Maintains modular architecture
* Uses outputs from data_lake module

---

# 6. Data Ingestion (Raw Layer)

---

## 6.1 Upload Strategy

Data was uploaded manually using:

```bash
aws s3 cp customers.csv \
s3://datagov-raw-dev/customers/ingestion_date=2026-04-01/
```

### Explanation

* Ensures partition structure
* Enables Glue/Athena compatibility

---

## 6.2 Required Structure

```text
s3://datagov-raw-dev/<table>/
  ingestion_date=YYYY-MM-DD/
    file.csv
```

---

# 7. Query Layer Validation (Athena)

---

## 7.1 Register Partitions

```sql
MSCK REPAIR TABLE customers;
```

### Explanation

* Scans S3
* Registers partitions in Glue
* Required for partitioned tables

---

## 7.2 Query Data

```sql
SELECT * FROM customers LIMIT 10;
```

### Result

* Data successfully retrieved
* End-to-end pipeline validated

---

# 8. Key Concepts Learned

---

## 8.1 Glue Table ≠ Data Storage

* Data lives in S3
* Glue stores metadata only

---

## 8.2 Schema Enforcement

* Only defined columns are queryable
* Extra columns ignored unless schema updated

---

## 8.3 Terraform State Management

Issue encountered:

* Table deleted manually
* Terraform did not recreate

Fix:

```bash
terraform refresh
terraform apply
```

### Lesson:

> Terraform state must match real infrastructure

---

## 8.4 Partitioning

* Partition = ingestion batch
* Not per-row grouping

---

# 9. Governance Alignment

This stage implements key governance requirements:

---

## 9.1 Metadata Management

✔ Glue Data Catalog implemented
✔ Schema defined
✔ Tables registered

> Requirement: “Data catalog and metadata management” 

---

## 9.2 Data Classification

✔ S3 bucket tagging
✔ Layer-based classification

> Confidential / Internal / Public 

---

## 9.3 Security

✔ KMS encryption
✔ HTTPS enforcement
✔ IAM roles

---

## 9.4 Discoverability

✔ Athena queries enabled
✔ Structured catalog

---

# 10. What We Did NOT Do (By Design)

---

## ❌ No Data Cleaning

* Raw layer remains untouched
* Processing happens later

---

## ❌ No Crawlers

* Avoided schema inference
* Used controlled schema definition

---

# 11. Final Outcome

At the end of this stage:

✔ 3 Glue databases created
✔ 5 tables dynamically created
✔ Data uploaded to S3
✔ Athena queries working
✔ Governance embedded

---

# 12. Next Steps

Next stage:

## 🔥 Data Processing Layer (Glue ETL)

We will implement:

* Data cleaning (null handling)
* Type enforcement
* Deduplication
* Writing to processed layer

---

# 13. Conclusion

This stage establishes a **production-grade metadata and discovery layer** by:

* Enforcing schema governance
* Enabling query access
* Maintaining reproducibility through Terraform
* Aligning with enterprise data governance principles

It forms the **foundation for all downstream processing and analytics**.

---


