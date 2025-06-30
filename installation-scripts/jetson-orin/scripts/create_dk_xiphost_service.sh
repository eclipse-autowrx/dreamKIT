# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/bash

# Define the path for the service unit file
SERVICE_FILE="/etc/systemd/system/dk_xiphost.service"

# Check if the service file already exists.
if [ -f "$SERVICE_FILE" ]; then
    echo "Service file $SERVICE_FILE already exists. Nothing to do."
else

# Write the unit file using a here document
cat << 'EOF' > "$SERVICE_FILE"
[Unit]
Description=DK XIP Host Service
After=network.target

[Service]
Type=simple
# Execute the script. Adjust the path if needed.
ExecStart=/home/.dk/dk_swupdate/dk_xiphost.sh
# Restart on failure with a 5-second delay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Created service file at $SERVICE_FILE"
fi

# Reload the systemd manager configuration
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling dk_xiphost service..."
systemctl enable dk_xiphost.service

# Start the service
echo "Starting dk_xiphost service..."
systemctl start dk_xiphost.service

echo "Service dk_xiphost has been created, enabled, and started."
