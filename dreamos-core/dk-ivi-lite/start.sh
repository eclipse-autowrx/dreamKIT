#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

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

# Unicode symbols
CHECKMARK="✓"
CROSS="✗"
ARROW="→"
STAR="★"
GEAR="⚙"
ROCKET="🚀"
DREAM="💭"

# Animation frames
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
PROGRESS_CHARS=("▱" "▰")

# Function to show info message
show_info() {
    local message=$1
    echo -e "${YELLOW} ${ARROW} ${message}${NC}"
}

show_info "Running dk_ivi Docker container..."
show_info "Ensure you have built the dk_ivi Docker image first by running build.sh."
show_info "This script will start the dk_ivi container with the necessary configurations."
show_info "You can customize the environment variables and volume mounts as needed."
show_info "The container will run in detached mode and will restart unless stopped."
show_info "To access the container, you can use the command: docker exec -it dk_ivi /bin/bash"
show_info "Make sure to have Docker installed and running on your system."
show_info "You can also modify the run.sh script to fit your environment and requirements."
show_info "For debugging, you can run command ""k9s --kubeconfig ~/.kube/config"""


# export DKCODE="dreamKIT"
# export DK_USER=$USER
# export DK_DOCKER_HUB_NAMESPACE="ghcr.io/samtranbosch"
# export DK_ARCH="amd64"
# export DK_CONTAINER_ROOT="/app/.dk/"
# export DK_VIP="true"
# export DK_VSS_VER="VSS_4.0"
# export KUBECONFIG=$HOME/.kube/config

# docker kill dk_ivi; docker rm dk_ivi ;

# docker run -d -it --name dk_ivi \
#     --network host --restart unless-stopped \
#     --device /dev/dri:/dev/dri \
#     -e DISPLAY=:0 -e DK_USER=$DK_USER -e DK_ARCH=$DK_ARCH \
#     -e DK_DOCKER_HUB_NAMESPACE=$DK_DOCKER_HUB_NAMESPACE -e DK_VIP=$DK_VIP -e DK_CONTAINER_ROOT=$DK_CONTAINER_ROOT -e DKCODE=dreamKIT\
#     -v /tmp/.X11-unix:/tmp/.X11-unix \
#     -v ~/.dk:/app/.dk \
#     -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker \
#     -v /usr/local/bin/kubectl:/usr/local/bin/kubectl:ro -v $KUBECONFIG:/root/.kube/config:ro \
#     dk_ivi:latest

kubectl delete deployment.apps/dk-ivi --ignore-not-found

docker save dk_ivi:latest > dk_ivi.tar
sudo k3s ctr images import dk_ivi.tar
rm dk_ivi.tar

kubectl apply -f manifests/dk-ivi.yaml
