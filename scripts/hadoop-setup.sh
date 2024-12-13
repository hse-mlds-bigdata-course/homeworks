#!/bin/bash

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Read password at the beginning
read -sp "Enter team password: " TEAM_PASSWORD
echo
export SSHPASS=$TEAM_PASSWORD

# Check if sshpass is installed, if not install it
if ! command -v sshpass &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y sshpass
fi

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

# SSH wrapper function
ssh_with_pass() {
    local host=$1
    shift
    sshpass -e ssh -o StrictHostKeyChecking=no "team@$host" "$@"
}

# SCP wrapper function
scp_with_pass() {
    sshpass -e scp -o StrictHostKeyChecking=no "$@"
}

validate_and_parse_config() {
    log "Validating configuration..."
    
    # First line is jump server IP
    JUMP_SERVER=$(head -n 1 nodes.txt)
    info "Jump server IP: $JUMP_SERVER"
    
    # Initialize NODES array
    declare -g -A NODES
    
    # Second line is jump node
    JUMP_LINE=$(sed -n '2p' nodes.txt)
    JUMP_NODE_IP=$(echo "$JUMP_LINE" | awk '{print $1}')
    JUMP_NODE=$(echo "$JUMP_LINE" | awk '{print $2}')
    NODES[$JUMP_NODE]=$JUMP_NODE_IP
    info "Jump node: $JUMP_NODE ($JUMP_NODE_IP)"
    
    # Third line is name node
    NAME_LINE=$(sed -n '3p' nodes.txt)
    NAME_NODE_IP=$(echo "$NAME_LINE" | awk '{print $1}')
    NAME_NODE=$(echo "$NAME_LINE" | awk '{print $2}')
    NODES[$NAME_NODE]=$NAME_NODE_IP
    info "Name node: $NAME_NODE ($NAME_NODE_IP)"
    
    # Fourth line is data node 0
    DN0_LINE=$(sed -n '4p' nodes.txt)
    DATA_NODE_0_IP=$(echo "$DN0_LINE" | awk '{print $1}')
    DATA_NODE_0=$(echo "$DN0_LINE" | awk '{print $2}')
    NODES[$DATA_NODE_0]=$DATA_NODE_0_IP
    info "Data node 0: $DATA_NODE_0 ($DATA_NODE_0_IP)"
    
    # Fifth line is data node 1
    DN1_LINE=$(sed -n '5p' nodes.txt)
    DATA_NODE_1_IP=$(echo "$DN1_LINE" | awk '{print $1}')
    DATA_NODE_1=$(echo "$DN1_LINE" | awk '{print $2}')
    NODES[$DATA_NODE_1]=$DATA_NODE_1_IP
    info "Data node 1: $DATA_NODE_1 ($DATA_NODE_1_IP)"
}

test_connectivity() {
    log "Testing connectivity to all nodes..."
    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Testing connection to $node ($ip)"
        
        if ! ping -c 1 "$ip" > /dev/null 2>&1; then
            error "Cannot ping $node ($ip)"
            continue
        fi
        
        if ! timeout 5 ssh -o BatchMode=yes -o StrictHostKeyChecking=no "team@$ip" "echo 'Connected'" > /dev/null 2>&1; then
            error "Cannot SSH to $node ($ip). Please check SSH access and password."
            continue
        fi
        
        info "Successfully connected to $node"
    done
    
    log "All nodes are reachable"
}

test_connectivity() {
    log "Testing connectivity to all nodes..."
    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Testing connection to $node ($ip)"
        
        if ! ping -c 1 "$ip" > /dev/null 2>&1; then
            error "Cannot ping $node ($ip)"
        fi
        
        if ! ssh_with_pass "$ip" "echo 'SSH connection successful'" > /dev/null 2>&1; then
            error "Cannot SSH to $node ($ip)"
        fi
    done
    
    log "All nodes are reachable"
}

update_hosts() {
    local ip=$1
    local node=$2
    
    log "Updating hosts file on $node"
    
    # Create temporary hosts file
    > temp_hosts
    for n in "${!NODES[@]}"; do
        echo "${NODES[$n]} $n" >> temp_hosts
    done
    
    # Copy and apply hosts file
    scp_with_pass temp_hosts "team@$ip:/tmp/hosts"
    ssh_with_pass "$ip" "echo $TEAM_PASSWORD | sudo -S bash -c 'cat /tmp/hosts > /etc/hosts'"
    ssh_with_pass "$ip" "rm /tmp/hosts"
    rm -f temp_hosts
}

# Rest of your functions here...

# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    validate_and_parse_config
    test_connectivity
    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        update_hosts "$ip" "$node"
    done
    
    # Rest of your setup...
}

main