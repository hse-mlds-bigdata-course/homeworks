#!/bin/bash

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Log functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}  → $1${NC}"
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
    if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+([^[:space:]]+)$ ]]; then
        NODES["${BASH_REMATCH[2]}"]="${BASH_REMATCH[1]}"
    fi
done < <(tail -n +2 nodes.txt)

# Constants
HADOOP_VERSION="3.4.0"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VERSION}"
NAME_NODE=$(grep "nn" nodes.txt | awk '{print $2}')

# Create necessary configuration files
create_profile() {
    cat > hadoop_profile << EOF
export HADOOP_HOME=/home/hadoop/hadoop-${HADOOP_VERSION}
export JAVA_HOME=${JAVA_HOME}
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF
}

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

create_nginx_config() {
    cat > nn << EOF
server {
    listen 9870 default_server;
    location / {
        proxy_pass http://${NAME_NODE}:9870;
    }
}
EOF
}

# Setup functions
update_hosts() {
    local ip=$1
    local node=$2
    
    log "Updating hosts file on $node"
    
    # Create temporary hosts file
    > temp_hosts
    for n in "${!NODES[@]}"; do
        echo "${NODES[$n]} $n" >> temp_hosts
    done
    
    # Copy and replace hosts file
    scp temp_hosts "team@$ip:/tmp/hosts"
    ssh "team@$ip" "sudo bash -c 'cat /tmp/hosts > /etc/hosts'"
    ssh "team@$ip" "rm /tmp/hosts"
    rm -f temp_hosts
    
    # Verify connectivity
    for n in "${!NODES[@]}"; do
        info "Verifying connectivity to $n"
        ssh "team@$ip" "ping -c 1 $n" || error "Cannot ping $n from $node"
    done
}

install_prerequisites() {
    local ip=$1
    local node=$2
    
    log "Installing prerequisites on $node"
    ssh "team@$ip" "sudo apt-get update && sudo apt-get install -y software-properties-common openjdk-11-jdk-headless"
    
    # Verify Java installation
    info "Verifying Java installation"
    ssh "team@$ip" "java -version" || error "Java installation failed on $node"
}

setup_hadoop_user() {
    local ip=$1
    local node=$2
    
    log "Setting up hadoop user on $node"
    
    # Create hadoop user
    ssh "team@$ip" "sudo adduser --disabled-password --gecos '' hadoop"
    
    # Generate SSH key
    ssh "team@$ip" "sudo -u hadoop bash -c 'mkdir -p /home/hadoop/.ssh && ssh-keygen -t ed25519 -N \"\" -f /home/hadoop/.ssh/id_ed25519'"
}

collect_and_distribute_keys() {
    log "Collecting and distributing SSH keys"
    
    # Collect keys from all nodes
    > authorized_keys
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Collecting key from $node"
        ssh "team@$ip" "sudo cat /home/hadoop/.ssh/id_ed25519.pub" >> authorized_keys
    done
    
    # Distribute keys to all nodes
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Distributing keys to $node"
        scp authorized_keys "team@$ip:/tmp/"
        ssh "team@$ip" "sudo mkdir -p /home/hadoop/.ssh && \
                       sudo cp /tmp/authorized_keys /home/hadoop/.ssh/ && \
                       sudo chown -R hadoop:hadoop /home/hadoop/.ssh && \
                       sudo chmod 600 /home/hadoop/.ssh/authorized_keys"
    done
    
    # Verify SSH connectivity
    for node in "${!NODES[@]}"; do
        info "Verifying SSH connectivity for $node"
        ssh "team@${NODES[$node]}" "sudo -u hadoop ssh -o StrictHostKeyChecking=no $node echo 'SSH connection successful'"
    done
    
    rm -f authorized_keys
}

setup_hadoop() {
    log "Setting up Hadoop"
    
    # Download Hadoop if needed
    if [ ! -f "hadoop-${HADOOP_VERSION}.tar.gz" ]; then
        info "Downloading Hadoop ${HADOOP_VERSION}"
        wget --progress=bar:force "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" 2>&1
    fi
    
    # Create configuration files
    create_profile
    create_hadoop_env
    create_core_site
    create_hdfs_site
    create_workers
    
    # Process each node
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        if [[ $node != *"jn"* ]]; then
            info "Setting up Hadoop on $node"
            
            # Copy and extract Hadoop
            scp "hadoop-${HADOOP_VERSION}.tar.gz" "team@$ip:/tmp/"
            ssh "team@$ip" "sudo -u hadoop tar -xzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C /home/hadoop/"
            
            # Copy configurations
            scp hadoop_profile "team@$ip:/home/hadoop/.profile"
            ssh "team@$ip" "sudo chown hadoop:hadoop /home/hadoop/.profile"
            
            scp hadoop-env.sh core-site.xml hdfs-site.xml workers "team@$ip:/tmp/"
            ssh "team@$ip" "sudo -u hadoop cp /tmp/hadoop-env.sh /tmp/core-site.xml /tmp/hdfs-site.xml /tmp/workers /home/hadoop/hadoop-${HADOOP_VERSION}/etc/hadoop/"
            
            # Source profile
            ssh "team@$ip" "sudo -u hadoop bash -c 'source /home/hadoop/.profile'"
            
            # Cleanup
            ssh "team@$ip" "rm /tmp/hadoop-${HADOOP_VERSION}.tar.gz /tmp/hadoop-env.sh /tmp/core-site.xml /tmp/hdfs-site.xml /tmp/workers"
        fi
    done
}

setup_nginx() {
    log "Setting up Nginx configuration"
    
    create_nginx_config
    
    # Copy and enable Nginx configuration
    scp nn "team@${NODES[$NAME_NODE]}:/tmp/"
    ssh "team@${NODES[$NAME_NODE]}" "sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/nn && \
                                    sudo cp /tmp/nn /etc/nginx/sites-available/ && \
                                    sudo ln -sf /etc/nginx/sites-available/nn /etc/nginx/sites-enabled/nn && \
                                    sudo systemctl reload nginx"
    
    rm -f nn
}

start_hadoop() {
    log "Starting Hadoop services"
    
    # Format HDFS
    info "Formatting HDFS"
    ssh "team@${NODES[$NAME_NODE]}" "sudo -u hadoop $HADOOP_HOME/bin/hdfs namenode -format"
    
    # Start HDFS
    info "Starting HDFS"
    ssh "team@${NODES[$NAME_NODE]}" "sudo -u hadoop $HADOOP_HOME/sbin/start-dfs.sh"
    
    # Check processes on all nodes
    for node in "${!NODES[@]}"; do
        if [[ $node != *"jn"* ]]; then
            info "Checking processes on $node"
            ssh "team@${NODES[$node]}" "sudo -u hadoop jps"
        fi
    done
}

# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    
    # Setup each node
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        install_prerequisites "$ip" "$node"
        update_hosts "$ip" "$node"
        setup_hadoop_user "$ip" "$node"
    done
    
    collect_and_distribute_keys
    setup_hadoop
    setup_nginx
    start_hadoop
    
    log "Setup complete! Access Hadoop web interface at ${JUMP_SERVER}:9870"
}

# Run main function
main

# Cleanup temporary files
rm -f hadoop_profile hadoop-env.sh core-site.xml hdfs-site.xml workers temp_hosts

exit 0