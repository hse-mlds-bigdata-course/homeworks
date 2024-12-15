
# Руководство по установке и настройке кластера Hadoop

Данное руководство описывает установку и настройку Hadoop на кластере из нескольких узлов под управлением Ubuntu Linux. 

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

Если ваша конфигурация отличается, внесите соответствующие изменения в IP-адреса и имена хостов.

## Предварительная подготовка

### Проверка SSH и хостов

Подключаемся к первому (jump) узлу:

```bash
ssh team@176.109.91.27
```

Проверяем версии Python (опционально):

```bash
python3 -V
```

Проверяем доступность остальных узлов (ping по IP-адресу):

```bash
ping 192.168.1.102
ping 192.168.1.103
ping 192.168.1.104
ping 192.168.1.105
```

### Установка Java

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo apt-get install -y openjdk-11-jdk-headless
```

Проверяем Java:

```bash
java -version
```

### Создание пользователя Hadoop и настройка SSH-ключей

На каждом узле создадим пользователя hadoop, настроим SSH-ключи для безпарольного доступа.

На jump-узле (team-25-jn):

```bash
sudo adduser hadoop
# Следуйте инструкциям, пароль такой же, как и у пользователя team

sudo -i -u hadoop
ssh-keygen
# Нажимаем Enter несколько раз, без пароля

cat .ssh/id_ed25519.pub
# Скопируйте содержимое ключа
```

Сохраните этот ключ, он понадобится для авторизации на других узлах.

### Загрузка Hadoop

Скачиваем дистрибутив Hadoop на jump-узле:

```bash
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
```

### Настройка файла `/etc/hosts` на каждом узле

На каждом узле (JN, NN, DN0, DN1) нужно обновить файл `/etc/hosts`, чтобы узлы знали друг о друге по именам.

Пример для jump-узла:

```bash
sudo nano /etc/hosts
```

Добавьте следующие строки:

```text
192.168.1.102   team-25-jn
192.168.1.103   team-25-nn
192.168.1.104   team-25-dn-0
192.168.1.105   team-25-dn-1
```

Проверяем доступ по имени:

```bash
ping team-25-jn
ping team-25-nn
ping team-25-dn-0
ping team-25-dn-1
```

Проделайте аналогичные действия для остальных узлов.



### Создание пользователя Hadoop на остальных узлах и копирование ключей

На каждом узле создаем пользователя hadoop и генерируем SSH-ключи:

```bash
ssh team-25-nn
sudo adduser hadoop
sudo -i -u hadoop
ssh-keygen
cat .ssh/id_ed25519.pub
```

Скопируйте открытые ключи со всех узлов (JN, NN, DN0, DN1), предварительно перейдя в них по SSH:

```bash
ssh team-25-dn-0
ssh team-25-dn-1
```


После этого вернитесь на jump-узел и вставьте все ключи в `~hadoop/.ssh/authorized_keys`:

```bash
ssh team-25-jn
nano .ssh/authorized_keys
# Вставьте все 4 ключа
```

Затем распределите этот файл на все узлы:

```bash
scp .ssh/authorized_keys team-25-nn:/home/hadoop/.ssh/
scp .ssh/authorized_keys team-25-dn-0:/home/hadoop/.ssh/
scp .ssh/authorized_keys team-25-dn-1:/home/hadoop/.ssh/
```

Теперь проверим доступ без пароля:

```bash
ssh team-25-jn
ssh team-25-nn
ssh team-25-dn-0
ssh team-25-dn-1
```

### Распространение Hadoop на все узлы

```bash
scp hadoop-3.4.0.tar.gz team-25-nn:/home/hadoop
scp hadoop-3.4.0.tar.gz team-25-dn-0:/home/hadoop
scp hadoop-3.4.0.tar.gz team-25-dn-1:/home/hadoop
```

Распаковываем Hadoop на каждом узле:

```bash
tar -xvzf hadoop-3.4.0.tar.gz
ssh team-25-nn "tar -xvzf hadoop-3.4.0.tar.gz"
ssh team-25-dn-0 "tar -xvzf hadoop-3.4.0.tar.gz"
ssh team-25-dn-1 "tar -xvzf hadoop-3.4.0.tar.gz"
```

## Настройка Hadoop

### Настройка переменных среды

На узле team-25-nn (NameNode):

```bash
ssh team-25-nn
su hadoop
java -version
which java
readlink -f /usr/bin/java
```

Откроем файл `~/.profile` для пользователя hadoop:

```bash
nano ~/.profile
```

Добавляем строки:

```bash
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

Активируем переменные:

```bash
source ~/.profile
hadoop version
echo $HADOOP_HOME
echo $JAVA_HOME
```

Копируем `.profile` на DataNodes:

```bash
scp ~/.profile team-25-dn-0:/home/hadoop
scp ~/.profile team-25-dn-1:/home/hadoop
```


Активируем переменные на других нодах и возвращаемся на NameNode:

```bash
ssh team-25-dn-0
source ~/.profile

ssh team-25-dn-1
source ~/.profile

ssh team-25-nn
```

### Конфигурационные файлы Hadoop

#### `hadoop-env.sh`

```bash
nano hadoop-3.4.0/etc/hadoop/hadoop-env.sh
```
Добавляем:

```bash
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
```
Копируем на другие ноды:

```bash
scp hadoop-env.sh team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp hadoop-env.sh team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
```

#### `core-site.xml`

```bash
nano hadoop-3.4.0/etc/hadoop/core-site.xml
```

Добавляем:

```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://team-25-nn:9000</value>
  </property>
</configuration>
```

#### `hdfs-site.xml`

```bash
nano hadoop-3.4.0/etc/hadoop/hdfs-site.xml
```

Добавляем:

```xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
</configuration>
```



#### `workers`

```bash
nano hadoop-3.4.0/etc/hadoop/workers
```

Заменяем `localhost` на:

```text
team-25-nn
team-25-dn-0
team-25-dn-1
```

Копируем на другие ноды:

```bash
scp core-site.xml team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp core-site.xml team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp hdfs-site.xml team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp hdfs-site.xml team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp workers team-25-dn-0:/home/hadoop/hadoop-3.4.0/etc/hadoop
scp workers team-25-dn-1:/home/hadoop/hadoop-3.4.0/etc/hadoop
```


---

## Запуск Hadoop (сначала форматируем hdfs систему на NameNode)

```bash
cd ~/hadoop-3.4.0
bin/hdfs namenode -format
sbin/start-dfs.sh
jps
```
Если jps показывает следующее, то всё работает:
```bash
Jps
DataNode
NameNode
SecondaryNameNode
```

---

## Настройка NGINX

Заходим на JumpNode как team:
```bash
ssh team-25-jn
su team
```

```bash
sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/nn
sudo nano /etc/nginx/sites-available/nn
```

Добавляем / комментируем существующие строки:

```nginx
server {
    listen 9870 default_server;
    # listen [::]:80 default_server;
    .....
    location / {
      # try_files $uri $uri/ =404;
      proxy_pass http://team-25-nn:9870;
	}
}
```

Активируем NGINX:

```bash
sudo ln -s /etc/nginx/sites-available/nn /etc/nginx/sites-enabled/nn
sudo systemctl reload nginx
```

Доступ к веб-интерфейсу:

```text
http://176.109.91.27:9870
```

---

## Результат

Кластер Hadoop успешно настроен и запущен!