#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# Enhanced xhost setup script with multi-display and Docker container support
# Supports multiple virtual displays for isolated Qt applications
# Handles Docker container X11 access permissions

set -uo pipefail

# Configuration
DEFAULT_DISPLAY_COUNT=4
DEFAULT_RESOLUTION="1280x720x24"
BASE_DISPLAY=1
MAX_DISPLAYS=20

# Installation paths
INSTALL_DIR="$HOME/.dk/sys-service"
SCRIPT_NAME="dk_enable_xhost.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_docker() {
    echo -e "${PURPLE}[DOCKER]${NC} $1"
}

# Get the actual user (not root) - simplified version
get_real_user() {
    local real_user=""
    
    # Try different methods in order of preference
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        real_user="$SUDO_USER"
    elif [[ -n "${DISPLAY:-}" ]]; then
        real_user=$(who | grep "(:0)" | awk '{print $1}' | head -n1 2>/dev/null | tr -d '\n')
    fi
    
    if [[ -z "$real_user" && -n "${USER:-}" && "$USER" != "root" ]]; then
        real_user="$USER"
    fi
    
    if [[ -z "$real_user" && -n "${LOGNAME:-}" && "$LOGNAME" != "root" ]]; then
        real_user="$LOGNAME"
    fi
    
    if [[ -z "$real_user" ]]; then
        real_user=$(who | grep -v "^root " | awk '{print $1}' | head -n1 2>/dev/null | tr -d '\n')
    fi
    
    # Clean any whitespace/newlines
    real_user=$(echo "$real_user" | tr -d ' \n\r\t')
    
    echo "$real_user"
}

# Check root and setup user variables
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        log_info "Usage: sudo $0 [command] [options]"
        exit 1
    fi
    
    # Get the real user
    local detected_user=$(get_real_user)
    
    if [[ -z "$detected_user" ]]; then
        log_error "Could not determine the real user (non-root user)"
        log_error "Available users logged in:"
        who 2>/dev/null || echo "  (no users found)"
        log_error "Environment variables:"
        log_error "  SUDO_USER: ${SUDO_USER:-'not set'}"
        log_error "  USER: ${USER:-'not set'}"
        log_error "  LOGNAME: ${LOGNAME:-'not set'}"
        exit 1
    fi
    
    log_info "Detected user: $detected_user"
    
    # Verify the user exists and has a home directory
    if ! id "$detected_user" >/dev/null 2>&1; then
        log_error "User '$detected_user' does not exist on this system"
        exit 1
    fi
    
    local user_home=$(getent passwd "$detected_user" | cut -d: -f6)
    if [[ ! -d "$user_home" ]]; then
        log_error "User home directory '$user_home' does not exist"
        exit 1
    fi
    
    # Set the global variables
    USERNAME="$detected_user"
    USER_HOME="$user_home"
    USER_ID=$(id -u "$USERNAME")
    USER_GID=$(id -g "$USERNAME")
    
    # Update install directory to use actual user home
    INSTALL_DIR="$USER_HOME/.dk/sys-service"
    
    log_info "User home directory: $USER_HOME"
    log_info "User ID: $USER_ID, Group ID: $USER_GID"
    log_info "Install directory: $INSTALL_DIR"
}

# Install script to system location
install_script() {
    local current_script="$0"
    local target_script="$INSTALL_DIR/$SCRIPT_NAME"
    
    log_info "Installing script to system location"
    
    # Create directory structure
    mkdir -p "$INSTALL_DIR"
    chown "$USERNAME:$USERNAME" "$INSTALL_DIR"
    chmod 755 "$INSTALL_DIR"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$INSTALL_DIR")"
    chown "$USERNAME:$USERNAME" "$(dirname "$INSTALL_DIR")"
    
    # Copy script to target location
    if cp "$current_script" "$target_script"; then
        chown "$USERNAME:$USERNAME" "$target_script"
        chmod 755 "$target_script"
        log_success "Script installed to: $target_script"
        
        # Create symlink for easy access
        local symlink_path="/usr/local/bin/dk-multi-display"
        if ln -sf "$target_script" "$symlink_path" 2>/dev/null; then
            log_success "Symlink created: $symlink_path"
        else
            log_warning "Could not create symlink (non-critical)"
        fi
        
        return 0
    else
        log_error "Failed to install script"
        return 1
    fi
}

# Check if script is installed in the correct location
check_installation() {
    local target_script="$INSTALL_DIR/$SCRIPT_NAME"
    
    if [[ -f "$target_script" && -x "$target_script" ]]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# Check Docker installation and setup
check_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_docker "Docker installation detected"
        
        # Check if user is in docker group
        if groups "$USERNAME" | grep -q docker; then
            log_docker "User $USERNAME is in docker group"
            DOCKER_ENABLED=true
        else
            log_warning "User $USERNAME is not in docker group"
            log_info "Add user to docker group: sudo usermod -aG docker $USERNAME"
            DOCKER_ENABLED=false
        fi
        
        # Check Docker daemon
        if systemctl is-active --quiet docker; then
            log_docker "Docker daemon is running"
        else
            log_warning "Docker daemon is not running"
            log_info "Start Docker: sudo systemctl start docker"
        fi
        
        return 0
    else
        log_warning "Docker not installed"
        DOCKER_ENABLED=false
        return 1
    fi
}

# Check if display is available
is_display_available() {
    local display_num=$1
    if ! timeout 3 xdpyinfo -display ":$display_num" >/dev/null 2>&1; then
        return 0  # Available
    else
        return 1  # In use
    fi
}

# Start virtual display with Docker support
start_virtual_display() {
    local display_num=$1
    local resolution=${2:-$DEFAULT_RESOLUTION}
    local enable_docker=${3:-true}
    
    if is_display_available "$display_num"; then
        log_info "Starting virtual display :$display_num with resolution $resolution"
        
        # Create X authority file
        local auth_file="/tmp/.X${display_num}-auth"
        touch "$auth_file"
        chown "$USERNAME:$USERNAME" "$auth_file"
        chmod 600 "$auth_file"
        
        # Start Xvfb with optimized settings
        runuser -u "$USERNAME" -- Xvfb ":$display_num" \
            -screen 0 "$resolution" \
            -dpi 96 \
            -nolisten tcp \
            -noreset \
            +extension RENDER \
            +extension GLX \
            +extension RANDR \
            -auth "$auth_file" \
            > "/var/log/xvfb_${display_num}.log" 2>&1 &
        
        local xvfb_pid=$!
        
        # Wait for X server to start
        local timeout=10
        while [ $timeout -gt 0 ]; do
            if timeout 3 runuser -u "$USERNAME" -- xdpyinfo -display ":$display_num" >/dev/null 2>&1; then
                log_success "Virtual display :$display_num started (PID: $xvfb_pid)"
                
                # Set up xhost permissions
                setup_display_permissions "$display_num" "$enable_docker"
                
                # Save PID for management
                echo "$xvfb_pid" > "/var/run/xvfb_${display_num}.pid"
                
                return 0
            fi
            sleep 1
            timeout=$((timeout - 1))
        done
        
        log_error "Failed to start display :$display_num"
        kill "$xvfb_pid" 2>/dev/null || true
        return 1
    else
        log_warning "Display :$display_num is already in use"
        # Still setup permissions for existing display
        setup_display_permissions "$display_num" "$enable_docker"
        return 0
    fi
}

# Setup display permissions for both local and Docker access
setup_display_permissions() {
    local display_num=$1
    local enable_docker=${2:-true}
    
    log_info "Setting up permissions for display :$display_num"
    
    # Basic local permissions
    if runuser -u "$USERNAME" -- env DISPLAY=":$display_num" xhost +local: >/dev/null 2>&1; then
        log_success "Local access enabled for :$display_num"
    else
        log_warning "Failed to enable local access for :$display_num"
    fi
    
    # User-specific permissions
    if runuser -u "$USERNAME" -- env DISPLAY=":$display_num" xhost +"SI:localuser:$USERNAME" >/dev/null 2>&1; then
        log_success "User $USERNAME access enabled for :$display_num"
    else
        log_warning "Failed to enable user access for :$display_num"
    fi
    
    # Docker-specific permissions
    if [[ "$enable_docker" == "true" && "$DOCKER_ENABLED" == "true" ]]; then
        # Enable Docker access
        if runuser -u "$USERNAME" -- env DISPLAY=":$display_num" xhost +local:docker >/dev/null 2>&1; then
            log_docker "Docker access enabled for :$display_num"
        else
            log_warning "Failed to enable Docker access for :$display_num"
        fi
        
        # Additional container-friendly permissions
        if runuser -u "$USERNAME" -- env DISPLAY=":$display_num" xhost +local:root >/dev/null 2>&1; then
            log_docker "Container root access enabled for :$display_num"
        else
            log_warning "Failed to enable container root access for :$display_num"
        fi
        
        # Set up X11 socket permissions for containers
        local x11_socket="/tmp/.X11-unix/X${display_num}"
        if [[ -S "$x11_socket" ]]; then
            chmod 777 "$x11_socket" 2>/dev/null || true
            log_docker "X11 socket permissions updated for containers"
        fi
    fi
}

# Stop virtual display
stop_virtual_display() {
    local display_num=$1
    local pid_file="/var/run/xvfb_${display_num}.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping virtual display :$display_num (PID: $pid)"
            kill "$pid"
            rm -f "$pid_file"
            log_success "Display :$display_num stopped"
        else
            log_warning "Display :$display_num process not running"
            rm -f "$pid_file"
        fi
    else
        # Try to find and kill any Xvfb process for this display
        local xvfb_pid=$(pgrep -f "Xvfb :$display_num" || true)
        if [[ -n "$xvfb_pid" ]]; then
            log_info "Found orphaned Xvfb process for :$display_num (PID: $xvfb_pid)"
            kill "$xvfb_pid"
            log_success "Orphaned display :$display_num stopped"
        else
            log_warning "No process found for display :$display_num"
        fi
    fi
    
    # Clean up log files
    rm -f "/var/log/xvfb_${display_num}.log"
}

# List active displays
list_displays() {
    echo "Active Displays:"
    echo "==============="
    
    # System display
    if timeout 3 xdpyinfo -display ":0" >/dev/null 2>&1; then
        local x0_access=$(runuser -u "$USERNAME" -- env DISPLAY=:0 xhost 2>/dev/null | grep -E "(local:|docker)" | wc -l || echo "0")
        echo "  :0 - System Display (Physical) - Access rules: $x0_access"
    fi
    
    # Virtual displays
    local found_displays=false
    for ((i=1; i<=MAX_DISPLAYS; i++)); do
        if ! is_display_available "$i"; then
            local pid_file="/var/run/xvfb_${i}.pid"
            local memory="N/A"
            local docker_access="No"
            
            if [[ -f "$pid_file" ]]; then
                local pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}' || echo "N/A")
                fi
            fi
            
            # Check Docker access
            if runuser -u "$USERNAME" -- env DISPLAY=":$i" xhost 2>/dev/null | grep -q "local:docker"; then
                docker_access="Yes"
            fi
            
            echo "  :$i - Virtual Display - Memory: $memory - Docker: $docker_access"
            found_displays=true
        fi
    done
    
    if [[ "$found_displays" == "false" ]]; then
        echo "  No virtual displays found"
    fi
    
    echo ""
    echo "Docker Status:"
    if [[ "$DOCKER_ENABLED" == "true" ]]; then
        echo "  ✓ Docker support enabled"
        echo "  ✓ User in docker group"
    else
        echo "  ✗ Docker support disabled"
        if ! command -v docker >/dev/null 2>&1; then
            echo "    - Docker not installed"
        else
            echo "    - User not in docker group"
        fi
    fi
    
    echo ""
    echo "Installation Status:"
    if check_installation; then
        echo "  ✓ Script installed at: $INSTALL_DIR/$SCRIPT_NAME"
    else
        echo "  ✗ Script not installed in system location"
    fi
}

# Start multiple displays
start_multiple_displays() {
    local count=${1:-$DEFAULT_DISPLAY_COUNT}
    local resolution=${2:-$DEFAULT_RESOLUTION}
    local enable_docker=${3:-true}
    
    log_info "Starting $count virtual displays with resolution $resolution"
    
    # Setup system display permissions first
    setup_display_permissions 0 "$enable_docker"
    
    # Start virtual displays
    local success_count=0
    for ((i=BASE_DISPLAY; i<BASE_DISPLAY+count; i++)); do
        if start_virtual_display "$i" "$resolution" "$enable_docker"; then
            success_count=$((success_count + 1))
        fi
        sleep 1  # Brief delay between starts
    done
    
    log_success "Successfully started $success_count out of $count displays"
    
    if [[ "$DOCKER_ENABLED" == "true" ]]; then
        log_docker "Docker containers can now access displays using:"
        log_docker "  docker run -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix ..."
    fi
}

# Stop all virtual displays
stop_all_displays() {
    log_info "Stopping all virtual displays"
    
    local stopped_count=0
    for ((i=1; i<=MAX_DISPLAYS; i++)); do
        if ! is_display_available "$i"; then
            stop_virtual_display "$i"
            stopped_count=$((stopped_count + 1))
        fi
    done
    
    log_success "Stopped $stopped_count virtual displays"
}

# Create enhanced systemd service for multi-display
create_systemd_service() {
    local service_path="/etc/systemd/system/dk-multi-display.service"
    local display_count=${1:-$DEFAULT_DISPLAY_COUNT}
    local script_path="$INSTALL_DIR/$SCRIPT_NAME"
    
    log_info "Creating systemd service for $display_count displays"
    
    # Ensure script is installed first
    if ! check_installation; then
        log_info "Installing script to system location first..."
        if ! install_script; then
            log_error "Failed to install script"
            return 1
        fi
    fi

    cat <<EOF > "$service_path"
[Unit]
Description=Multi-Display X Server with Docker Support
After=display-manager.service graphical.target docker.service
PartOf=graphical.target
Wants=docker.service

[Service]
Type=forking
ExecStart=$script_path start-service $display_count
ExecReload=$script_path restart-service $display_count
ExecStop=$script_path stop-all
User=root
Restart=on-failure
RestartSec=10
TimeoutStartSec=60
Environment=HOME=$USER_HOME
PIDFile=/var/run/dk-multi-display.pid

[Install]
WantedBy=graphical.target
EOF

    chmod 644 "$service_path"
    
    if systemctl daemon-reload 2>/dev/null; then
        log_success "Systemd service created: dk-multi-display.service"
        log_success "Script path: $script_path"
        log_info "Enable with: sudo systemctl enable dk-multi-display"
        log_info "Start with: sudo systemctl start dk-multi-display"
        
        # Test the service file
        if systemctl status dk-multi-display >/dev/null 2>&1; then
            log_success "Service file syntax is valid"
        else
            log_warning "Service file may have issues, check with: systemctl status dk-multi-display"
        fi
    else
        log_warning "Failed to reload systemd daemon"
    fi
}

# Create Docker helper script
create_docker_helper() {
    local script_path="$USER_HOME/docker-display-run.sh"
    
    log_docker "Creating Docker helper script"
    
    cat <<EOF > "$script_path"
#!/bin/bash
# Docker Display Helper Script
# Auto-generated by dk_enable_xhost.sh

# Usage: ./docker-display-run.sh <display_num> <image> [command]

DISPLAY_NUM=\${1:-1}
IMAGE=\${2:-ubuntu:20.04}
COMMAND=\${3:-bash}

if [[ -z "\$IMAGE" ]]; then
    echo "Usage: \$0 <display_num> <image> [command]"
    echo "Example: \$0 1 my-qt-app python3 app.py"
    exit 1
fi

# Check if display exists
if ! xdpyinfo -display ":\$DISPLAY_NUM" >/dev/null 2>&1; then
    echo "Error: Display :\$DISPLAY_NUM is not available"
    echo "Available displays:"
    for i in {0..10}; do
        if xdpyinfo -display ":\$i" >/dev/null 2>&1; then
            echo "  :\$i"
        fi
    done
    exit 1
fi

# Docker run with X11 forwarding
echo "Starting container on display :\$DISPLAY_NUM"
docker run -it --rm \\
    -e DISPLAY=":\$DISPLAY_NUM" \\
    -e QT_X11_NO_MITSHM=1 \\
    -e QT_QUICK_BACKEND=software \\
    -v /tmp/.X11-unix:/tmp/.X11-unix \\
    -v /dev/shm:/dev/shm \\
    --user \$(id -u):\$(id -g) \\
    --network host \\
    "\$IMAGE" \\
    \$COMMAND
EOF

    chmod +x "$script_path"
    chown "$USERNAME:$USERNAME" "$script_path"
    
    log_docker "Docker helper created: $script_path"
}

# Create Docker Compose template
create_docker_compose_template() {
    local compose_path="$USER_HOME/docker-compose-multi-display.yml"
    
    log_docker "Creating Docker Compose template"
    
    cat <<EOF > "$compose_path"
# Multi-Display Docker Compose Template
# Auto-generated by dk_enable_xhost.sh

version: '3.8'

services:
  qt-app-1:
    image: your-qt-app:latest
    environment:
      - DISPLAY=:1
      - QT_X11_NO_MITSHM=1
      - QT_QUICK_BACKEND=software
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /dev/shm:/dev/shm
    user: "$USER_ID:$USER_GID"
    network_mode: host
    restart: unless-stopped
    
  qt-app-2:
    image: your-qt-app:latest
    environment:
      - DISPLAY=:2
      - QT_X11_NO_MITSHM=1
      - QT_QUICK_BACKEND=software
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /dev/shm:/dev/shm
    user: "$USER_ID:$USER_GID"
    network_mode: host
    restart: unless-stopped
    
  qt-app-3:
    image: your-qt-app:latest
    environment:
      - DISPLAY=:3
      - QT_X11_NO_MITSHM=1
      - QT_QUICK_BACKEND=software
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /dev/shm:/dev/shm
    user: "$USER_ID:$USER_GID"
    network_mode: host
    restart: unless-stopped
    
  qt-app-4:
    image: your-qt-app:latest
    environment:
      - DISPLAY=:4
      - QT_X11_NO_MITSHM=1
      - QT_QUICK_BACKEND=software
    volumes:
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /dev/shm:/dev/shm
    user: "$USER_ID:$USER_GID"
    network_mode: host
    restart: unless-stopped

# Usage:
# 1. Replace 'your-qt-app:latest' with your actual image
# 2. Start services: docker-compose -f $compose_path up -d
# 3. Scale services: docker-compose -f $compose_path up -d --scale qt-app-1=2
# 4. View logs: docker-compose -f $compose_path logs -f qt-app-1
EOF

    chown "$USERNAME:$USERNAME" "$compose_path"
    
    log_docker "Docker Compose template created: $compose_path"
}

# Service management functions
start_service() {
    local count=${1:-$DEFAULT_DISPLAY_COUNT}
    echo $$ > "/var/run/dk-multi-display.pid"
    start_multiple_displays "$count"
}

restart_service() {
    local count=${1:-$DEFAULT_DISPLAY_COUNT}
    stop_all_displays
    sleep 3
    start_multiple_displays "$count"
}

# Test Docker X11 connectivity
test_docker_display() {
    local display_num=${1:-1}
    
    if [[ "$DOCKER_ENABLED" != "true" ]]; then
        log_error "Docker is not enabled"
        return 1
    fi
    
    log_docker "Testing Docker X11 connectivity on display :$display_num"
    
    # Test with simple X11 app
    if docker run --rm \
        -e DISPLAY=":$display_num" \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        --network host \
        ubuntu:20.04 \
        bash -c "apt-get update -qq && apt-get install -y -qq x11-apps && xeyes" >/dev/null 2>&1; then
        log_docker "Docker X11 test successful on display :$display_num"
        return 0
    else
        log_error "Docker X11 test failed on display :$display_num"
        log_info "Troubleshooting:"
        log_info "1. Check if display :$display_num is running: xdpyinfo -display :$display_num"
        log_info "2. Check xhost permissions: xhost"
        log_info "3. Verify Docker permissions: docker run --rm ubuntu:20.04 whoami"
        return 1
    fi
}

# Uninstall service and script
uninstall() {
    log_info "Uninstalling dk-multi-display service and script"
    
    # Stop and disable service
    if systemctl is-active --quiet dk-multi-display; then
        systemctl stop dk-multi-display
    fi
    
    if systemctl is-enabled --quiet dk-multi-display; then
        systemctl disable dk-multi-display
    fi
    
    # Remove service file
    if [[ -f "/etc/systemd/system/dk-multi-display.service" ]]; then
        rm -f "/etc/systemd/system/dk-multi-display.service"
        systemctl daemon-reload
        log_success "Service file removed"
    fi
    
    # Remove symlink
    if [[ -L "/usr/local/bin/dk-multi-display" ]]; then
        rm -f "/usr/local/bin/dk-multi-display"
        log_success "Symlink removed"
    fi
    
    # Stop all displays
    stop_all_displays
    
    log_success "Uninstallation complete"
    log_info "Script files in $INSTALL_DIR are preserved"
}

# Usage information
usage() {
    echo "Enhanced Multi-Display X Host Setup with Docker Support"
    echo "Usage: sudo $0 <command> [options]"
    echo ""
    echo "Display Management:"
    echo "  start [count] [resolution]    - Start multiple displays (default: 4, 1280x720x24)"
    echo "  stop <display_num>           - Stop specific display"
    echo "  stop-all                     - Stop all virtual displays"
    echo "  list                         - List active displays and permissions"
    echo "  setup-permissions <display>  - Setup permissions for specific display"
    echo ""
    echo "Installation:"
    echo "  install-script               - Install script to ~/.dk/sys-service/"
    echo "  install-service [count]      - Install systemd service"
    echo "  uninstall                    - Remove service and cleanup"
    echo ""
    echo "Docker Integration:"
    echo "  test-docker [display]        - Test Docker X11 connectivity"
    echo "  create-docker-helper         - Create Docker helper script"
    echo "  create-docker-compose        - Create Docker Compose template"
    echo ""
    echo "Service Management:"
    echo "  start-service [count]        - Start as service (internal)"
    echo "  restart-service [count]      - Restart service (internal)"
    echo ""
    echo "Legacy Support:"
    echo "  legacy                       - Run original single-display setup"
    echo ""
    echo "Examples:"
    echo "  sudo $0 install-service 4           # Install service for 4 displays"
    echo "  sudo $0 start 6                     # Start 6 virtual displays"
    echo "  sudo $0 start 3 1920x1080x24       # Start 3 displays with 1080p"
    echo "  sudo $0 create-docker-helper        # Create Docker helper script"
    echo "  sudo $0 test-docker 1               # Test Docker on display :1"
    echo ""
    echo "After Installation:"
    echo "  sudo systemctl enable dk-multi-display   # Enable auto-start"
    echo "  sudo systemctl start dk-multi-display    # Start service"
    echo "  sudo systemctl status dk-multi-display   # Check status"
    echo ""
    echo "Docker Usage:"
    echo "  docker run -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix your-qt-app"
    echo "  ./docker-display-run.sh 2 my-app python3 app.py"
}

# Main execution
main() {
    # Always check root and setup user variables
    check_root
    check_docker
    
    case "${1:-}" in
        install-script)
            install_script
            ;;
        start)
            start_multiple_displays "${2:-$DEFAULT_DISPLAY_COUNT}" "${3:-$DEFAULT_RESOLUTION}"
            create_docker_helper
            ;;
        stop)
            if [[ -n "${2:-}" ]]; then
                stop_virtual_display "$2"
            else
                log_error "Display number required"
                exit 1
            fi
            ;;
        stop-all)
            stop_all_displays
            ;;
        list)
            list_displays
            ;;
        setup-permissions)
            if [[ -n "${2:-}" ]]; then
                setup_display_permissions "$2" true
            else
                log_error "Display number required"
                exit 1
            fi
            ;;
        test-docker)
            test_docker_display "${2:-1}"
            ;;
        create-docker-helper)
            create_docker_helper
            ;;
        create-docker-compose)
            create_docker_compose_template
            ;;
        install-service)
            create_systemd_service "${2:-$DEFAULT_DISPLAY_COUNT}"
            ;;
        start-service)
            start_service "${2:-$DEFAULT_DISPLAY_COUNT}"
            ;;
        restart-service)
            restart_service "${2:-$DEFAULT_DISPLAY_COUNT}"
            ;;
        uninstall)
            uninstall
            ;;
        legacy)
            log_info "Running legacy single-display setup..."
            # Run original functionality here - setup for :0 only
            setup_display_permissions 0 true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
