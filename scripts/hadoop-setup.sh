#!/bin/bash

# Function to read node names from file
get_nodes() {
    local nodes_file=$1
    tail -n +2 "$nodes_file" | awk '{print $2}'
}

# Function to install Java
install_java() {
    echo "Installing Java..."
    sudo apt-get update
    sudo apt-get install -y software-properties-common openjdk-11-jdk-headless
}

# Function to create configuration files
create_configs() {
    local nn_hostname=$1
    
    # Create core-site.xml
    cat > core-site.xml << EOF
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${nn_hostname}:9000</value>
    </property>
</configuration>
EOF

    # Create hdfs-site.xml
    cat > hdfs-site.xml << EOF
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
</configuration>
EOF

    # Create workers file
    echo "${nn_hostname}" > workers
    for node in $(get_nodes "$nodes_file" | grep "dn"); do
        echo "$node" >> workers
    done
}

# Main execution
main() {
    local nodes_file=$1
    
    # Check if nodes file exists
    if [ ! -f "$nodes_file" ]; then
        echo "Usage: $0 <nodes_file>"
        exit 1
    fi
    
    # Get namenode hostname
    namenode=$(get_nodes "$nodes_file" | grep "nn")
    
    # Install Java and Hadoop
    install_java
    
    # Download Hadoop
    echo "Downloading Hadoop..."
    wget -q --show-progress https://dlcdn.apache.org/hadoop/common/hadoop-3.4.0/hadoop-3.4.0.tar.gz
    
    # Copy to all nodes
    echo "Copying Hadoop to all nodes..."
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        scp hadoop-3.4.0.tar.gz "hadoop@$node:/home/hadoop/"
    done
    
    # Extract on all nodes
    echo "Extracting Hadoop on all nodes..."
    tar -xzf hadoop-3.4.0.tar.gz
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        ssh "hadoop@$node" "tar -xzf hadoop-3.4.0.tar.gz"
    done
    
    # Create .profile
    echo "Setting up environment variables..."
    cat > ~/.profile << EOF
export HADOOP_HOME=/home/hadoop/hadoop-3.4.0
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
EOF
    
    # Copy .profile to all nodes
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        scp ~/.profile "hadoop@$node:/home/hadoop/"
        ssh "hadoop@$node" "source ~/.profile"
    done
    
    # Source profile locally
    source ~/.profile
    
    # Update hadoop-env.sh
    echo "Configuring Hadoop environment..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/hadoop-3.4.0/etc/hadoop/hadoop-env.sh
    
    # Copy hadoop-env.sh to all nodes
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        scp ~/hadoop-3.4.0/etc/hadoop/hadoop-env.sh "hadoop@$node:/home/hadoop/hadoop-3.4.0/etc/hadoop/"
    done
    
    # Create and distribute configuration files
    echo "Creating Hadoop configuration files..."
    cd ~/hadoop-3.4.0/etc/hadoop
    create_configs "$namenode"
    
    # Copy configuration files to all nodes
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        scp core-site.xml hdfs-site.xml workers "hadoop@$node:/home/hadoop/hadoop-3.4.0/etc/hadoop/"
    done
    
    # Format HDFS and start services
    echo "Formatting HDFS..."
    cd ~/hadoop-3.4.0
    bin/hdfs namenode -format
    
    echo "Starting Hadoop services..."
    sbin/start-dfs.sh
    
    # Check services on all nodes
    echo "Checking services status..."
    jps
    for node in $(get_nodes "$nodes_file" | grep -v "jn"); do
        echo "Status on $node:"
        ssh "hadoop@$node" "jps"
    done
    
    echo "Hadoop installation and configuration completed!"
}

# Execute main function
main "$1"