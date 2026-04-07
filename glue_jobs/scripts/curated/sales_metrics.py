import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("sales_metrics").getOrCreate()

processed_bucket = "s3://datagov-processed-dev"
curated_bucket = "s3://datagov-curated-dev"

orders = spark.read.parquet(f"{processed_bucket}/orders/")
payments = spark.read.parquet(f"{processed_bucket}/payments/")

df = orders.join(payments, "order_id")

df = df.withColumn("order_year", F.year("order_purchase_timestamp"))
df = df.withColumn("order_month", F.month("order_purchase_timestamp"))

df = df.groupBy("order_year", "order_month").agg(
    F.sum("payment_value").alias("total_revenue"),
    F.countDistinct("order_id").alias("total_orders"),
    F.avg("payment_value").alias("avg_order_value")
)

df.write.mode("overwrite") \
  .partitionBy("order_year", "order_month") \
  .parquet(f"{curated_bucket}/sales_metrics/")