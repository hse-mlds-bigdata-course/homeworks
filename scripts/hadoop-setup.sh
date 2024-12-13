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

# Validate nodes.txt and parse configuration
validate_and_parse_config() {
    log "Validating configuration..."
    
    # First line is jump server IP
    JUMP_SERVER=$(head -n 1 nodes.txt)
    info "Jump server IP: $JUMP_SERVER"
    
    # Initialize NODES array
    declare -g -A NODES
    
    # Second line is jump node
    JUMP_LINE=$(sed -n '2p' nodes.txt)
    JUMP_NODE_IP=$(echo "$JUMP_LINE" | cut -d' ' -f1)
    JUMP_NODE=$(echo "$JUMP_LINE" | cut -d' ' -f2)
    NODES[$JUMP_NODE]=$JUMP_NODE_IP
    info "Jump node: $JUMP_NODE ($JUMP_NODE_IP)"
    
    # Third line is name node
    NAME_LINE=$(sed -n '3p' nodes.txt)
    NAME_NODE_IP=$(echo "$NAME_LINE" | cut -d' ' -f1)
    NAME_NODE=$(echo "$NAME_LINE" | cut -d' ' -f2)
    NODES[$NAME_NODE]=$NAME_NODE_IP
    info "Name node: $NAME_NODE ($NAME_NODE_IP)"
    
    # Fourth line is data node 0
    DN0_LINE=$(sed -n '4p' nodes.txt)
    DN0_IP=$(echo "$DN0_LINE" | cut -d' ' -f1)
    DATA_NODE_0=$(echo "$DN0_LINE" | cut -d' ' -f2)
    NODES[$DATA_NODE_0]=$DN0_IP
    info "Data node 0: $DATA_NODE_0 ($DN0_IP)"
    
    # Fifth line is data node 1
    DN1_LINE=$(sed -n '5p' nodes.txt)
    DN1_IP=$(echo "$DN1_LINE" | cut -d' ' -f1)
    DATA_NODE_1=$(echo "$DN1_LINE" | cut -d' ' -f2)
    NODES[$DATA_NODE_1]=$DN1_IP
    info "Data node 1: $DATA_NODE_1 ($DN1_IP)"
}

# Test connectivity to all nodes
test_connectivity() {
    log "Testing connectivity to all nodes..."
    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Testing connection to $node ($ip)"
        
        if ! ping -c 1 "$ip" > /dev/null 2>&1; then
            error "Cannot ping $node ($ip)"
        fi
        
        if ! ssh -o ConnectTimeout=5 "team@$ip" "echo 'SSH connection successful'" > /dev/null 2>&1; then
            error "Cannot SSH to $node ($ip)"
        fi
    done
    
    log "All nodes are reachable"
}

# Constants
HADOOP_VERSION="3.4.0"
JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
HADOOP_HOME="/home/hadoop/hadoop-${HADOOP_VERSION}"

# Update hosts file
update_hosts() {
    local ip=$1
    local node=$2
    
    log "Updating hosts file on $node"
    
    # Create temporary hosts file with all node entries
    > temp_hosts
    for n in "${!NODES[@]}"; do
        echo "${NODES[$n]} $n" >> temp_hosts
    done
    
    # Backup existing hosts file
    ssh "team@$ip" "sudo cp /etc/hosts /etc/hosts.backup"
    
    # Update hosts file
    scp temp_hosts "team@$ip:/tmp/hosts"
    ssh "team@$ip" "sudo bash -c 'cat /tmp/hosts > /etc/hosts'"
    ssh "team@$ip" "rm /tmp/hosts"
    
    # Test hostname resolution
    for n in "${!NODES[@]}"; do
        if ! ssh "team@$ip" "ping -c 1 $n" > /dev/null 2>&1; then
            error "Hostname resolution failed for $n on $node"
        fi
    done
    
    info "Hosts file updated successfully on $node"
}

# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    
    # Initial validation and connectivity test
    validate_and_parse_config
    test_connectivity
    
    # Update hosts files first
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        update_hosts "$ip" "$node"
    done
    
    # Continue with rest of the setup...
    # [Previous setup functions remain the same]
    
    log "Setup complete!"
}

# Run main function
main

exit 0