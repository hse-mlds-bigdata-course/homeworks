# Руководство по установке Airflow

На данном этапе у нас уже должен быть развернут кластер Hadoop, yarn, hive и для spark добавлены необходимые env переменные.

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

Запускаем airflow
```
airflow standalone 
```

Зайдем в web интерфейс airflow на порту 8080, используем логин и пароль который был выведен при запуске сервиса.