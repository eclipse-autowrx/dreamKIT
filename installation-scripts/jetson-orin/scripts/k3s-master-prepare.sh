#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# K3s Agent Server: Setup and prepare offline agent install package for amd64 and arm64 workers
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
    echo -e "${YELLOW}${BOLD}Could not find an IP address on interface '$SERVER_NET_IF'. Please check your network interface.${NC}"
    exit 1
fi

# 1. Install k3s server (if not already installed)
if ! command -v k3s &> /dev/null; then
    echo -e "${BLUE} ${ARROW} Installing K3s server...${NC}"
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-name=xip --advertise-address ${SERVER_IP} --tls-san ${SERVER_IP}" sh -
else
    echo -e "${BLUE} ${ARROW} K3s server is already installed.${NC}"
fi

# 2.a) Change kubeconfig file permissions
sudo chown $USER:$USER /etc/rancher/k3s/k3s.yaml
# sudo chmod 644 /etc/rancher/k3s/k3s.yaml
# 2.b) For regular user access, copy the kubeconfig file
sudo mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# 3. for offline scenario
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml << EOF
write-kubeconfig-mode: "0644"
# Minimal configuration for offline stability
disable-network-policy: true
disable-cloud-controller: true
flannel-backend: "host-gw"
kubelet-arg:
  - "max-pods=50"
  - "eviction-hard=memory.available<100Mi"
disable:
  - traefik
  - metrics-server
  - local-storage
# Don't specify node-ip or flannel-iface - let k3s auto-detect
EOF

# 4. Extract node token and server IP (from the provided interface)
NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

echo -e "${BLUE} ${ARROW} Server IP ($SERVER_NET_IF): $SERVER_IP.${NC}"
echo -e "${BLUE} ${ARROW} Node Token: $NODE_TOKEN.${NC}"

# 5. Download K3s binaries for both amd64 and arm64
sudo kubectl delete -f manifests/k3s-rancher-mirrored-pause-mirror.yaml --ignore-not-found
sudo kubectl apply -f manifests/k3s-rancher-mirrored-pause-mirror.yaml

# === ADJUST THESE ===  
NODE_IP="192.168.56.49"  
NODE_NET_IF="eth0"
# ====================
echo -e "${BLUE} ${ARROW} Prepare package for S32G with IP ($NODE_NET_IF): $NODE_IP.${NC}"


# 6. Prepare agent service template (with placeholders)
cat <<EOF > ../nxp-s32g/scripts/k3s.service

# Derived from the k3s install.sh's create_systemd_service_file() function
[Unit]
Description=Lightweight Kubernetes
Documentation=https://k3s.io
Requires=containerd.service
After=containerd.service
After=network-online.target
Wants=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-/etc/systemd/system/k3s.service.env
KillMode=process
Delegate=yes
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! systemctl is-enabled --quiet nm-cloud-setup.service'
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStartPre=-/sbin/modprobe overlay
# ExecStart=/usr/local/bin/k3s server
ExecStart=/usr/local/bin/k3s agent \\
  --server https://${SERVER_IP}:6443 \\
  --token ${NODE_TOKEN} \\
  --node-name=vip \\
  --node-ip ${NODE_IP} \\
  --flannel-iface ${NODE_NET_IF} \\
  --kubelet-arg="allowed-unsafe-sysctls=net.ipv4.ip_forward"

# Avoid any delay due to this service when the system is rebooting or shutting
# down by using the k3s-killall.sh script to kill all of the running k3s
# services and containers
ExecStopPost=/bin/sh -c "if systemctl is-system-running | grep -i \
                           'stopping'; then /usr/local/bin/k3s-killall.sh; fi"
EOF


# 7) Configure containerd as a Mirror
# With that in place, any Pod spec referring to ghcr.io/... will first try your local mirror at 192.168.56.48:5000, then fall back to the real ghcr.io if the mirror is missing.
# You still must push the image to your local registry once (same docker pull / tag / push steps above), but future pulls even using the original ghcr.io/... name will come from your local mirror.
cat >../nxp-s32g/scripts/registries.yaml <<EOF
mirrors:
  "docker.io":
    endpoint:
      - "http://192.168.56.48:5000"
  "ghcr.io":
    endpoint:
      - "http://192.168.56.48:5000"
configs:
  "192.168.56.48:5000":
    tls:
      insecure_skip_verify: true
EOF
