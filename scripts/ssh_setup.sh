#!/bin/bash

# Function to create user with password from env variable
create_user() {
    local user=$1
    
    if id "$user" &>/dev/null; then
        echo "Removing existing $user user..."
        sudo pkill -u "$user" 2>/dev/null || true
        sudo userdel -r "$user" 2>/dev/null || true
        sleep 1
    fi
    
    echo "Creating new $user user..."
    sudo useradd -m -s /bin/bash "$user"
    
    # Create hashed password and set it
    local hashed_password=$(openssl passwd -1 "$hadoop_pwd")
    sudo usermod -p "$hashed_password" "$user"
    
    # Verify the password was set
    echo "Verifying password setup..."
    if ! echo "$hadoop_pwd" | sudo -S -u "$user" whoami >/dev/null 2>&1; then
        echo "Warning: Password verification failed. You might need to set it manually with 'sudo passwd hadoop'"
    fi
}

# Function to setup SSH keys
setup_ssh_keys() {
    local user=$1
    sudo rm -rf "/home/$user/.ssh"
    sudo -u "$user" mkdir -p "/home/$user/.ssh"
    sudo -u "$user" chmod 700 "/home/$user/.ssh"
    sudo -u "$user" touch "/home/$user/.ssh/known_hosts"
    sudo -u "$user" chmod 600 "/home/$user/.ssh/known_hosts"
    sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
}

# Main execution
main() {
    local nodes_file=$1
    
    # Check for hadoop_pwd environment variable
    if [ -z "$hadoop_pwd" ]; then
        echo "Error: hadoop_pwd environment variable is not set"
        echo "Please set it first: export hadoop_pwd=your_password"
        exit 1
    fi
    
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
    tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > /tmp/hosts_content
    
    # Setup each node
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Setting up node: $name ($ip)"
        
        # Update /etc/hosts
        echo "Updating /etc/hosts..."
        sudo cp /tmp/hosts_content /etc/hosts
        
        # Create hadoop user
        create_user "hadoop"
        
        # Setup SSH keys
        echo "Setting up SSH keys..."
        setup_ssh_keys "hadoop"
        
        # Collect the public key
        sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub >> /tmp/all_keys
    done
    
    # Distribute SSH keys
    echo "Distributing SSH keys to all nodes..."
    sort -u /tmp/all_keys > /tmp/authorized_keys
    
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Copying keys to $name..."
        sudo -u hadoop bash -c "ssh-keyscan -H $name >> /home/hadoop/.ssh/known_hosts 2>/dev/null"
        sudo -u hadoop scp /tmp/authorized_keys "hadoop@$name:/home/hadoop/.ssh/authorized_keys"
    done
    
    # Cleanup
    rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys
    
    echo "Setup completed successfully!"
}

# Execute main function
main "$1"