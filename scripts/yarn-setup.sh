#!/bin/bash

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# Log functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Read configuration from nodes.txt
if [ ! -f "nodes.txt" ]; then
    error "nodes.txt not found!"
fi

# Parse nodes.txt
JUMP_SERVER=$(head -n 1 nodes.txt)
declare -A NODES
while read -r line; do
    if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+(.+)$ ]]; then
        NODES[${BASH_REMATCH[2]}]=${BASH_REMATCH[1]}
    fi
done < <(tail -n +2 nodes.txt)

# Constants
HADOOP_VERSION="3.4.0"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VERSION}"
NAME_NODE=$(grep "nn" nodes.txt | awk '{print $2}')

# Create YARN configuration files
create_mapred_site() {
    cat > mapred-site.xml << EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>\$HADOOP_HOME/share/hadoop/mapreduce/*:\$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOF
}

create_yarn_site() {
    cat > yarn-site.xml << EOF
<?xml version="1.0"?>
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
EOF
}

create_nginx_configs() {
    # YARN web interface config
    cat > ya << EOF
server {
    listen 8088 default_server;
    location / {
        proxy_pass http://${NAME_NODE}:8088;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    # History server web interface config
    cat > dh << EOF
server {
    listen 19888 default_server;
    location / {
        proxy_pass http://${NAME_NODE}:19888;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
}

# Setup functions
setup_yarn() {
    log "Setting up YARN configuration"
    
    # Create configuration files
    create_mapred_site
    create_yarn_site
    
    # Copy configurations to name node
    scp mapred-site.xml yarn-site.xml team@${NODES[$NAME_NODE]}:/tmp/
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop cp /tmp/mapred-site.xml /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/"
    
    # Copy to data nodes
    for node in "${!NODES[@]}"; do
        if [[ $node == *"dn"* ]]; then
            log "Copying configuration to $node"
            scp mapred-site.xml yarn-site.xml team@${NODES[$node]}:/tmp/
            ssh team@${NODES[$node]} "sudo -u hadoop cp /tmp/mapred-site.xml /tmp/yarn-site.xml $HADOOP_HOME/etc/hadoop/"
        fi
    done
}

setup_nginx() {
    log "Setting up Nginx configuration"
    
    create_nginx_configs
    
    # Copy and enable Nginx configs
    scp ya dh team@$JUMP_SERVER:/tmp/
    ssh team@$JUMP_SERVER "sudo cp /tmp/ya /etc/nginx/sites-available/ && \
                          sudo cp /tmp/dh /etc/nginx/sites-available/ && \
                          sudo ln -sf /etc/nginx/sites-available/ya /etc/nginx/sites-enabled/ya && \
                          sudo ln -sf /etc/nginx/sites-available/dh /etc/nginx/sites-enabled/dh && \
                          sudo systemctl reload nginx"
}

start_services() {
    log "Starting YARN services"
    
    # Start YARN
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/sbin/start-yarn.sh"
    
    # Start history server
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/bin/mapred --daemon start historyserver"
    
    log "YARN services started successfully"
}

stop_services() {
    log "Stopping all services"
    
    # Stop services on name node
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/bin/mapred --daemon stop historyserver"
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/sbin/stop-yarn.sh"
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/sbin/stop-dfs.sh"
    
    # Check processes on all nodes
    for node in "${!NODES[@]}"; do
        if [[ $node != *"jn"* ]]; then
            log "Checking processes on $node"
            ssh team@${NODES[$node]} "sudo -u hadoop jps"
        fi
    done
}

# Main execution
usage() {
    echo "Usage: $0 [start|stop]"
    echo "  start: Setup and start YARN services"
    echo "  stop:  Stop all Hadoop and YARN services"
    exit 1
}

case "$1" in
    "start")
        log "Starting YARN setup and services..."
        setup_yarn
        setup_nginx
        start_services
        log "Setup complete! Access YARN web interface at ${JUMP_SERVER}:8088"
        log "Access History Server at ${JUMP_SERVER}:19888"
        ;;
    "stop")
        log "Stopping all services..."
        stop_services
        log "All services stopped"
        ;;
    *)
        usage
        ;;
esac

# Cleanup temporary files
rm -f mapred-site.xml yarn-site.xml ya dh

exit 0