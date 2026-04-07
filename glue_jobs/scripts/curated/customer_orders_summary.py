import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("customer_orders_summary").getOrCreate()

# Paths
processed_bucket = "s3://datagov-processed-dev"
curated_bucket = "s3://datagov-curated-dev"

# Load processed data
customers = spark.read.parquet(f"{processed_bucket}/customers/")
orders = spark.read.parquet(f"{processed_bucket}/orders/")
payments = spark.read.parquet(f"{processed_bucket}/payments/")

# Join tables
df = customers.join(orders, "customer_id", "inner") \
              .join(payments, "order_id", "left")

# Aggregation
df = df.groupBy("customer_id").agg(
    F.countDistinct("order_id").alias("total_orders"),
    F.sum("payment_value").alias("total_spent"),
    F.avg("payment_value").alias("avg_order_value")
)

# Governance: Mask sensitive fields
df = df.withColumn("customer_city", F.lit("REDACTED"))

# Write curated data
df.write.mode("overwrite").parquet(f"{curated_bucket}/customer_orders_summary/")