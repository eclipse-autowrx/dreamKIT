#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# K3s Master Setup & Agent Package Preparation
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

# --- 1. K3S INSTALLATION ---
if ! command -v k3s &> /dev/null; then
    echo -e "${BLUE}Installing K3s server...${NC}"
    # Use INSTALL_K3S_EXEC to set the node name during the initial installation
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-name=xip" sh -
else
    echo -e "${GREEN}K3s server is already installed.${NC}"
fi

# --- 2. KUBECONFIG PERMISSIONS ---
echo -e "${BLUE}Configuring kubectl access for the current user...${NC}"
sudo mkdir -p /etc/rancher/k3s
sudo chown "$USER":"$USER" /etc/rancher/k3s/k3s.yaml
sudo mkdir -p "$HOME/.kube"
sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

# --- 3. K3S CONFIGURATION FOR OFFLINE/EMBEDDED USE ---
echo -e "${BLUE}Creating robust K3s configuration file at /etc/rancher/k3s/config.yaml...${NC}"
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml << EOF
write-kubeconfig-mode: "0644"

# === NETWORKING: CRITICAL for multi-homed systems ===
bind-address: "${SERVER_IP}"
advertise-address: "${SERVER_IP}"
node-ip: "${SERVER_IP}"
flannel-iface: "${SERVER_NET_IF}"

# Minimal configuration for offline stability
disable-network-policy: true
disable-cloud-controller: true
flannel-backend: "host-gw"

# Offline mode configurations
cluster-init: true
disable-helm-controller: true
prefer-bundled-bin: true

kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
  - "resolv-conf=/etc/resolv.conf"
  - "fail-swap-on=false"

kube-apiserver-arg:
  - "default-not-ready-toleration-seconds=30"
  - "default-unreachable-toleration-seconds=30"
  - "service-cluster-ip-range=10.43.0.0/16"

kube-controller-manager-arg:
  - "bind-address=0.0.0.0"
  - "node-monitor-grace-period=30s"
  - "node-monitor-period=5s"

disable:
  - traefik
  - metrics-server
  - local-storage
  - servicelb
EOF

# --- 4. SYSTEMD AND BOOT RESILIENCE ---
# (This section remains unchanged from the previous version)

# 4.1. Systemd override
echo -e "${BLUE}Creating systemd override for k3s.service...${NC}"
sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo tee /etc/systemd/system/k3s.service.d/override.conf << EOF
[Unit]
After=network.target k3s-network-prep.service
Wants=network.target k3s-network-prep.service
[Service]
Environment="K3S_RESOLV_CONF=/etc/resolv.conf"
TimeoutStartSec=300
Restart=always
RestartSec=10s
StartLimitInterval=0
EOF

# 4.2. Network preparation script
echo -e "${BLUE}Creating network preparation script...${NC}"
sudo tee /usr/local/bin/k3s-network-prep.sh << 'EOF'
#!/bin/bash
ip link set dev lo up
if ! ip link show cni0 >/dev/null 2>&1; then
    ip link add name cni0 type bridge 2>/dev/null || true
    ip link set dev cni0 up 2>/dev/null || true
fi
CONFIG_FILE="/etc/rancher/k3s/config.yaml"
STORED_IP_FILE="/var/lib/rancher/k3s/server/stored-ip"
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_IP=$(grep 'advertise-address:' "$CONFIG_FILE" | awk '{print $2}')
    if [ -f "$STORED_IP_FILE" ]; then
        STORED_IP=$(cat "$STORED_IP_FILE")
        if [ "$CURRENT_IP" != "$STORED_IP" ] && [ -n "$CURRENT_IP" ]; then
            echo "K3s Prep: IP changed. Cleaning etcd data."
            systemctl stop k3s.service >/dev/null 2>&1 || true
            rm -rf /var/lib/rancher/k3s/server/db/etcd
            echo "$CURRENT_IP" > "$STORED_IP_FILE"
        fi
    elif [ -n "$CURRENT_IP" ]; then
        echo "K3s Prep: Storing initial IP $CURRENT_IP."
        mkdir -p /var/lib/rancher/k3s/server
        echo "$CURRENT_IP" > "$STORED_IP_FILE"
    fi
fi
exit 0
EOF
sudo chmod +x /usr/local/bin/k3s-network-prep.sh

# 4.3. Systemd service for network prep
echo -e "${BLUE}Creating k3s-network-prep.service...${NC}"
sudo tee /etc/systemd/system/k3s-network-prep.service << EOF
[Unit]
Description=K3s Network Preparation
Before=k3s.service
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/k3s-network-prep.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

# --- 5. START AND VERIFY K3S ---
echo -e "${BLUE}Reloading systemd, enabling services, and restarting K3s...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable k3s-network-prep.service
sudo systemctl restart k3s

echo -e "${BLUE}Waiting for K3s API server to be ready...${NC}"
for i in {1..40}; do
    if sudo k3s kubectl get nodes --no-headers 2>/dev/null | grep -q Ready; then
        echo -e "${GREEN}${BOLD}✓ K3s master node is Ready!${NC}"
        break
    fi
    echo -e "${DIM}Waiting for K3s... ($i/40)${NC}"
    sleep 5
done

if ! sudo k3s kubectl get nodes --no-headers 2>/dev/null | grep -q Ready; then
    echo -e "${RED}${BOLD}✗ K3s failed to start. Please check logs: 'sudo journalctl -u k3s'${NC}"
    exit 1
fi

# --- 6. PREPARE AGENT INSTALLATION PACKAGE ---
echo -e "${BLUE}Preparing agent installation package...${NC}"

# 6.1. Extract node token
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

# 6.2. Agent configuration (adjust these placeholders for the target worker)
# These values will be written into the k3s.service file for the agent.
# === ADJUST THESE FOR YOUR TARGET WORKER NODE ===
WORKER_NODE_IP="192.168.56.49"
WORKER_NODE_NET_IF="eth0"
# ================================================

echo -e "${CYAN}Agent package will be configured for worker node:${NC}"
echo -e "${CYAN}  - IP: ${WORKER_NODE_IP}${NC}"
echo -e "${CYAN}  - Interface: ${WORKER_NODE_NET_IF}${NC}"

# Create directories for the package artifacts if they don't exist
# This assumes a structure like ../nxp-s32g/scripts relative to the script's location
PACKAGE_DIR="../nxp-s32g/scripts"
mkdir -p "$PACKAGE_DIR"

# 6.3. Prepare agent k3s.service template
cat <<EOF > "${PACKAGE_DIR}/k3s.service"
# This file is generated by k3s-master-prepare-v2.sh
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

# 6.4. Prepare containerd mirror configuration
# This configures the agent to use a local registry mirror.
# === ADJUST THE MIRROR IP IF NEEDED ===
REGISTRY_MIRROR_IP="192.168.56.2"
# ======================================
cat >"${PACKAGE_DIR}/registries.yaml" <<EOF
# This file is generated by k3s-master-prepare-v2.sh
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

# --- 7. FINAL SUMMARY ---
echo ""
echo -e "${GREEN}${BOLD}✓✓✓ K3s Master and Agent Package Setup Complete! ✓✓✓${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "${WHITE}Master Node Name:  ${BOLD}xip${NC}"
echo -e "${WHITE}Master IP:         ${BOLD}${SERVER_IP}${NC}"
echo -e "${WHITE}Agent Node Token:  (see below)${NC}"
echo -e "${BOLD}${NODE_TOKEN}${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "${YELLOW}1. Copy the contents of the '${PACKAGE_DIR}' directory to your worker node.${NC}"
echo -e "${YELLOW}2. Follow the worker node setup instructions.${NC}"
echo ""
