#############################################
# GLUE DATABASES
#############################################

resource "aws_glue_catalog_database" "raw" {
  name = "${var.project_name}_raw_db"

  description = "Raw layer database"

  tags = merge(var.common_tags, {
    Layer = "raw"
  })
}

resource "aws_glue_catalog_database" "processed" {
  name = "${var.project_name}_processed_db"

  description = "Processed layer database"

  tags = merge(var.common_tags, {
    Layer = "processed"
  })
}

resource "aws_glue_catalog_database" "curated" {
  name = "${var.project_name}_curated_db"

  description = "Curated layer database"

  tags = merge(var.common_tags, {
    Layer = "curated"
  })
}

#############################################
# RAW TABLE SCHEMA REGISTRY
#############################################

locals {
  raw_tables = {
    customers = {
      columns = [
        { name = "customer_id", type = "string" },
        { name = "customer_unique_id", type = "string" },
        { name = "customer_zip_code_prefix", type = "int" },
        { name = "customer_city", type = "string" },
        { name = "customer_state", type = "string" }
      ]
    }

    orders = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "customer_id", type = "string" },
        { name = "order_status", type = "string" },
        { name = "order_purchase_timestamp", type = "timestamp" },
        { name = "order_approved_at", type = "timestamp" },
        { name = "order_delivered_carrier_date", type = "timestamp" },
        { name = "order_delivered_customer_date", type = "timestamp" },
        { name = "order_estimated_delivery_date", type = "timestamp" }
      ]
    }

    order_items = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "order_item_id", type = "int" },
        { name = "product_id", type = "string" },
        { name = "seller_id", type = "string" },
        { name = "shipping_limit_date", type = "timestamp" },
        { name = "price", type = "double" },
        { name = "freight_value", type = "double" }
      ]
    }

    products = {
      columns = [
        { name = "product_id", type = "string" },
        { name = "product_category_name", type = "string" },
        { name = "product_name_lenght", type = "int" },
        { name = "product_description_lenght", type = "int" },
        { name = "product_photos_qty", type = "int" },
        { name = "product_weight_g", type = "int" },
        { name = "product_length_cm", type = "int" },
        { name = "product_height_cm", type = "int" },
        { name = "product_width_cm", type = "int" }
      ]
    }

    payments = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "payment_sequential", type = "int" },
        { name = "payment_type", type = "string" },
        { name = "payment_installments", type = "int" },
        { name = "payment_value", type = "double" }
      ]
    }
  }
}

#############################################
# DYNAMIC TABLE CREATION
#############################################

resource "aws_glue_catalog_table" "raw_tables" {
  for_each = local.raw_tables

  name          = each.key
  database_name = aws_glue_catalog_database.raw.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    classification = "csv"
    typeOfData     = "file"
  }

  storage_descriptor {
    location      = "s3://${var.raw_bucket}/${each.key}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"

      parameters = {
        "field.delim" = ","
      }
    }

    dynamic "columns" {
      for_each = each.value.columns

      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }

  partition_keys {
    name = "ingestion_date"
    type = "string"
  }
}



#############################################
# PROCESSED TABLES
#############################################

locals {
  processed_tables = {
    customers = {
      columns = [
        { name = "customer_id", type = "string" },
        { name = "customer_unique_id", type = "string" },
        { name = "customer_zip_code_prefix", type = "string" },
        { name = "customer_city", type = "string" },
        { name = "customer_state", type = "string" }
      ]
    }

    orders = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "customer_id", type = "string" },
        { name = "order_status", type = "string" },
        { name = "order_purchase_timestamp", type = "timestamp" }
      ]

      partitions = [
        { name = "order_year", type = "int" },
        { name = "order_month", type = "int" }
      ]
    }

    order_items = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "order_item_id", type = "int" },
        { name = "product_id", type = "string" },
        { name = "price", type = "double" },
        { name = "freight_value", type = "double" }
      ]
    }

    payments = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "payment_sequential", type = "int" },
        { name = "payment_type", type = "string" },
        { name = "payment_installments", type = "int" },
        { name = "payment_value", type = "double" }
      ]
    }

    products = {
      columns = [
        { name = "product_id", type = "string" },
        { name = "product_category_name", type = "string" }
      ]
    }
  }
}

###CREATE PROCESSED TABLES

resource "aws_glue_catalog_table" "processed_tables" {
  for_each = local.processed_tables

  name          = each.key
  database_name = aws_glue_catalog_database.processed.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    classification = "parquet"
  }

  storage_descriptor {
    location      = "s3://${var.processed_bucket}/${each.key}/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = each.value.columns

      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }

  dynamic "partition_keys" {
    for_each = lookup(each.value, "partitions", [])

    content {
      name = partition_keys.value.name
      type = partition_keys.value.type
    }
  }
}





#############################################
# CURATED TABLES
#############################################

locals {
  curated_tables = {
    customer_orders_summary = {
      columns = [
        { name = "customer_id", type = "string" },
        { name = "total_orders", type = "int" },
        { name = "total_spent", type = "double" },
        { name = "avg_order_value", type = "double" }
      ]
    }

    order_details_enriched = {
      columns = [
        { name = "order_id", type = "string" },
        { name = "customer_id", type = "string" },
        { name = "order_purchase_timestamp", type = "timestamp" },
        { name = "product_id", type = "string" },
        { name = "price", type = "double" },
        { name = "freight_value", type = "double" },
        { name = "product_category_name", type = "string" },
        { name = "total_price", type = "double" }
      ]
    }

    sales_metrics = {
      columns = [
        { name = "total_revenue", type = "double" },
        { name = "total_orders", type = "int" },
        { name = "avg_order_value", type = "double" }
      ]

      partitions = [
        { name = "order_year", type = "int" },
        { name = "order_month", type = "int" }
      ]
    }
  }
}


##create curated tables


resource "aws_glue_catalog_table" "curated_tables" {
  for_each = local.curated_tables

  name          = each.key
  database_name = aws_glue_catalog_database.curated.name

  table_type = "EXTERNAL_TABLE"

  parameters = {
    classification = "parquet"
  }

  storage_descriptor {
    location      = "s3://${var.curated_bucket}/${each.key}/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = each.value.columns

      content {
        name = columns.value.name
        type = columns.value.type
      }
    }
  }

  dynamic "partition_keys" {
    for_each = lookup(each.value, "partitions", [])

    content {
      name = partition_keys.value.name
      type = partition_keys.value.type
    }
  }
}