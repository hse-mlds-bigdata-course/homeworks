# #!/bin/bash

# # Function to create user
# create_user() {
#     local user=$1
#     local node=$2
    
#     if id "$user" &>/dev/null; then
#         echo "Removing existing $user user..."
#         sudo pkill -u "$user" 2>/dev/null || true
#         sudo userdel -r "$user" 2>/dev/null || true
#         sleep 1
#     fi
    
#     echo "Creating new $user user..."
#     sudo useradd -m -s /bin/bash "$user"
#     echo "Please set password for $user on $node:"
#     sudo passwd "$user"
# }

# # Function to setup SSH keys
# setup_ssh_keys() {
#     local user=$1
#     sudo rm -rf "/home/$user/.ssh"
#     sudo -u "$user" mkdir -p "/home/$user/.ssh"
#     sudo -u "$user" chmod 700 "/home/$user/.ssh"
#     sudo -u "$user" touch "/home/$user/.ssh/known_hosts"
#     sudo -u "$user" chmod 600 "/home/$user/.ssh/known_hosts"
#     sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
# }

# # Function to distribute SSH keys
# distribute_keys() {
#     local nodes_file=$1
#     echo "Distributing SSH keys to all nodes..."
    
#     # Sort and remove duplicates from collected keys
#     sort -u /tmp/all_keys > /tmp/authorized_keys
#     sudo chown hadoop:hadoop /tmp/authorized_keys
#     sudo chmod 600 /tmp/authorized_keys
    
#     # Distribute to all nodes using IP addresses
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Copying keys to $ip ($name)..."
#         # Use IP address instead of hostname
#         sudo -u hadoop ssh-keyscan -H "$ip" >> /home/hadoop/.ssh/known_hosts 2>/dev/null
#         sudo -u hadoop scp -o StrictHostKeyChecking=no /tmp/authorized_keys "hadoop@$ip:/home/hadoop/.ssh/authorized_keys"
#     done
# }

# # Main execution
# main() {
#     local nodes_file=$1
    
#     # Check for hadoop_pwd environment variable
#     if [ -z "$hadoop_pwd" ]; then
#         echo "Error: hadoop_pwd environment variable is not set"
#         echo "Please set it first: export hadoop_pwd=your_password"
#         exit 1
#     fi
    
#     # Check parameters
#     if [ -z "$nodes_file" ]; then
#         echo "Usage: $0 <nodes_file>"
#         exit 1
#     fi
    
#     # Check if nodes file exists
#     if [ ! -f "$nodes_file" ]; then
#         echo "Error: Nodes file $nodes_file not found"
#         exit 1
#     fi
    
#     # Initialize temporary files
#     : > /tmp/all_keys
#     : > /tmp/hosts_content
    
#     # Generate hosts content
#     tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > /tmp/hosts_content
    
#     # Setup each node
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Setting up node: $name ($ip)"
        
#         # Update /etc/hosts
#         echo "Updating /etc/hosts..."
#         sudo cp /tmp/hosts_content /etc/hosts
        
#         # Create hadoop user
#         create_user "hadoop"
        
#         # Setup SSH keys
#         echo "Setting up SSH keys..."
#         setup_ssh_keys "hadoop"
        
#         # Collect the public key
#         sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub >> /tmp/all_keys
#     done
    
#     # Distribute SSH keys
#     echo "Distributing SSH keys to all nodes..."
    
#     distribute_keys "$nodes_file"
    
#     # Cleanup
#     rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys
    
#     echo "Setup completed successfully!"
# }

# # Execute main function
# main "$1"


#!/bin/bash

# # Function to create user
# create_user() {
#     local user=$1
#     local node=$2
    
#     if id "$user" &>/dev/null; then
#         echo "Removing existing $user user..."
#         sudo pkill -u "$user" 2>/dev/null || true
#         sudo userdel -r "$user" 2>/dev/null || true
#         sleep 1
#     fi
    
#     echo "Creating new $user user..."
#     sudo useradd -m -s /bin/bash "$user"
#     # Use password from environment variable
#     echo "$user:$hadoop_pwd" | sudo chpasswd
# }

# # Function to setup SSH keys
# setup_ssh_keys() {
#     local user=$1
#     sudo rm -rf "/home/$user/.ssh"
#     sudo -u "$user" mkdir -p "/home/$user/.ssh"
#     sudo -u "$user" chmod 700 "/home/$user/.ssh"
#     sudo -u "$user" touch "/home/$user/.ssh/known_hosts"
#     sudo -u "$user" chmod 600 "/home/$user/.ssh/known_hosts"
#     sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
# }

# # Function to distribute SSH keys
# distribute_keys() {
#     local nodes_file=$1
#     echo "Distributing SSH keys to all nodes..."
    
#     # Sort and remove duplicates from collected keys
#     sort -u /tmp/all_keys > /tmp/authorized_keys
#     sudo chown hadoop:hadoop /tmp/authorized_keys
#     sudo chmod 600 /tmp/authorized_keys
    
#     # Distribute to all nodes using IP addresses
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Copying keys to $ip ($name)..."
#         # Use IP address instead of hostname
#         sudo -u hadoop ssh-keyscan -H "$ip" >> /home/hadoop/.ssh/known_hosts 2>/dev/null
#         sudo -u hadoop scp -o StrictHostKeyChecking=no /tmp/authorized_keys "hadoop@$ip:/home/hadoop/.ssh/authorized_keys"
#     done
# }

# # Main execution
# main() {
#     local nodes_file=$1
    
#     # Check for hadoop_pwd environment variable
#     if [ -z "$hadoop_pwd" ]; then
#         echo "Error: hadoop_pwd environment variable is not set"
#         echo "Please set it first: export hadoop_pwd=your_password"
#         exit 1
#     fi
    
#     # Check parameters
#     if [ -z "$nodes_file" ]; then
#         echo "Usage: $0 <nodes_file>"
#         exit 1
#     fi
    
#     # Check if nodes file exists
#     if [ ! -f "$nodes_file" ]; then
#         echo "Error: Nodes file $nodes_file not found"
#         exit 1
#     fi
    
#     # Initialize temporary files
#     : > /tmp/all_keys
#     : > /tmp/hosts_content
    
#     # Generate hosts content
#     tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > /tmp/hosts_content
    
#     # PHASE 1: Create hadoop users on all nodes
#     echo "Phase 1: Creating hadoop users on all nodes..."
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Setting up node: $name ($ip)"
        
#         # Update /etc/hosts
#         echo "Updating /etc/hosts..."
#         sudo cp /tmp/hosts_content /etc/hosts
        
#         # Create hadoop user with password from environment variable
#         create_user "hadoop" "$name"
#     done
    
#     # PHASE 2: Setup SSH for all nodes
#     echo "Phase 2: Setting up SSH connections..."
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Setting up SSH for node: $name ($ip)"
#         setup_ssh_keys "hadoop"
#         sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub >> /tmp/all_keys
#     done
    
#     # Distribute the keys
#     distribute_keys "$nodes_file"
    
#     # Cleanup
#     rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys
    
#     echo "Setup completed successfully!"
#     echo "Try testing: ssh hadoop@team-25-nn"
# }

# # Execute main function
# main "$1"



create_user_remote() {
    local node=$1
    echo "Creating hadoop user on $node..."
    
    # SSH to node as team user and create hadoop user
    ssh "team@$node" "
        if id hadoop &>/dev/null; then
            echo 'Removing existing hadoop user...'
            sudo pkill -u hadoop 2>/dev/null || true
            sudo userdel -r hadoop 2>/dev/null || true
            sleep 1
        fi
        echo 'Creating new hadoop user...'
        sudo useradd -m -s /bin/bash hadoop
        echo 'hadoop:$hadoop_pwd' | sudo chpasswd
    "
}

# Function to setup SSH keys
setup_ssh_keys() {
    local node=$1
    echo "Setting up SSH keys on $node..."
    
    ssh "team@$node" "
        sudo -u hadoop bash -c '
            rm -rf ~/.ssh
            mkdir -p ~/.ssh
            chmod 700 ~/.ssh
            touch ~/.ssh/known_hosts
            chmod 600 ~/.ssh/known_hosts
            ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N \"\"
        '
    "
    # Collect the public key
    ssh "team@$node" "sudo cat /home/hadoop/.ssh/id_ed25519.pub" >> /tmp/all_keys
}

# Function to distribute SSH keys
distribute_keys() {
    local nodes_file=$1
    echo "Distributing SSH keys to all nodes..."
    
    # Sort and remove duplicates from collected keys
    sort -u /tmp/all_keys > /tmp/authorized_keys
    
    # Distribute to all nodes using hostname
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Copying keys to $name..."
        ssh "team@$name" "
            sudo cp /tmp/authorized_keys /home/hadoop/.ssh/authorized_keys
            sudo chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
            sudo chmod 600 /home/hadoop/.ssh/authorized_keys
            sudo -u hadoop bash -c 'ssh-keyscan -H $ip >> /home/hadoop/.ssh/known_hosts' 2>/dev/null
        "
        scp /tmp/authorized_keys "team@$name:/tmp/authorized_keys"
    done
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
    
    # Update local hosts file
    echo "Updating /etc/hosts..."
    sudo cp /tmp/hosts_content /etc/hosts
    
    # PHASE 1: Create hadoop users on all nodes
    echo "Phase 1: Creating hadoop users on all nodes..."
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        create_user_remote "$name"
    done
    
    # PHASE 2: Setup SSH for all nodes
    echo "Phase 2: Setting up SSH connections..."
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        setup_ssh_keys "$name"
    done
    
    # Distribute the keys
    distribute_keys "$nodes_file"
    
    # Cleanup
    rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys
    
    echo "Setup completed successfully!"
    echo "Try testing: ssh hadoop@team-25-nn"
}

# Execute main function
main "$1"