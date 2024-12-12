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
    if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]+([^[:space:]]+)$ ]]; then
        NODES["${BASH_REMATCH[2]}"]="${BASH_REMATCH[1]}"
    fi
done < <(tail -n +2 nodes.txt)

# Constants
HADOOP_VERSION="3.4.0"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VERSION}"
NAME_NODE=$(grep "nn" nodes.txt | awk '{print $2}')

# Function to update /etc/hosts
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
    rm -f temp_hosts
}

# Function to install prerequisites
install_prerequisites() {
    local ip=$1
    local node=$2
    
    log "Installing prerequisites on $node"
    ssh "team@$ip" "sudo apt-get update && sudo apt-get install -y software-properties-common openjdk-11-jdk-headless"
}

# Function to create hadoop user and setup SSH
setup_hadoop_user() {
    local ip=$1
    local node=$2
    
    log "Setting up hadoop user on $node"
    
    # Create hadoop user if it doesn't exist
    ssh "team@$ip" "sudo adduser --disabled-password --gecos '' hadoop"
    
    # Generate SSH key
    ssh "team@$ip" "sudo -u hadoop bash -c 'if [ ! -f /home/hadoop/.ssh/id_ed25519 ]; then mkdir -p /home/hadoop/.ssh && ssh-keygen -t ed25519 -N \"\" -f /home/hadoop/.ssh/id_ed25519; fi'"
}

# Function to distribute SSH keys
collect_and_distribute_keys() {
    log "Collecting and distributing SSH keys"
    
    # Create temporary authorized_keys file
    > authorized_keys
    
    # Collect keys from all nodes
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        ssh "team@$ip" "sudo cat /home/hadoop/.ssh/id_ed25519.pub" >> authorized_keys
    done
    
    # Distribute keys to all nodes
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        scp authorized_keys "team@$ip:/tmp/"
        ssh "team@$ip" "sudo mkdir -p /home/hadoop/.ssh && sudo cp /tmp/authorized_keys /home/hadoop/.ssh/ && sudo chown -R hadoop:hadoop /home/hadoop/.ssh && sudo chmod 600 /home/hadoop/.ssh/authorized_keys"
    done
    
    rm -f authorized_keys
}

# Function to setup Hadoop
setup_hadoop() {
    log "Setting up Hadoop"
    
    # Download Hadoop
    wget -q "https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    
    # Distribute and extract on all nodes
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        scp "hadoop-${HADOOP_VERSION}.tar.gz" "team@$ip:/tmp/"
        ssh "team@$ip" "sudo -u hadoop tar -xzf /tmp/hadoop-${HADOOP_VERSION}.tar.gz -C /home/hadoop/"
    done
}

# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    
    # Process each node
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        
        log "Processing node: $node ($ip)"
        install_prerequisites "$ip" "$node"
        update_hosts "$ip" "$node"
        setup_hadoop_user "$ip" "$node"
    done
    
    collect_and_distribute_keys
    setup_hadoop
    
    log "Setup complete!"
}

# Run main function
main

exit 0