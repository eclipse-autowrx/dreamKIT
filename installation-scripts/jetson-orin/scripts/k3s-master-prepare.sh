#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# K3s Master Setup & Agent Package Preparation - JETSON ORIN FIX
# Usage: sudo ./k3s-master-prepare.sh <network_interface>

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

# --- SCRIPT SETUP AND VALIDATION ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}${BOLD}This script must be run as root (sudo).${NC}"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo -e "${YELLOW}${BOLD}Usage: sudo $0 <network_interface>.${NC}"
    echo -e "${YELLOW}${BOLD}Example: sudo $0 eth0.${NC}"
    exit 1
fi

SERVER_NET_IF="$1"

SERVER_IP=$(ip -4 addr show "$SERVER_NET_IF" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}${BOLD}Could not find an IP address on interface '$SERVER_NET_IF'. Please check the interface name.${NC}"
    exit 1
fi

echo -e "${BLUE}Preparing K3s master on interface ${BOLD}${SERVER_NET_IF}${NC} with IP ${BOLD}${SERVER_IP}${NC}"

# --- 0. JETSON ORIN SPECIFIC CLEANUP ---
# echo -e "${BLUE}Cleaning up any previous K3s installation...${NC}"
# if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
#     /usr/local/bin/k3s-uninstall.sh || true
# fi

# Kill any existing K3s processes
# pkill -f k3s || true
# sleep 2

# Clean up existing bridge interfaces that might conflict
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true

# --- 1. K3S INSTALLATION WITH JETSON SPECIFIC CONFIG ---
echo -e "${BLUE}Installing K3s server with Jetson Orin specific configuration...${NC}"

# Create the K3s configuration directory first
mkdir -p /etc/rancher/k3s

# Create the configuration file BEFORE installation to avoid conflicts
cat > /etc/rancher/k3s/config.yaml << EOF
write-kubeconfig-mode: "0644"

# === CRITICAL: Network configuration for Jetson Orin ===
advertise-address: "${SERVER_IP}"
node-ip: "${SERVER_IP}"
flannel-iface: "${SERVER_NET_IF}"
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"

# Disable components that cause issues on Jetson
disable-network-policy: true
disable-cloud-controller: true
flannel-backend: "host-gw"

# Single node cluster setup
cluster-init: true
disable-helm-controller: true
prefer-bundled-bin: true

# Jetson Orin specific kubelet arguments
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

# Install K3s with specific configuration for Jetson
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-name=xip --config /etc/rancher/k3s/config.yaml" sh -

# --- 2. JETSON SPECIFIC SYSTEM CONFIGURATION ---
echo -e "${BLUE}Configuring system for Jetson Orin...${NC}"

# Ensure proper kernel modules are loaded
modprobe br_netfilter || true
modprobe overlay || true

# Add to modules to load at boot
echo 'br_netfilter' >> /etc/modules-load.d/k3s.conf
echo 'overlay' >> /etc/modules-load.d/k3s.conf

# --- 3. KUBECONFIG PERMISSIONS ---
echo -e "${BLUE}Configuring kubectl access...${NC}"
mkdir -p /etc/rancher/k3s
chown "$USER":"$USER" /etc/rancher/k3s/k3s.yaml 2>/dev/null || true
mkdir -p "$HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

# --- 4. SYSTEMD CONFIGURATION FOR JETSON ---
echo -e "${BLUE}Creating Jetson-specific systemd configuration...${NC}"

# Create network wait script that waits for the specific interface and IP
tee /usr/local/bin/k3s-network-wait.sh << EOF
#!/bin/bash
# Jetson Orin K3s network wait script
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
chmod +x /usr/local/bin/k3s-network-wait.sh

# Note: Instead of creating a separate service, we'll use ExecStartPre in the override

# Create systemd override for k3s service
mkdir -p /etc/systemd/system/k3s.service.d
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

# Jetson-specific environment
Environment="K3S_NODE_NAME=xip"
Environment="K3S_ADVERTISE_ADDRESS=${SERVER_IP}"
EOF

# --- 5. START SERVICES ---
echo -e "${BLUE}Starting K3s with Jetson configuration...${NC}"
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
echo -e "${BLUE}Preparing agent installation package...${NC}"

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
# This file is generated by k3s-master-prepare-jetson-fix.sh
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

# Prepare containerd mirror configuration
REGISTRY_MIRROR_IP="192.168.56.2"
cat >"${PACKAGE_DIR}/registries.yaml" <<EOF
# This file is generated by k3s-master-prepare-jetson-fix.sh
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

echo -e "${GREEN}✓ Agent package artifacts created in ${PACKAGE_DIR}/${NC}"

# --- 8. FINAL SUMMARY ---
echo ""
echo -e "${GREEN}${BOLD}✓✓✓ K3s Master Setup Complete for Jetson Orin! ✓✓✓${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "${WHITE}Master Node Name:  ${BOLD}xip${NC}"
echo -e "${WHITE}Master IP:         ${BOLD}${SERVER_IP}${NC}"
echo -e "${WHITE}Network Interface: ${BOLD}${SERVER_NET_IF}${NC}"
echo -e "${WHITE}Agent Node Token:  (see below)${NC}"
echo -e "${BOLD}${NODE_TOKEN}${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "${YELLOW}Jetson Orin Specific Fixes Applied:${NC}"
echo -e "${YELLOW}- Force IP binding to prevent multi-homed issues${NC}"
echo -e "${YELLOW}- Kernel module loading for ARM64 architecture${NC}"
echo -e "${YELLOW}- Network interface cleanup and preparation${NC}"
echo -e "${YELLOW}- Network wait script for interface availability${NC}"
echo -e "${YELLOW}- Extended timeouts for Jetson hardware${NC}"
echo ""