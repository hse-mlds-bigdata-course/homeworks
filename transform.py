from pyspark.sql import SparkSession
import pyspark.sql.functions as f


INPUT_CSV_PATH = "/user/hive/warehouse/test.db/balance_payments/test_file.csv"


spark = (
    SparkSession.builder
    .appName("DataTransformation")
    .master("yarn")
    .enableHiveSupport()
    .getOrCreate()
)

df = spark.read.csv(INPUT_CSV_PATH, header=True, inferSchema=True)

# 1. Convert the 'Period' column to date format
df = df.withColumn('Date', f.to_date(
    f.concat_ws(
        '-', 
        f.substring(f.col('Period'), 1, 4), 
        f.substring(f.col('Period'), 6, 2), 
        f.lit('01'),
    ),
    'yyyy-MM-dd',
))

# 2. Extract the year and month from the date
df = (
    df
    .withColumn('Year', f.year(f.col('Date')))
    .withColumn('Month', f.month(f.col('Date')))
)

# 3. Filter rows with non-zero 'Data_value' values
df = df.filter(f.col('Data_value').isNotNull())

# 4. Convert the data type of the 'MAGNTUDE' column to integer
df = df.withColumn('MAGNTUDE', f.col('MAGNTUDE').cast('integer'))

# 5. # Create the 'Decade' column to reduce the number of partitions
df = df.withColumn('Decade', (f.col('Year') / 10).cast('integer') * 10)

# Create database
spark.sql("CREATE DATABASE IF NOT EXISTS transformed_data")
spark.sql("USE transformed_data")

(
    df.write.mode('overwrite')
    .partitionBy('Decade')
    .saveAsTable('transformed_balance_payments')
)