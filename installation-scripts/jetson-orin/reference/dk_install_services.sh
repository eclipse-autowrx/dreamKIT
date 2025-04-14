#!/bin/bash

# Determine the user who ran the command
if [ -n "$SUDO_USER" ]; then
    # Command was run with sudo
    DK_USER=$SUDO_USER
else
    # Command was not run with sudo, fall back to current user
    DK_USER=$USER
fi

# Get the current directory path
CURRENT_DIR=$(pwd)

# Detect the system architecture
ARCH_DETECT=$(uname -m)
# Set ARCH variable based on the detected architecture
if [[ "$ARCH_DETECT" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH_DETECT" == "aarch64" ]]; then
    ARCH="arm64"
else
    ARCH="unknown"
fi

# Set Env Variables
HOME_DIR="/home/$DK_USER"
DOCKER_SHARE_PARAM="-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker"
DOCKER_AUDIO_PARAM="--device /dev/snd --group-add audio -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native -v $HOME_DIR/.config/pulse/cookie:/root/.config/pulse/cookie"
LOG_LIMIT_PARAM="--log-opt max-size=10m --log-opt max-file=3"
DOCKER_HUB_NAMESPACE="phongbosch"


echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "ARCH: $ARCH"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_SHARE_PARAM: $DOCKER_SHARE_PARAM"
echo "DOCKER_AUDIO_PARAM: $DOCKER_AUDIO_PARAM"
echo "LOG_LIMIT_PARAM: $LOG_LIMIT_PARAM"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"

# Install dk_service_coffee
dk_service_coffee=""
# Loop through all input arguments
for arg in "$@"; do
    if [[ "$arg" == dk_service_coffee=* ]]; then
        # Extract the value after the equal sign
        dk_service_coffee="${arg#*=}"
    fi
done
if [[ "$dk_service_coffee" == "true" ]]; then
    docker pull $DOCKER_HUB_NAMESPACE/dk_service_coffee:latest
    docker stop dk_service_coffee;docker rm dk_service_coffee;docker run -d -it --name dk_service_coffee --network host --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_HUB_NAMESPACE/dk_service_coffee:latest
else
    echo "To Install dk_service_coffee, run './dk_install_services dk_service_coffee=true'"
fi

# Install dk_service_tts
dk_service_tts=""
# Loop through all input arguments
for arg in "$@"; do
    if [[ "$arg" == dk_service_tts=* ]]; then
        # Extract the value after the equal sign
        dk_service_tts="${arg#*=}"
    fi
done
if [[ "$dk_service_tts" == "true" ]]; then
    docker pull $DOCKER_HUB_NAMESPACE/dk_service_tts:latest
    docker stop dk_service_tts;docker rm dk_service_tts; docker run -d -it --name dk_service_tts --network dk_network --restart unless-stopped $DOCKER_AUDIO_PARAM $LOG_LIMIT_PARAM $DOCKER_HUB_NAMESPACE/dk_service_tts:latest
else
    echo "To Install dk_service_tts, run './dk_install_services dk_service_tts=true'"
fi

