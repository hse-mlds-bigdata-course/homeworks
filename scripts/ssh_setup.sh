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


#!/bin/bash

#!/bin/bash

#!/bin/bash

# Function to create user - works locally on each node
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
#         # First SSH to the node and then create user
#         echo "SSHing to $name..."
#         # ssh "team@$name" "export hadoop_pwd='$hadoop_pwd' && $(declare -f create_user) && create_user hadoop $name"
#         ssh -o StrictHostKeyChecking=no "team@$ip" "export hadoop_pwd='$hadoop_pwd'; $(declare -f create_user); create_user hadoop '$name'"
#     done
    
#     # PHASE 2: Setup SSH for all nodes
#     echo "Phase 2: Setting up SSH connections..."
#     tail -n +2 "$nodes_file" | while read -r ip name rest; do
#         echo "Setting up SSH for node: $name ($ip)"
#         # Again, use IP
#         ssh -o StrictHostKeyChecking=no "team@$ip" "$(declare -f setup_ssh_keys); setup_ssh_keys hadoop"
#         # Fetch the public key
#         ssh -o StrictHostKeyChecking=no "team@$ip" "sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub" >> /tmp/all_keys
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



#!/bin/bash

# Function to create user - reads password from TEAM_PASSWORD
create_user() {
    local user=$1
    local node=$2
    
    if id "$user" &>/dev/null; then
        echo "Removing existing $user user..."
        printf "%s\n" "$TEAM_PASSWORD" | sudo -S pkill -u "$user" 2>/dev/null || true
        printf "%s\n" "$TEAM_PASSWORD" | sudo -S userdel -r "$user" 2>/dev/null || true
        sleep 1
    fi
    
    echo "Creating new $user user..."
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S useradd -m -s /bin/bash "$user"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S sh -c "echo '$user:$hadoop_pwd' | chpasswd"
}

# Function to setup SSH keys
setup_ssh_keys() {
    local user=$1
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S rm -rf "/home/$user/.ssh"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S -u "$user" mkdir -p "/home/$user/.ssh"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S -u "$user" chmod 700 "/home/$user/.ssh"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S -u "$user" touch "/home/$user/.ssh/known_hosts"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S -u "$user" chmod 600 "/home/$user/.ssh/known_hosts"
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""
}

main() {
    local nodes_file=$1

    if [ -z "$hadoop_pwd" ] || [ -z "$TEAM_PASSWORD" ]; then
        echo "Please ensure both hadoop_pwd and TEAM_PASSWORD are set as environment variables"
        exit 1
    fi
    
    if [ ! -f "$nodes_file" ]; then
        echo "Error: Nodes file $nodes_file not found"
        exit 1
    fi

    : > /tmp/all_keys
    : > /tmp/hosts_content

    tail -n +2 "$nodes_file" | awk '{print $1 "\t" $2}' > /tmp/hosts_content
    printf "%s\n" "$TEAM_PASSWORD" | sudo -S cp /tmp/hosts_content /etc/hosts

    echo "Phase 1: Creating hadoop users on all nodes..."
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Setting up node: $name ($ip)"
        # Double TTY (-tt) and correct variable expansion:
        ssh -tt "team@$ip" "
            export hadoop_pwd=\"${hadoop_pwd}\"
            export TEAM_PASSWORD=\"${TEAM_PASSWORD}\"
            $(declare -f create_user)
            create_user hadoop \"$name\"
        "
    done
    
    # PHASE 2: Setup SSH for all nodes
    echo "Phase 2: Setting up SSH connections..."
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Setting up SSH for node: $name ($ip)"
        ssh -t "team@$ip" "
            export hadoop_pwd='$hadoop_pwd'
            export TEAM_PASSWORD='$TEAM_PASSWORD'
            $(declare -f setup_ssh_keys)
            setup_ssh_keys hadoop
        "
        ssh -t "team@$ip" "sudo -u hadoop cat /home/hadoop/.ssh/id_ed25519.pub" >> /tmp/all_keys
    done

    # Distribute the keys
    distribute_keys "$nodes_file"

    # Cleanup
    rm -f /tmp/all_keys /tmp/hosts_content /tmp/authorized_keys

    echo "Setup completed successfully!"
    echo "Try: ssh hadoop@team-25-nn"
}

main "$1"
