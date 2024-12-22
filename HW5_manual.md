# Руководство по установке Airflow и запуску DAG
На данном этапе у нас уже должен быть развернут кластер Hadoop, yarn, hive и для spark добавлены необходимые env переменные.

## Описание среды

В примере используются следующие версии и настройки:

- **ОС**: Ubuntu (версия 20.04 или выше)
- **Java**: OpenJDK 11 (openjdk-11-jdk-headless)
- **Hadoop**: Версия 3.4.0
- **Пользователи**: 
  - Системный пользователь: `team` (имеет SSH-доступ к узлам)
  - Пользователь Hadoop: `hadoop` (будет создан для управления кластером)
  
- **IP-адреса и имена узлов** (приведены в качестве примера, при необходимости замените на свои значения):
  - Входной узел Jump Node (JN) для SSH-доступа: `176.109.91.27`
  - Jump Node (JN): `192.168.1.102` с именем `team-25-jn`
  - NameNode (NN): `192.168.1.103` с именем `team-25-nn`
  - DataNode 0 (DN0): `192.168.1.104` с именем `team-25-dn-0`
  - DataNode 1 (DN1): `192.168.1.105` с именем `team-25-dn-1`

Перед началом работы проверьте доступ по SSH к указанным хостам и наличие необходимых прав.

## Подключение

Подключитесь к jump node:
```bash
ssh team@176.109.91.27
```

Переключитесь на пользователя hadoop:
```bash
su hadoop
cd ~
```

Устанавливаем пакет для работы с виртуальными окружениями в python
```bash
sudo apt install python3-virtualenv
```

Создадим виртуальное окружение
```bash
virtualenv -p python3 ~/airflow 
```

Активируем виртуальное окружение
```bash
source airflow/bin/activate
```

В это окружение установим необходиые пакеты, сам apache airflow и spark
```bash
pip install "apache-airflow[celery]==2.10.3" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.8.txt"
pip install pyspark
```

По умолчанию airflow запускается на порту 8080, но так как spark-ui у нас уже занимает данный порт, необходимо поменять конфигурацию airflow

Запускаем airflow в первый раз, чтобы создался файл конфигурации airflow.cfg
```bash
airflow standalone
```
Останавливаем airflow ctrl + c

Отредактируем файл airflow.cfg в папкe ~/airflow
В секции [webserver]
Поменяем значения
base_url = http://localhost:8090
web_server_port = 8090

Запускаем airflow
```bash
airflow standalone 
```

Зайдем в web интерфейс airflow на порту 8090, используем логин и пароль который был выведен при запуске сервиса.

Создаем файл dag.py
```bash
touch dag.py
```

Заполняем его кодом
```python
import datetime
from airflow.decorators import task
from airflow.models.dag import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, count

with DAG(
    "example",
    schedule_interval=None,
    start_date = days_ago(2),
    catchup=False,
    schedule=None,
    tags=["example"],
) as dag:

    def process_and_save_data():
        spark = SparkSession.builder \
            .master("yarn") \
            .appName("HW5") \
            .config("spark.sql.warehouse.dir", "hdfs://team-25-nn:9000/user/hive/warehouse") \
            .config("hive.metastore.uris", "thrift://team-25-jn:5433") \
            .enableHiveSupport() \
            .getOrCreate()
        df = spark.read.csv("/user/hive/warehouse/test.db/balance_payments/test_file.csv", header=True, inferSchema=True)

        df = df.withColumn("Data_value", col("Data_value").cast("double"))

        aggregated_df = df.groupBy("Group").agg(
            avg("Data_value").alias("avg_amount"),
            count("*").alias("count_records")
        )

        filtered_df = aggregated_df.filter(col("avg_amount") > 100)

        table_name = "test_db.partitioned_table"

        spark.sql(f"""
            CREATE TABLE IF NOT EXISTS {table_name} (
                avg_amount DOUBLE,
                count_records BIGINT
            )
            PARTITIONED BY (Group STRING)
            STORED AS PARQUET
        """)

        filtered_df.write \
            .mode("overwrite") \
            .format("hive") \
            .partitionBy("Group") \
            .saveAsTable(table_name)

        spark.stop()

    process_and_save_data = PythonOperator(task_id="process_and_save_data", python_callable=process_and_save_data)

    process_and_save_data
```

Копируем в папку с примерами
```bash
cp dag.py airflow/lib/python3.12/site-packages/airflow/example_dags
```

Запускаем в ui airflow dag на выполнение

Проверяем результат

## Итоги

- Airflow установлен
- Описан Dag, который загружает данные, трансформирует их и записывает результат в новую таблицу