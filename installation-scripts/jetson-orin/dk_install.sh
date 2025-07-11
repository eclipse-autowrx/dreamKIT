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

# Global variables for progress tracking
TOTAL_STEPS=12
CURRENT_STEP=0

# Function to show animated banner
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════════╗
    ║                                                                          ║
    ║    ████████╗ ██████═╗ ███████╗  █████╗  ███╗   ███╗  ██████╗ ███████╗    ║
    ║    ██╔═══██║ ██╔══██║ ██╔════╝ ██╔══██╗ ████╗ ████║ ██╔═══██╗██╔════╝    ║
    ║    ██║   ██║ ██████╔╝ █████╗   ███████║ ██╔████╔██║ ██║   ██║███████╗    ║
    ║    ██║   ██║ ██╔══██╗ ██╔══╝   ██╔══██║ ██║╚██╔╝██║ ██║   ██║╚════██║    ║
    ║    ████████║ ██║  ██║ ███████╗ ██║  ██║ ██║ ╚═╝ ██║ ╚██████╔╝███████║    ║
    ║    ╚═══════╝ ╚═╝  ╚═╝ ╚══════╝ ╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═════╝ ╚══════╝    ║
    ║                                                                          ║
    ║                    Professional Installation Suite                       ║
    ║                          Version 2.0 - Next Gen                          ║
    ║                                                                          ║
    ╚══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Animated subtitle
    local subtitle="Initializing dreamOS installation environment..."
    echo -e "${CYAN}${DIM}"
    for ((i=0; i<${#subtitle}; i++)); do
        echo -n "${subtitle:$i:1}"
        sleep 0.03
    done
    echo -e "${NC}\n"
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}${BOLD}Progress: [${GREEN}"
    printf "%*s" $filled | tr ' ' '█'
    printf "${DIM}"
    printf "%*s" $empty | tr ' ' '░'
    printf "${BLUE}${BOLD}] %3d%% (%d/%d)${NC}" $percentage $current $total
}

# Function for animated spinner
spinner() {
    local pid=$1
    local message=$2
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${YELLOW}${SPINNER_FRAMES[i]} ${WHITE}%s${NC}" "$message"
        i=$(((i + 1) % ${#SPINNER_FRAMES[@]}))
        sleep 0.1
    done
    printf "\r"
}

# Function to show step header
show_step() {
    local step_num=$1
    local step_name=$2
    local description=$3
    
    CURRENT_STEP=$step_num
    echo -e "\n${BLUE}${BOLD}[$step_num/$TOTAL_STEPS] $step_name${NC}"
    echo -e "${DIM}$description${NC}"
    show_progress $CURRENT_STEP $TOTAL_STEPS
    echo
}

# Function to show success message
show_success() {
    local message=$1
    echo -e "${GREEN}${BOLD} ${CHECKMARK} ${message}${NC}"
}

# Function to show error message
show_error() {
    local message=$1
    echo -e "${RED}${BOLD} ${CROSS} ${message}${NC}"
}

# Function to show info message
show_info() {
    local message=$1
    echo -e "${BLUE} ${ARROW} ${message}${NC}"
}

# Function to show warning message
show_warning() {
    local message=$1
    echo -e "${YELLOW}${BOLD} ⚠ ${message}${NC}"
}

# Function for typing animation
type_text() {
    local text=$1
    local delay=${2:-0.02}
    echo -e "${WHITE}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep $delay
    done
    echo -e "${NC}"
}

# Function to run docker pull with detailed info
docker_pull_with_info() {
    local image=$1
    local description=$2
    local registry_info=$3
    
    echo -e "${CYAN}${BOLD}Downloading: ${WHITE}$image${NC}"
    echo -e "${DIM}Description: $description${NC}"
    echo -e "${DIM}Registry: $registry_info${NC}"
    echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"
    
    # Show docker pull output
    docker pull "$image" 2>&1 | while IFS= read -r line; do
        if [[ "$line" == *"Pulling"* ]]; then
            echo -e "${BLUE} → $line${NC}"
        elif [[ "$line" == *"Download complete"* ]]; then
            echo -e "${GREEN} ✓ $line${NC}"
        elif [[ "$line" == *"Pull complete"* ]]; then
            echo -e "${GREEN} ✓ $line${NC}"
        elif [[ "$line" == *"Status:"* ]]; then
            echo -e "${GREEN}${BOLD} $line${NC}"
        elif [[ "$line" == *"Error"* ]] || [[ "$line" == *"error"* ]]; then
            echo -e "${RED} ✗ $line${NC}"
        else
            echo -e "${DIM} $line${NC}"
        fi
    done
    
    # Get image size info
    local image_size=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep "$image" | awk '{print $2}' | head -1)
    if [ -n "$image_size" ]; then
        echo -e "${GREEN}${BOLD} ✓ Download completed - Image size: $image_size${NC}"
    else
        echo -e "${GREEN}${BOLD} ✓ Download completed${NC}"
    fi
    echo
}
run_with_feedback() {
    local command=$1
    local success_msg=$2
    local error_msg=$3
    local show_output=${4:-false}
    local needs_sudo=${5:-false}
    
    if [ "$show_output" = "true" ]; then
        echo -e "${DIM}${CYAN}Running: $command${NC}"
        if [ "$needs_sudo" = "true" ]; then
            echo -e "${YELLOW}[sudo] password for $DK_USER: ${NC}"
        fi
        if eval "$command"; then
            show_success "$success_msg"
            return 0
        else
            show_error "$error_msg"
            return 1
        fi
    else
        # For sudo commands, show password prompt clearly
        if [ "$needs_sudo" = "true" ]; then
            echo -e "${YELLOW}[sudo] password for $DK_USER: ${NC}"
            eval "$command" 2>&1 | while IFS= read -r line; do
                if [[ "$line" == *"password"* ]]; then
                    echo -e "\r${YELLOW}[sudo] password for $DK_USER: ${NC}"
                fi
            done
        else
            # Run command in background and show spinner
            eval "$command" >/dev/null 2>&1 &
            local cmd_pid=$!
            spinner $cmd_pid "Processing..."
            wait $cmd_pid
        fi
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            show_success "$success_msg"
            return 0
        else
            show_error "$error_msg"
            return 1
        fi
    fi
}

# Function to create fancy separator
separator() {
    echo -e "${DIM}$(printf '─%.0s' {1..50})${NC}"
}

# Main installation function
main() {
    # Show banner
    show_banner
    
    # Welcome message with animation
    echo -e "${CYAN}${BOLD}${DREAM} Welcome to the dreamOS Installation Experience! ${DREAM}${NC}\n"
    type_text "This installer will set up your complete dreamOS environment with all required components." 0.01
    echo -e "\n${YELLOW}${BOLD}${ROCKET} Ready to begin your journey? ${ROCKET}${NC}\n"
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Step 1: Environment Detection
    show_step 1 "Environment Detection" "Analyzing system configuration and user environment"
    
    # Determine the user who ran the command
    if [ -n "$SUDO_USER" ]; then
        DK_USER=$SUDO_USER
    else
        DK_USER=$USER
    fi
    show_info "Detected user: ${BOLD}$DK_USER${NC}"
    
    # Get the current install script path
    CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    show_info "Installation directory: ${BOLD}$CURRENT_DIR${NC}"
    
    # Detect architecture
    ARCH_DETECT=$(uname -m)
    if [[ "$ARCH_DETECT" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH_DETECT" == "aarch64" ]]; then
        ARCH="arm64"
    else
        ARCH="unknown"
    fi
    show_info "System architecture: ${BOLD}$ARCH${NC} (${ARCH_DETECT})"
    
    # Create the serial_number file, which will be referred by dk_manager, sdv-runtime, dk_ivi
    serial_file="/home/$DK_USER/.dk/dk_manager/serial-number"
    # Ensure the directory exists
    sudo mkdir -p "$(dirname "$serial_file")"
    # If the file doesn't exist or is empty, generate a random 16-character hex string
    if [[ ! -s "$serial_file" ]]; then
        serial_number=$(openssl rand -hex 8)  # 8 bytes = 16 hex chars
        echo "$serial_number" > "$serial_file"
    else
        serial_number=$(tail -n 1 "$serial_file")
    fi
    # Get last 8 characters (if the line is shorter, will print the whole line)
    RUNTIME_NAME="SDV-RUNTIME"

    sleep 1
    show_success "Environment detection completed"
    
    # Step 2: Docker Configuration
    show_step 2 "Docker Setup" "Configuring Docker environment and user permissions"
    
    # Check if docker group exists
    if getent group docker > /dev/null 2>&1; then
        show_info "Docker group already exists"
    else
        run_with_feedback "sudo groupadd docker" "Docker group created successfully" "Failed to create docker group" false true
    fi
    
    # Add user to docker group
    run_with_feedback "sudo usermod -aG docker '$DK_USER'" "User '$DK_USER' added to docker group" "Failed to add user to docker group" false true
    show_warning "Please log out and back in for group changes to take effect"
    
    # Step 3: System Architecture & Runtime
    show_step 3 "Runtime Configuration" "Setting up XDG runtime and audio parameters"
    
    # Get XDG_RUNTIME_DIR
    XDG_RUNTIME_DIR=$(sudo -u "$DK_USER" env | grep XDG_RUNTIME_DIR | cut -d= -f2)
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u "$DK_USER")"
    fi
    show_info "XDG Runtime Directory: ${BOLD}$XDG_RUNTIME_DIR${NC}"
    
    # Set environment variables
    HOME_DIR="/home/$DK_USER"
    DOCKER_SHARE_PARAM="-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker"
    DOCKER_AUDIO_PARAM="--device /dev/snd --group-add audio -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native -v $HOME_DIR/.config/pulse/cookie:/root/.config/pulse/cookie"
    LOG_LIMIT_PARAM="--log-opt max-size=10m --log-opt max-file=3"
    DOCKER_HUB_NAMESPACE="ghcr.io/eclipse-autowrx"
    DOCKER_HUB_NAMESPACE1="danh22"
    
    show_success "Runtime configuration completed"
    
    # Step 4: Directory Structure
    show_step 4 "Directory Structure" "Creating dreamOS directory hierarchy"
    
    run_with_feedback "mkdir -p /home/$DK_USER/.dk/dk_swupdate /home/$DK_USER/.dk/dk_swupdate/dk_patch /home/$DK_USER/.dk/dk_swupdate/dk_current /home/$DK_USER/.dk/dk_swupdate/dk_current_patch" "Directory structure created successfully" "Failed to create directory structure"
    
    # Step 5: Network Setup
    show_step 5 "Network Setup" "Establishing Docker network infrastructure"
    
    run_with_feedback "docker network create dk_network 2>/dev/null || true" "Docker network 'dk_network' ready" "Network setup encountered issues"
    
    # Step 6: Dependencies Installation
    show_step 6 "Dependencies" "Installing required system utilities"
    
    if command -v git >/dev/null 2>&1; then
        show_info "Git is already installed"
    else
        show_info "Installing Git..."
        run_with_feedback "sudo apt-get update && sudo apt-get install -y git" "Git installed successfully" "Failed to install Git" true true
    fi
    
    # Step 7: KUKSA Client
    show_step 7 "KUKSA Client" "Downloading vehicle signal specification client"
    
    docker_pull_with_info "ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2" \
        "Eclipse KUKSA VAL client for vehicle signal access and testing" \
        "GitHub Container Registry (Eclipse Foundation)"
    
    # Step 8: SDV Runtime
    # show_step 8 "SDV Runtime" "Setting up Software Defined Vehicle runtime environment"
    
    # docker_pull_with_info "$DOCKER_HUB_NAMESPACE/sdv-runtime:latest" \
    #     "Eclipse AutoWrx SDV runtime for vehicle application management" \
    #     "GitHub Container Registry (Eclipse AutoWrx Project)"
    
    # show_info "Configuring SDV runtime container..."
    # show_info "RUNTIME_NAME: $RUNTIME_NAME"
    # run_with_feedback "docker stop sdv-runtime 2>/dev/null || true; docker rm sdv-runtime 2>/dev/null || true" "Cleaned up existing SDV runtime" "Cleanup warning"
    # run_with_feedback "docker run -d -it --name sdv-runtime --restart unless-stopped -e USER=$DK_USER -e RUNTIME_NAME=$RUNTIME_NAME -e DK_VIP=192.168.88.26 -e ARCH=$ARCH $DOCKER_HUB_NAMESPACE/sdv-runtime:latest" "SDV runtime container started on port 55555" "Failed to start SDV runtime"
    
    # Step 9: DreamKit Manager
    show_step 9 "DreamKit Manager" "Installing core management services"
    
    docker_pull_with_info "$DOCKER_HUB_NAMESPACE/dk_manager:latest" \
        "DreamOS core manager for system orchestration and service management" \
        "GitHub Container Registry (DreamOS Project)"
    
    show_info "Configuring DreamKit manager container..."
    run_with_feedback "docker stop dk_manager 2>/dev/null || true; docker rm dk_manager 2>/dev/null || true" "Cleaned up existing manager" "Manager cleanup"
    run_with_feedback "docker run -d -it --name dk_manager $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk --restart unless-stopped -e USER=$DK_USER -e DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE -e ARCH=$ARCH $DOCKER_HUB_NAMESPACE/dk_manager:latest" "DreamKit manager started with Docker socket access" "Failed to start manager"

    # Step 10: App Installation Service
    show_step 10 "App Services" "Installing application management services"

    docker_pull_with_info "$DOCKER_HUB_NAMESPACE/dk_appinstallservice:latest" \
        "DreamOS application installation and lifecycle management service" \
        "GitHub Container Registry (DreamOS Project)"
    
    # Step 11: Docker local registry (Optional)
    show_step 11 "Docker local registry" "VIP installation"
    dk_vip_demo="false"
    echo -e "\n${YELLOW}Do you want to continue? [y/N]: ${NC}"
    read -r install_dockerlocalregistry_choice
    
    if [[ "$install_dockerlocalregistry_choice" =~ ^[Yy]$ ]]; then
        dk_vip_demo="true"
        show_info "Setup local registry..."
        run_with_feedback "$CURRENT_DIR/scripts/setup_local_docker_registry.sh" "Docker local host enabled" "Docker local setup failed"
    fi

    # Step 12: IVI Interface (Optional)
    show_step 12 "IVI Interface" "Configuring In-Vehicle Infotainment system"
    
    # Check for dk_ivi parameter
    dk_ivi_value=""
    for arg in "$@"; do
        if [[ "$arg" == dk_ivi=* ]]; then
            dk_ivi_value="${arg#*=}"
        fi
    done
    
    if [[ "$dk_ivi_value" == "true" ]]; then
        show_info "Installing IVI interface..."
        run_with_feedback "$CURRENT_DIR/scripts/dk_enable_xhost.sh" "X11 forwarding enabled" "X11 setup failed"
        run_with_feedback "docker pull $DOCKER_HUB_NAMESPACE/dk_ivi:latest" "IVI image downloaded" "Failed to download IVI"
        run_with_feedback "xhost +local:docker" "Docker X11 access granted" "X11 access failed"
        
        if [ -f "/etc/nv_tegra_release" ]; then
            show_info "NVIDIA Jetson board detected - optimizing for hardware"
            run_with_feedback "docker stop dk_ivi 2>/dev/null || true; docker rm dk_ivi 2>/dev/null || true; 
            docker run -d -it --net=host -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR -e QT_QUICK_BACKEND=software --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_VIP=$dk_vip_demo -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE1 -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT=\"/app/.dk/\" $DOCKER_HUB_NAMESPACE1/dk_ivi:latest" "IVI started (NVIDIA optimized)" "Failed to start IVI"
        else
            show_info "Standard hardware detected - using generic configuration"
            run_with_feedback "docker stop dk_ivi 2>/dev/null || true; docker rm dk_ivi 2>/dev/null || true; 
            docker run -d -it --net=host -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR --device /dev/dri:/dev/dri --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_VIP=$dk_vip_demo -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE1 -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT=\"/app/.dk/\" $DOCKER_HUB_NAMESPACE1/dk_ivi:latest" "IVI started (standard)" "Failed to start IVI"
        fi
    else
        show_info "IVI installation skipped"
        echo -e "\n${CYAN}The In-Vehicle Infotainment (IVI) interface provides a graphical user interface"
        echo -e "for vehicle dashboard and entertainment features.${NC}"
        echo -e "\n${YELLOW}Would you like to install the IVI interface now? [y/N]: ${NC}"
        read -r install_ivi_choice
        
        if [[ "$install_ivi_choice" =~ ^[Yy]$ ]]; then
            echo -e "\n${GREEN}Installing IVI interface...${NC}"
            run_with_feedback "$CURRENT_DIR/scripts/dk_enable_xhost.sh" "X11 forwarding enabled" "X11 setup failed"
            run_with_feedback "docker pull $DOCKER_HUB_NAMESPACE/dk_ivi:latest" "IVI image downloaded" "Failed to download IVI"
            run_with_feedback "xhost +local:docker" "Docker X11 access granted" "X11 access failed"
            
            if [ -f "/etc/nv_tegra_release" ]; then
                show_info "NVIDIA Jetson board detected - optimizing for hardware"
                run_with_feedback "docker stop dk_ivi 2>/dev/null || true; docker rm dk_ivi 2>/dev/null || true; 
                docker run -d -it --net=host -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR -e QT_QUICK_BACKEND=software --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_VIP=$dk_vip_demo -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE1 -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT=\"/app/.dk/\" $DOCKER_HUB_NAMESPACE1/dk_ivi:latest" "IVI started (NVIDIA optimized)" "Failed to start IVI"
            else
                show_info "Standard hardware detected - using generic configuration"
                run_with_feedback "docker stop dk_ivi 2>/dev/null || true; docker rm dk_ivi 2>/dev/null || true; 
                docker run -d -it --net=host -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=$DISPLAY -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR --device /dev/dri:/dev/dri --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_VIP=$dk_vip_demo -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE1 -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT=\"/app/.dk/\" $DOCKER_HUB_NAMESPACE1/dk_ivi:latest" "IVI started (standard)" "Failed to start IVI"
            fi
            # Update the environment variable to reflect the installation
            dk_ivi_value="true"
        else
            show_info "IVI installation skipped (you can install later with './dk_install dk_ivi=true')"
        fi
    fi
    
    # Final steps
    separator
    echo -e "\n${BLUE}${BOLD}Finalizing installation...${NC}\n"
    
    # Save environment variables
    show_info "Saving environment configuration..."
    mkdir -p $HOME_DIR/.dk/dk_swupdate
    DK_ENV_FILE="$HOME_DIR/.dk/dk_swupdate/dk_swupdate_env.sh"
    cat <<EOF > "${DK_ENV_FILE}"
#!/bin/bash

DK_USER="${DK_USER}"
ARCH="${ARCH}"
HOME_DIR="${HOME_DIR}"
DOCKER_SHARE_PARAM="${DOCKER_SHARE_PARAM}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
DOCKER_AUDIO_PARAM="${DOCKER_AUDIO_PARAM}"
LOG_LIMIT_PARAM="${LOG_LIMIT_PARAM}"
DOCKER_HUB_NAMESPACE="${DOCKER_HUB_NAMESPACE}"
dk_ivi_value="${dk_ivi_value}"
EOF
    chmod +x "${DK_ENV_FILE}"
    
    # Create additional services
    run_with_feedback "$CURRENT_DIR/scripts/create_dk_xiphost_service.sh" "Additional services configured" "Service configuration warning"
    
    # Cleanup
    show_info "Cleaning up temporary files..."
    run_with_feedback "docker image prune -f" "Docker cleanup completed" "Cleanup warning"
    
    # Success message
    echo -e "\n${GREEN}${BOLD}Installation completed successfully!${NC}\n"
    
    # Installation summary
    echo -e "${CYAN}${BOLD}Installation Summary:${NC}"
    echo -e "${GREEN} ${CHECKMARK} Environment configured for user: ${BOLD}$DK_USER${NC}"
    echo -e "${GREEN} ${CHECKMARK} System architecture: ${BOLD}$ARCH${NC}"
    echo -e "${GREEN} ${CHECKMARK} Docker environment ready${NC}"
    echo -e "${GREEN} ${CHECKMARK} All core services installed${NC}"
    echo -e "${GREEN} ${CHECKMARK} Network infrastructure ready${NC}"
    if [[ "$dk_ivi_value" == "true" ]]; then
        echo -e "${GREEN} ${CHECKMARK} IVI interface installed${NC}"
    fi
    
    echo -e "\n${YELLOW}${BOLD}Important:${NC}"
    echo -e " • Please reboot your system for all changes to take effect"
    echo -e " • Log out and back in to apply Docker group permissions"
    echo -e " • Your dreamOS environment will be ready after reboot"
    
    if [[ "$dk_ivi_value" == "true" ]]; then
        echo -e "\n${CYAN}${BOLD}To start the IVI interface:${NC}"
        echo -e "${WHITE} • Run: ${CYAN}./dk_run.sh${NC}"
        echo -e "${DIM} • This will launch the In-Vehicle Infotainment dashboard${NC}"
    fi
    
    echo -e "\n${GREEN}Thank you for choosing dreamOS!${NC}"
}

# Run main function
main "$@"
