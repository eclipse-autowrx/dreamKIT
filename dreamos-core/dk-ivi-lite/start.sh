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


# Detect environment and set variables
detect_environment() {
    show_info "Detecting environment configuration..."

    # Detect architecture
    local arch=$(uname -m)
    case $arch in
        x86_64)
            export ARCH="amd64"
            ;;
        aarch64|arm64)
            export ARCH="arm64"
            ;;
        *)
            show_info "Unknown architecture: $arch, defaulting to amd64"
            export ARCH="amd64"
            ;;
    esac

    # Detect user and home directory based on existing users
    if id "sdv-orin" &>/dev/null; then
        export DK_USER="sdv-orin"
        export HOME_DIR="/home/sdv-orin"
        show_info "Detected Jetson environment (user: sdv-orin, arch: $ARCH)"
    elif id "developer" &>/dev/null; then
        export DK_USER="developer"
        export HOME_DIR="/home/developer"
        show_info "Detected development environment (user: developer, arch: $ARCH)"
    else
        export DK_USER=$USER
        export HOME_DIR=$HOME
        show_info "Using current user environment (user: $DK_USER, arch: $ARCH)"
    fi

    # Set other environment variables
    export DKCODE="dreamKIT"
    # export DOCKER_HUB_NAMESPACE="ghcr.io/eclipse-autowrx"
    export DOCKER_HUB_NAMESPACE="docker.io/library"
    export DK_CONTAINER_ROOT="/app/.dk/"
    export DK_VIP=""
    export DISPLAY="${DISPLAY:-:0}"
    export XDG_RUNTIME_DIR=$(sudo -u "$DK_USER" env | grep XDG_RUNTIME_DIR | cut -d= -f2)

    show_info "Environment variables set:"
    show_info "  DK_USER: $DK_USER"
    show_info "  HOME_DIR: $HOME_DIR"
    show_info "  ARCH: $ARCH"
    show_info "  DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"
    show_info "  DISPLAY: $DISPLAY"
    show_info "  XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
}

# Apply manifest with environment variable substitution
apply_manifest() {
    show_info "Applying manifest with environment substitution..."

    # Create temporary manifest with substituted variables
    local temp_manifest=$(mktemp)
    envsubst < manifests/dk-ivi.yaml > "$temp_manifest"

    kubectl apply -f "$temp_manifest"
    rm "$temp_manifest"
}

# Detect environment
detect_environment

kubectl delete deployment.apps/dk-ivi --ignore-not-found

docker save dk_ivi:latest > dk_ivi.tar
sudo k3s ctr images import dk_ivi.tar
rm dk_ivi.tar

apply_manifest
