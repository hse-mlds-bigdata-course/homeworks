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
scp_with_pass() {
    local src=$1
    local dest=$2
    info "Running SCP command: $src to $dest"
    sshpass -p "$TEAM_PASSWORD" scp -o StrictHostKeyChecking=no "$src" "$dest"
}

ssh_with_pass() {
    local host=$1
    shift
    info "Running SSH command on $host: $@"
    sshpass -p "$TEAM_PASSWORD" ssh -o StrictHostKeyChecking=no "team@$host" "$@"
}

validate_and_parse_config() {
    log "Validating configuration..."
    
    # First line is jump server IP
    JUMP_SERVER=$(head -n 1 nodes.txt | tr -d '\r')
    info "Jump server IP: $JUMP_SERVER"
    
    # Initialize NODES array
    declare -g -A NODES
    
    # Parse remaining lines
    local i=0
    while IFS= read -r line || [ -n "$line" ]; do
        i=$((i+1))
        if [ $i -eq 1 ]; then continue; fi  # Skip first line
        
        # Clean the line and split into IP and hostname
        local clean_line=$(echo "$line" | tr -d '\r')
        local ip=$(echo "$clean_line" | awk '{print $1}')
        local hostname=$(echo "$clean_line" | awk '{print $2}')
        
        case $i in
            2)
                JUMP_NODE=$hostname
                NODES[$hostname]=$ip
                info "Jump node: $hostname ($ip)"
                ;;
            3)
                NAME_NODE=$hostname
                NODES[$hostname]=$ip
                info "Name node: $hostname ($ip)"
                ;;
            4)
                DATA_NODE_0=$hostname
                NODES[$hostname]=$ip
                info "Data node 0: $hostname ($ip)"
                ;;
            5)
                DATA_NODE_1=$hostname
                NODES[$hostname]=$ip
                info "Data node 1: $hostname ($ip)"
                ;;
        esac
    done < nodes.txt
}

test_connectivity() {
    log "Testing connectivity to all nodes..."
    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        info "Testing connection to $node ($ip)"
        
        # Test ping
        if ! ping -c 1 "$ip" > /dev/null 2>&1; then
            error "Cannot ping $node ($ip)"
            continue
        fi
        
        # Test SSH with sshpass
        if ! sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "team@$ip" echo "SSH test successful" > /dev/null 2>&1; then
            error "Failed to SSH to $node ($ip)"
            continue
        fi
        
        info "Successfully connected to $node"
    done
    
    log "All nodes are reachable"
}


update_hosts() {
    log "Updating hosts files..."
    
    # Create hosts file content
    > temp_hosts
    for n in "${!NODES[@]}"; do
        echo "${NODES[$n]} $n" >> temp_hosts
    done
    info "Created hosts file content:"
    cat temp_hosts
    
    # First update current node (jump node)
    info "Updating hosts on current node (jump node)..."
    echo "$TEAM_PASSWORD" | sudo -S bash -c "cat temp_hosts > /etc/hosts"
    if [ $? -ne 0 ]; then
        error "Failed to update hosts on jump node"
        rm -f temp_hosts
        return 1
    fi
    info "Successfully updated jump node hosts"
    
    # Then update other nodes
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        if [[ "$node" != *"jn"* ]]; then  # Skip jump node as it's already done
            info "Updating hosts on $node ($ip)..."
            
            # Copy file and update with sudo -t for terminal allocation
            scp temp_hosts "team@$ip:/tmp/hosts"
            ssh -t "team@$ip" "sudo cat /tmp/hosts > /etc/hosts && rm /tmp/hosts"
            
            if [ $? -ne 0 ]; then
                error "Failed to update hosts on $node"
            else
                info "Successfully updated hosts on $node"
            fi
        fi
    done
    
    # Cleanup
    rm -f temp_hosts
}


# Main execution
main() {
    log "Starting Hadoop cluster setup..."
    validate_and_parse_config

    export SSHPASS="$TEAM_PASSWORD"

    
    for node in "${!NODES[@]}"; do
        local ip="${NODES[$node]}"
        update_hosts "$ip" "$node"
    done

    test_connectivity
    
    # Rest of your setup...
}

main