#############################################
# AWS Glue ETL Job - Customers Table
#############################################

import sys
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions

#############################################
# 1. Job Parameters
#############################################

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "raw_bucket",
    "processed_bucket"
])

raw_bucket = args["raw_bucket"]
processed_bucket = args["processed_bucket"]

#############################################
# 2. Initialize Glue Context
#############################################

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

#############################################
# 3. Read Raw Data from S3
#############################################

input_path = f"s3://{raw_bucket}/customers/"

df = spark.read \
    .option("header", "true") \
    .csv(input_path)

#############################################
# 4. Data Quality Checks
#############################################

# 4.1 Remove NULL critical fields
df = df.filter(
    (F.col("customer_id").isNotNull()) &
    (F.col("customer_unique_id").isNotNull())
)

# 4.2 Remove duplicates
df = df.dropDuplicates(["customer_id"])

#############################################
# 5. Data Transformation
#############################################

# 5.1 Mask customer_city
df = df.withColumn(
    "customer_city",
    F.lit("REDACTED")
)

# 5.2 Mask ZIP (keep first 2 digits)
df = df.withColumn(
    "customer_zip_code_prefix",
    F.substring(F.col("customer_zip_code_prefix"), 1, 2)
)

#############################################
# 6. Add Metadata Column
#############################################

df = df.withColumn(
    "ingestion_date",
    F.current_date()
)

#############################################
# 7. Write to Processed Layer (Parquet)
#############################################

output_path = f"s3://{processed_bucket}/customers/"

df.write \
    .mode("overwrite") \
    .partitionBy("ingestion_date") \
    .parquet(output_path)

#############################################
# 8. Job Complete
#############################################

print("Customers ETL job completed successfully")