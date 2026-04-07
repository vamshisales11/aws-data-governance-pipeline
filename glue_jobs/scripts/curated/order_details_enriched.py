import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("order_details_enriched").getOrCreate()

processed_bucket = "s3://datagov-processed-dev"
curated_bucket = "s3://datagov-curated-dev"

orders = spark.read.parquet(f"{processed_bucket}/orders/")
items = spark.read.parquet(f"{processed_bucket}/order_items/")
products = spark.read.parquet(f"{processed_bucket}/products/")
payments = spark.read.parquet(f"{processed_bucket}/payments/")

# Join with aliases
df = orders.alias("o") \
    .join(items.alias("i"), "order_id") \
    .join(products.alias("p"), "product_id") \
    .join(payments.alias("pay"), "order_id", "left")

# Select required columns only
df = df.select(
    "o.order_id",
    "o.customer_id",
    "o.order_purchase_timestamp",
    "i.product_id",
    "i.price",
    "i.freight_value",
    "p.product_category_name"
)

# Business transformation
df = df.withColumn(
    "total_price",
    F.col("price") + F.col("freight_value")
)

# Write output
df.write.mode("overwrite").parquet(f"{curated_bucket}/order_details_enriched/")