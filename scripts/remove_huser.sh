#!/bin/bash

# Exit on error
set -e

# Function to read nodes from file
cleanup_nodes() {
    local nodes_file=$1
    
    echo "Starting hadoop user cleanup on all nodes..."
    
    # Skip first line (jump server) and process each node
    tail -n +2 "$nodes_file" | while read -r ip name rest; do
        echo "Removing hadoop user from $name..."
        ssh "$name" 'sudo userdel -r hadoop 2>/dev/null || true'
        
        if [ $? -eq 0 ]; then
            echo "Successfully removed hadoop user from $name"
        else
            echo "Note: hadoop user might not exist on $name or there were minor issues during removal"
        fi
    done
}

# Main execution
main() {
    local nodes_file=$1
    
    # Check if nodes file is provided
    if [ -z "$nodes_file" ]; then
        echo "Usage: $0 <nodes_file>"
        echo "Example: $0 nodes.txt"
        exit 1
    fi
    
    # Check if nodes file exists
    if [ ! -f "$nodes_file" ]; then
        echo "Error: Nodes file $nodes_file not found"
        exit 1
    fi
    
    cleanup_nodes "$nodes_file"
    
    echo "Cleanup completed!"
}

# Execute main function
main "$1"