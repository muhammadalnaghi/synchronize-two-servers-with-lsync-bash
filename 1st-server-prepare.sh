#!/bin/bash

# Function to exit on error
exit_on_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Prompt for user input
read -p "Enter username: " USERNAME
read -p "Enter source IP: " SOURCE_IP
read -p "Enter source path: " SOURCE_PATH
read -p "Enter destination IP: " DESTINATION_IP
read -p "Enter destination path: " DESTINATION_PATH

# Add user to sudoers
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers
exit_on_error "Failed to add user to sudoers"

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -q -N ""
exit_on_error "Failed to generate SSH key pair"

# Copy public key to destination server
ssh-copy-id "$USERNAME@$DESTINATION_IP"
exit_on_error "Failed to copy SSH public key to destination server"

# Create lsyncd configuration file
cat <<EOF | sudo tee /etc/lsyncd/lsyncd.conf.lua
settings {
    logfile = "/var/log/lsyncd/lsyncd.log",
    statusFile = "/var/log/lsyncd/lsyncd-status.log",
    statusInterval = 20
}

sync {
    default.rsyncssh,
    source = "$SOURCE_PATH",
    host = "$DESTINATION_IP",
    targetdir = "$DESTINATION_PATH",
    delay = 5,
    rsync = {
        binary = "/usr/bin/rsync",
        archive = true,
        compress = true
    }
}
EOF
exit_on_error "Failed to create lsyncd configuration file"

# Create log directory and set permissions
sudo mkdir -p /var/log/lsyncd
sudo chown -R $USERNAME:$USERNAME /var/log/lsyncd
exit_on_error "Failed to create log directory and set permissions"

# Start lsyncd
sudo systemctl start lsyncd
exit_on_error "Failed to start lsyncd"

echo "Server prepared for lsyncd synchronization successfully."
