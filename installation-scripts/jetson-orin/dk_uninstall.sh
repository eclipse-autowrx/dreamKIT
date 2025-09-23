#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT


# Determine the user who ran the command
if [ -n "$SUDO_USER" ]; then
    # Command was run with sudo
    DK_USER=$SUDO_USER
else
    # Command was not run with sudo, fall back to current user
    DK_USER=$USER
fi
echo "username: $DK_USER"

# Set Env Variables
HOME_DIR="/home/$DK_USER"
DOCKER_HUB_NAMESPACE="ghcr.io/eclipse-autowrx"
DK_CONTAINER_LIST="dk_manager dk_ivi sdv-runtime dk_appinstallservice"

echo "Env Variables:"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"

k3s-killall.sh
k3s-uninstall.sh
scripts/k3s-uninstall.sh

# Also remove the custom files created by the script
sudo rm -rf /etc/systemd/system/k3s.service.d
sudo rm -f /etc/systemd/system/k3s-network-prep.service
sudo rm -f /usr/local/bin/k3s-network-prep.sh
# Reload systemd
sudo systemctl daemon-reload

echo "Stopping all running containers..."
docker kill $(docker ps -q)

echo "Removing all stopped Docker containers..."
docker rm $(docker ps -aq)

echo "Delete dk data..."
rm -rf /home/$DK_USER/.dk

echo "Delete dk_manager image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_manager:latest

echo "Delete dk_ivi image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_ivi:latest

echo "Delete sdv-runtime image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/sdv-runtime:latest

echo "Delete App/service installation service image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_appinstallservice

echo "Remove network ..."
docker network rm dk_network
