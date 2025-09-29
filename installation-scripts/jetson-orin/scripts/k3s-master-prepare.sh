#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# K3s Master Setup & Agent Package Preparation - Generic Device Support
# Usage:
#   ./k3s-master-prepare.sh <network_interface>     # Auto-detects user
#   sudo ./k3s-master-prepare.sh <network_interface> # Auto-detects original user
#   sudo DK_USER="username" ./k3s-master-prepare.sh <network_interface>
# Examples:
#   ./k3s-master-prepare.sh eth0
#   sudo ./k3s-master-prepare.sh eth0
#   sudo DK_USER="myuser" ./k3s-master-prepare.sh eth0

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

set -e # Exit immediately if a command exits with a non-zero status.

# Function to display final summary
show_summary() {
    local node_token="$1"
    echo ""
    echo -e "${GREEN}${BOLD}✓✓✓ K3s Master Setup Complete! ✓✓✓${NC}"
    echo -e "${CYAN}--------------------------------------------------${NC}"
    echo -e "${WHITE}Master Node Name:  ${BOLD}xip${NC}"

    if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
        echo -e "${WHITE}Master Mode:       ${BOLD}Standalone (no worker artifacts)${NC}"
        echo -e "${WHITE}Network Interface: ${BOLD}${SERVER_NET_IF} (not available)${NC}"
    else
        echo -e "${WHITE}Master IP:         ${BOLD}${SERVER_IP}${NC}"
        echo -e "${WHITE}Network Interface: ${BOLD}${SERVER_NET_IF}${NC}"
        echo -e "${WHITE}Worker Artifacts:  ${BOLD}Generated in ../nxp-s32g/scripts/${NC}"
    fi

    echo -e "${WHITE}Agent Node Token:  (see below)${NC}"
    echo -e "${BOLD}${node_token}${NC}"
    echo -e "${CYAN}--------------------------------------------------${NC}"
}

# --- SCRIPT SETUP AND VALIDATION ---
# Auto-detect user if running directly (not via sudo)
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ] && [ -z "$DK_USER" ]; then
    echo -e "${YELLOW}${BOLD}Warning: Running directly as root. Consider running as regular user or via sudo.${NC}"
fi

# Auto-detect the target user for kubeconfig setup
if [ -z "$DK_USER" ]; then
    if [ -n "$SUDO_USER" ]; then
        DK_USER="$SUDO_USER"
        echo -e "${BLUE}Auto-detected user from sudo: $DK_USER${NC}"
    elif [ "$EUID" -ne 0 ]; then
        DK_USER="$(whoami)"
        echo -e "${BLUE}Auto-detected current user: $DK_USER${NC}"
        # If not root, we need to escalate for certain operations
        if ! sudo -n true 2>/dev/null; then
            echo -e "${YELLOW}This script requires sudo privileges for system configuration.${NC}"
            echo -e "${YELLOW}Please run with sudo or ensure passwordless sudo is configured.${NC}"
            exit 1
        fi
    else
        DK_USER="root"
        echo -e "${BLUE}Running as root user${NC}"
    fi
else
    echo -e "${BLUE}Using explicitly provided user: $DK_USER${NC}"
fi

if [ $# -ne 1 ]; then
    echo -e "${YELLOW}${BOLD}Usage: sudo $0 <network_interface>.${NC}"
    echo -e "${YELLOW}${BOLD}Example: sudo $0 eth0.${NC}"
    exit 1
fi

SERVER_NET_IF="$1"

SERVER_IP=$(ip -4 addr show "$SERVER_NET_IF" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$SERVER_IP" ]; then
    echo -e "${YELLOW}${BOLD}Warning: Could not find an IP address on interface '$SERVER_NET_IF'.${NC}"
    echo -e "${YELLOW}This could mean the interface doesn't exist or has no IP assigned.${NC}"
    echo -e "${YELLOW}Proceeding with K3s master-only installation (node name: xip).${NC}"
    echo -e "${YELLOW}Worker node artifact generation will be skipped.${NC}"

    # Set flag to skip worker node preparation
    SKIP_WORKER_ARTIFACTS=true

    echo -e "${BLUE}Preparing K3s master-only installation${NC}"
    echo -e "${BLUE}Target user for kubeconfig: ${BOLD}${DK_USER}${NC}"
else
    echo -e "${BLUE}Preparing K3s master on interface ${BOLD}${SERVER_NET_IF}${NC} with IP ${BOLD}${SERVER_IP}${NC}"
    echo -e "${BLUE}Target user for kubeconfig: ${BOLD}${DK_USER}${NC}"

    # Clear flag for normal operation
    SKIP_WORKER_ARTIFACTS=false
fi

# --- 0. DEVICE SPECIFIC CLEANUP ---
# echo -e "${BLUE}Cleaning up any previous K3s installation...${NC}"
# if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
#     /usr/local/bin/k3s-uninstall.sh || true
# fi

# Kill any existing K3s processes
# pkill -f k3s || true
# sleep 2

# Clean up existing bridge interfaces that might conflict (ARM/x86 compatible)
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true

# --- 1. K3S INSTALLATION WITH DEVICE SPECIFIC CONFIG ---
if ! command -v k3s &> /dev/null; then
    echo -e "${BLUE}Installing K3s server with device-specific configuration...${NC}"

    # Create the K3s configuration directory first
    mkdir -p /etc/rancher/k3s

    # Create the configuration file BEFORE installation to avoid conflicts
    if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
        # Master-only configuration without specific network interface binding
        cat > /etc/rancher/k3s/config.yaml << EOF
write-kubeconfig-mode: "0644"

# === Master-only configuration ===
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"

# Disable components that cause issues on embedded devices
disable-network-policy: true
disable-cloud-controller: true
flannel-backend: "host-gw"

# Single node cluster setup
cluster-init: true
disable-helm-controller: true
prefer-bundled-bin: true

# Device-specific kubelet arguments
kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
  - "resolv-conf=/etc/resolv.conf"
  - "fail-swap-on=false"
  - "address=0.0.0.0"

# API server configuration
kube-apiserver-arg:
  - "default-not-ready-toleration-seconds=30"
  - "default-unreachable-toleration-seconds=30"
  - "service-cluster-ip-range=10.43.0.0/16"
  - "bind-address=0.0.0.0"

kube-controller-manager-arg:
  - "bind-address=0.0.0.0"
  - "node-monitor-grace-period=30s"
  - "node-monitor-period=5s"

# Disable problematic components
disable:
  - traefik
  - metrics-server
  - local-storage
  - servicelb
EOF
    else
        # Normal configuration with network interface binding
        cat > /etc/rancher/k3s/config.yaml << EOF
write-kubeconfig-mode: "0644"

# === CRITICAL: Network configuration for multi-arch devices ===
advertise-address: "${SERVER_IP}"
node-ip: "${SERVER_IP}"
flannel-iface: "${SERVER_NET_IF}"
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"

# Disable components that cause issues on embedded devices
disable-network-policy: true
disable-cloud-controller: true
flannel-backend: "host-gw"

# Single node cluster setup
cluster-init: true
disable-helm-controller: true
prefer-bundled-bin: true

# Device-specific kubelet arguments
kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
  - "resolv-conf=/etc/resolv.conf"
  - "fail-swap-on=false"
  - "node-ip=${SERVER_IP}"
  - "address=0.0.0.0"

# API server configuration for multi-homed systems
kube-apiserver-arg:
  - "default-not-ready-toleration-seconds=30"
  - "default-unreachable-toleration-seconds=30"
  - "service-cluster-ip-range=10.43.0.0/16"
  - "advertise-address=${SERVER_IP}"
  - "bind-address=0.0.0.0"

kube-controller-manager-arg:
  - "bind-address=0.0.0.0"
  - "node-monitor-grace-period=30s"
  - "node-monitor-period=5s"

# Disable problematic components
disable:
  - traefik
  - metrics-server
  - local-storage
  - servicelb
EOF
    fi

    # Install K3s with specific configuration for Jetson
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-name=xip --config /etc/rancher/k3s/config.yaml" sh -
else
    echo -e "${BLUE}K3s server is already installed, skipping to final summary...${NC}"
    # Extract node token for agent package preparation
    NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
    # Jump to final summary
    show_summary "$NODE_TOKEN"
    exit 0
fi

# --- 2. DEVICE SPECIFIC SYSTEM CONFIGURATION ---
echo -e "${BLUE}Configuring system for embedded device...${NC}"

# Ensure proper kernel modules are loaded
modprobe br_netfilter || true
modprobe overlay || true

# Add to modules to load at boot
echo 'br_netfilter' >> /etc/modules-load.d/k3s.conf
echo 'overlay' >> /etc/modules-load.d/k3s.conf

# --- 4. SYSTEMD CONFIGURATION FOR DEVICE ---
echo -e "${BLUE}Creating device-specific systemd configuration...${NC}"

# Create network wait script that waits for the specific interface and IP
if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
    # Simplified network wait script for master-only mode
    tee /usr/local/bin/k3s-network-wait.sh << EOF
#!/bin/bash
# K3s network wait script for master-only embedded devices
set -e

echo "Master-only mode: Ensuring basic network readiness..."

# Ensure loopback is up
ip link set dev lo up

# Clean up any conflicting bridge interfaces
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true

# Ensure kernel modules are loaded
modprobe br_netfilter || true
modprobe overlay || true

echo "Network preparation complete for master-only installation"
exit 0
EOF
else
    # Full network wait script for normal operation
    tee /usr/local/bin/k3s-network-wait.sh << EOF
#!/bin/bash
# K3s network wait script for embedded devices
set -e

INTERFACE="${SERVER_NET_IF}"
EXPECTED_IP="${SERVER_IP}"
MAX_WAIT=300  # 5 minutes
WAIT_INTERVAL=2

echo "Waiting for network interface \$INTERFACE with IP \$EXPECTED_IP..."

for ((i=0; i<MAX_WAIT; i+=WAIT_INTERVAL)); do
    # Check if interface exists and is up
    if ip link show "\$INTERFACE" &>/dev/null && ip link show "\$INTERFACE" | grep -q "state UP"; then
        # Check if the expected IP is assigned
        CURRENT_IP=\$(ip -4 addr show "\$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
        if [ "\$CURRENT_IP" = "\$EXPECTED_IP" ]; then
            echo "Network interface \$INTERFACE is ready with IP \$EXPECTED_IP"

            # Ensure loopback is up
            ip link set dev lo up

            # Clean up any conflicting bridge interfaces
            ip link delete cni0 2>/dev/null || true
            ip link delete flannel.1 2>/dev/null || true

            # Ensure kernel modules are loaded
            modprobe br_netfilter || true
            modprobe overlay || true

            exit 0
        fi
        echo "Interface \$INTERFACE is up but has IP \$CURRENT_IP, waiting for \$EXPECTED_IP..."
    else
        echo "Waiting for interface \$INTERFACE to be up... (\$i/\$MAX_WAIT seconds)"
    fi
    sleep \$WAIT_INTERVAL
done

echo "ERROR: Network interface \$INTERFACE with IP \$EXPECTED_IP not ready after \$MAX_WAIT seconds"
exit 1
EOF
fi
chmod +x /usr/local/bin/k3s-network-wait.sh

# Note: Instead of creating a separate service, we'll use ExecStartPre in the override

# Create systemd override for k3s service
mkdir -p /etc/systemd/system/k3s.service.d
if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
    # Master-only systemd configuration
    tee /etc/systemd/system/k3s.service.d/override.conf << EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
# Network preparation and wait before k3s starts
ExecStartPre=/usr/local/bin/k3s-network-wait.sh
Environment="K3S_RESOLV_CONF=/etc/resolv.conf"
TimeoutStartSec=600
Restart=always
RestartSec=15s
StartLimitInterval=0

# Device-specific environment
Environment="K3S_NODE_NAME=xip"
EOF
else
    # Normal systemd configuration with network binding
    tee /etc/systemd/system/k3s.service.d/override.conf << EOF
[Unit]
After=network-online.target
Wants=network-online.target

[Service]
# Network preparation and wait before k3s starts
ExecStartPre=/usr/local/bin/k3s-network-wait.sh
Environment="K3S_RESOLV_CONF=/etc/resolv.conf"
TimeoutStartSec=600
Restart=always
RestartSec=15s
StartLimitInterval=0

# Device-specific environment
Environment="K3S_NODE_NAME=xip"
Environment="K3S_ADVERTISE_ADDRESS=${SERVER_IP}"
EOF
fi

# --- 5. START SERVICES ---
echo -e "${BLUE}Starting K3s with device configuration...${NC}"
systemctl daemon-reload
systemctl stop k3s || true
systemctl start k3s

# --- 6. WAIT FOR K3S TO BE READY ---
echo -e "${BLUE}Waiting for K3s API server to be ready...${NC}"
for i in {1..60}; do
    if k3s kubectl get nodes --no-headers 2>/dev/null | grep -q Ready; then
        echo -e "${GREEN}${BOLD}✓ K3s master node is Ready!${NC}"
        break
    fi
    echo -e "${DIM}Waiting for K3s... ($i/60)${NC}"
    sleep 5
done

if ! k3s kubectl get nodes --no-headers 2>/dev/null | grep -q Ready; then
    echo -e "${RED}${BOLD}✗ K3s failed to start. Please check logs: 'sudo journalctl -u k3s'${NC}"
    echo -e "${RED}Current K3s status:${NC}"
    systemctl status k3s --no-pager || true
    exit 1
fi

# --- 7. PREPARE AGENT INSTALLATION PACKAGE ---
if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
    echo -e "${YELLOW}Skipping worker node artifact generation (network interface not available)${NC}"

    # Extract node token for display in summary
    NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
else
    echo -e "${BLUE}Preparing agent installation package...${NC}"

    # Download K3s binaries for both amd64 and arm64 (for NXP agent preparation)
    k3s kubectl delete -f manifests/k3s-rancher-mirrored-pause-mirror.yaml --ignore-not-found || true
    k3s kubectl apply -f manifests/k3s-rancher-mirrored-pause-mirror.yaml || true

    # Extract node token
    NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

    # Agent configuration (adjust these placeholders for the target worker)
    WORKER_NODE_IP="192.168.56.49"
    WORKER_NODE_NET_IF="eth0"

    echo -e "${CYAN}Agent package will be configured for worker node:${NC}"
    echo -e "${CYAN}  - IP: ${WORKER_NODE_IP}${NC}"
    echo -e "${CYAN}  - Interface: ${WORKER_NODE_NET_IF}${NC}"

    # Create directories for the package artifacts
    PACKAGE_DIR="../nxp-s32g/scripts"
    mkdir -p "$PACKAGE_DIR"

# Prepare agent k3s.service template
cat <<EOF > "${PACKAGE_DIR}/k3s.service"
# This file is generated by k3s-master-prepare.sh
# It should be placed in /etc/systemd/system/ on the worker node.
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Requires=containerd.service
After=containerd.service network-online.target
Wants=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/k3s agent \\
  --server https://${SERVER_IP}:6443 \\
  --token ${NODE_TOKEN} \\
  --node-name=vip \\
  --node-ip ${WORKER_NODE_IP} \\
  --flannel-iface ${WORKER_NODE_NET_IF} \\
  --kubelet-arg="allowed-unsafe-sysctls=net.ipv4.ip_forward"

ExecStopPost=/bin/sh -c "if systemctl is-system-running | grep -i 'stopping'; then /usr/local/bin/k3s-killall.sh; fi"
EOF

# Prepare containerd mirror configuration - use detected master IP as registry mirror
REGISTRY_MIRROR_IP="$SERVER_IP"
cat >"${PACKAGE_DIR}/registries.yaml" <<EOF
# This file is generated by k3s-master-prepare.sh
# It should be placed in /etc/rancher/k3s/ on the worker node.
mirrors:
  "docker.io":
    endpoint:
      - "http://${REGISTRY_MIRROR_IP}:5000"
  "ghcr.io":
    endpoint:
      - "http://${REGISTRY_MIRROR_IP}:5000"
configs:
  "${REGISTRY_MIRROR_IP}:5000":
    tls:
      insecure_skip_verify: true
EOF

# Prepare daemon.json for containerd registry mirror
cat >"${PACKAGE_DIR}/daemon.json" <<EOF
{
  "insecure-registries": ["${REGISTRY_MIRROR_IP}:5000"]
}
EOF

# Prepare dreamos-setup.service for systemd
cat >"${PACKAGE_DIR}/dreamos-setup.service" <<EOF
# This file is generated by k3s-master-prepare.sh
# It should be placed in /etc/systemd/system/ on the worker node.
[Unit]
Description=DreamOS Setup Service
After=network.target
Before=k3s.service
Wants=network.target

[Service]
Type=oneshot
ExecStart=/home/root/.dk/nxp-s32g/scripts/dreamos_setup.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Update dreamos_setup.sh with current date
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")
echo -e "${BLUE}Updating dreamos_setup.sh with current date: ${CURRENT_DATE}${NC}"

if [ -f "${PACKAGE_DIR}/dreamos_setup.sh" ]; then
    # Update the date line in dreamos_setup.sh
    sed -i "s/date -s \".*\"/date -s \"${CURRENT_DATE}\"/" "${PACKAGE_DIR}/dreamos_setup.sh"
    # Update the default gateway to use the detected master IP
    sed -i "s/ip route add default via .* dev eth0/ip route add default via ${SERVER_IP} dev eth0/" "${PACKAGE_DIR}/dreamos_setup.sh"
    echo -e "${GREEN}✓ Updated dreamos_setup.sh date and gateway configuration${NC}"
else
    echo -e "${YELLOW}⚠ dreamos_setup.sh not found in ${PACKAGE_DIR}, creating new one${NC}"
    # Create a basic dreamos_setup.sh if it doesn't exist
    cat >"${PACKAGE_DIR}/dreamos_setup.sh" <<EOF
#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

set -e

# Configure CAN0
ip link set can0 type can bitrate 500000 sample-point 0.7 dbitrate 2000000 fd on
ip link set can0 up
ifconfig can0 txqueuelen 65536

# Configure CAN1
#ip link set can1 type can bitrate 500000
ip link set can1 type can bitrate 500000 sample-point 0.75 dbitrate 2000000 fd on
ip link set can1 up
ifconfig can1 txqueuelen 65536

# Configure CanTP
insmod /home/root/.dk/nxp-s32g/library/can-isotp-s32g-ewaol.ko

# Configure IPv4 - K3S
ifconfig eth0 ${WORKER_NODE_IP}

# Configure K3S - default gateway
ip route add default via ${SERVER_IP} dev eth0

# Configure K3S - CA
timedatectl set-ntp true
date -s "${CURRENT_DATE}"
EOF
    chmod +x "${PACKAGE_DIR}/dreamos_setup.sh"
fi

    echo -e "${GREEN}✓ Agent package artifacts created in ${PACKAGE_DIR}/:${NC}"
    echo -e "${GREEN}  - k3s.service (systemd service file for K3s agent)${NC}"
    echo -e "${GREEN}  - dreamos-setup.service (systemd service file for DreamOS setup)${NC}"
    echo -e "${GREEN}  - registries.yaml (K3s registry mirror config)${NC}"
    echo -e "${GREEN}  - daemon.json (containerd registry mirror config)${NC}"
    echo -e "${GREEN}  - dreamos_setup.sh (network and system setup script)${NC}"

    # Set execute permissions for all shell scripts in the package directory
    echo -e "${BLUE}Setting execute permissions for shell scripts...${NC}"
    chmod +x "${PACKAGE_DIR}"/*.sh 2>/dev/null || true
    echo -e "${GREEN}✓ Execute permissions set for all .sh files in ${PACKAGE_DIR}${NC}"
fi

# --- 3. KUBECONFIG PERMISSIONS ---
echo -e "${BLUE}Configuring kubectl access...${NC}"

# Use the auto-detected user from earlier in the script
ORIGINAL_USER="$DK_USER"

ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)

echo -e "${BLUE}Detected original user: $ORIGINAL_USER${NC}"
echo -e "${BLUE}User home directory: $ORIGINAL_HOME${NC}"

# Validate that we detected a non-root user (unless truly running as root)
if [ "$ORIGINAL_USER" = "root" ] && [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Warning: Could not detect the original non-root user. Kubeconfig will be set up for root only.${NC}"
elif [ "$ORIGINAL_USER" != "root" ] && [ ! -d "$ORIGINAL_HOME" ]; then
    echo -e "${RED}Error: Detected user $ORIGINAL_USER but home directory $ORIGINAL_HOME does not exist.${NC}"
    exit 1
fi

# Set up kubeconfig for the original user (non-root access)
if [ "$ORIGINAL_USER" != "root" ]; then
    echo -e "${BLUE}Setting up kubeconfig for user: $ORIGINAL_USER${NC}"

    # Step 1: Change k3s kubeconfig ownership to user (matches your working solution)
    sudo chown "$ORIGINAL_USER":"$ORIGINAL_USER" /etc/rancher/k3s/k3s.yaml
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml

    # Step 2: Create .kube directory and copy kubeconfig (matches your working solution)
    sudo -u "$ORIGINAL_USER" mkdir -p "$ORIGINAL_HOME/.kube"
    sudo cp /etc/rancher/k3s/k3s.yaml "$ORIGINAL_HOME/.kube/config"
    sudo chown "$ORIGINAL_USER":"$ORIGINAL_USER" "$ORIGINAL_HOME/.kube/config"
    sudo chmod 600 "$ORIGINAL_HOME/.kube/config"

    # Set KUBECONFIG environment variable hint
    echo -e "${CYAN}To use kubectl and k9s as $ORIGINAL_USER, make sure KUBECONFIG is set:${NC}"
    echo -e "${CYAN}export KUBECONFIG=$ORIGINAL_HOME/.kube/config${NC}"
    echo -e "${CYAN}Or simply use: kubectl (will use ~/.kube/config by default)${NC}"

    # Verify kubectl access works for the user
    if sudo -u "$ORIGINAL_USER" kubectl get nodes >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Kubeconfig access configured and verified for user $ORIGINAL_USER${NC}"
        echo -e "${GREEN}✓ kubectl is working properly${NC}"

        # Test k9s configuration access
        if sudo -u "$ORIGINAL_USER" timeout 5s k9s info >/dev/null 2>&1; then
            echo -e "${GREEN}✓ k9s configuration access verified${NC}"
        else
            echo -e "${YELLOW}⚠ k9s configuration check failed - this may be due to TTY limitations${NC}"
        fi
    else
        echo -e "${RED}✗ Warning: kubectl access verification failed for user $ORIGINAL_USER${NC}"
    fi
else
    echo -e "${YELLOW}Running as root - kubeconfig already accessible${NC}"
fi

# --- 8. FINAL SUMMARY ---
show_summary "$NODE_TOKEN"
echo -e "${YELLOW}Device-Specific Fixes Applied:${NC}"
if [ "$SKIP_WORKER_ARTIFACTS" = "true" ]; then
    echo -e "${YELLOW}- Master-only configuration (no network interface binding)${NC}"
    echo -e "${YELLOW}- Basic network preparation for standalone operation${NC}"
else
    echo -e "${YELLOW}- Force IP binding to prevent multi-homed issues${NC}"
    echo -e "${YELLOW}- Network interface-specific configuration${NC}"
fi
echo -e "${YELLOW}- Kernel module loading for multi-arch support${NC}"
echo -e "${YELLOW}- Network interface cleanup and preparation${NC}"
echo -e "${YELLOW}- Network wait script for interface availability${NC}"
echo -e "${YELLOW}- Extended timeouts for embedded hardware${NC}"
echo -e "${YELLOW}- Kubeconfig permissions configured for user access${NC}"
echo ""
echo -e "${CYAN}${BOLD}Post-Installation Notes:${NC}"
echo -e "${CYAN}• kubectl and k9s should work immediately for user $ORIGINAL_USER${NC}"
echo -e "${CYAN}• Both /etc/rancher/k3s/k3s.yaml and ~/.kube/config are configured${NC}"
echo -e "${CYAN}• Script supports auto-detection when run standalone or via sudo${NC}"
echo -e "${CYAN}• For custom user: sudo DK_USER=\"username\" $0 <interface>${NC}"
echo -e "${CYAN}• If issues persist, verify file permissions and ownership${NC}"
echo ""