#!/bin/bash

# Check if the script is run with sudo/root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Get the username of the non-root user running sudo
USERNAME=$SUDO_USER

# Open config.txt file and add the overlay if not already added
CONFIG_FILE="/boot/firmware/config.txt"
OVERLAY_LINE="dtoverlay=seeed-can-fd-hat-v2"

if grep -q "$OVERLAY_LINE" "$CONFIG_FILE"; then
    echo "CAN-FD HAT overlay is already present in $CONFIG_FILE"
else
    echo "Adding CAN-FD HAT overlay to $CONFIG_FILE"
    echo "$OVERLAY_LINE" >> "$CONFIG_FILE"
    echo "CAN-FD HAT overlay added."
fi

# Create a systemd service to bring up can0 as CAN-FD and can1 as normal CAN
SERVICE_PATH="/etc/systemd/system/dk-can-setup.service"

# Stop any existing services with the same name
if systemctl is-active --quiet dk-can-setup.service; then
    echo "Stopping existing dk-can-setup.service..."
    systemctl stop dk-can-setup.service
fi

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Setup CAN interfaces (can0 as CAN-FD, can1 as normal CAN)
Requires=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /home/$USERNAME/.dk/dk_setup/can-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "Service file created at $SERVICE_PATH"

# Create the directory for the can-setup.sh script
CAN_SETUP_DIR="/home/$USERNAME/.dk/dk_setup"
CAN_SETUP_SCRIPT="$CAN_SETUP_DIR/can-setup.sh"

mkdir -p "$CAN_SETUP_DIR"

# Create the CAN setup script
cat <<'EOF' > "$CAN_SETUP_SCRIPT"
#!/bin/bash

# Bring up can0 as CAN-FD
sudo ip link set can0 type can bitrate 500000 dbitrate 2000000 fd on
sudo ip link set up can0

# Bring up can1 as normal CAN
sudo ip link set can1 type can bitrate 500000
sudo ip link set up can1
EOF

# Make the script executable
chmod +x "$CAN_SETUP_SCRIPT"
echo "CAN setup script created at $CAN_SETUP_SCRIPT"

# Enable the systemd service
echo "Enabling CAN setup service..."
systemctl daemon-reload
if systemctl enable dk-can-setup.service; then
    echo "Service enabled successfully."
else
    echo "Failed to enable service."
    exit 1
fi

# Start the service
if systemctl start dk-can-setup.service; then
    echo "Service started successfully."
else
    echo "Failed to start the service."
    exit 1
fi

echo "CAN setup completed successfully."