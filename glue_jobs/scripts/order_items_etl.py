#############################################
# AWS Glue ETL - Order Items
#############################################

import sys
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, [
    "JOB_NAME",
    "raw_bucket",
    "processed_bucket"
])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

input_path = f"s3://{args['raw_bucket']}/order_items/"
output_path = f"s3://{args['processed_bucket']}/order_items/"

df = spark.read.option("header", "true").csv(input_path)

# Data Quality
df = df.filter(
    (F.col("order_id").isNotNull()) &
    (F.col("product_id").isNotNull())
)

df = df.dropDuplicates(["order_id", "order_item_id"])

# Numeric validation
df = df.filter(
    (F.col("price").cast("double") >= 0) &
    (F.col("freight_value").cast("double") >= 0)
)

# Add ingestion_date
df = df.withColumn("ingestion_date", F.current_date())

# Write
df.write \
    .mode("overwrite") \
    .partitionBy("ingestion_date") \
    .parquet(output_path)

print("Order Items ETL completed")