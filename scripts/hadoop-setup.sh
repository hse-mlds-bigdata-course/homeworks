#!/bin/bash

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'  # No Color

# Log function
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
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VERSION}"
NAME_NODE=$(grep "nn" nodes.txt | awk '{print $2}')

# Create configuration files
create_hadoop_env() {
    cat > hadoop-env.sh << EOF
export JAVA_HOME=${JAVA_HOME}
EOF
}

create_core_site() {
    cat > core-site.xml << EOF
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${NAME_NODE}:9000</value>
    </property>
</configuration>
EOF
}

create_hdfs_site() {
    cat > hdfs-site.xml << EOF
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
</configuration>
EOF
}

create_workers() {
    > workers
    for node in "${!NODES[@]}"; do
        if [[ $node != *"jn"* ]]; then
            echo "$node" >> workers
        fi
    done
}

create_profile() {
    cat > hadoop_profile << EOF
export HADOOP_HOME=${HADOOP_HOME}
export JAVA_HOME=${JAVA_HOME}
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF
}

create_nginx_conf() {
    cat > nn << EOF
server {
    listen 9870 default_server;
    location / {
        proxy_pass http://${NAME_NODE}:9870;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
}

# Setup functions
setup_hosts() {
    local node=$1
    log "Setting up hosts file on $node"
    
    # Create temporary hosts file
    > temp_hosts
    for n in "${!NODES[@]}"; do
        echo "${NODES[$n]} $n" >> temp_hosts
    done
    
    scp temp_hosts team@$node:/tmp/
    ssh team@$node "sudo bash -c 'cat /tmp/temp_hosts > /etc/hosts'"
    rm temp_hosts
}

setup_node() {
    local node=$1
    local ip=${NODES[$node]}
    
    log "Setting up node: $node ($ip)"
    
    # Install prerequisites
    ssh team@$node "sudo apt-get update && sudo apt-get install -y software-properties-common openjdk-11-jdk-headless"
    
    # Create hadoop user
    ssh team@$node "sudo adduser --disabled-password --gecos '' hadoop"
    
    # Generate SSH key
    ssh team@$node "sudo -u hadoop ssh-keygen -t ed25519 -N '' -f /home/hadoop/.ssh/id_ed25519"
    
    # Setup hosts
    setup_hosts $ip
}

collect_ssh_keys() {
    log "Collecting SSH keys"
    > authorized_keys
    for node in "${!NODES[@]}"; do
        ssh team@${NODES[$node]} "sudo cat /home/hadoop/.ssh/id_ed25519.pub" >> authorized_keys
    done
}

distribute_ssh_keys() {
    log "Distributing SSH keys"
    for node in "${!NODES[@]}"; do
        scp authorized_keys team@${NODES[$node]}:/tmp/
        ssh team@${NODES[$node]} "sudo mkdir -p /home/hadoop/.ssh && sudo cp /tmp/authorized_keys /home/hadoop/.ssh/ && sudo chown -R hadoop:hadoop /home/hadoop/.ssh && sudo chmod 600 /home/hadoop/.ssh/authorized_keys"
    done
}

setup_hadoop() {
    log "Setting up Hadoop"
    
    # Download Hadoop
    wget -q "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    
    # Create configuration files
    create_hadoop_env
    create_core_site
    create_hdfs_site
    create_workers
    create_profile
    create_nginx_conf
    
    # Distribute Hadoop and configurations
    for node in "${!NODES[@]}"; do
        if [[ $node != *"jn"* ]]; then
            scp "hadoop-${HADOOP_VERSION}.tar.gz" team@${NODES[$node]}:/tmp/
            ssh team@${NODES[$node]} "sudo -u hadoop tar -xzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C /home/hadoop/"
            
            # Copy configurations
            scp hadoop-env.sh core-site.xml hdfs-site.xml workers team@${NODES[$node]}:/tmp/
            ssh team@${NODES[$node]} "sudo -u hadoop cp /tmp/hadoop-env.sh /tmp/core-site.xml /tmp/hdfs-site.xml /tmp/workers /home/hadoop/hadoop-${HADOOP_VERSION}/etc/hadoop/"
            
            # Copy profile
            scp hadoop_profile team@${NODES[$node]}:/tmp/
            ssh team@${NODES[$node]} "sudo -u hadoop cp /tmp/hadoop_profile /home/hadoop/.profile && sudo -u hadoop source /home/hadoop/.profile"
        fi
    done
}

setup_nginx() {
    log "Setting up Nginx"
    scp nn team@${NODES[$NAME_NODE]}:/tmp/
    ssh team@${NODES[$NAME_NODE]} "sudo cp /tmp/nn /etc/nginx/sites-available/ && sudo ln -sf /etc/nginx/sites-available/nn /etc/nginx/sites-enabled/nn && sudo systemctl reload nginx"
}

start_hadoop() {
    log "Starting Hadoop"
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/bin/hdfs namenode -format"
    ssh team@${NODES[$NAME_NODE]} "sudo -u hadoop $HADOOP_HOME/sbin/start-dfs.sh"
}

# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    
    # Setup each node
    for node in "${!NODES[@]}"; do
        setup_node $node
    done
    
    # Setup SSH keys
    collect_ssh_keys
    distribute_ssh_keys
    
    # Setup Hadoop
    setup_hadoop
    
    # Setup Nginx
    setup_nginx
    
    # Start Hadoop
    start_hadoop
    
    log "Setup complete! Access Hadoop web interface at ${JUMP_SERVER}:9870"
}

# Run main function
main

# Cleanup temporary files
rm -f hadoop-env.sh core-site.xml hdfs-site.xml workers hadoop_profile nn authorized_keys

exit 0