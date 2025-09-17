#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# Improved xhost setup script for Linux environments with Qt XCB support
# Supports multiple Linux distributions and desktop environments
# Handles Qt platform plugin issues and XCB connection problems

set -uo pipefail  # Remove -e to prevent exit on non-critical errors

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Simplified check_root function
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        log_info "Usage: sudo $0"
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
    
    # Set the global USERNAME variable
    USERNAME="$detected_user"
    USER_HOME="$user_home"
    
    log_info "User home directory: $USER_HOME"
}

# Detect Linux distribution
detect_distro() {
    if [[ -f "/etc/os-release" ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f "/etc/redhat-release" ]]; then
        echo "rhel"
    elif [[ -f "/etc/debian_version" ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Get distribution version
get_distro_version() {
    if [[ -f "/etc/os-release" ]]; then
        . /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

# Detect desktop environment
detect_desktop_environment() {
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]'
    elif command -v gnome-session >/dev/null 2>&1; then
        echo "gnome"
    elif command -v kde-session >/dev/null 2>&1; then
        echo "kde"
    elif command -v xfce4-session >/dev/null 2>&1; then
        echo "xfce"
    else
        echo "unknown"
    fi
}

# Check if X11 is available
check_x11() {
    if ! command -v xhost >/dev/null 2>&1; then
        log_error "xhost command not found. Please install X11 utilities."
        case "$DISTRO" in
            ubuntu|debian)
                log_info "Install with: sudo apt-get install x11-xserver-utils"
                ;;
            fedora|centos|rhel)
                log_info "Install with: sudo dnf install xorg-x11-server-utils"
                ;;
            arch)
                log_info "Install with: sudo pacman -S xorg-xhost"
                ;;
        esac
        return 1
    fi
    return 0
}

# Create systemd service
create_systemd_service() {
    local service_path="/etc/systemd/system/dk-xhost-allow.service"
    log_info "Creating systemd service at $service_path"

    cat <<EOF > "$service_path"
[Unit]
Description=Allow local connections to X server
After=display-manager.service graphical.target
PartOf=graphical.target
Requisite=display-manager.service

[Service]
Type=oneshot
ExecStart=/usr/bin/xhost +local:
User=$USERNAME
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$USERNAME/.Xauthority
RemainAfterExit=yes
TimeoutSec=30

[Install]
WantedBy=graphical.target
EOF

    # Set proper permissions
    chmod 644 "$service_path"
    
    # Reload systemd and enable service (don't fail script on errors)
    if systemctl daemon-reload 2>/dev/null; then
        log_success "Systemd daemon reloaded"
    else
        log_warning "Failed to reload systemd daemon, continuing..."
        return 0  # Don't fail the script
    fi

    if systemctl enable dk-xhost-allow.service 2>/dev/null; then
        log_success "Service enabled successfully"
    else
        log_warning "Failed to enable dk-xhost-allow.service, continuing..."
        return 0  # Don't fail the script
    fi
}

# Update create_xhost_script to use USER_HOME
create_xhost_script() {
    local script_path="$USER_HOME/xhost-allow.sh"
    log_info "Creating enhanced xhost script with Qt support at $script_path"

    cat <<EOF > "$script_path"
#!/bin/bash
# Allow local connections to X server with Qt XCB support
# Auto-generated by dk-xhost-allow setup script

# Wait for X server to be ready
timeout=30
while [ \$timeout -gt 0 ]; do
    if xset q >/dev/null 2>&1; then
        break
    fi
    sleep 1
    timeout=\$((timeout - 1))
done

# Set display if not set
if [[ -z "\${DISPLAY:-}" ]]; then
    export DISPLAY=:0
fi

# Set up Qt environment
source "\$HOME/.config/qt_environment.sh" 2>/dev/null || true

# Allow local connections
if command -v xhost >/dev/null 2>&1; then
    xhost +local: >/dev/null 2>&1 || {
        echo "Warning: Failed to execute xhost +local:"
        exit 1
    }
    echo "X server local access enabled"
    
    # Test Qt connectivity
    if [[ -f "\$HOME/.config/qt_environment.sh" ]]; then
        echo "Qt environment configured for XCB support"
    fi
else
    echo "Error: xhost command not found"
    exit 1
fi

# Additional X server permissions for containers
xhost +SI:localuser:\$(whoami) >/dev/null 2>&1 || true
EOF

    chmod +x "$script_path"
    chown "$USERNAME:$USERNAME" "$script_path"
    log_success "Enhanced xhost script created and made executable"
}

# Update create_autostart_entry to use USER_HOME
create_autostart_entry() {
    local autostart_dir="$USER_HOME/.config/autostart"
    local desktop_file="$autostart_dir/xhost-allow.desktop"
    
    log_info "Creating autostart entry for desktop environment: $DESKTOP_ENV"
    
    # Create autostart directory
    mkdir -p "$autostart_dir"
    
    case "$DESKTOP_ENV" in
        gnome|unity|cinnamon|mate|xfce|lxde|lxqt)
            # Standard XDG autostart
            cat <<EOF > "$desktop_file"
[Desktop Entry]
Type=Application
Exec=$USER_HOME/xhost-allow.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-MATE-Autostart-enabled=true
StartupNotify=false
Name=Xhost Allow Local Access
Comment=Allow local X server connections for containerized applications
Categories=System;
EOF
            ;;
        kde|plasma)
            # KDE Plasma autostart
            cat <<EOF > "$desktop_file"
[Desktop Entry]
Type=Application
Exec=$USER_HOME/xhost-allow.sh
Hidden=false
NoDisplay=false
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
Name=Xhost Allow Local Access
Comment=Allow local X server connections for containerized applications
Categories=System;
EOF
            ;;
        *)
            # Generic autostart entry
            log_warning "Unknown desktop environment, creating generic autostart entry"
            cat <<EOF > "$desktop_file"
[Desktop Entry]
Type=Application
Exec=$USER_HOME/xhost-allow.sh
Hidden=false
NoDisplay=false
StartupNotify=false
Name=Xhost Allow Local Access
Comment=Allow local X server connections for containerized applications
Categories=System;
EOF
            ;;
    esac
    
    # Set proper ownership and permissions
    chown "$USERNAME:$USERNAME" "$desktop_file"
    chmod 644 "$desktop_file"
    chown -R "$USERNAME:$USERNAME" "$autostart_dir"
    
    log_success "Autostart entry created"
}

# Update create_user_session_script to use USER_HOME
create_user_session_script() {
    local profile_script="$USER_HOME/.profile_xhost"
    
    log_info "Creating enhanced user session script with Qt support"
    
    cat <<EOF > "$profile_script"
# Auto-generated xhost and Qt configuration
# Source this file or add to your shell profile

# Qt Environment Setup
if [[ -f "\$HOME/.config/qt_environment.sh" ]]; then
    source "\$HOME/.config/qt_environment.sh"
fi

# Function to enable xhost local access
enable_xhost_local() {
    if [[ -n "\${DISPLAY:-}" ]] && command -v xhost >/dev/null 2>&1; then
        xhost +local: >/dev/null 2>&1 && echo "X server local access enabled"
        xhost +SI:localuser:\$(whoami) >/dev/null 2>&1 || true
    fi
}

# Function to diagnose Qt issues
diagnose_qt() {
    if [[ -f "\$HOME/qt_troubleshoot.sh" ]]; then
        "\$HOME/qt_troubleshoot.sh"
    else
        echo "Qt troubleshooting script not found"
    fi
}

# Enable on login if X session is active
if [[ -n "\${DISPLAY:-}" ]]; then
    enable_xhost_local
fi

# Export functions
export -f enable_xhost_local diagnose_qt
EOF

    chown "$USERNAME:$USERNAME" "$profile_script"
    chmod 644 "$profile_script"
    
    log_success "Enhanced user session script created"
}

# New Qt-specific functions

# Detect Qt installation and platform plugins
detect_qt_environment() {
    log_info "Detecting Qt environment and platform plugins"
    
    local qt_info=""
    local qt_platforms=""
    
    # Check for Qt installations
    if command -v qmake >/dev/null 2>&1; then
        qt_info=$(qmake -version 2>/dev/null | head -n1)
        log_info "Found Qt: $qt_info"
    fi
    
    # Look for Qt platform plugins in common locations
    local qt_plugin_paths=(
        "/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms"
        "/usr/lib/qt5/plugins/platforms"
        "/usr/lib64/qt5/plugins/platforms"
        "/usr/lib/x86_64-linux-gnu/qt6/plugins/platforms"
        "/usr/lib/qt6/plugins/platforms"
        "/usr/lib64/qt6/plugins/platforms"
        "/opt/qt*/plugins/platforms"
    )
    
    for path in "${qt_plugin_paths[@]}"; do
        if [[ -d "$path" ]]; then
            local plugins=$(ls "$path" 2>/dev/null | grep -E '\.(so|dylib)$' | sed 's/lib//g' | sed 's/\.so.*//g' | tr '\n' ' ')
            if [[ -n "$plugins" ]]; then
                log_info "Found Qt plugins in $path: $plugins"
                qt_platforms="$qt_platforms $plugins"
            fi
        fi
    done
    
    echo "$qt_platforms"
}

# Check XCB connectivity and X11 setup
check_xcb_connectivity() {
    log_info "Checking XCB and X11 connectivity"
    
    # Check if DISPLAY is set
    if [[ -z "${DISPLAY:-}" ]]; then
        log_warning "DISPLAY environment variable is not set"
        return 1
    fi
    
    # Check X server connectivity
    if ! timeout 5 xset q >/dev/null 2>&1; then
        log_warning "Cannot connect to X server on $DISPLAY"
        return 1
    fi
    
    # Check X11 socket
    local x11_socket="/tmp/.X11-unix/X${DISPLAY#*:}"
    x11_socket="${x11_socket%.*}"  # Remove screen number if present
    
    if [[ ! -S "$x11_socket" ]]; then
        log_warning "X11 socket $x11_socket not found"
        return 1
    fi
    
    # Check Xauthority
    if [[ -n "${XAUTHORITY:-}" ]] && [[ ! -f "$XAUTHORITY" ]]; then
        log_warning "XAUTHORITY file $XAUTHORITY not found"
        return 1
    fi
    
    log_success "XCB/X11 connectivity check passed"
    return 0
}

# Install missing Qt and XCB dependencies
install_qt_dependencies() {
    log_info "Installing Qt and XCB dependencies"
    
    case "$DISTRO" in
        ubuntu|debian)
            local packages=(
                "libqt5gui5"
                "libqt5widgets5"
                "libqt5core5a"
                "qt5-qmake"
                "libxcb1"
                "libxcb-xinerama0"
                "libxcb-randr0"
                "libxcb-render0"
                "libxcb-shape0"
                "libxcb-sync1"
                "libxcb-xfixes0"
                "libxcb-shm0"
                "libxcb-glx0"
                "libxcb-keysyms1"
                "libxcb-image0"
                "libxcb-icccm4"
                "libxcb-util1"
                "libgl1-mesa-glx"
                "libglib2.0-0"
                "libfontconfig1"
                "libdbus-1-3"
            )
            
            log_info "Installing packages: ${packages[*]}"
            if apt-get update >/dev/null 2>&1 && apt-get install -y "${packages[@]}" >/dev/null 2>&1; then
                log_success "Qt/XCB dependencies installed successfully"
            else
                log_warning "Some Qt/XCB dependencies may not have installed correctly"
            fi
            ;;
        fedora|centos|rhel)
            local packages=(
                "qt5-qtbase"
                "qt5-qtbase-gui"
                "libxcb"
                "xcb-util"
                "xcb-util-keysyms"
                "xcb-util-image"
                "xcb-util-wm"
                "xcb-util-renderutil"
                "mesa-libGL"
                "fontconfig"
                "dbus-libs"
            )
            
            log_info "Installing packages: ${packages[*]}"
            if dnf install -y "${packages[@]}" >/dev/null 2>&1 || yum install -y "${packages[@]}" >/dev/null 2>&1; then
                log_success "Qt/XCB dependencies installed successfully"
            else
                log_warning "Some Qt/XCB dependencies may not have installed correctly"
            fi
            ;;
        arch)
            local packages=(
                "qt5-base"
                "libxcb"
                "xcb-util"
                "xcb-util-keysyms"
                "xcb-util-image"
                "xcb-util-wm"
                "xcb-util-renderutil"
                "mesa"
                "fontconfig"
                "dbus"
            )
            
            log_info "Installing packages: ${packages[*]}"
            if pacman -S --noconfirm "${packages[@]}" >/dev/null 2>&1; then
                log_success "Qt/XCB dependencies installed successfully"
            else
                log_warning "Some Qt/XCB dependencies may not have installed correctly"
            fi
            ;;
        *)
            log_warning "Automatic Qt/XCB dependency installation not supported for $DISTRO"
            log_info "Please install Qt5/Qt6 base packages and XCB libraries manually"
            ;;
    esac
}

# Create Qt environment configuration
create_qt_environment_script() {
    local qt_script="$USER_HOME/.config/qt_environment.sh"
    local qt_config_dir="$USER_HOME/.config"
    
    log_info "Creating Qt environment configuration"
    
    mkdir -p "$qt_config_dir"
    
    cat <<EOF > "$qt_script"
#!/bin/bash
# Qt Environment Configuration
# Auto-generated by dk-xhost-allow setup script

# Set Qt platform plugin path
export QT_QPA_PLATFORM_PLUGIN_PATH="/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms:/usr/lib/qt5/plugins/platforms:/usr/lib64/qt5/plugins/platforms:/usr/lib/x86_64-linux-gnu/qt6/plugins/platforms:/usr/lib/qt6/plugins/platforms:/usr/lib64/qt6/plugins/platforms"

# Prefer XCB platform but provide fallbacks
export QT_QPA_PLATFORM="xcb"

# XCB debugging (comment out for production)
# export QT_LOGGING_RULES="qt.qpa.xcb.debug=true"

# Font configuration
export QT_FONT_DPI=96
export QT_AUTO_SCREEN_SCALE_FACTOR=0

# XCB specific settings
export QT_XCB_GL_INTEGRATION="xcb_egl"

# Fallback platform options (uncomment if XCB fails)
# export QT_QPA_PLATFORM="wayland;xcb"  # Try Wayland first, then XCB
# export QT_QPA_PLATFORM="offscreen"    # For headless environments
# export QT_QPA_PLATFORM="vnc"          # For VNC environments
# export QT_QPA_PLATFORM="eglfs"        # For embedded systems

# Function to test Qt platform
test_qt_platform() {
    echo "Testing Qt platform: \$QT_QPA_PLATFORM"
    echo "Available platforms: \$(qt5-config --platforms 2>/dev/null || echo 'qt5-config not available')"
    
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
try:
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    print('Qt platform test: SUCCESS')
    app.quit()
except Exception as e:
    print(f'Qt platform test: FAILED - {e}')
" 2>/dev/null || echo "PyQt5 not available for testing"
    fi
}

# Export function for use in shells
export -f test_qt_platform
EOF

    chown "$USERNAME:$USERNAME" "$qt_script"
    chmod +x "$qt_script"
    
    log_success "Qt environment script created"
}

# Create comprehensive Qt troubleshooting script
create_qt_troubleshoot_script() {
    local troubleshoot_script="$USER_HOME/qt_troubleshoot.sh"
    
    log_info "Creating Qt troubleshooting script"
    
    cat <<EOF > "$troubleshoot_script"
#!/bin/bash
# Qt XCB Troubleshooting Script
# Auto-generated by dk-xhost-allow setup script

echo "=== Qt XCB Troubleshooting Report ==="
echo "Date: \$(date)"
echo

echo "1. Environment Variables:"
echo "   DISPLAY: \${DISPLAY:-'NOT SET'}"
echo "   XAUTHORITY: \${XAUTHORITY:-'NOT SET'}"
echo "   QT_QPA_PLATFORM: \${QT_QPA_PLATFORM:-'NOT SET'}"
echo "   QT_QPA_PLATFORM_PLUGIN_PATH: \${QT_QPA_PLATFORM_PLUGIN_PATH:-'NOT SET'}"
echo

echo "2. X Server Connectivity:"
if xset q >/dev/null 2>&1; then
    echo "   ✓ X server is accessible"
    echo "   Display info: \$(xset q | grep -E 'auto repeat|DPMS' | head -n1)"
else
    echo "   ✗ Cannot connect to X server"
fi
echo

echo "3. X11 Socket:"
local x11_socket="/tmp/.X11-unix/X\${DISPLAY#*:}"
x11_socket="\${x11_socket%.*}"
if [[ -S "\$x11_socket" ]]; then
    echo "   ✓ X11 socket exists: \$x11_socket"
    echo "   Permissions: \$(ls -la \$x11_socket)"
else
    echo "   ✗ X11 socket not found: \$x11_socket"
fi
echo

echo "4. Xauthority:"
if [[ -n "\${XAUTHORITY:-}" ]] && [[ -f "\$XAUTHORITY" ]]; then
    echo "   ✓ Xauthority file exists: \$XAUTHORITY"
    echo "   Permissions: \$(ls -la \$XAUTHORITY)"
else
    echo "   ✗ Xauthority file issue"
    echo "   Alternative locations:"
    for auth_file in "\$HOME/.Xauthority" "/tmp/.X*auth*"; do
        if [[ -f "\$auth_file" ]]; then
            echo "     Found: \$auth_file"
        fi
    done
fi
echo

echo "5. Qt Platform Plugins:"
for plugin_path in "/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms" "/usr/lib/qt5/plugins/platforms" "/usr/lib64/qt5/plugins/platforms" "/usr/lib/x86_64-linux-gnu/qt6/plugins/platforms" "/usr/lib/qt6/plugins/platforms" "/usr/lib64/qt6/plugins/platforms"; do
    if [[ -d "\$plugin_path" ]]; then
        echo "   Found plugins in: \$plugin_path"
        ls -la "\$plugin_path" | grep -E '\.(so|dylib)\$' | awk '{print "     " \$9}'
    fi
done
echo

echo "6. XCB Libraries:"
for lib in libxcb.so libxcb-xinerama.so libQt5XcbQpa.so; do
    if ldconfig -p | grep -q "\$lib"; then
        echo "   ✓ \$lib is available"
    else
        echo "   ✗ \$lib not found"
    fi
done
echo

echo "7. Suggested Solutions:"
echo "   If XCB fails, try these environment variables:"
echo "   export QT_QPA_PLATFORM=wayland      # Use Wayland instead"
echo "   export QT_QPA_PLATFORM=offscreen    # Headless mode"
echo "   export QT_QPA_PLATFORM=vnc          # VNC mode"
echo "   export QT_DEBUG_PLUGINS=1           # Debug plugin loading"
echo
echo "   Or install missing dependencies:"
echo "   sudo apt install libqt5gui5 libxcb1 qt5-qmake  # Ubuntu/Debian"
echo "   sudo dnf install qt5-qtbase libxcb              # Fedora/RHEL"
echo

echo "8. Quick Test:"
if command -v python3 >/dev/null 2>&1; then
    echo "   Testing with Python/Qt..."
    python3 -c "
import sys
try:
    from PyQt5.QtWidgets import QApplication
    app = QApplication(sys.argv)
    print('   ✓ Qt/XCB test: SUCCESS')
    app.quit()
except ImportError:
    print('   - PyQt5 not installed')
except Exception as e:
    print(f'   ✗ Qt/XCB test: FAILED - {e}')
"
else
    echo "   Python3 not available for testing"
fi

echo
echo "=== End of Report ==="
EOF

    chown "$USERNAME:$USERNAME" "$troubleshoot_script"
    chmod +x "$troubleshoot_script"
    
    log_success "Qt troubleshooting script created"
}

# Main execution with better error handling
main() {
    log_info "Starting enhanced xhost and Qt XCB setup for Linux environment"
    
    # Initial checks (these should still fail the script)
    check_root
    
    log_info "Setting up for user: $USERNAME"
    log_info "User home directory: $USER_HOME"
    
    # Detect system information
    DISTRO=$(detect_distro)
    DISTRO_VERSION=$(get_distro_version)
    DESKTOP_ENV=$(detect_desktop_environment)
    
    log_info "Detected distribution: $DISTRO $DISTRO_VERSION"
    log_info "Detected desktop environment: $DESKTOP_ENV"
    
    # Check X11 availability (this should fail the script)
    if ! check_x11; then
        exit 1
    fi
    
    # Qt environment detection and setup
    QT_PLATFORMS=$(detect_qt_environment)
    if [[ -n "$QT_PLATFORMS" ]]; then
        log_info "Detected Qt platforms: $QT_PLATFORMS"
    else
        log_warning "No Qt platforms detected, will install dependencies"
        install_qt_dependencies
    fi
    
    # Check XCB connectivity
    if ! check_xcb_connectivity; then
        log_warning "XCB connectivity issues detected, but continuing with setup"
    fi
    
    # Track if any critical component failed
    local setup_success=true
    
    # Create Qt-specific components
    if ! create_qt_environment_script; then
        log_error "Failed to create Qt environment script"
        setup_success=false
    fi
    
    if ! create_qt_troubleshoot_script; then
        log_warning "Failed to create Qt troubleshooting script, but continuing"
    fi
    
    # Create components based on system capabilities
    case "$DISTRO" in
        ubuntu|debian|fedora|centos|rhel|arch|opensuse*)
            log_info "Supported distribution detected, proceeding with full setup"
            
            # Create systemd service (non-critical)
            if command -v systemctl >/dev/null 2>&1; then
                if ! create_systemd_service; then
                    log_warning "Systemd service creation had issues, but continuing"
                fi
            else
                log_warning "systemctl not found, skipping systemd service creation"
            fi
            
            # Create enhanced xhost script (critical)
            if ! create_xhost_script; then
                log_error "Failed to create xhost script"
                setup_success=false
            fi
            
            # Create autostart entry (critical)
            if ! create_autostart_entry; then
                log_error "Failed to create autostart entry"
                setup_success=false
            fi
            
            # Create enhanced user session script (non-critical)
            if ! create_user_session_script; then
                log_warning "Failed to create user session script, but continuing"
            fi
            ;;
        *)
            log_warning "Unknown or unsupported distribution: $DISTRO"
            log_info "Proceeding with basic setup"
            
            if ! create_xhost_script; then
                setup_success=false
            fi
            if ! create_autostart_entry; then
                setup_success=false
            fi
            create_user_session_script || true  # Don't fail on this
            ;;
    esac
    
    # Check overall success
    if [[ "$setup_success" == "true" ]]; then
        # Final instructions
        log_success "Enhanced setup completed successfully!"
        echo
        log_info "Next steps:"
        echo "  1. Reboot your system to apply all changes"
        echo "  2. Log into your desktop session"
        echo "  3. Verify xhost is working: xhost"
        echo "  4. Test Qt applications: \$HOME/qt_troubleshoot.sh"
        echo "  5. Test with containers: docker run --rm -e DISPLAY=\$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix <qt-app-image>"
        echo
        log_info "Qt XCB troubleshooting:"
        echo "  - Troubleshoot Qt issues: \$HOME/qt_troubleshoot.sh"
        echo "  - Qt environment config: \$HOME/.config/qt_environment.sh"
        echo "  - Manual activation: \$HOME/xhost-allow.sh"
        echo "  - Session profile: source \$HOME/.profile_xhost"
        echo
        log_info "If Qt XCB still fails, try these environment variables:"
        echo "  export QT_QPA_PLATFORM=wayland    # Use Wayland instead of X11"
        echo "  export QT_QPA_PLATFORM=offscreen  # For headless applications"
        echo "  export QT_DEBUG_PLUGINS=1         # Debug plugin loading issues"
        
        exit 0
    else
        log_error "Setup completed with errors. Some components may not work properly."
        log_info "Try running the troubleshooting script: \$HOME/qt_troubleshoot.sh"
        exit 1
    fi
}

# Run main function
main "$@"
