# Руководство по установке и настройке Spark под управлением YARN для чтения, трансформации и записи данных (HW4)

В данном руководстве описаны шаги по установке и настройке Spark и запуску PySpark-скрипта для трансформации данных.

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

## Загрузка и установка Spark

Скачайте и распакуйте Spark (например, версию 3.4.4):
```bash
wget https://downloads.apache.org/spark/spark-3.4.4/spark-3.4.4-bin-hadoop3.tgz
tar -xvzf spark-3.4.4-bin-hadoop3.tgz
mv spark-3.4.4-bin-hadoop3 spark
```

Откройте файл `~/.profile` пользователя hadoop:
```bash
nano ~/.profile
```
Добавьте следующие строки:
```bash
export SPARK_HOME=/home/hadoop/spark
export PATH=$PATH:$SPARK_HOME/bin
```

Сохраните изменения и примените их:
```bash
source ~/.profile
```

Проверьте версию Spark:
```bash
spark-shell --version
```
Должна отобразиться версия Spark.

Зайдите на узел `team-25-nn`:
```bash
ssh team-25-nn
```

Внесите в файл `~/.profile` (под пользователем hadoop) те же изменения, что описаны выше (добавьте две указанные строки). Выполните файл командой `source ~/.profile`. Выйдите обратно на `team-25-jn` командой `exit`. Повторите для двух оставшихся узлов: `team-25-dn-0` и `team-25-dn-1`.

## Настройка Spark для работы в режиме YARN

Перейдите в каталог конфигурации Spark:
```bash
cd $SPARK_HOME/conf
```

Скопируйте шаблон `spark-env.sh`:
```bash
cp spark-env.sh.template spark-env.sh
```

Откройте файл `spark-env.sh`:
```bash
nano spark-env.sh
```

Добавьте (или раскомментируйте) строки:
```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HADOOP_CONF_DIR=/home/hadoop/hadoop-3.4.0/etc/hadoop
export YARN_CONF_DIR=/home/hadoop/hadoop-3.4.0/etc/hadoop
```
Сохраните и выйдите.

Скопируйте шаблон `spark-defaults.conf`:
```bash
cp spark-defaults.conf.template spark-defaults.conf
nano spark-defaults.conf
```

Добавьте/обновите параметры:
```bash
spark.master                    yarn
spark.submit.deployMode         client
spark.yarn.am.memory            2g
spark.yarn.driver.memory        2g
spark.yarn.executor.memory      2g
spark.yarn.executor.cores       2
spark.hadoop.fs.defaultFS       hdfs://team-25-nn:9000
spark.sql.warehouse.dir         hdfs://team-25-nn:9000/user/hive/warehouse
hive.metastore.uris             thrift://team-25-jn:5433
```

## Установка Spark на остальные узлы кластера
Скопируйте директорию Spark на NameNode и DataNodes (убедитесь, что вы находитесь на `team-25-jn` под пользователем hadoop и внутри `~`):
```bash
scp -r spark team-25-nn:/home/hadoop
scp -r spark team-25-dn-0:/home/hadoop
scp -r spark team-25-dn-1:/home/hadoop
```

Проверьте доступность Spark на NameNode:
```
ssh team-25-nn
source ~/.profile
spark-shell --version
exit
```
Повторите проверку для `team-25-dn-0` и `team-25-dn-1`.

Зайдите на узел `team-25-nn` и убедитесь, что на нем запущен ResourceManager:
```bash
ssh team-25-nn
jps
```
Если в выводе отсутствует ResourceManager, запустите YARN:
```bash
cd ~/hadoop-3.4.0
sbin/start-yarn.sh
```

Выйдите обратно на `team-25-jn` командой `exit`.

Аналогичным образом проверьте, что на `team-25-dn-0` и `team-25-dn-1` запущен NodeManager, и в случае необходимости запустите на них YARN.

Убедитесь, что находитесь на `team-25-jn`. Скопируйте директорию с конфигами Hadoop c `team-25-nn` на `team-25-jn`:
```bash
scp -r hadoop@team-25-nn:/home/hadoop/hadoop-3.4.0/etc/hadoop /home/hadoop/hadoop-3.4.0/etc/
```

Откройте конфиг `yarn-site.xml`:
```bash
nano /home/hadoop/hadoop-3.4.0/etc/hadoop/yarn-site.xml
```
Добавьте между тегами `<configuration>` и `</configuration>` следующие строки:
```bash
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>team-25-nn</value>
    </property>
    <property>
        <name>yarn.resourcemanager.address</name>
        <value>team-25-nn:8032</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.address</name>
        <value>team-25-nn:8030</value>
    </property>
```

## Проверка работы Spark в режиме YARN
Находясь на `team-25-jn`, запустите Spark shell в yarn-режиме:
```bash
spark-shell --master yarn
```
Должно открыться интерактивное окружение Scala. Выйдите из него:
```scala
:quit
```

## Установка PostgreSQL JDBC драйвера
Скопируйте драйвер PostgreSQL в Spark из директории установленного ранее Hive:
```bash
cp /home/hadoop/apache-hive-4.0.0-alpha-2-bin/lib/postgresql-42.7.4.jar $SPARK_HOME/jars
```

Отправьте драйвер на остальные узлы:
```bash
cd $SPARK_HOME/jars
scp postgresql-42.7.4.jar team-25-nn:/home/hadoop/spark/jars
scp postgresql-42.7.4.jar team-25-dn-0:/home/hadoop/spark/jars
scp postgresql-42.7.4.jar team-25-dn-1:/home/hadoop/spark/jars
```

## Создание виртуального окружения Python и установка PySpark
Переключитесь на пользователя team:
```bash
su team
```

Установите пакет `python3.12-venv` для создания виртуальных окружений (считаем, что на машине установлен Python 3.12):
```bash
sudo apt install python3.12-venv
```

Переключитесь на пользователя hadoop:
```bash
exit
```

Создайте и активируйте виртуальное окружение в `~`, а затем установите PySpark:
```bash
cd ~
python3 -m venv venv
source ~/venv/bin/activate
pip install ipython pyspark==3.4.4
```

## Запуск скрипта
В корне репозитория, там же, где находится данное руководство, есть скрипт `transform.py`. Скрипт создает Spark-сессию в режиме YARN, загружает сохраненные в предыдущих заданиях данные (`/user/hive/warehouse/test.db/balance_payments/test_file.csv`), применяет 5 трансформаций к данным, устанавливает новый столбец `decade` в качестве столбца партиционирования (вместо `year`, таким образом уменьшая число партиций) и сохраняет данные как таблицу.

Находясь в `~` пользователя hadoop, откройте новый файл `transform.py` в редакторе:
```bash
nano transform.py
```
Скопируйте содержимое файла `transform.py` из данного репозитория и вставьте в открытый редактор. Сохраните изменения и выйдите из редактора.

Запустите скрипт с помощью Spark:
```bash
spark-submit --master yarn --deploy-mode client transform.py
```

## Проверка результатов
После завершения работы скрипта подключитесь к HiveServer2 через Beeline:
```bash
beeline -u jdbc:hive2://team-25-jn:5433
```
(Если подключиться не удается, запустите HiveServer2, как указано в руководстве `HW3_manual.md`).

Выполните:
```bash
SHOW DATABASES;
```
Вывод должен быть следующим (обязательно наличие `test` и `transformed_data`):
```bash
+-------------------+
|   database_name   |
+-------------------+
| default           |
| test              |
| transformed_data  |
+-------------------+
```

Выполните:
```bash
USE transformed_data;
SHOW TABLES;
```

Вывод:
```bash
+-------------------------------+
|           tab_name            |
+-------------------------------+
| transformed_balance_payments  |
+-------------------------------+
```

Выполните:
```bash
SELECT `period`, `date`, `year`, `month`, `data_value`, `decade` 
FROM transformed_balance_payments 
LIMIT 5;
```
Пример вывода:
```bash
+----------+-------------+-------+--------+-------------+---------+
|  period  |    date     | year  | month  | data_value  | decade  |
+----------+-------------+-------+--------+-------------+---------+
| 1971.06  | 1971-06-01  | 1971  | 6      | 426.0       | 1970    |
| 1971.09  | 1971-09-01  | 1971  | 9      | 435.0       | 1970    |
| 1971.12  | 1971-12-01  | 1971  | 12     | 360.0       | 1970    |
| 1972.03  | 1972-03-01  | 1972  | 3      | 417.0       | 1970    |
| 1972.06  | 1972-06-01  | 1972  | 6      | 528.0       | 1970    |
+----------+-------------+-------+--------+-------------+---------+
```


Вы также можете зайти в Hadoop UI (`http://localhost:9870/`) и удостовериться, что:
1. Появилась новая БД `transformed_data.db` (см. `screenshots/HW4.1_new_db.png` в репозитории)
2. В данной БД есть таблица `transformed_balance_payments` (см. `screenshots/HW4.2_new_table.png` в репозитории)
3. В данной таблице 6 партиций, партиционирование произведено по десятилетию (см. `screenshots/HW4.3_new_partitions.png` в репозитории)

