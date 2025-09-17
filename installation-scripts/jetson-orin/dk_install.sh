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
TOTAL_STEPS=13
CURRENT_STEP=0

# Parse command line arguments early
parse_arguments() {
    # Default values
    dk_ivi_value="true"        # Changed default to true
    zecu_value="true"          # Default enable zonal ECU setup
    swupdate_value="false"     # Default disable software update only mode
    
    # Parse all arguments
    for arg in "$@"; do
        case "$arg" in
            dk_ivi=*)
                dk_ivi_value="${arg#*=}"
                ;;
            zecu=*)
                zecu_value="${arg#*=}"
                ;;
            swupdate=*)
                swupdate_value="${arg#*=}"
                ;;
        esac
    done
    
    # Validate argument values
    case "$dk_ivi_value" in
        true|false) ;;
        *) 
            show_error "Invalid dk_ivi value: $dk_ivi_value (must be true or false)"
            exit 1
            ;;
    esac
    
    case "$zecu_value" in
        true|false) ;;
        *) 
            show_error "Invalid zecu value: $zecu_value (must be true or false)"
            exit 1
            ;;
    esac
    
    case "$swupdate_value" in
        true|false) ;;
        *) 
            show_error "Invalid swupdate value: $swupdate_value (must be true or false)"
            exit 1
            ;;
    esac
    
    # Export for use in other functions
    export dk_ivi_value zecu_value swupdate_value
}

# Update show_usage function to include possible parameter
show_usage() {
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════════════════\n"
    echo -e "${CYAN}${BOLD}dreamOS Installation Suite - Usage Guide${NC}\n"
    
    echo -e "${WHITE}${BOLD}Parameters:${NC}"
    echo -e "${CYAN}  zecu=${BOLD}true|false${NC}           ${DIM}Setup zonal ECU (S32G) (default: true)${NC}"
    echo -e "${CYAN}  swupdate=${BOLD}true|false${NC}       ${DIM}Software update only mode (default: false)${NC}"
    echo -e "${CYAN}  dk_ivi=${BOLD}true|false${NC}         ${DIM}Install IVI interface (default: true)${NC}"
    echo

    echo -e "${WHITE}${BOLD}Frequently Usage:${NC}"
    echo -e "${WHITE}  sudo ./dk_install.sh                                    ${DIM}# Full installation with IVI enabled, zonal ECU setup${NC}"
    echo -e "${WHITE}  sudo ./dk_install.sh zecu=false                         ${DIM}# Skip zonal ECU (S32G) setup${NC}"
    echo -e "${WHITE}  sudo ./dk_install.sh zecu=false swupdate=true           ${DIM}# Software update only mode${NC}"
    echo
    
    echo -e "${WHITE}${BOLD}Software Update Mode:${NC}"
    echo -e "${CYAN}  When swupdate=true, only steps 10-12 are executed:${NC}"
    echo -e "${DIM}  - Step 10: SDV Runtime update${NC}"
    echo -e "${DIM}  - Step 11: DreamKit Manager update${NC}"
    echo -e "${DIM}  - Step 12: IVI Interface update (if dk_ivi=true)${NC}"
    echo
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════════════════\n"
}

# Function to show animated banner
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════════════════╗
    ║                                                                      ║
    ║    ████████╗ ██████╗  ███████╗  █████╗  ███╗   ███╗  ██████╗ ███████╗║
    ║    ██╔═══██║██╔══██╗ ██╔════╝ ██╔══██╗ ████╗ ████║ ██╔═══██╗██╔════╝║
    ║    ██║   ██║██████╔╝ █████╗   ███████║ ██╔████╔██║ ██║   ██║███████╗║
    ║    ██║   ██║██╔══██╗ ██╔══╝   ██╔══██║ ██║╚██╔╝██║ ██║   ██║╚════██║║
    ║    ████████║██║  ██║ ███████╗ ██║  ██║ ██║ ╚═╝ ██║ ╚██████╔╝███████║║
    ║    ╚═══════╝╚═╝  ╚═╝ ╚══════╝ ╚═╝  ╚═╝ ╚═╝     ╚═╝  ╚═════╝ ╚══════╝║
    ║                                                                      ║
    ║                    Professional Installation Suite                   ║
    ║                    --> Version 2.0 - K3s Deployment                  ║
    ╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # Show current configuration
    echo -e "${CYAN}${DIM}Configuration:${NC}"
    echo -e "${DIM}  IVI Interface: ${BOLD}$dk_ivi_value${NC}"
    echo -e "${DIM}  Zonal ECU Setup: ${BOLD}$zecu_value${NC}"
    echo -e "${DIM}  Software Update Only: ${BOLD}$swupdate_value${NC}"
    
    # Animated subtitle
    local subtitle="Initializing dreamOS installation environment..."
    if [[ "$swupdate_value" == "true" ]]; then
        subtitle="Initializing dreamOS software update process..."
    fi
    
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

# Enhanced environment setup function - moved up before step 4
setup_environment_variables() {
    show_info "Setting up environment variables..."
    
    # Determine the user who ran the command
    if [ -n "$SUDO_USER" ]; then
        DK_USER=$SUDO_USER
    else
        DK_USER=$USER
    fi
    
    # Get the current install script path
    CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Detect architecture
    ARCH_DETECT=$(uname -m)
    if [[ "$ARCH_DETECT" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH_DETECT" == "aarch64" ]]; then
        ARCH="arm64"
    else
        ARCH="unknown"
    fi
    
    # Create the serial_number file
    serial_file="/home/$DK_USER/.dk/dk_manager/serial-number"
    sudo mkdir -p "$(dirname "$serial_file")"
    if [[ ! -s "$serial_file" ]]; then
        serial_number=$(openssl rand -hex 8)
        echo "$serial_number" > "$serial_file"
    else
        serial_number=$(tail -n 1 "$serial_file")
    fi
    RUNTIME_NAME="dreamKIT-${serial_number: -8}"
    
    # Get XDG_RUNTIME_DIR
    XDG_RUNTIME_DIR=$(sudo -u "$DK_USER" env | grep XDG_RUNTIME_DIR | cut -d= -f2)
    if [ -z "$XDG_RUNTIME_DIR" ]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u "$DK_USER")"
    fi
    
    # Set all environment variables
    HOME_DIR="/home/$DK_USER"
    DOCKER_SHARE_PARAM="-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker"
    DOCKER_AUDIO_PARAM="--device /dev/snd --group-add audio -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native -v $HOME_DIR/.config/pulse/cookie:/root/.config/pulse/cookie"
    K3S_SHARE_PARAM=" -v /usr/local/bin/kubectl:/usr/local/bin/kubectl:ro -v ~/.kube/config:/root/.kube/config:ro"
    LOG_LIMIT_PARAM="--log-opt max-size=10m --log-opt max-file=3"
    DOCKER_HUB_NAMESPACE="ghcr.io/eclipse-autowrx"
    
    # Export variables for use throughout the script
    export DK_USER CURRENT_DIR ARCH RUNTIME_NAME XDG_RUNTIME_DIR HOME_DIR
    export DOCKER_SHARE_PARAM DOCKER_AUDIO_PARAM K3S_SHARE_PARAM LOG_LIMIT_PARAM DOCKER_HUB_NAMESPACE
    
    show_info "Environment configured for user: ${BOLD}$DK_USER${NC}"
    show_info "Architecture: ${BOLD}$ARCH${NC} (${ARCH_DETECT})"
    show_info "Runtime name: ${BOLD}$RUNTIME_NAME${NC}"
    show_info "Home directory: ${BOLD}$HOME_DIR${NC}"
}

# Function to run docker pull with detailed info
docker_pull_with_info() {
    local image=$1
    local description=$2
    local registry_info=$3
    local max_retries=${4:-3}
    local retry_delay=${5:-10}
    
    echo -e "${CYAN}${BOLD}Downloading: ${WHITE}$image${NC}"
    echo -e "${DIM}Description: $description${NC}"
    echo -e "${DIM}Registry: $registry_info${NC}"
    echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"
    
    local retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if [ $retry_count -gt 0 ]; then
            show_warning "Retry attempt $retry_count/$max_retries after ${retry_delay}s delay..."
            sleep $retry_delay
        fi
        
        # Show docker pull output
        if docker pull "$image" 2>&1 | while IFS= read -r line; do
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
        done; then
            # Get image size info
            local image_size=$(docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep "$image" | awk '{print $2}' | head -1)
            if [ -n "$image_size" ]; then
                echo -e "${GREEN}${BOLD} ✓ Download completed - Image size: $image_size${NC}"
            else
                echo -e "${GREEN}${BOLD} ✓ Download completed${NC}"
            fi
            echo
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            show_error "Pull failed, retrying in ${retry_delay} seconds..."
        fi
    done
    
    show_error "Failed to pull $image after $max_retries attempts"
    echo
    return 1
}

# Function to show K3s cluster information
show_k3s_cluster_info() {
    # Quick cluster check
    if ! command -v kubectl &> /dev/null || ! kubectl cluster-info &> /dev/null; then
        show_error "K3s cluster not accessible"
        return 1
    fi
    
    show_success "K3s cluster accessible"
    
    # Display node information
    echo -e "\n${BLUE}${BOLD}Node Status:${NC}"
    kubectl get nodes -o wide --no-headers 2>/dev/null | while IFS= read -r line; do
        echo -e "${GREEN}  ✓ $line${NC}"
    done
    
    echo -e "\n${BLUE}${BOLD}Unique Container Images and Image IDs${NC}"
    
    # Get image data efficiently
    local image_data=$(kubectl get pods --all-namespaces \
      -o jsonpath='{range .items[*]}{range .status.containerStatuses[*]}{.image}{"\t"}{.imageID}{"\n"}{end}{end}' 2>/dev/null)
    
    if [ -n "$image_data" ]; then
        # Simple header
        printf "%-50s %s\n" "IMAGE" "IMAGE_ID"
        echo "$(printf '%*s' 120 '' | tr ' ' '-')"
        
        # Remove duplicates and display unique image-to-imageID mappings
        echo "$image_data" | sort -u | while IFS=$'\t' read -r image image_id; do
            # Remove only protocol prefix
            clean_id=$(echo "$image_id" | sed 's/.*:\/\///')
            printf "%-50s %s\n" "$image" "$clean_id"
        done
        
        # Quick summary
        local total=$(echo "$image_data" | wc -l)
        local unique=$(echo "$image_data" | sort -u | wc -l)
        echo -e "\n${GREEN}Unique mappings: $unique (from $total total containers)${NC}"
        
    else
        show_info "No images found"
    fi
    
    show_success "Node status and unique image information displayed"
}

force_deployment_update() {
    local deployment_name=$1
    local namespace=${2:-default}
    local image_name=$3  # Optional: specific image to verify
    
    show_info "Forcing update for deployment: $deployment_name"
    
    # Step 1: Delete existing deployment to ensure fresh start
    run_with_feedback \
        "sudo kubectl delete deployment/$deployment_name -n $namespace --ignore-not-found --wait=true" \
        "Existing deployment removed" \
        "Deployment cleanup completed"
    
    # Step 2: Wait for complete cleanup
    show_info "Waiting for cleanup to complete..."
    sleep 3
    
    # Step 3: Verify pods are terminated
    local pod_count=$(kubectl get pods -l app=$deployment_name -n $namespace --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
        show_warning "Force deleting remaining pods..."
        kubectl delete pods -l app=$deployment_name -n $namespace --force --grace-period=0 --ignore-not-found
        sleep 5
    fi
    
    # Step 4: Clear any cached images if specified
    if [ -n "$image_name" ]; then
        show_info "Clearing cached image: $image_name"
        docker rmi "$image_name" 2>/dev/null || true
    fi
    
    return 0
}

apply_manifest() {
    # -----------------------------------------------------------------
    # make all placeholders available to envsubst
    # -----------------------------------------------------------------
    export DOCKER_HUB_NAMESPACE ARCH DK_USER RUNTIME_NAME HOME_DIR \
        dk_vip_demo DISPLAY XDG_RUNTIME_DIR

    # -----------------------------------------------------------------
    MANIFEST_DIR="${CURRENT_DIR}/manifests"
    local yaml="$1"
    local tmp_dir="tmp/dk_manifests"
    local parsed_yaml="${tmp_dir}/parsed_${yaml}"
    
    # Create tmp directory for parsed manifests
    mkdir -p "$tmp_dir"
    
    local VARS='${DOCKER_HUB_NAMESPACE} ${ARCH} ${DK_USER} ${RUNTIME_NAME} \
                ${HOME_DIR} ${dk_vip_demo} ${DISPLAY} ${XDG_RUNTIME_DIR}'
    
    show_info "Processing manifest: ${BOLD}${yaml}${NC}"
    show_info "Creating parsed version in: ${DIM}${parsed_yaml}${NC}"
    
    # Parse template and save to tmp folder
    if envsubst "${VARS}" < "${MANIFEST_DIR}/${yaml}" > "${parsed_yaml}"; then
        show_success "Manifest parsed successfully"
        show_info "Parsed manifest saved to: ${CYAN}${parsed_yaml}${NC}"
        
        # Show some key information from the parsed manifest
        if command -v yq >/dev/null 2>&1; then
            local kind=$(yq eval '.kind' "${parsed_yaml}" 2>/dev/null || echo "Unknown")
            local name=$(yq eval '.metadata.name' "${parsed_yaml}" 2>/dev/null || echo "Unknown")
            show_info "Resource type: ${BOLD}${kind}${NC}, Name: ${BOLD}${name}${NC}"
        fi
        
        # Apply the parsed manifest
        run_with_feedback \
            "kubectl apply -f '${parsed_yaml}'" \
            "Applied manifest ${yaml}" \
            "Failed to apply ${yaml}"
            
        # Optional: Show what was applied
        if [ $? -eq 0 ]; then
            show_info "Manifest applied from: ${DIM}${parsed_yaml}${NC}"
            show_info "You can inspect the parsed manifest for debugging"
        fi
    else
        show_error "Failed to parse manifest ${yaml}"
        return 1
    fi
}

# Enhanced manifest application with force update
apply_manifest_with_force_update() {
    local yaml="$1"
    local deployment_name="$2"
    local image_name="$3"  # Optional
    
    # Step 1: Force update if deployment exists
    if kubectl get deployment "$deployment_name" -n default >/dev/null 2>&1; then
        show_info "Deployment exists, forcing update..."
        force_deployment_update "$deployment_name" "default" "$image_name"
    fi
    
    # Step 2: Apply manifest
    apply_manifest "$yaml"
    
    # Step 3: Wait for deployment with extended timeout
    run_with_feedback \
        "sudo kubectl rollout status deployment/$deployment_name" \
        "$deployment_name is READY with latest image" \
        "$deployment_name failed to start"
    
    # Step 4: Verify image version (if provided)
    if [ -n "$image_name" ]; then
        show_info "Verifying deployed image..."
        local deployed_image=$(kubectl get deployment "$deployment_name" -o jsonpath='{.spec.template.spec.containers[0].image}')
        show_info "Deployed image: $deployed_image"
        
        # Optional: Get image digest for verification
        local image_digest=$(kubectl get deployment "$deployment_name" -o jsonpath='{.spec.template.spec.containers[0].image}' | xargs docker inspect --format='{{index .RepoDigests 0}}' 2>/dev/null || echo "N/A")
        if [ "$image_digest" != "N/A" ]; then
            show_info "Image digest: $image_digest"
        fi
    fi
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

# NEW: Enhanced function to perform software updates (steps 10-12)
perform_software_updates() {
    local step_offset=${1:-0}  # Allows adjusting step numbers when called from main installation
    local update_mode=${2:-"update"}  # "update" or "install" mode
    
    ###############################################################################
    # Step 10   SDV Runtime (Main)
    ###############################################################################
    local step_num=$((10 - step_offset))
    if [[ "$update_mode" == "update" ]]; then
        show_step $step_num "SDV Runtime Update" "Updating Software Defined Vehicle runtime environment"
    else
        show_step $step_num "SDV Runtime" "Setting up Software Defined Vehicle runtime environment"
    fi

    # Export variables for sub-scripts
    export HOME_DIR
    export DK_USER
    
    # Enhanced VSS setup with existence check
    if [[ "$update_mode" == "install" ]]; then
        scripts/setup_default_vss.sh
    else
        show_info "Checking existing VSS configuration..."
        if [ -f "${HOME_DIR}/.dk/sdv-runtime/vss.json" ]; then
            show_success "VSS configuration already exists, skipping default setup"
        else
            show_info "No existing VSS configuration found, setting up defaults..."
            scripts/setup_default_vss.sh
        fi
    fi

    # Enhanced SDV Runtime deployment with improved pull strategy
    show_info "Deploying main SDV Runtime with force update..."

    # Pull latest image first with retry logic
    apply_manifest sdv-runtime-pull.yaml
    
    # Enhanced wait with timeout and better error handling
    local pull_timeout=600
    show_info "Waiting for SDV Runtime image pull (timeout: ${pull_timeout}s)..."
    if ! run_with_feedback \
        "sudo kubectl wait --for=condition=complete job/sdv-runtime-pull --timeout=${pull_timeout}s" \
        "Latest SDV Runtime image pulled successfully" \
        "SDV Runtime image pull failed or timed out" \
        false \
        true; then
        
        # Fallback: Check if job failed and retry once
        show_warning "Initial pull failed, checking job status and retrying..."
        local job_status=$(kubectl get job sdv-runtime-pull -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "Unknown")
        
        if [[ "$job_status" == "True" ]]; then
            show_info "Job failed, cleaning up and retrying..."
            kubectl delete job sdv-runtime-pull --ignore-not-found
            sleep 5
            
            # Retry the pull job
            apply_manifest sdv-runtime-pull.yaml
            run_with_feedback \
                "sudo kubectl wait --for=condition=complete job/sdv-runtime-pull --timeout=600s" \
                "SDV Runtime image pulled on retry" \
                "SDV Runtime image pull failed after retry" \
                false \
                true
        fi
    fi

    # Clean up pull job
    run_with_feedback \
        "sudo kubectl delete job sdv-runtime-pull --ignore-not-found" \
        "Pull job cleaned up" \
        "Cleanup completed"

    # Apply with force update
    apply_manifest_with_force_update "sdv-runtime.yaml" "sdv-runtime" "${DOCKER_HUB_NAMESPACE}/sdv-runtime:latest"

    ###############################################################################
    # Step 11   DreamKit Manager
    ###############################################################################
    step_num=$((11 - step_offset))
    if [[ "$update_mode" == "update" ]]; then
        show_step $step_num "DreamKit Manager Update" "Updating core management services"
    else
        show_step $step_num "DreamKit Manager" "Installing core management services"
    fi

    # Pull latest image first
    apply_manifest dk-manager-pull.yaml
    run_with_feedback \
        "sudo kubectl wait --for=condition=complete job/dk-manager-pull --timeout=600s" \
        "Latest DreamKit Manager image pulled" \
        "DreamKit Manager image pull failed" \
        false \
        true

    # Clean up pull job
    run_with_feedback \
        "sudo kubectl delete job dk-manager-pull --ignore-not-found" \
        "Pull job cleaned up" \
        "Cleanup completed"

    # Apply with force update
    apply_manifest_with_force_update "dk-manager.yaml" "dk-manager" "${DOCKER_HUB_NAMESPACE}/dk-manager:latest"

    ###############################################################################
    # Step 12   IVI Interface (conditional)
    ###############################################################################
    if [[ "$dk_ivi_value" == "true" ]]; then
        step_num=$((12 - step_offset))
        if [[ "$update_mode" == "update" ]]; then
            show_step $step_num "IVI Interface Update" "Updating In-Vehicle Infotainment system"
        else
            show_step $step_num "IVI Interface" "Configuring In-Vehicle Infotainment system"
        fi

        # Pull latest image first
        apply_manifest dk-ivi-pull.yaml
        run_with_feedback \
            "sudo kubectl wait --for=condition=complete job/dk-ivi-pull --timeout=600s" \
            "Latest IVI image pulled" \
            "IVI image pull failed" \
            false \
            true
        
        # Clean up pull job
        run_with_feedback \
            "sudo kubectl delete job dk-ivi-pull --ignore-not-found" \
            "Pull job cleaned up" \
            "Cleanup completed"

        # Decide which manifest to apply and force update
        if [ -f "/etc/nv_tegra_release" ]; then
            apply_manifest_with_force_update "dk-ivi-jetson.yaml" "dk-ivi" "${DOCKER_HUB_NAMESPACE}/dk_ivi:latest"
        else
            apply_manifest_with_force_update "dk-ivi.yaml" "dk-ivi" "${DOCKER_HUB_NAMESPACE}/dk_ivi:latest"
        fi
    else
        if [[ "$update_mode" == "update" ]]; then
            show_info "IVI interface update skipped (dk_ivi=false)"
        else
            show_info "IVI installation skipped (you can install later with './dk_install dk_ivi=true')"
        fi
    fi

    ###############################################################################
    # Step 13   K3s Cluster Information
    ###############################################################################
    step_num=$((13 - step_offset))
    show_step $step_num "K3s Cluster Information" "Displaying node status, images and image IDs"
    show_k3s_cluster_info
}

# Enhanced main installation function
main() {
    # Parse arguments first
    parse_arguments "$@"
    
    # Show usage if help requested
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Show banner with current configuration
    show_banner
    
    # Welcome message with animation
    echo -e "${CYAN}${BOLD}${DREAM} Welcome to the dreamOS Installation Experience! ${DREAM}${NC}\n"
    
    if [[ "$swupdate_value" == "true" ]]; then
        type_text "This installer will update your dreamOS software components to the latest versions." 0.01
        echo -e "\n${YELLOW}${BOLD}${ROCKET} Ready to update your dreamOS environment? ${ROCKET}${NC}\n"
        
        # Adjust total steps for software update mode
        TOTAL_STEPS=3
        if [[ "$dk_ivi_value" == "false" ]]; then
            TOTAL_STEPS=2
        fi
    else
        type_text "This installer will set up your complete dreamOS environment with all required components." 0.01
        echo -e "\n${YELLOW}${BOLD}${ROCKET} Ready to begin your journey? ${ROCKET}${NC}\n"
        
        # Show configuration summary
        echo -e "${BLUE}${BOLD}Installation Configuration:${NC}"
        echo -e "${GREEN} ${CHECKMARK} IVI Interface: ${BOLD}$dk_ivi_value${NC}"
        echo -e "${GREEN} ${CHECKMARK} Zonal ECU Setup: ${BOLD}$zecu_value${NC}"
        echo -e "${GREEN} ${CHECKMARK} Software Update Only: ${BOLD}$swupdate_value${NC}"
        echo
    fi
    
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # Setup environment variables early
    setup_environment_variables
    
    # Software update mode - only run steps 10-12
    if [[ "$swupdate_value" == "true" ]]; then
        show_info "Running in software update mode - executing steps 10-12 only"
        
        # Call the new software update function with step offset for proper numbering
        perform_software_updates 9 "update"  # Offset by 9 to show as steps 1-3
        
        # Software update completion message
        echo -e "\n${GREEN}${BOLD}Software update completed successfully!${NC}\n"
        show_success "All specified components have been updated to the latest versions"
        
        return 0
    fi
    
    # Full installation mode - run all steps
    # Steps 1-3: Environment Detection, Docker Setup, Runtime Configuration
    
    # Step 1: Environment Detection
    show_step 1 "Environment Detection" "Analyzing system configuration and user environment"
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
    
    # Step 3: Runtime Configuration - now uses pre-configured environment
    show_step 3 "Runtime Configuration" "Using pre-configured runtime environment"
    show_success "Runtime configuration completed"
    
    # Step 4: Directory Structure
    show_step 4 "Directory Structure" "Creating dreamOS directory hierarchy"
    run_with_feedback "mkdir -p /home/$DK_USER/.dk/dk_swupdate /home/$DK_USER/.dk/dk_swupdate/dk_patch /home/$DK_USER/.dk/dk_swupdate/dk_current /home/$DK_USER/.dk/dk_swupdate/dk_current_patch" "Directory structure created successfully" "Failed to create directory structure"
    
    # Step 5: Network Setup
    show_step 5 "Network Setup" "Establishing Docker network infrastructure"
    run_with_feedback "docker network create dk_network 2>/dev/null || true" "Docker network 'dk_network' ready" "Network setup encountered issues"
    
    # Step 6: Dependencies Installation
    show_step 6 "Dependencies" "Installing required system utilities and tools"

    # Make the script executable first
    chmod +x "$CURRENT_DIR/scripts/install_dependencies.sh"

    run_with_feedback \
        "sudo $CURRENT_DIR/scripts/install_dependencies.sh" \
        "Dependencies installation completed" \
        "Dependencies installation failed"

    if [ $? -ne 0 ]; then
        show_error "Dependencies installation failed. Please check the logs."
        exit 1
    fi

    # Setup X11 forwarding
    run_with_feedback "sudo $CURRENT_DIR/scripts/dk_enable_xhost.sh" \
                        "X11 forwarding enabled" "X11 setup failed" false true
    run_with_feedback "xhost +local:docker" "Docker X11 access granted" "X11 access failed"
    
    ###############################################################################
    # Step 7   local Docker registry
    ###############################################################################
    show_step 7 "Docker local registry" "VIP installation"
    show_info "Setup local registry..."
    run_with_feedback \
        "sudo $CURRENT_DIR/scripts/setup_local_docker_registry.sh" \
        "Docker local host enabled.\
        \n ✓ You can now use the local Docker registry for your images.\
        \n ✓ To push images, use: docker push localhost:5000/your-image-name" \
        "Docker local setup failed"

    ###############################################################################
    # Step 8   K3s-based installation
    ###############################################################################
    show_step 8 "K3s-based installation" "k3s master installation & preparation for local registry"
    sudo scripts/k3s-master-prepare.sh eth0
    if [ $? -ne 0 ]; then
        show_error "Failed to prepare K3s master. Please check the logs."
        exit 1
    fi
    show_success "K3s master prepared successfully"
    
    ###############################################################################
    # Step-9   NXP-S32G setup (k3s-agent & friends) - conditional based on zecu parameter
    ###############################################################################
    if [[ "$zecu_value" == "true" ]]; then
        show_step 9 "NXP-S32G setup" "k3s-agent installation & relevant stuff"

        TARGET_IP="192.168.56.49"
        PING_COUNT=3      # how many echo-requests we send
        PING_TIMEOUT=2    # wait time (seconds) for each reply

        show_info "Checking reachability of ECU at ${TARGET_IP} ..."

        if ping -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${TARGET_IP}" >/dev/null 2>&1; then
            show_success "ECU reachable."
            show_info "Proceed with the NXP-S32G setup? [y/N]: "
        else
            show_warning "Could NOT reach ${TARGET_IP}. Is the ECU powered on and connected?"
            show_info "Attempt the NXP-S32G setup anyway? [y/N]: "
        fi

        read -r nxp_s32g_setup
        
        if [[ "$nxp_s32g_setup" =~ ^[Yy]$ ]]; then
            show_info "Calling NXP-S32G setup script..."
            run_with_feedback "sudo $CURRENT_DIR/scripts/k3s-agent-offline-install.sh" \
                            "NXP-S32G setup completed" \
                            "NXP-S32G setup failed"
        else
            show_info "NXP-S32G setup skipped (you can run it later with './scripts/k3s-agent-offline-install.sh')"
        fi
    else
        show_info "NXP-S32G (Zonal ECU) setup skipped (zecu=false)"
        show_info "You can run it later with: sudo ./dk_install.sh zecu=true"
    fi
    
    ###############################################################################
    # Steps 10-12: Software Components - call the new function
    ###############################################################################
    perform_software_updates 0 "install"  # No offset, run as steps 10-12
    
    ###############################################################################
    # Final steps
    ###############################################################################
    separator
    echo -e "\n${BLUE}${BOLD}Finalizing installation...${NC}\n"
    
    # Save environment variables (include new parameters)
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
zecu_value="${zecu_value}"
swupdate_value="${swupdate_value}"
EOF
    chmod +x "${DK_ENV_FILE}"
    
    # Create additional services
    run_with_feedback "$CURRENT_DIR/scripts/create_dk_xiphost_service.sh" "Additional services configured" "Service configuration warning"
    
    # Cleanup
    show_info "Cleaning up temporary files..."
    run_with_feedback "docker image prune -f" "Docker cleanup completed" "Cleanup warning"
    
    # Success message with configuration summary
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
    if [[ "$zecu_value" == "true" ]]; then
        echo -e "${GREEN} ${CHECKMARK} Zonal ECU (S32G) setup completed${NC}"
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