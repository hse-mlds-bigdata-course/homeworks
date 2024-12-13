#!/bin/bash

# Exit on any error
set -e

# Function to read nodes from file and create hosts content
generate_hosts_content() {
    local nodes_file=$1
    # Skip first line (jump server) and create hosts content
    tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > /tmp/hosts_content
}

# Function to setup SSH keys
setup_ssh_keys() {
    local user=$1
    # Remove existing keys if they exist
    sudo -u "$user" rm -f "/home/$user/.ssh/id_ed25519" "/home/$user/.ssh/id_ed25519.pub"
    # Create .ssh directory if it doesn't exist
    sudo -u "$user" mkdir -p "/home/$user/.ssh"
    # Set proper permissions
    sudo -u "$user" chmod 700 "/home/$user/.ssh"
    # Create empty known_hosts file if it doesn't exist
    sudo -u "$user" touch "/home/$user/.ssh/known_hosts"
    sudo -u "$user" chmod 600 "/home/$user/.ssh/known_hosts"
    # Generate new keys
    sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
}

# Function to create user if not exists
create_user() {
    local user=$1
    
    if id "$user" &>/dev/null; then
        echo "Removing existing $user user..."
        sudo pkill -u "$user" 2>/dev/null || true  # Kill any processes
        sudo userdel -r "$user" 2>/dev/null || true
        sleep 1  # Give system time to clean up
    fi
    
    echo "Creating new $user user..."
    # Create new user
    sudo useradd -m -s /bin/bash "$user"
    
    echo "Please set password for $user using passwd..."
    # Use interactive passwd command
    sudo passwd "$user"
}

# Main setup function
setup_node() {
    local node_ip=$1
    local node_name=$2
    
    echo "Setting up node: $node_name ($node_ip)"
    
    # Update /etc/hosts
    echo "Updating /etc/hosts..."
    sudo cp /tmp/hosts_content /etc/hosts
    
    # Create hadoop user and setup SSH
    echo "Creating hadoop user..."
    create_user "hadoop"
    
    # Setup SSH keys
    echo "Setting up SSH keys..."
    setup_ssh_keys "hadoop"
    
    # Collect the public key
    sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub >> /tmp/all_keys
}

# Function to distribute SSH keys
distribute_keys() {
    local nodes_file=$1
    echo "Distributing SSH keys to all nodes..."
    
    # Sort and remove duplicates from collected keys
    sort -u /tmp/all_keys > /tmp/authorized_keys
    
    # Distribute to all nodes
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Copying keys to $name..."
        # Add host to known_hosts file as hadoop user
        sudo -u hadoop bash -c "ssh-keyscan -H $name >> /home/hadoop/.ssh/known_hosts 2>/dev/null"
        # Copy authorized_keys file
        sudo -u hadoop scp /tmp/authorized_keys "hadoop@$name:/home/hadoop/.ssh/authorized_keys"
    done
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
    
    # Initialize temporary files
    : > /tmp/all_keys
    : > /tmp/hosts_content
    
    # Generate hosts content
    generate_hosts_content "$nodes_file"
    
    # Setup each node
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        setup_node "$ip" "$name"
    done
    
    # Distribute SSH keys
    distribute_keys "$nodes_file"
    
    # Cleanup
    rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys
    
    echo "Setup completed successfully!"
}

# Execute main function
main "$1"