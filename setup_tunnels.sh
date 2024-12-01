#!/bin/bash

echo "Cleaning up existing tunnels..."
# Kill existing SSH tunnels
pkill -f "ssh -L.*team-25-nn"

# Wait a moment for processes to clean up
sleep 2

# Kill any remaining processes on these ports
for port in 9870 8088 8080 19888; do
    pid=$(sudo lsof -t -i:$port)
    if [ ! -z "$pid" ]; then
        echo "Killing process on port $port"
        sudo kill -9 $pid
    fi
done

# Wait another moment for ports to free up
sleep 2

echo "Setting up new tunnels..."
# Create new SSH tunnels
ssh -L 9870:localhost:9870 -L 8088:localhost:8088 -L 8080:localhost:8080 -L 19888:localhost:19888 hadoop@team-25-nn -N &

# Save the tunnel process ID
echo $! > ~/.hadoop_tunnels.pid

# Function to check if tunnels are running
check_tunnels() {
    ps aux | grep "ssh -L" | grep -v grep
}

# Print tunnel status
echo "Checking tunnel status:"
check_tunnels

echo "Tunnels established. You can now access:"
echo "Hadoop UI: http://localhost:9870"
echo "YARN UI: http://localhost:8088"
echo "Spark UI: http://localhost:8080"
echo "History Server: http://localhost:19888"


chmod +x ~/setup_tunnels.sh
