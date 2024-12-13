#!/bin/bash

# Function to create user
create_user() {
    local user=$1
    local node=$2
    
    echo "Setting up user $user on node $node"
    
    if id "$user" &>/dev/null; then
        echo "Removing existing $user user..."
        sudo pkill -u "$user" 2>/dev/null || true
        sudo userdel -r "$user" 2>/dev/null || true
        sleep 1
    fi
    
    echo "Creating new $user user..."
    sudo useradd -m -s /bin/bash "$user"
    echo "Please set password for $user on $node:"
    sudo passwd "$user"
}

# Function to setup SSH keys
setup_ssh_keys() {
    local user=$1
    echo "Setting up SSH keys for $user..."
    
    # Clean up and create .ssh directory
    sudo rm -rf "/home/$user/.ssh"
    sudo -u "$user" mkdir -p "/home/$user/.ssh"
    sudo -u "$user" chmod 700 "/home/$user/.ssh"
    
    # Generate new keys
    sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
}

# Function to distribute SSH keys
distribute_keys() {
    local user=$1
    local nodes_file=$2
    
    echo "Collecting and distributing SSH keys..."
    
    # Create temporary authorized_keys file
    local temp_auth_keys=$(mktemp)
    
    # Collect all public keys
    while read -r ip name rest; do
        if [[ "$name" =~ ^team-25 ]]; then  # Only process team-25 nodes
            sudo -u "$user" ssh-keygen -R "$name" 2>/dev/null || true  # Remove old known hosts entries
            sudo -u "$user" ssh-keyscan -H "$ip" >> "/home/$user/.ssh/known_hosts" 2>/dev/null
            sudo cat "/home/$user/.ssh/id_ed25519.pub" >> "$temp_auth_keys"
        fi
    done < "$nodes_file"
    
    # Remove duplicates and set proper permissions
    sort -u "$temp_auth_keys" > "/home/$user/.ssh/authorized_keys"
    sudo chown "$user:$user" "/home/$user/.ssh/authorized_keys"
    sudo chmod 600 "/home/$user/.ssh/authorized_keys"
    
    # Copy to other nodes
    while read -r ip name rest; do
        if [[ "$name" =~ ^team-25 ]]; then  # Only process team-25 nodes
            echo "Copying keys to $name..."
            sudo -u "$user" scp -o StrictHostKeyChecking=no "/home/$user/.ssh/authorized_keys" "$user@$ip:/home/$user/.ssh/authorized_keys"
        fi
    done < "$nodes_file"
    
    rm -f "$temp_auth_keys"
}

# Main execution
main() {
    local nodes_file=$1
    
    # Check parameters
    if [ -z "$nodes_file" ]; then
        echo "Usage: $0 <nodes_file>"
        exit 1
    fi
    
    # Check if nodes file exists
    if [ ! -f "$nodes_file" ]; then
        echo "Error: Nodes file $nodes_file not found"
        exit 1
    fi
    
    # Generate hosts content and update /etc/hosts
    echo "Updating /etc/hosts..."
    local temp_hosts=$(mktemp)
    tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > "$temp_hosts"
    sudo cp "$temp_hosts" /etc/hosts
    rm -f "$temp_hosts"
    
    # Process each node
    while read -r ip name rest; do
        if [[ "$name" =~ ^team-25 ]]; then  # Only process team-25 nodes
            echo "Setting up node: $name ($ip)"
            create_user "hadoop" "$name"
            setup_ssh_keys "hadoop"
        fi
    done < "$nodes_file"
    
    # Distribute SSH keys
    distribute_keys "hadoop" "$nodes_file"
    
    echo "Setup completed successfully!"
    echo "Try connecting with: ssh hadoop@team-25-jn"
}

# Execute main function
main "$1"