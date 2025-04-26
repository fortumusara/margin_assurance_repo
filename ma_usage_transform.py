import sys
from pyspark.context import SparkContext
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, year, month
from awsglue.context import GlueContext
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.dynamicframe import DynamicFrame

# Read job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'input_path', 'output_path', 'database_name', 'table_name'])

# Spark + Glue contexts
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = glueContext.create_job(args['JOB_NAME'])

# Read raw CSV file from S3
raw_df = spark.read.option("header", True).csv(args['input_path'])

# Example transformations
transformed_df = raw_df \
    .dropna(subset=["customer_id", "usage_amount"]) \
    .withColumn("usage_amount", col("usage_amount").cast("double")) \
    .withColumn("billing_cycle", col("billing_date").substr(0, 7)) \
    .withColumn("ingestion_ts", current_timestamp())

# Write as Parquet partitioned by billing_cycle
transformed_df.write \
    .mode("overwrite") \
    .partitionBy("billing_cycle") \
    .format("parquet") \
    .save(args['output_path'])

# Convert to Glue DynamicFrame and update catalog
dynamic_frame = DynamicFrame.fromDF(transformed_df, glueContext, "dynamic_frame")

glueContext.write_dynamic_frame.from_options(
    frame=dynamic_frame,
    connection_type="s3",
    connection_options={
        "path": args['output_path'],
        "partitionKeys": ["billing_cycle"]
    },
    format="parquet"
)

# Register table in Glue Catalog
glueContext.catalog.create_table(
    database=args['database_name'],
    table_name=args['table_name'],
    path=args['output_path'],
    format="parquet",
    partition_keys=["billing_cycle"]
)

job.commit()
