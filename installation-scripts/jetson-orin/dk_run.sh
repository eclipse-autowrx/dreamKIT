# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/bash

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
WARNING="⚠"
GEAR="⚙"
ROCKET="🚀"
DREAM="💭"

# Global variables
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE=""

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
    echo -e "${YELLOW}${BOLD} ${WARNING} ${message}${NC}"
}

# Function to show banner
show_banner() {
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║                  dreamOS Runtime Manager                             ║
    ║                     Quick Service Launcher                           ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${DREAM} ${CYAN}Starting dreamOS services...${NC}\n"
}

# Function to load environment variables
load_environment() {
    show_info "Loading dreamOS environment configuration..."
    
    # Determine the user who ran the command
    if [ -n "$SUDO_USER" ]; then
        DK_USER=$SUDO_USER
    else
        DK_USER=$USER
    fi
    
    # Look for environment file
    ENV_FILE="/home/$DK_USER/.dk/dk_swupdate/dk_swupdate_env.sh"
    
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        show_success "Environment loaded from $ENV_FILE"
        show_info "User: ${BOLD}$DK_USER${NC}, Architecture: ${BOLD}$ARCH${NC}"
        return 0
    else
        show_error "Environment file not found at $ENV_FILE"
        return 1
    fi
}

# Function to check if required Docker images are available
check_docker_images() {
    show_info "Checking required Docker images..."
    
    local required_images=(
        "ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2"
        "ghcr.io/eclipse-autowrx/sdv-runtime:latest"
        "ghcr.io/samtranbosch/dk_manager:latest"
        "ghcr.io/samtranbosch/dk_appinstallservice:latest"
    )
    
    local missing_images=()
    
    for image in "${required_images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
            show_success "Found: $image"
        else
            show_warning "Missing: $image"
            missing_images+=("$image")
        fi
    done
    
    if [ ${#missing_images[@]} -eq 0 ]; then
        show_success "All required Docker images are available"
        return 0
    else
        show_error "Missing ${#missing_images[@]} required Docker images"
        return 1
    fi
}

# Function to check if core services are running
check_core_services() {
    show_info "Checking core dreamOS services..."
    
    local services=("sdv-runtime" "dk_manager")
    local stopped_services=()
    
    for service in "${services[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^$service$"; then
            show_success "Running: $service"
        else
            show_warning "Stopped: $service"
            stopped_services+=("$service")
        fi
    done
    
    if [ ${#stopped_services[@]} -eq 0 ]; then
        show_success "All core services are running"
        return 0
    else
        show_warning "${#stopped_services[@]} core services are not running"
        return 1
    fi
}

# Function to start core services if needed
start_core_services() {
    show_info "Starting core dreamOS services..."
    
    # Start SDV Runtime if not running
    if ! docker ps --format "{{.Names}}" | grep -q "^sdv-runtime$"; then
        show_info "Starting SDV Runtime..."
        docker start sdv-runtime >/dev/null 2>&1 || {
            show_info "Creating new SDV Runtime container..."
            docker run -d -it --name sdv-runtime --restart unless-stopped \
                -e USER="$DK_USER" \
                -e RUNTIME_NAME="DreamKIT_BGSV" \
                -p 55555:55555 \
                -e ARCH="$ARCH" \
                ghcr.io/eclipse-autowrx/sdv-runtime:latest >/dev/null 2>&1
        }
        show_success "SDV Runtime started"
    fi
    
    # Start DK Manager if not running
    if ! docker ps --format "{{.Names}}" | grep -q "^dk_manager$"; then
        show_info "Starting DreamKit Manager..."
        docker start dk_manager >/dev/null 2>&1 || {
            show_info "Creating new DreamKit Manager container..."
            docker run -d -it --name dk_manager \
                $LOG_LIMIT_PARAM \
                $DOCKER_SHARE_PARAM \
                -v "$HOME_DIR/.dk:/app/.dk" \
                --restart unless-stopped \
                -e USER="$DK_USER" \
                -e DOCKER_HUB_NAMESPACE="$DOCKER_HUB_NAMESPACE" \
                -e ARCH="$ARCH" \
                ghcr.io/samtranbosch/dk_manager:latest >/dev/null 2>&1
        }
        show_success "DreamKit Manager started"
    fi
}

# Function to check if IVI is available
check_ivi_availability() {
    show_info "Checking IVI interface availability..."
    
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^ghcr.io/samtranbosch/dk_ivi:latest$"; then
        show_success "IVI interface image found"
        return 0
    else
        show_warning "IVI interface image not found"
        return 1
    fi
}

# Function to start IVI interface
start_ivi() {
    show_info "Starting IVI interface..."
    
    # Enable X11 forwarding
    if [ -f "$CURRENT_DIR/scripts/dk_enable_xhost.sh" ]; then
        "$CURRENT_DIR/scripts/dk_enable_xhost.sh" >/dev/null 2>&1
    fi
    xhost +local:docker >/dev/null 2>&1
    
    # Stop existing IVI container if running
    docker stop dk_ivi >/dev/null 2>&1
    docker rm dk_ivi >/dev/null 2>&1
    
    # Check for NVIDIA hardware
    if [ -f "/etc/nv_tegra_release" ]; then
        show_info "NVIDIA Jetson detected - using optimized configuration"
        docker run -d -it --name dk_ivi \
            --network host \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -e DISPLAY="$DISPLAY" \
            -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            -e QT_QUICK_BACKEND=software \
            --restart unless-stopped \
            $LOG_LIMIT_PARAM \
            $DOCKER_SHARE_PARAM \
            -v "$HOME_DIR/.dk:/app/.dk" \
            -e DKCODE=dreamKIT \
            -e DK_USER="$DK_USER" \
            -e DK_DOCKER_HUB_NAMESPACE="$DOCKER_HUB_NAMESPACE" \
            -e DK_ARCH="$ARCH" \
            -e DK_CONTAINER_ROOT="/app/.dk/" \
            ghcr.io/samtranbosch/dk_ivi:latest >/dev/null 2>&1
    else
        show_info "Standard hardware detected - using generic configuration"
        docker run -d -it --name dk_ivi \
            --network host \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -e DISPLAY="$DISPLAY" \
            -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
            --device /dev/dri:/dev/dri \
            --restart unless-stopped \
            $LOG_LIMIT_PARAM \
            $DOCKER_SHARE_PARAM \
            -v "$HOME_DIR/.dk:/app/.dk" \
            -e DKCODE=dreamKIT \
            -e DK_USER="$DK_USER" \
            -e DK_DOCKER_HUB_NAMESPACE="$DOCKER_HUB_NAMESPACE" \
            -e DK_ARCH="$ARCH" \
            -e DK_CONTAINER_ROOT="/app/.dk/" \
            ghcr.io/samtranbosch/dk_ivi:latest >/dev/null 2>&1
    fi
    
    # Verify IVI started successfully
    sleep 2
    if docker ps --format "{{.Names}}" | grep -q "^dk_ivi$"; then
        show_success "IVI interface started successfully"
        show_info "IVI dashboard should now be available on your display"
        return 0
    else
        show_error "Failed to start IVI interface"
        return 1
    fi
}

# Function to show status
show_status() {
    echo -e "\n${CYAN}${BOLD}dreamOS Service Status:${NC}"
    
    local services=("sdv-runtime" "dk_manager" "dk_ivi")
    
    for service in "${services[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^$service$"; then
            local status=$(docker ps --format "{{.Status}}" --filter "name=^$service$")
            echo -e "${GREEN} ${CHECKMARK} $service: ${BOLD}Running${NC} ${DIM}($status)${NC}"
        else
            echo -e "${RED} ${CROSS} $service: ${BOLD}Stopped${NC}"
        fi
    done
    echo
}

# Main function
main() {
    show_banner
    
    # Step 1: Load environment
    echo -e "${BLUE}${BOLD}[1/5] Environment Check${NC}"
    if ! load_environment; then
        echo -e "\n${RED}${BOLD}Installation Required${NC}"
        echo -e "${YELLOW}dreamOS is not properly installed on this system.${NC}"
        echo -e "${WHITE}Please run the installer first:${NC}"
        echo -e "${CYAN}  ./dk_install${NC}\n"
        exit 1
    fi
    
    # Step 2: Check Docker images
    echo -e "\n${BLUE}${BOLD}[2/5] Docker Images Check${NC}"
    if ! check_docker_images; then
        echo -e "\n${RED}${BOLD}Missing Components${NC}"
        echo -e "${YELLOW}Some required Docker images are missing.${NC}"
        echo -e "${WHITE}Please run the installer to download missing components:${NC}"
        echo -e "${CYAN}  ./dk_install${NC}\n"
        exit 1
    fi
    
    # Step 3: Check core services
    echo -e "\n${BLUE}${BOLD}[3/5] Core Services Check${NC}"
    if ! check_core_services; then
        show_info "Some core services need to be started..."
        start_core_services
    fi
    
    # Step 4: Check IVI availability
    echo -e "\n${BLUE}${BOLD}[4/5] IVI Interface Check${NC}"
    if ! check_ivi_availability; then
        echo -e "\n${YELLOW}${BOLD}IVI Interface Not Available${NC}"
        echo -e "${WHITE}The IVI interface is not installed.${NC}"
        echo -e "${CYAN}Would you like to install it now? [y/N]: ${NC}"
        read -r install_choice
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            echo -e "\n${GREEN}Installing IVI interface...${NC}"
            echo -e "${DIM}This will download and configure the IVI interface...${NC}"
            ./dk_install dk_ivi=true
        else
            echo -e "\n${YELLOW}IVI installation skipped.${NC}"
            echo -e "${WHITE}You can install it later with:${NC}"
            echo -e "${CYAN}  ./dk_install dk_ivi=true${NC}\n"
            exit 0
        fi
    fi
    
    # Step 5: Start IVI
    echo -e "\n${BLUE}${BOLD}[5/5] IVI Launch${NC}"
    if start_ivi; then
        show_status
        echo -e "${GREEN}${BOLD}${ROCKET} dreamOS IVI interface is now running!${NC}"
        echo -e "${CYAN}The dashboard should appear on your display shortly.${NC}"
        
        # Show useful commands
        echo -e "\n${DIM}Useful commands:${NC}"
        echo -e "${WHITE}  View IVI logs:${NC} ${CYAN}docker logs -f dk_ivi${NC}"
        echo -e "${WHITE}  Stop IVI:${NC}     ${CYAN}docker stop dk_ivi${NC}"
        echo -e "${WHITE}  Restart IVI:${NC}  ${CYAN}docker restart dk_ivi${NC}"
    else
        show_error "Failed to start IVI interface"
        echo -e "\n${YELLOW}Troubleshooting:${NC}"
        echo -e "${WHITE}  Check logs:${NC} ${CYAN}docker logs dk_ivi${NC}"
        echo -e "${WHITE}  Verify X11:${NC} ${CYAN}echo \$DISPLAY${NC}"
        echo -e "${WHITE}  Test Docker:${NC} ${CYAN}docker run --rm hello-world${NC}"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo -e "${CYAN}${BOLD}dreamOS Runner - Quick Service Launcher${NC}"
        echo -e "\n${WHITE}Usage:${NC}"
        echo -e "  ${CYAN}./dk_run.sh${NC}          Start IVI interface"
        echo -e "  ${CYAN}./dk_run.sh --help${NC}   Show this help"
        echo -e "  ${CYAN}./dk_run.sh --status${NC} Show service status"
        echo -e "\n${WHITE}Description:${NC}"
        echo -e "This script checks if dreamOS is properly installed and starts"
        echo -e "the IVI (In-Vehicle Infotainment) interface along with required services."
        echo
        exit 0
        ;;
    --status|-s)
        if load_environment >/dev/null 2>&1; then
            show_status
        else
            echo -e "${RED}${CROSS} dreamOS not installed${NC}"
        fi
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac