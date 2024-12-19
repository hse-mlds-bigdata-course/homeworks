# Руководство по установке и настройке Hive с использованием PostgreSQL (HW3)

Данное руководство предназначено для начинающих пользователей. В нём описаны шаги по установке и настройке PostgreSQL на узле NameNode, а также настройка Hive, интеграция с Metastore на базе PostgreSQL, создание и загрузка данных в таблицы. Инструкции сопровождаются комментариями на русском языке.

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

## Подготовка PostgreSQL на NameNode

1. Подключитесь к jump node:
```bash
ssh team@176.109.91.27
```

2. Перейдите на NameNode:
```bash
ssh team-25-nn
# введите пароль при необходимости
```

3. Перейдите на пользователя team:
```bash
su team
```

4. Установите PostgreSQL на NameNode:
```bash
sudo apt install postgresql
# введите пароль, согласитесь с установкой (y)
```

5. Переключитесь на пользователя postgres:
```bash
sudo -i -u postgres
psql
```

## Создание базы данных Metastore

В консоли psql выполните следующие команды:

```sql
CREATE DATABASE metastore;
CREATE USER hive WITH PASSWORD 'any_pass_you_like';
GRANT ALL PRIVILEGES ON DATABASE "metastore" TO hive;
ALTER DATABASE metastore OWNER TO hive;
```

Выйдите из psql и вернитесь к пользователю team:
```bash
\q
exit
su team
```

## Настройка PostgreSQL для удалённого доступа

1. Отредактируйте файл `/etc/postgresql/16/main/postgresql.conf`:
```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

Найдите секцию CONNECTION AND AUTHENTICATION, добавьте строку:
```
listen_addresses = 'team-25-nn'
```
(Вы можете указать имя хоста или IP-адрес, где запущен PostgreSQL)

2. Отредактируйте файл `/etc/postgresql/16/main/pg_hba.conf`:
```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

Найдите секцию "IPv4 local connections" и добавьте строки:
```
host    metastore       hive            192.168.1.0/24          scram-sha-256
host    metastore       hive            127.0.0.1/32            scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
```

3. Перезапустите PostgreSQL:
```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

## Установка клиента PostgreSQL на Jump Node

1. Вернитесь на jump node:
```bash
exit
ssh team-25-jn
su team
```

2. Установите клиент PostgreSQL:
```bash
sudo apt install postgresql-client-16
# вводим пароль, подтверждаем установку
```

3. Переключитесь на пользователя hadoop:
```bash
su hadoop
```

## Создание туннеля для проверки подключения к PostgreSQL

1. Создаём SSH-туннель с JN к NN:
```bash
ssh -L 5432:team-25-nn:5432 hadoop@team-25-nn -N &
```

2. Проверяем подключение к базе:
```bash
psql -h localhost -p 5432 -U hive -W -d metastore
# вводим пароль: any_pass_you_like
\q # выход
```

## Установка и настройка Hive

1. Переключитесь на пользователя hadoop:
```bash
su hadoop
```

2. Зайдите в домашнюю директорию и скачайте Hive:
```bash
cd ~
wget wget https://archive.apache.org/dist/hive/hive-4.0.0-alpha-2/apache-hive-4.0.0-alpha-2-bin.tar.gz
tar -xvzf apache-hive-4.0.0-alpha-2-bin.tar.gz
cd apache-hive-4.0.0-alpha-2-bin/
```

3. Загрузите PostgreSQL JDBC драйвер:
```bash
cd lib
wget https://jdbc.postgresql.org/download/postgresql-42.7.4.jar
```

4. Настройте hive-site.xml:
```bash
cd ../conf/
nano hive-site.xml
```

Вставьте конфигурации:
```xml
<configuration>
    <property>
        <name>hive.server2.authentication</name>
        <value>NONE</value>
    </property>
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/user/hive/warehouse</value>
    </property>
    <property>
        <name>hive.server2.thrift.port</name>
        <value>5433</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:postgresql://team-25-nn:5432/metastore</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>org.postgresql.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>hive</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>any_pass_you_like</value>
    </property>
</configuration>
```

5. Настройте переменные окружения в `~/.profile`:
```bash
nano ~/.profile
```

Добавьте строки:
```bash
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

export HIVE_HOME=/home/hadoop/apache-hive-4.0.0-alpha-2-bin
export HIVE_CONF_DIR=$HIVE_HOME/conf
export HIVE_AUX_JARS_PATH=$HIVE_HOME/lib/*
export PATH=$PATH:$HIVE_HOME/bin
```

6. Активируйте новые переменные:
```bash
source ~/.profile
```

7. Проверьте версию Hive:
```bash
hive --version
```

## Настройка Hadoop для Hive

1. Отредактируйте core-site.xml:
```bash
cd $HADOOP_HOME/etc/hadoop
nano core-site.xml
```

Добавьте:
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://team-25-nn:9000</value>
    </property>
</configuration>
```

2. Создайте директории в HDFS:
```bash
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod g+w /tmp
hdfs dfs -chmod g+w /user/hive/warehouse
```

## Инициализация Metastore Hive

1. Инициализируйте схему базы данных для Hive:
```bash
cd ~/apache-hive-4.0.0-alpha-2-bin/
bin/schematool -dbType postgres -initSchema
```

2. Запустите HiveServer2:
```bash
hive --hiveconf hive.server2.enable.doAs=false --hiveconf hive.security.authorization.enabled=false --service hiveserver2 1>> /tmp/hs2.log 2>> /tmp/hs2.log &
```

## Работа с базой данных и загрузка данных

1. Откройте новый сеанс в tmux:
```bash
tmux
```

2. Подключитесь к HiveServer2 через Beeline:
```bash
beeline -u jdbc:hive2://team-25-jn:5433
```

3. Создайте базу данных:
```sql
CREATE DATABASE test;
SHOW DATABASES;
```

4. Создайте директорию для данных в HDFS:
```bash
hdfs dfs -mkdir /input
hdfs dfs -chmod g+w /input
```

5. Загрузите тестовый CSV файл (для примера используется файл Balance of payments, можно использовать лююбой другой):

```bash
cd ~
wget https://www.stats.govt.nz/assets/Uploads/Balance-of-payments/Balance-of-payments-and-international-investment-position-June-2024-quarter/Download-data/balance-of-payments-and-international-investment-position-june-2024-quarter.csv

mv balance-of-payments-and-international-investment-position-june-2024-quarter.csv test_file.csv

hdfs dfs -put test_file.csv /input
hdfs fsck /input/test_file.csv
head -10 test_file.csv
```

## Создание таблицы в Hive и загрузка данных

1. Вернитесь в beeline:
```bash
beeline -u jdbc:hive2://team-25-jn:5433
use test;
```

2. Создайте таблицу:
```sql
CREATE TABLE IF NOT EXISTS test.balance_payments (
    Series_reference STRING,
    Period DECIMAL(6,2),
    Data_value INT,
    Suppressed STRING,
    STATUS STRING,
    UNITS STRING,
    MAGNTUDE INT,
    Subject STRING,
    Group_name STRING,
    Series_title_1 STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
TBLPROPERTIES ("skip.header.line.count"="1");
```

3. Просмотрите таблицы и структуру:
```sql
SHOW TABLES;
DESCRIBE balance_payments;
SHOW CREATE TABLE balance_payments;
```

4. Загрузите данные в таблицу:
```sql
LOAD DATA INPATH '/input/test_file.csv' INTO TABLE test.balance_payments;
```

5. Проверка загрузки данных:
```sql
SELECT * FROM balance_payments LIMIT 5;
SELECT COUNT(*) FROM balance_payments;
```

## Создание партиционированной таблицы

1. Создайте партиционированную таблицу:
```sql
CREATE TABLE test.balance_payments_partitioned (
    Series_reference STRING,
    Data_value INT,
    Suppressed STRING,
    STATUS STRING,
    UNITS STRING,
    MAGNTUDE INT,
    Subject STRING,
    Group_name STRING,
    Series_title_1 STRING
)
PARTITIONED BY (year INT)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ',';
```

2. Включите динамическое партиционирование:
```sql
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
```

3. Перенесите данные с добавлением партиций:
```sql
INSERT OVERWRITE TABLE test.balance_payments_partitioned 
PARTITION(year)
SELECT 
    Series_reference,
    Data_value,
    Suppressed,
    STATUS,
    UNITS,
    MAGNTUDE,
    Subject,
    Group_name,
    Series_title_1,
    CAST(FLOOR(Period) AS INT) AS year
FROM test.balance_payments;
```

4. Проверьте партиции и данные:
```sql
SHOW PARTITIONS test.balance_payments_partitioned;
SELECT * FROM test.balance_payments_partitioned LIMIT 5;
```

## Проверка содержимого HDFS

1. Просмотрите файлы в HDFS:
```bash
hdfs dfs -ls /user/hive/warehouse/test.db/balance_payments
hdfs dfs -cat /user/hive/warehouse/test.db/balance_payments/* | head -n 5
```

2. Также просмотрите партиционированную таблицу:
```bash
hdfs dfs -ls /user/hive/warehouse/test.db/balance_payments_partitioned
```

## Проверка через веб-интерфейс Hadoop

1. Создайте локальный форвардинг портов для доступа к веб-интерфейсам:
```bash
ssh -L 9870:localhost:9870 -L 8088:localhost:8088 -L 19888:localhost:19888 team@176.109.91.27
```

2. На локальной машине откройте в браузере:
- http://localhost:9870 — интерфейс HDFS NameNode
- http://localhost:8088 — интерфейс YARN
- http://localhost:19888 — History Server (при наличии)

3. Перейдите к разделу Utilities / Browse the file system и проверьте содержимое:
```bash
/user/hive/warehouse/test.db/balance_payments/
/user/hive/warehouse/test.db/balance_payments_partitioned/
```

## Итоги

- PostgreSQL успешно установлен и настроен для работы с Hive Metastore.
- Hive установлен, сконфигурирован для использования Metastore на PostgreSQL.
- Данные загружены в HDFS и успешно импортированы в таблицы Hive.
- Создана партиционированная таблица и данные в неё перенесены.
- Доступ к веб-интерфейсам Hadoop и проверка содержимого HDFS осуществлены.

На этом настройка и базовая проверка работы Hive Metastore и загрузки данных в Hive завершены.
