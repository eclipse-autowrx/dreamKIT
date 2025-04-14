#!/bin/bash

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
DOCKER_HUB_NAMESPACE="phongbosch"
DK_CONTAINER_LIST="dk_manager dk_ivi dk_vssgen vehicledatabroker"

echo "Env Variables:"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"


echo "Stopping all running containers..."
docker stop $(docker ps -q)

echo "Removing all stopped Docker containers..."
docker rm $(docker ps -aq)

echo "Delete dk data..."
rm -rf /home/$DK_USER/.dk

echo "Delete base image for velocitas app..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_app_python_template:baseimage

echo "Delete dk_manager image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_manager:latest

echo "Delete vssgen image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_vssgeneration_image:vss4.0

echo "Delete dk_ivi image ..."
docker rmi -f $DOCKER_HUB_NAMESPACE/dk_ivi:latest

echo "Delete vehicledatabroker image ..."
docker rmi -f ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4

echo "Remove network ..."
docker network rm dk_network
