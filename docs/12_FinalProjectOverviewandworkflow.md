Below is the **refined, professional, enterprise-grade documentation** rewritten in a formal tone, eliminating conversational language and first-person pronouns. The structure aligns with industry-standard architecture and governance documentation.

---

# AWS Data Governance Data Pipeline (End-to-End Architecture)

---

# 1. Project Overview

This project implements a **production-grade, enterprise-level data platform on AWS**, with governance controls embedded across the entire data lifecycle.

The solution extends beyond a traditional data pipeline and represents a **fully governed data platform** characterized by:

* Strong data governance enforcement
* End-to-end security controls
* Observability and monitoring capabilities
* Event-driven automation
* Scalable and modular architecture

---

## Core Objectives

The platform is designed to ensure:

* **Data Quality** — Validation, deduplication, and schema enforcement
* **Security & Compliance** — Encryption, access control, and auditing
* **Controlled Access** — Role-based and column-level permissions
* **Auditability** — Traceable data access and system activity
* **Automation** — Event-driven orchestration

---

## Guiding Principle

> Governance is implemented as a foundational component of the architecture rather than an afterthought.

---

# 2. Architecture Overview

The system follows a layered and modular architecture:

```
Source Data (CSV)
        ↓
S3 Raw Layer
        ↓
AWS Glue ETL (Validation & Cleaning)
        ↓
S3 Processed Layer
        ↓
AWS Glue ETL (Business Transformations)
        ↓
S3 Curated Layer
        ↓
Glue Data Catalog
        ↓
Athena (Query Layer)
        ↓
Lake Formation (Governance Layer)
        ↓
IAM + KMS (Security Layer)
        ↓
EventBridge + Step Functions (Automation)
        ↓
CloudWatch + SNS (Observability)
```

---

# 3. Data Model and Dataset

The dataset used is the **Brazilian E-Commerce Dataset (Olist)**.

---

## Core Tables

* customers
* orders
* order_items
* products
* payments

---

## Relationships

```
customers → orders → order_items → products
orders → payments
```

---

## Data Classification Strategy

| Layer     | Classification |
| --------- | -------------- |
| Raw       | Confidential   |
| Processed | Internal       |
| Curated   | Public         |

---

## Governance Rules

* Masking of personally identifiable information (PII)
* Restriction of sensitive financial data
* Enforcement of schema and null validation rules

Detailed definitions are provided in the data model document 

---

# 4. Infrastructure as Code (Terraform)

---

## Backend (State Management)

The Terraform backend is configured using:

* Amazon S3 for remote state storage
* Amazon DynamoDB for state locking

This ensures:

* Consistency and integrity of infrastructure state
* Safe concurrent operations
* Version-controlled infrastructure

Implementation details: 

---

## Data Lake (Amazon S3)

The data lake is structured into three layers:

* Raw
* Processed
* Curated

Each layer is implemented as an independent S3 bucket with:

* Versioning enabled
* KMS-based encryption
* Lifecycle policies (30/90/365 days)
* HTTPS-only access enforcement

Implementation details: 

---

## Encryption (AWS KMS)

A customer-managed KMS key is provisioned with:

* Automatic key rotation
* Controlled access policies
* Integration with S3, Glue, and CloudWatch

Implementation details: 

---

## Identity and Access Management (IAM)

The IAM model enforces least-privilege access using:

* Glue service role for ETL execution
* Data engineer role with full access
* Data analyst role with restricted access to curated data

Policies are scoped to specific resources and actions to avoid over-permissioning.

Implementation details: 

---

# 5. Metadata Management (Glue Data Catalog)

---

## Design Approach: Schema-First

Schemas are explicitly defined using Terraform rather than inferred using crawlers.

### Benefits

* Prevents schema drift
* Ensures reproducibility
* Enables governance enforcement

---

## Implementation

* Three databases:

  * raw_db
  * processed_db
  * curated_db

* Dynamic table creation using Terraform (`for_each`)

Implementation details: 

---

# 6. ETL Layer (AWS Glue)

---

## Raw to Processed Layer

Transformations include:

* Null validation
* Deduplication
* Data type enforcement
* Partitioning for performance

---

## Processed to Curated Layer

Transformations include:

* Multi-table joins
* Aggregations
* Business logic application

### Curated Datasets

* customer_orders_summary
* order_details_enriched
* sales_metrics

---

## Key Outcomes

* Clean, validated datasets
* Optimized Parquet storage format
* Partitioned data for cost-efficient querying

Implementation details:

* ETL layer: 
* Curated layer: 

---

# 7. Data Governance (Lake Formation)

---

## Purpose

IAM alone does not provide:

* Column-level security
* Centralized governance
* Fine-grained access control

Lake Formation addresses these limitations.

---

## Implementation

* IAM access override disabled
* S3 locations registered with Lake Formation
* Role-based access control implemented
* Column-level permissions enforced

---

## Example

A data analyst role is permitted to access:

```sql
customer_id, total_orders
```

Access to sensitive fields such as financial metrics is restricted.

---

## Critical Resolution

KMS permissions were extended to the Lake Formation service role to resolve decryption failures.

Implementation details: 

---

# 8. Observability and Alerting

---

## Initial Limitation

CloudWatch metrics did not provide reliable Glue job status visibility.

---

## Final Architecture

```
Glue → EventBridge → SNS → Email Notifications
```

---

## Capabilities

* Real-time failure detection
* Event-driven alerting
* Email-based notification system

---

## Key Insight

CloudWatch metrics are suitable for infrastructure monitoring but not for Glue job state tracking.

Implementation details: 

---

# 9. Automation and Orchestration

---

## Architecture

```
S3 Event → EventBridge → Step Functions → Glue Jobs
```

---

## Design Decision

A centralized orchestration model was implemented using Step Functions.

### Rationale

* Simplifies pipeline management
* Enables end-to-end orchestration
* Supports retry and failure handling

---

## Capabilities

* Sequential execution of pipeline stages
* Built-in retry logic
* Execution tracking and traceability

---

## Cost Model

* Serverless architecture
* No cost when idle
* Charges incurred only during execution

---

## Event-Driven Execution

Pipeline execution is triggered exclusively by data arrival in S3.

---

# 10. Governance Reporting (Athena)

---

Reports were developed to monitor:

* Data quality metrics
* Data freshness
* Data volume trends

---

## Purpose

* Evaluate governance effectiveness
* Detect anomalies
* Support compliance and auditing

---

# 11. Testing and Validation

---

Validation covered:

* IAM access enforcement
* Lake Formation permissions
* Encryption verification (KMS)
* Athena query correctness
* ETL pipeline outputs

---

# 12. Challenges and Key Learnings

---

## Challenges

* Lack of Glue job metrics in CloudWatch
* KMS permission issues affecting query execution
* IAM override conflicts in Lake Formation
* Schema mismatches between Glue and data
* Terraform state drift

---

## Key Learnings

* Governance must be implemented early in the design
* AWS services are tightly interconnected
* Effective debugging requires system-level understanding
* Schema-first design is critical for data reliability

---

# 13. Final System Capabilities

---

| Capability                  | Status   |
| --------------------------- | -------- |
| Data Lake Architecture      | Complete |
| ETL Pipeline                | Complete |
| Governance (Lake Formation) | Complete |
| Security (IAM + KMS)        | Complete |
| Metadata Management         | Complete |
| Query Layer (Athena)        | Complete |
| Observability               | Complete |
| Automation (Step Functions) | Complete |
| Event-Driven Execution      | Complete |

---

# 14. Project Significance

---

This implementation demonstrates:

* End-to-end data platform design
* Enterprise-grade governance architecture
* Secure and compliant data handling
* Event-driven system design
* Advanced troubleshooting and system integration capabilities

---

# 15. Resource Cleanup

---

To prevent unnecessary AWS charges:

```bash
terraform destroy
```

Additional verification steps:

* Ensure S3 buckets are empty
* Remove Glue jobs
* Delete Step Functions workflows

---

# 16. Conclusion

---

This project represents the transformation from:

> A basic data pipeline

to:

> A fully governed, production-grade data platform

---

## Final State

* Fully automated
* Fully governed
* Fully observable
* Fully secure

---


