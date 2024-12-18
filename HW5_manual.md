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
```

Копируем в папку с примерами
```
cp dag.py airflow/lib/python3.12/site-packages/airflow/example_dags
```