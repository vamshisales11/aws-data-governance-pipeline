#############################################
# AWS Glue ETL Job - Orders Table
#############################################

import sys
from pyspark.context import SparkContext
from pyspark.sql import functions as F
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
# 2. Initialize Glue
#############################################

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

#############################################
# 3. Read Raw Data
#############################################

input_path = f"s3://{raw_bucket}/orders/"

df = spark.read \
    .option("header", "true") \
    .csv(input_path)

#############################################
# 4. Data Quality Checks
#############################################

# Remove NULL critical fields
df = df.filter(
    (F.col("order_id").isNotNull()) &
    (F.col("customer_id").isNotNull())
)

# Remove duplicates
df = df.dropDuplicates(["order_id"])

##raise Exception("FORCED FAILURE FOR TESTING")

#############################################
# 5. Timestamp Handling
#############################################

df = df.withColumn(
    "order_purchase_timestamp",
    F.to_timestamp("order_purchase_timestamp")
)

#############################################
# 6. Derive Partition Columns
#############################################

df = df.withColumn(
    "order_year",
    F.year("order_purchase_timestamp")
)

df = df.withColumn(
    "order_month",
    F.month("order_purchase_timestamp")
)

#############################################
# 7. Write to Processed Layer
#############################################

output_path = f"s3://{processed_bucket}/orders/"

df.write \
    .mode("overwrite") \
    .partitionBy("order_year", "order_month") \
    .parquet(output_path)

#############################################
# 8. Done
#############################################

print("Orders ETL job completed successfully")