# Data Model

**Project:** AWS Data Governance Data Pipeline
**Stage:** Data Understanding & Modeling (Pre-Glue Catalog)

---

# 1. Purpose of This Document

This document defines the **data model, structure, relationships, governance context, and design decisions** for the dataset used in this project.

It serves as a **single source of truth** for:

* Schema design
* Glue Data Catalog implementation
* ETL transformations
* Data governance enforcement
* Analytical querying

All future pipeline components **must strictly adhere to this document**.

---

# 2. Dataset Overview

**Dataset:** Brazilian E-Commerce Public Dataset (Olist)

This dataset simulates a real-world e-commerce platform and includes:

* Customers
* Orders
* Products
* Order line items
* Payments

The dataset represents a **transactional system**, which is modeled into a **data lake architecture**.

---

# 3. Data Model (Relational Structure)

## 3.1 Entity Relationship Model

```
customers (1) ──── (N) orders
orders (1) ─────── (N) order_items
order_items (N) ── (1) products
orders (1) ─────── (N) payments
```

---

## 3.2 Tables and Schema Definitions

### 3.2.1 customers

| Column                   | Type   | Description                            |
| ------------------------ | ------ | -------------------------------------- |
| customer_id              | string | Primary key (transactional identifier) |
| customer_unique_id       | string | Unique customer identity               |
| customer_zip_code_prefix | int    | ZIP prefix                             |
| customer_city            | string | Customer city                          |
| customer_state           | string | Customer state                         |

---

### 3.2.2 orders

| Column                        | Type      | Description             |
| ----------------------------- | --------- | ----------------------- |
| order_id                      | string    | Primary key             |
| customer_id                   | string    | Foreign key → customers |
| order_status                  | string    | Order status            |
| order_purchase_timestamp      | timestamp | Purchase time           |
| order_approved_at             | timestamp | Approval time           |
| order_delivered_carrier_date  | timestamp | Carrier delivery        |
| order_delivered_customer_date | timestamp | Final delivery          |
| order_estimated_delivery_date | timestamp | Estimated delivery      |

---

### 3.2.3 order_items

| Column              | Type      | Description            |
| ------------------- | --------- | ---------------------- |
| order_id            | string    | Foreign key → orders   |
| order_item_id       | int       | Line item identifier   |
| product_id          | string    | Foreign key → products |
| seller_id           | string    | Seller identifier      |
| shipping_limit_date | timestamp | Shipping deadline      |
| price               | double    | Item price             |
| freight_value       | double    | Shipping cost          |

**Primary Key:** (order_id, order_item_id)

---

### 3.2.4 products

| Column                     | Type   | Description        |
| -------------------------- | ------ | ------------------ |
| product_id                 | string | Primary key        |
| product_category_name      | string | Category           |
| product_name_lenght        | int    | Name length        |
| product_description_lenght | int    | Description length |
| product_photos_qty         | int    | Number of photos   |
| product_weight_g           | int    | Weight             |
| product_length_cm          | int    | Length             |
| product_height_cm          | int    | Height             |
| product_width_cm           | int    | Width              |

---

### 3.2.5 payments

| Column               | Type   | Description          |
| -------------------- | ------ | -------------------- |
| order_id             | string | Foreign key → orders |
| payment_sequential   | int    | Sequence number      |
| payment_type         | string | Payment method       |
| payment_installments | int    | Installments         |
| payment_value        | double | Payment amount       |

**Primary Key:** (order_id, payment_sequential)

---

# 4. Data Classification (Governance)

| Table       | Classification | Reason                      |
| ----------- | -------------- | --------------------------- |
| customers   | Confidential   | Contains location-based PII |
| payments    | Confidential   | Financial data              |
| orders      | Internal       | Operational data            |
| order_items | Internal       | Transactional data          |
| products    | Public         | Non-sensitive catalog       |

---

## 4.1 Column-Level Sensitivity

| Table     | Column                   | Action            |
| --------- | ------------------------ | ----------------- |
| customers | customer_city            | Mask              |
| customers | customer_zip_code_prefix | Partial mask      |
| payments  | payment_value            | Restricted access |

---

# 5. Data Lake Layer Mapping

## 5.1 Raw Layer

* Format: CSV (unchanged)
* Purpose: Immutable source data
* Partition Strategy:

  ```
  ingestion_date = YYYY-MM-DD
  ```

Example:

```
s3://datagov-raw-dev/customers/ingestion_date=2026-04-01/
```

---

## 5.2 Processed Layer

* Cleaned and validated data
* Standardized schema
* Partition strategy:

### Orders:

```
order_year
order_month
```

### Other Tables:

```
ingestion_date
```

---

## 5.3 Curated Layer

* Business-ready datasets
* Aggregations and joins
* Sensitive data masked or restricted

---

# 6. Data Quality Rules

The following rules must be enforced during processing:

## 6.1 Mandatory Fields

* customer_id NOT NULL
* order_id NOT NULL
* product_id NOT NULL

## 6.2 Numeric Validation

* payment_value ≥ 0
* price ≥ 0
* freight_value ≥ 0

## 6.3 Timestamp Validation

* All timestamps must be valid and converted to UTC

## 6.4 Uniqueness

* customers.customer_id → unique
* orders.order_id → unique
* Composite keys enforced where applicable

---

# 7. Data Type Standardization

| Logical Type    | Glue Type |
| --------------- | --------- |
| Identifier      | string    |
| Numeric integer | int       |
| Decimal         | double    |
| Timestamp       | timestamp |

---

# 8. Key Design Decisions

## 8.1 Schema First Approach

Schemas are explicitly defined instead of inferred to ensure:

* Reproducibility
* Governance enforcement
* Predictability

---

## 8.2 Partition Strategy

Partitioning is designed for:

* Query performance (Athena)
* Cost optimization
* Lifecycle management

---

## 8.3 Governance Integration

Data classification and sensitivity are embedded into:

* S3 tagging
* Glue metadata (future)
* Access policies

---

# 9. Constraints & Assumptions

* Raw data is immutable
* Schema evolution will be controlled (no auto-inference)
* Partition columns may be derived during ETL
* Data ingestion will append (not overwrite)

---

# 10. Usage of This Document

This document must be referenced when:

* Creating Glue Catalog tables
* Designing ETL pipelines
* Writing IAM/Lake Formation policies
* Implementing data quality checks
* Designing Athena queries

---

# 11. Next Steps

Based on this data model:

1. Build Glue Data Catalog (databases + tables)
2. Add partition-aware schemas
3. Implement Glue ETL jobs
4. Enable Athena querying
5. Introduce Lake Formation for fine-grained governance

---

# 12. Conclusion

This document establishes a **production-grade data foundation** by defining:

* Accurate schemas
* Clear relationships
* Governance-aware classifications
* Optimized partition strategies

All infrastructure and pipeline components will be built on top of this foundation to ensure:

* Scalability
* Security
* Cost efficiency
* Maintainability

---
