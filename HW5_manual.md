# Руководство по установке Airflow

На данном этапе у нас уже должен быть развернут кластер Hadoop, yarn, hive и для spark добавлены необходимые env переменные.

Устанавливаем пакет для работы с виртуальными окружениями в python
```
sudo apt install python3-virtualenv
```

Создадим виртуальное окружение
```
virtualenv -p python3 ~/airflow 
```

Активируем виртуальное окружение
```
source airflow/bin/activate
```

В это окружение установим необходиые пакеты, сам apache airflow и spark
```
pip install "apache-airflow[celery]==2.10.3" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.10.3/constraints-3.8.txt"
pip install pyspark
pip install onetl[files]
```

По умолчанию airflow запускается на порту 8080, но так как spark-ui у нас уже занимает данный порт, необходимо поменять конфигурацию airflow

Отредактируем файл airflow.cfg в папку ~/airflow
В секции [webserver]
Поменяем значения
base_url = http://localhost:8090
web_server_port = 8090

Запускаем airflow
```
airflow standalone 
```

Зайдем в web интерфейс airflow на порту 8090, используем логин и пароль который был выведен при запуске сервиса.

Создаем файл dag.py
```
touch dag.py
```

Заполняем его кодом
```
import datetime
from airflow.decorators import task
from airflow.models.dag import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago

from pyspark.sql import SparkSession

with DAG(
    "example",
    schedule_interval=None,
    start_date = days_ago(2),
    catchup=False,
    schedule=None,
    tags=["example"],
) as dag:

    def load_data():
        spark = SparkSession.builder \
            .master("yarn") \
            .appName("HW5") \
            .config("spark.sql.warehouse.dir", "hdfs://team-25-nn:9000/user/hive/warehouse") \
            .config("hive.metastore.uris", "thrift://team-25-jn:5433") \
            .enableHiveSupport() \
            .getOrCreate()

        df = spark.read.csv("/user/hive/warehouse/test.db/balance_payments/test_file.csv", header=True, inferSchema=True)

        df.write.saveAsTable("test.balance_payments")
        spark.stop()

    load_data = PythonOperator(task_id="load_data", python_callable=load_data)

    load_data
```

Копируем в папку с примерами
```
cp dag.py airflow/lib/python3.12/site-packages/airflow/example_dags
```

Запускаем в ui airflow dag на выполнение

Проверяем результат 