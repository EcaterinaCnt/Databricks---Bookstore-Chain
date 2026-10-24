# Databricks notebook cell after copying arrival-batch files to a UC Volume.
# Change catalog and schema to your actual accessible values.
from pyspark.sql import SparkSession  # type: ignore[reportMissingImports]

spark = SparkSession.builder.getOrCreate()

CATALOG = 'YOUR_CATALOG'
SCHEMA = 'YOUR_SCHEMA'
VOLUME = 'bookstore_landing'
ROOT = f'/Volumes/{CATALOG}/{SCHEMA}/{VOLUME}/landing'

# Preview raw catalogue snapshots (Bronze staging proof of concept)
path = f'{ROOT}/batch_01_arrived_2026-10-05/master/product_catalogue_20261005.csv'
catalogue = (spark.read.option('header', True).option('inferSchema', True).csv(path))
catalogue.select('product_id','product_code','title','format','list_price','status').show(truncate=False)

# Preview one daily till JSON file, with its nested receipts and payment records.
pos_file = f'{ROOT}/batch_01_arrived_2026-10-05/pos/ST001_T01_20261005.json'
raw_pos = spark.read.option('multiLine', True).json(pos_file)
raw_pos.select('store_id','till_id','business_date').show(truncate=False)
(raw_pos.selectExpr('explode(receipts) AS receipt')
        .selectExpr('receipt.receipt_id','receipt.status','receipt.receipt_total')
        .show(truncate=False))

# Later: replace these batch-path reads with Auto Loader and managed Bronze tables.
