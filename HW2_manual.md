
# Руководство по настройке YARN в кластере Hadoop

Данное руководство содержит пошаговые инструкции по настройке и запуску YARN в кластере Hadoop с несколькими узлами. Предполагается, что доступ по SSH к кластеру, а также установка Hadoop и Java уже настроены.

## Описание окружения

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


## Подготовительные шаги

1. Подключитесь к узлу `Jump Node` и переключитесь на пользователя `hadoop`:

   ```bash
   ssh team@176.109.91.27
   su hadoop
   ```

2. Подключитесь к `NameNode` и перейдите в папку `hadoop`:

   ```bash
   ssh team-25-nn
   su hadoop
   cd hadoop-3.4.0/etc/hadoop/
   ```

---

## Настройка YARN

### Настройка `mapred-site.xml`

1. Откройте файл конфигурации:

   ```bash
   nano mapred-site.xml
   ```

2. Добавьте следующие параметры:

   ```xml
   <configuration>
       <property>
           <name>mapreduce.framework.name</name>
           <value>yarn</value>
       </property>
       <property>
           <name>mapreduce.application.classpath</name>
           <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
       </property>
   </configuration>
   ```

3. Сохраните изменения и выйдите из редактора.

### Настройка `yarn-site.xml`

1. Откройте файл:

   ```bash
   nano yarn-site.xml
   ```

2. Добавьте следующие параметры:

   ```xml
   <configuration>
       <property>
           <name>yarn.nodemanager.aux-services</name>
           <value>mapreduce_shuffle</value>
       </property>
       <property>
           <name>yarn.nodemanager.env-whitelist</name>
           <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
       </property>
   </configuration>
   ```

3. Сохраните изменения и выйдите из редактора.

### Распространение файлов конфигурации

Скопируйте обновленные файлы на `DataNodes`:

```bash
scp mapred-site.xml team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp mapred-site.xml team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp yarn-site.xml team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp yarn-site.xml team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
```

---

## Запуск YARN и History Server

1. Вернитесь в домашнюю директорию Hadoop:

   ```bash
   cd ~/hadoop-3.4.0
   ```

2. Запустите YARN:

   ```bash
   sbin/start-yarn.sh
   ```

3. Запустите History Server:

   ```bash
   bin/mapred --daemon start historyserver
   ```

---

## Настройка прокси-сервера NGINX (опционально)

### Настройка прокси для веб-интерфейса YARN

1. Подключитесь к узлу `Jump Node`:

   ```bash
   ssh team-25-jn
   su team
   ```

2. Скопируйте и настройте шаблоны NGINX:

   ```bash
   sudo cp /etc/nginx/sites-available/nn /etc/nginx/sites-available/ya
   sudo cp /etc/nginx/sites-available/nn /etc/nginx/sites-available/dh
   
   ```

3. Откройте конфигурацию:
   ```bash
   sudo nano /etc/nginx/sites-available/ya
   ```

   Добавьте или обновите:

   ```nginx
   server {
       listen 8088 default_server;
       .....
       location / {
           proxy_pass http://team-25-nn:8088;
       }
   }
   ```

   Конфигурация history server:
   ```bash
   sudo nano /etc/nginx/sites-available/dh 
   ```

   Добавьте или обновите:

   ```nginx
   server {
      listen 19888 default_server;
      .....
      location / {
         proxy_pass http://team-25-nn:19888;
      }
   ```

4. Включите конфигурацию:

   ```bash
   sudo ln -s /etc/nginx/sites-available/ya /etc/nginx/sites-enabled/ya
   sudo ln -s /etc/nginx/sites-available/dh /etc/nginx/sites-enabled/dh
   sudo systemctl reload nginx
   ```

---

## Откройте веб-браузер на локальной машине (после запуска тоннелей) и проверьте работу
   Yarn interface:

   ```web
   localhost:8088
   ```

   JobHistory server:
   
   ```web
   localhost:19888
   ```


## Остановка сервисов

1. Подключитесь к `NameNode`:

   ```bash
   ssh team-25-nn
   cd hadoop-3.4.0/
   ```

2. Остановите History Server и YARN:

   ```bash
   mapred --daemon stop historyserver
   sbin/stop-yarn.sh
   ```

3. Проверьте отсутствие работающих процессов:

   ```bash
   jps
   ```

---

## Результаты и проверка

- Веб-интерфейсы YARN и History Server должны быть доступны.
- Все узлы должны корректно сообщать о своем состоянии.
- Логи можно просмотреть в директории `$HADOOP_HOME/logs`.

Поздравляем! YARN успешно настроен и запущен.
