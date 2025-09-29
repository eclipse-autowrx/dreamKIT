#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
#
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# K3s Agent Offline Installation - Generic Device Support
# Usage:
#   ./k3s-agent-offline-install.sh [target_ip] [target_user] [target_password]
#   sudo ./k3s-agent-offline-install.sh [target_ip] [target_user] [target_password]
# Examples:
#   ./k3s-agent-offline-install.sh 192.168.56.49 root ""
#   sudo DK_USER="myuser" ./k3s-agent-offline-install.sh 192.168.56.49 root ""

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

set -e # Exit immediately if a command exits with a non-zero status.

# --- SCRIPT SETUP AND VALIDATION ---
# Parse command line arguments with defaults
TARGET_IP="${1:-192.168.56.49}"
TARGET_USER="${2:-root}"
TARGET_PASSWORD="${3:-}"

echo -e "${BLUE}${BOLD}K3s Agent Offline Installation${NC}"
echo -e "${BLUE}Target: ${TARGET_USER}@${TARGET_IP}${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"

# Auto-detect the local user if running directly (not via sudo)
if [ "$EUID" -eq 0 ] && [ -z "$SUDO_USER" ] && [ -z "$DK_USER" ]; then
    echo -e "${YELLOW}${BOLD}Warning: Running directly as root. Consider running as regular user or via sudo.${NC}"
fi

# Auto-detect the target user for local operations
if [ -z "$DK_USER" ]; then
    if [ -n "$SUDO_USER" ]; then
        DK_USER="$SUDO_USER"
        echo -e "${BLUE}Auto-detected local user from sudo: $DK_USER${NC}"
    elif [ "$EUID" -ne 0 ]; then
        DK_USER="$(whoami)"
        echo -e "${BLUE}Auto-detected current user: $DK_USER${NC}"
        # If not root, we need to escalate for certain operations
        if ! sudo -n true 2>/dev/null; then
            echo -e "${YELLOW}This script requires sudo privileges for kubectl operations.${NC}"
            echo -e "${YELLOW}Please run with sudo or ensure passwordless sudo is configured.${NC}"
            exit 1
        fi
    else
        DK_USER="root"
        echo -e "${BLUE}Running as root user${NC}"
    fi
else
    echo -e "${BLUE}Using explicitly provided local user: $DK_USER${NC}"
fi

# Determine the user's home directory
if [ "$DK_USER" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME=$(eval echo ~$DK_USER)
fi

echo -e "${BLUE}Local user home directory: $USER_HOME${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"

# Remove host key from known_hosts to avoid conflicts
echo -e "${BLUE}Cleaning SSH known_hosts...${NC}"
if [ "$EUID" -eq 0 ] || [ "$DK_USER" = "root" ]; then
    ssh-keygen -f "/root/.ssh/known_hosts" -R "$TARGET_IP" 2>/dev/null || true
fi

if [ -f "$USER_HOME/.ssh/known_hosts" ]; then
    if [ "$EUID" -eq 0 ] && [ "$DK_USER" != "root" ]; then
        sudo -u "$DK_USER" ssh-keygen -f "$USER_HOME/.ssh/known_hosts" -R "$TARGET_IP" 2>/dev/null || true
    else
        ssh-keygen -f "$USER_HOME/.ssh/known_hosts" -R "$TARGET_IP" 2>/dev/null || true
    fi

    # Ensure known_hosts file has correct ownership
    if [ "$(stat -c %U $USER_HOME/.ssh/known_hosts 2>/dev/null)" = "root" ] && [ "$DK_USER" != "root" ]; then
        sudo chown "$DK_USER:$DK_USER" "$USER_HOME/.ssh/known_hosts"
    fi
fi

# --- REMOTE INSTALLATION ---
echo -e "${BLUE}Starting remote installation on ${TARGET_USER}@${TARGET_IP}...${NC}"

# Check if sshpass is available
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Error: sshpass is required but not installed.${NC}"
    echo -e "${YELLOW}Please install sshpass: sudo apt-get install sshpass${NC}"
    exit 1
fi

# Build SSH command prefix
if [ -n "$TARGET_PASSWORD" ]; then
    SSH_CMD="sshpass -p '$TARGET_PASSWORD' ssh -o StrictHostKeyChecking=no"
    SCP_CMD="sshpass -p '$TARGET_PASSWORD' scp"
else
    SSH_CMD="ssh -o StrictHostKeyChecking=no"
    SCP_CMD="scp"
fi

echo -e "${BLUE}Creating remote directory structure...${NC}"
$SSH_CMD "$TARGET_USER@$TARGET_IP" 'mkdir -p ~/.dk/'

echo -e "${BLUE}Copying installation files...${NC}"
$SCP_CMD -r ../nxp-s32g "$TARGET_USER@$TARGET_IP":~/.dk/

echo -e "${BLUE}Setting execute permissions...${NC}"
$SSH_CMD "$TARGET_USER@$TARGET_IP" 'chmod +x ~/.dk/nxp-s32g/'
$SSH_CMD "$TARGET_USER@$TARGET_IP" 'chmod +x ~/.dk/nxp-s32g/scripts'
$SSH_CMD "$TARGET_USER@$TARGET_IP" 'chmod +x ~/.dk/nxp-s32g/dk_install.sh'

echo -e "${BLUE}Running installation script on remote device...${NC}"
$SSH_CMD "$TARGET_USER@$TARGET_IP" '~/.dk/nxp-s32g/dk_install.sh'

echo -e "${YELLOW}Rebooting remote device...${NC}"
$SSH_CMD "$TARGET_USER@$TARGET_IP" 'reboot' || echo -e "${CYAN}Remote device is rebooting (connection lost as expected)${NC}"

# --- LOCAL KUBERNETES CLEANUP ---
echo -e "${BLUE}Cleaning up old node registration...${NC}"
# Delete the node for new one connected
if [ "$EUID" -eq 0 ] || [ "$DK_USER" = "root" ]; then
    kubectl delete node vip --ignore-not-found || echo -e "${YELLOW}Note: Could not delete node 'vip' (may not exist)${NC}"
else
    sudo kubectl delete node vip --ignore-not-found || echo -e "${YELLOW}Note: Could not delete node 'vip' (may not exist)${NC}"
fi

echo -e "${GREEN}${BOLD}✓ Agent installation completed!${NC}"
echo -e "${CYAN}The remote device is rebooting and should join the cluster automatically.${NC}"
echo -e "${CYAN}Monitor with: kubectl get nodes${NC}"
