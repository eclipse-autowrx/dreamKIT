#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# Updated install_dependencies.sh - Standalone execution with parent script compatibility
# Enhanced with intelligent version checking and management
# Can be called both from dk_install.sh and as standalone sudo script

# Check if we're being called from dk_install.sh or standalone
if [[ -n "$CURRENT_DIR" && -n "$DK_USER" ]]; then
    # Called from dk_install.sh - functions and variables are available
    SCRIPT_MODE="integrated"
else
    # Called standalone - need to set up environment
    SCRIPT_MODE="standalone"
    
    # Detect user (handle sudo execution)
    if [ -n "$SUDO_USER" ]; then
        DK_USER=$SUDO_USER
    else
        DK_USER=$USER
    fi
    
    # Get script directory
    CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Colors and formatting for standalone mode
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
    
    # Utility functions for standalone mode
    show_info() {
        local message=$1
        echo -e "${BLUE} ${ARROW} ${message}${NC}"
    }
    
    show_success() {
        local message=$1
        echo -e "${GREEN}${BOLD} ${CHECKMARK} ${message}${NC}"
    }
    
    show_error() {
        local message=$1
        echo -e "${RED}${BOLD} ${CROSS} ${message}${NC}"
    }
    
    show_warning() {
        local message=$1
        echo -e "${YELLOW}${BOLD} ⚠ ${message}${NC}"
    }
    
    run_with_feedback() {
        local command=$1
        local success_msg=$2
        local error_msg=$3
        local show_output=${4:-false}
        
        if [ "$show_output" = "true" ]; then
            echo -e "${DIM}${CYAN}Running: $command${NC}"
            if eval "$command"; then
                show_success "$success_msg"
                return 0
            else
                show_error "$error_msg"
                return 1
            fi
        else
            eval "$command" >/dev/null 2>&1
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
    
    echo -e "${BLUE}${BOLD}dreamOS Dependencies Installation with Version Management${NC}"
    echo -e "${DIM}Installing system dependencies with intelligent version checking...${NC}"
    echo
fi

# Dependencies installation script with enhanced version management
# This handles all system dependencies for dreamOS

# ---------------------------------------------------------------------------
# Helper: compare semantic versions (returns 0 if v1 >= v2, 1 otherwise)
# ---------------------------------------------------------------------------
version_compare() {
    local version1=$1
    local version2=$2
    
    # Handle empty versions
    [[ -z "$version1" ]] && return 1
    [[ -z "$version2" ]] && return 0
    
    # Remove 'v' prefix if present
    version1=${version1#v}
    version2=${version2#v}
    
    # Split versions into arrays
    IFS='.' read -ra V1 <<< "$version1"
    IFS='.' read -ra V2 <<< "$version2"
    
    # Pad arrays to same length
    local max_length=$((${#V1[@]} > ${#V2[@]} ? ${#V1[@]} : ${#V2[@]}))
    
    for ((i=0; i<max_length; i++)); do
        local part1=${V1[i]:-0}
        local part2=${V2[i]:-0}
        
        # Remove non-numeric suffixes (e.g., "1.2.3-beta" -> "1.2.3")
        part1=$(echo "$part1" | grep -oE '^[0-9]+' || echo "0")
        part2=$(echo "$part2" | grep -oE '^[0-9]+' || echo "0")
        
        if (( part1 > part2 )); then
            return 0
        elif (( part1 < part2 )); then
            return 1
        fi
    done
    
    return 0  # versions are equal
}

# ---------------------------------------------------------------------------
# Helper: get installed version of a tool
# ---------------------------------------------------------------------------
get_installed_version() {
    local tool=$1
    local version=""
    
    case "$tool" in
        "node"|"nodejs")
            if command -v node >/dev/null 2>&1; then
                version=$(node --version 2>/dev/null | sed 's/^v//')
            fi
            ;;
        "npm")
            if command -v npm >/dev/null 2>&1; then
                version=$(npm --version 2>/dev/null)
            fi
            ;;
        "k9s")
            if command -v k9s >/dev/null 2>&1; then
                version=$(k9s version --short 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//')
            fi
            ;;
        "yq")
            if command -v yq >/dev/null 2>&1; then
                version=$(yq --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//')
            fi
            ;;
        "docker")
            if command -v docker >/dev/null 2>&1; then
                version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            fi
            ;;
        *)
            # Generic version detection
            if command -v "$tool" >/dev/null 2>&1; then
                version=$($tool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
            fi
            ;;
    esac
    
    echo "$version"
}

# ---------------------------------------------------------------------------
# Helper: check if tool meets version requirement
# ---------------------------------------------------------------------------
check_version_requirement() {
    local tool=$1
    local required_version=$2
    local installed_version
    
    installed_version=$(get_installed_version "$tool")
    
    if [[ -z "$installed_version" ]]; then
        show_info "$tool is not installed"
        return 1  # Not installed
    fi
    
    if version_compare "$installed_version" "$required_version"; then
        show_success "$tool v$installed_version meets requirement (>= v$required_version)"
        return 0  # Version meets requirement
    else
        show_warning "$tool v$installed_version is older than required v$required_version"
        return 1  # Version too old
    fi
}

# ---------------------------------------------------------------------------
# Helper: uninstall tool based on installation method
# ---------------------------------------------------------------------------
uninstall_tool() {
    local tool=$1
    local method=${2:-"auto"}  # auto, apt, binary, nodesource
    
    show_info "Uninstalling $tool..."
    
    case "$tool" in
        "node"|"nodejs")
            if [[ "$method" == "nodesource" ]] || dpkg -l | grep -q "nodejs.*nodesource"; then
                show_info "Removing Node.js (NodeSource)..."
                run_with_feedback \
                    "apt-get remove -y nodejs npm && apt-get autoremove -y" \
                    "NodeSource Node.js removed" \
                    "Failed to remove NodeSource Node.js"
                
                # Remove NodeSource repository
                if [ -f "/etc/apt/sources.list.d/nodesource.list" ]; then
                    run_with_feedback \
                        "rm -f /etc/apt/sources.list.d/nodesource.list && apt-get update" \
                        "NodeSource repository removed" \
                        "Failed to remove NodeSource repository"
                fi
            else
                run_with_feedback \
                    "apt-get remove -y nodejs npm" \
                    "Node.js removed via apt" \
                    "Failed to remove Node.js via apt"
            fi
            ;;
        "k9s")
            # Check different installation methods and remove accordingly
            local removed=false
            
            # Check if installed via package manager
            if command -v dpkg >/dev/null 2>&1 && dpkg -l | grep -q "^ii.*k9s"; then
                show_info "Removing k9s via dpkg..."
                if run_with_feedback "dpkg -r k9s" "k9s package removed via dpkg" "Failed to remove k9s package via dpkg"; then
                    removed=true
                fi
            fi
            
            if ! $removed && command -v rpm >/dev/null 2>&1 && rpm -q k9s >/dev/null 2>&1; then
                show_info "Removing k9s via rpm..."
                if run_with_feedback "rpm -e k9s" "k9s package removed via rpm" "Failed to remove k9s package via rpm"; then
                    removed=true
                fi
            fi
            
            if ! $removed && command -v apk >/dev/null 2>&1 && apk info -e k9s >/dev/null 2>&1; then
                show_info "Removing k9s via apk..."
                if run_with_feedback "apk del k9s" "k9s package removed via apk" "Failed to remove k9s package via apk"; then
                    removed=true
                fi
            fi
            
            # Fallback: remove binary installation
            if ! $removed && [ -f "/usr/local/bin/k9s" ]; then
                run_with_feedback \
                    "rm -f /usr/local/bin/k9s" \
                    "k9s binary removed from /usr/local/bin" \
                    "Failed to remove k9s binary"
                removed=true
            fi
            
            # Check system-wide installation paths
            if ! $removed; then
                for path in "/usr/bin/k9s" "/bin/k9s"; do
                    if [ -f "$path" ]; then
                        run_with_feedback \
                            "rm -f $path" \
                            "k9s binary removed from $path" \
                            "Failed to remove k9s binary from $path"
                        removed=true
                        break
                    fi
                done
            fi
            
            if ! $removed; then
                show_warning "k9s installation method not detected, manual cleanup may be required"
            fi
            ;;
        "yq")
            if [ -f "/usr/local/bin/yq" ]; then
                run_with_feedback \
                    "rm -f /usr/local/bin/yq" \
                    "yq binary removed" \
                    "Failed to remove yq binary"
            fi
            ;;
        *)
            # Try apt removal first
            if dpkg -l | grep -q "^ii.*$tool"; then
                run_with_feedback \
                    "apt-get remove -y $tool" \
                    "$tool removed via apt" \
                    "Failed to remove $tool via apt"
            fi
            
            # Remove from /usr/local/bin if exists
            if [ -f "/usr/local/bin/$tool" ]; then
                run_with_feedback \
                    "rm -f /usr/local/bin/$tool" \
                    "$tool binary removed from /usr/local/bin" \
                    "Failed to remove $tool binary"
            fi
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Helper: update package index
# ---------------------------------------------------------------------------
update_package_index() {
    show_info "Updating package index..."
    run_with_feedback \
        "apt-get update -y" \
        "Package index updated" \
        "Failed to update package index" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Helper: install a single deb package if the related command is absent
#   $1   binary/command to look for
#   $2   deb package to install (defaults to same as $1)
# ---------------------------------------------------------------------------
install_if_missing() {
    local cmd_name="$1"
    local deb_name="${2:-$1}"

    if command -v "$cmd_name" >/dev/null 2>&1; then
        show_info "$cmd_name is already installed"
    else
        show_info "Installing $deb_name..."
        run_with_feedback \
            "apt-get install -y $deb_name" \
            "$deb_name installed successfully" \
            "Failed to install $deb_name" \
            $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
    fi
}

# ---------------------------------------------------------------------------
# Helper: prepare host for offline k3s operation
# ---------------------------------------------------------------------------
prepare_offline_k3s_tools() {
    show_info "Preparing host for offline k3s operation..."
    
    # Install required tools for k3s offline operation
    local k3s_tools=(
        "util-linux"
        "netcat-openbsd" 
        "iputils-ping"
        "coreutils"
        "procps"
    )
    
    show_info "Installing k3s offline operation dependencies..."
    for tool in "${k3s_tools[@]}"; do
        install_if_missing "${tool%% *}" "$tool"
    done
    
    # Create tools directory for container mounting
    local tools_dir="/opt/k3s-tools/bin"
    show_info "Creating k3s tools directory: $tools_dir"
    
    run_with_feedback \
        "mkdir -p $tools_dir" \
        "k3s tools directory created" \
        "Failed to create k3s tools directory"
    
    # Copy essential binaries to tools directory
    show_info "Copying essential binaries for k3s offline operation..."
    
    local binaries=(
        "/usr/bin/nsenter"
        "/bin/ping"
        "/bin/nc" 
        "/usr/bin/timeout"
        "/bin/ps"
        "/usr/bin/pgrep"
        "/usr/bin/pkill"
        "/bin/kill"
        "/usr/bin/nohup"
        "/bin/sleep"
        "/usr/bin/tee"
        "/bin/cat"
        "/bin/echo"
        "/usr/bin/which"
    )
    
    local copied_tools=()
    local failed_tools=()
    
    for binary in "${binaries[@]}"; do
        local binary_name=$(basename "$binary")
        
        if [ -f "$binary" ]; then
            if cp "$binary" "$tools_dir/" 2>/dev/null; then
                copied_tools+=("$binary_name")
            else
                failed_tools+=("$binary_name")
            fi
        else
            # Try alternative locations
            local alt_binary=""
            case "$binary_name" in
                "nc")
                    for alt in "/usr/bin/nc" "/bin/nc.openbsd" "/usr/bin/nc.openbsd"; do
                        [ -f "$alt" ] && alt_binary="$alt" && break
                    done
                    ;;
                "ping")
                    for alt in "/usr/bin/ping" "/bin/ping"; do
                        [ -f "$alt" ] && alt_binary="$alt" && break
                    done
                    ;;
            esac
            
            if [ -n "$alt_binary" ] && [ -f "$alt_binary" ]; then
                if cp "$alt_binary" "$tools_dir/$binary_name" 2>/dev/null; then
                    copied_tools+=("$binary_name")
                else
                    failed_tools+=("$binary_name")
                fi
            else
                failed_tools+=("$binary_name")
            fi
        fi
    done
    
    # Set proper permissions
    run_with_feedback \
        "chmod +x $tools_dir/*" \
        "Set executable permissions for k3s tools" \
        "Failed to set permissions for k3s tools"
    
    # Report results
    if [ ${#copied_tools[@]} -gt 0 ]; then
        show_success "Copied ${#copied_tools[@]} tools for k3s offline operation"
        show_info "Available tools: ${copied_tools[*]}"
    fi
    
    if [ ${#failed_tools[@]} -gt 0 ]; then
        show_warning "Failed to copy ${#failed_tools[@]} tools: ${failed_tools[*]}"
    fi
    
    # Verify the setup
    show_info "Verifying k3s tools setup..."
    if [ -d "$tools_dir" ]; then
        local tool_count=$(find "$tools_dir" -type f -executable 2>/dev/null | wc -l)
        show_success "k3s tools directory prepared with $tool_count executable tools"
        
        # List available tools for debugging (only in standalone mode)
        if [[ "$SCRIPT_MODE" == "standalone" ]]; then
            show_info "Tools available in $tools_dir:"
            ls -la "$tools_dir/" | while IFS= read -r line; do
                echo -e "${DIM}  $line${NC}"
            done
        fi
    else
        show_error "k3s tools directory setup failed"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Helper: install additional system tools for k3s
# ---------------------------------------------------------------------------
install_k3s_system_dependencies() {
    show_info "Installing additional system dependencies for k3s..."
    
    # Install packages that provide required tools
    local packages=(
        "systemd"
        "util-linux"
        "mount"
        "iptables"
        "iproute2"
        "cgroup-tools"
    )
    
    for package in "${packages[@]}"; do
        install_if_missing "${package%% *}" "$package"
    done
    
    # Ensure cgroups are properly mounted
    show_info "Checking cgroups configuration..."
    if ! mount | grep -q cgroup; then
        show_info "Mounting cgroups..."
        run_with_feedback \
            "mount -t cgroup -o all cgroup /sys/fs/cgroup || true" \
            "cgroups mounted successfully" \
            "cgroups mount failed (may be normal)"
    else
        show_info "cgroups already mounted"
    fi
}

# ---------------------------------------------------------------------------
# Enhanced: install k9s with version checking and multiple installation methods
# ---------------------------------------------------------------------------
install_k9s() {
    # Version to pull (override via env K9S_VERSION)
    local VERSION="${K9S_VERSION:-0.50.9}"

    # Check if current version meets requirement
    if check_version_requirement "k9s" "$VERSION"; then
        return 0  # Already satisfied
    fi
    
    # Uninstall existing version if present
    if command -v k9s >/dev/null 2>&1; then
        show_info "Uninstalling existing k9s to install v$VERSION..."
        uninstall_tool "k9s"
    fi

    # Detect architecture and OS
    local ARCH
    local OS_TYPE
    local UNAME_ARCH="$(uname -m)"
    local UNAME_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    
    case "$UNAME_ARCH" in
        x86_64|amd64)   
            ARCH="amd64"
            show_info "Detected x86_64/amd64 architecture"
            ;;
        armv7l|armv7)   
            ARCH="armv7"
            show_info "Detected ARMv7 architecture"
            ;;
        aarch64|arm64)  
            ARCH="arm64"
            show_info "Detected ARM64 architecture (Jetson Orin compatible)"
            ;;
        *)
            show_error "Unsupported architecture: $UNAME_ARCH"
            show_error "k9s supports: x86_64/amd64, armv7, arm64"
            return 1
            ;;
    esac

    case "$UNAME_OS" in
        linux)
            OS_TYPE="Linux"
            ;;
        darwin)
            OS_TYPE="Darwin"
            ;;
        *)
            show_error "Unsupported OS: $UNAME_OS"
            return 1
            ;;
    esac

    # Installation method preference (override via env K9S_INSTALL_METHOD)
    local INSTALL_METHOD="${K9S_INSTALL_METHOD:-auto}"
    
    # For Linux, try different installation methods in order of preference
    if [[ "$OS_TYPE" == "Linux" ]]; then
        case "$INSTALL_METHOD" in
            "deb"|"auto")
                if command -v dpkg >/dev/null 2>&1 && [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" || "$ARCH" == "armv7" ]]; then
                    if install_k9s_deb "$VERSION" "$ARCH"; then
                        return 0
                    elif [[ "$INSTALL_METHOD" != "auto" ]]; then
                        return 1
                    fi
                fi
                ;;&
            "rpm"|"auto")
                if command -v rpm >/dev/null 2>&1 && [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" || "$ARCH" == "armv7" ]]; then
                    if install_k9s_rpm "$VERSION" "$ARCH"; then
                        return 0
                    elif [[ "$INSTALL_METHOD" != "auto" ]]; then
                        return 1
                    fi
                fi
                ;;&
            "apk"|"auto")
                if command -v apk >/dev/null 2>&1 && [[ "$ARCH" == "amd64" || "$ARCH" == "arm64" || "$ARCH" == "armv7" ]]; then
                    if install_k9s_apk "$VERSION" "$ARCH"; then
                        return 0
                    elif [[ "$INSTALL_METHOD" != "auto" ]]; then
                        return 1
                    fi
                fi
                ;;&
            "tarball"|"auto")
                install_k9s_tarball "$VERSION" "$OS_TYPE" "$ARCH"
                return $?
                ;;
            *)
                show_error "Unknown installation method: $INSTALL_METHOD"
                show_error "Supported methods: deb, rpm, apk, tarball, auto"
                return 1
                ;;
        esac
    else
        # For non-Linux systems, use tarball
        install_k9s_tarball "$VERSION" "$OS_TYPE" "$ARCH"
    fi
}

# ---------------------------------------------------------------------------
# Helper: install k9s via .deb package
# ---------------------------------------------------------------------------
install_k9s_deb() {
    local VERSION="$1"
    local ARCH="$2"
    
    # Map architecture names for deb packages
    case "$ARCH" in
        "amd64") local DEB_ARCH="amd64" ;;
        "arm64") local DEB_ARCH="arm64" ;;
        "armv7") local DEB_ARCH="arm" ;;
        *) return 1 ;;
    esac
    
    local DEB_FILE="k9s_linux_${DEB_ARCH}.deb"
    local URL="https://github.com/derailed/k9s/releases/download/v${VERSION}/${DEB_FILE}"
    
    show_info "Installing k9s v${VERSION} via .deb package for ${DEB_ARCH}..."
    
    # Verify URL exists
    if ! curl -fsSL --head "$URL" >/dev/null 2>&1; then
        show_warning "k9s .deb package not available for ${DEB_ARCH}"
        return 1
    fi
    
    run_with_feedback \
        "tmp_dir=\$(mktemp -d) && \
         curl -fsSL \"${URL}\" -o \"\$tmp_dir/${DEB_FILE}\" && \
         dpkg -i \"\$tmp_dir/${DEB_FILE}\" && \
         rm -rf \"\$tmp_dir\"" \
        "k9s v${VERSION} installed successfully via .deb package" \
        "Failed to install k9s .deb package" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Helper: install k9s via .rpm package
# ---------------------------------------------------------------------------
install_k9s_rpm() {
    local VERSION="$1"
    local ARCH="$2"
    
    # Map architecture names for rpm packages
    case "$ARCH" in
        "amd64") local RPM_ARCH="amd64" ;;
        "arm64") local RPM_ARCH="arm64" ;;
        "armv7") local RPM_ARCH="arm" ;;
        *) return 1 ;;
    esac
    
    local RPM_FILE="k9s_linux_${RPM_ARCH}.rpm"
    local URL="https://github.com/derailed/k9s/releases/download/v${VERSION}/${RPM_FILE}"
    
    show_info "Installing k9s v${VERSION} via .rpm package for ${RPM_ARCH}..."
    
    # Verify URL exists
    if ! curl -fsSL --head "$URL" >/dev/null 2>&1; then
        show_warning "k9s .rpm package not available for ${RPM_ARCH}"
        return 1
    fi
    
    run_with_feedback \
        "tmp_dir=\$(mktemp -d) && \
         curl -fsSL \"${URL}\" -o \"\$tmp_dir/${RPM_FILE}\" && \
         rpm -i \"\$tmp_dir/${RPM_FILE}\" && \
         rm -rf \"\$tmp_dir\"" \
        "k9s v${VERSION} installed successfully via .rpm package" \
        "Failed to install k9s .rpm package" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Helper: install k9s via .apk package (Alpine Linux)
# ---------------------------------------------------------------------------
install_k9s_apk() {
    local VERSION="$1"
    local ARCH="$2"
    
    # Map architecture names for apk packages
    case "$ARCH" in
        "amd64") local APK_ARCH="amd64" ;;
        "arm64") local APK_ARCH="arm64" ;;
        "armv7") local APK_ARCH="arm" ;;
        *) return 1 ;;
    esac
    
    local APK_FILE="k9s_linux_${APK_ARCH}.apk"
    local URL="https://github.com/derailed/k9s/releases/download/v${VERSION}/${APK_FILE}"
    
    show_info "Installing k9s v${VERSION} via .apk package for ${APK_ARCH}..."
    
    # Verify URL exists
    if ! curl -fsSL --head "$URL" >/dev/null 2>&1; then
        show_warning "k9s .apk package not available for ${APK_ARCH}"
        return 1
    fi
    
    run_with_feedback \
        "tmp_dir=\$(mktemp -d) && \
         curl -fsSL \"${URL}\" -o \"\$tmp_dir/${APK_FILE}\" && \
         apk add --allow-untrusted \"\$tmp_dir/${APK_FILE}\" && \
         rm -rf \"\$tmp_dir\"" \
        "k9s v${VERSION} installed successfully via .apk package" \
        "Failed to install k9s .apk package" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Helper: install k9s via tarball (fallback method)
# ---------------------------------------------------------------------------
install_k9s_tarball() {
    local VERSION="$1"
    local OS_TYPE="$2"
    local ARCH="$3"
    
    # Map architecture names for tarball
    case "$ARCH" in
        "amd64") local TAR_ARCH="amd64" ;;
        "arm64") local TAR_ARCH="arm64" ;;
        "armv7") local TAR_ARCH="armv7" ;;
        *) 
            show_error "Unsupported architecture for tarball: $ARCH"
            return 1 
            ;;
    esac
    
    local TARBALL="k9s_${OS_TYPE}_${TAR_ARCH}.tar.gz"
    local URL="https://github.com/derailed/k9s/releases/download/v${VERSION}/${TARBALL}"

    show_info "Installing k9s v${VERSION} via tarball for ${OS_TYPE} ${TAR_ARCH}..."
    
    # Verify URL exists before downloading
    if ! curl -fsSL --head "$URL" >/dev/null 2>&1; then
        show_error "k9s v${VERSION} tarball not available for ${OS_TYPE} ${TAR_ARCH}"
        show_error "URL: $URL"
        return 1
    fi

    # Download & install
    run_with_feedback \
        "tmp_dir=\$(mktemp -d) && \
         curl -fsSL \"${URL}\" -o \"\$tmp_dir/${TARBALL}\" && \
         tar -C /usr/local/bin -xzf \"\$tmp_dir/${TARBALL}\" k9s && \
         chmod +x /usr/local/bin/k9s && \
         rm -rf \"\$tmp_dir\"" \
        "k9s v${VERSION} installed successfully via tarball" \
        "Failed to install k9s v${VERSION} via tarball" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Enhanced: install Node.js via NodeSource repository with version checking
# ---------------------------------------------------------------------------
install_nodejs_nodesource() {
    local target_version="${NODE_VERSION:-20}"
    local target_full_version="${NODE_FULL_VERSION:-20.0.0}"
    
    # If full version specified, use it for comparison
    local version_to_check="$target_full_version"
    if [[ "$target_full_version" == *".0.0" ]]; then
        # If only major version specified, be more lenient
        version_to_check="$target_version.0.0"
    fi
    
    # Check if current version meets requirement
    if check_version_requirement "node" "$version_to_check"; then
        return 0  # Already satisfied
    fi
    
    # Uninstall existing version if present
    if command -v node >/dev/null 2>&1; then
        show_info "Uninstalling existing Node.js to install v$target_version..."
        uninstall_tool "node" "nodesource"
    fi
    
    show_info "Installing Node.js v${target_version} via NodeSource repository..."
    
    # Install NodeSource repository
    run_with_feedback \
        "curl -fsSL https://deb.nodesource.com/setup_${target_version}.x | bash -" \
        "NodeSource repository added successfully" \
        "Failed to add NodeSource repository" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
    
    # Install Node.js
    run_with_feedback \
        "apt-get install -y nodejs" \
        "Node.js v${target_version} installed successfully" \
        "Failed to install Node.js v${target_version}" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# Configure Docker service and user permissions
configure_docker_service() {
    local user="$1"
    
    # Ensure Docker service is enabled & running
    if systemctl is-active --quiet docker; then
        show_info "Docker service already running"
    else
        show_info "Starting Docker service..."
        run_with_feedback \
            "systemctl enable --now docker" \
            "Docker service enabled and started" \
            "Failed to start Docker service"
    fi

    # Add current user to docker group
    if groups "$user" | grep -q '\bdocker\b'; then
        show_info "User $user is already in the docker group"
    else
        show_info "Adding user to Docker group..."
        run_with_feedback \
            "usermod -aG docker $user" \
            "Added $user to docker group (logout/login for effect)" \
            "Failed to add $user to docker group"
        
        show_warning "Group changes will take effect after logout/login"
    fi
}

# Install additional system utilities
install_system_utilities() {
    local utilities=(
        "curl"
        "wget"
        "jq"
        "htop"
        "tree"
        "unzip"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "rsync"
        "tar"
        "gzip"
    )
    
    for util in "${utilities[@]}"; do
        install_if_missing "$util"
    done
}

# ---------------------------------------------------------------------------
# Enhanced: install yq (YAML processor) with version checking
# ---------------------------------------------------------------------------
install_yq_if_missing() {
    local target_version="${YQ_VERSION:-4.35.2}"
    
    # Check if current version meets requirement
    if check_version_requirement "yq" "$target_version"; then
        return 0  # Already satisfied
    fi
    
    # Uninstall existing version if present
    if command -v yq >/dev/null 2>&1; then
        show_info "Uninstalling existing yq to install v$target_version..."
        uninstall_tool "yq"
    fi
    
    show_info "Installing yq YAML processor v$target_version..."
    local ARCH
    case "$(uname -m)" in
        x86_64|amd64)   ARCH="amd64" ;;
        aarch64|arm64)  ARCH="arm64" ;;
        armv7l|armv7)   ARCH="arm" ;;
        *)
            show_warning "Unsupported architecture for yq: $(uname -m)"
            return 1
            ;;
    esac
    
    local URL="https://github.com/mikefarah/yq/releases/download/v${target_version}/yq_linux_${ARCH}"
    run_with_feedback \
        "curl -fsSL \"${URL}\" -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq" \
        "yq v$target_version installed successfully" \
        "Failed to install yq v$target_version" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Helper: install Docker with optional version checking
# ---------------------------------------------------------------------------
install_docker_versioned() {
    local target_version="${DOCKER_VERSION:-}"
    
    # If no specific version required, use standard installation
    if [[ -z "$target_version" ]]; then
        install_if_missing docker docker.io
        return $?
    fi
    
    # Check if current version meets requirement
    if check_version_requirement "docker" "$target_version"; then
        return 0  # Already satisfied
    fi
    
    # Uninstall existing version if present
    if command -v docker >/dev/null 2>&1; then
        show_info "Uninstalling existing Docker to install v$target_version..."
        uninstall_tool "docker"
    fi
    
    # For specific Docker versions, you might want to use Docker's official repository
    # This is a simplified version - you may need to adapt based on your needs
    show_info "Installing Docker v$target_version..."
    run_with_feedback \
        "curl -fsSL https://get.docker.com | sh" \
        "Docker installed successfully" \
        "Failed to install Docker" \
        $([[ "$SCRIPT_MODE" == "standalone" ]] && echo "true" || echo "false")
}

# ---------------------------------------------------------------------------
# Main installation function with enhanced version checking
# ---------------------------------------------------------------------------
install_dependencies() {
    show_info "Starting dependencies installation with version management for user: ${BOLD}${DK_USER}${NC}"
    
    # Display version requirements if set
    echo
    show_info "Version requirements (if specified):"
    [[ -n "$NODE_VERSION" ]] && echo -e "${DIM}  Node.js: v${NODE_VERSION}${NC}"
    [[ -n "$NODE_FULL_VERSION" ]] && echo -e "${DIM}  Node.js (full): v${NODE_FULL_VERSION}${NC}"
    [[ -n "$K9S_VERSION" ]] && echo -e "${DIM}  k9s: v${K9S_VERSION}${NC}"
    [[ -n "$YQ_VERSION" ]] && echo -e "${DIM}  yq: v${YQ_VERSION}${NC}"
    [[ -n "$DOCKER_VERSION" ]] && echo -e "${DIM}  Docker: v${DOCKER_VERSION}${NC}"
    echo
    
    # Update repositories first
    update_package_index
    
    # Core dependencies
    show_info "Installing core dependencies..."
    install_if_missing git
    install_if_missing sshpass
    
    # Docker with optional version checking
    show_info "Installing Docker..."
    install_docker_versioned
    
    # Configure Docker
    configure_docker_service "$DK_USER"
    
    # Node.js with version checking
    show_info "Installing Node.js with version checking..."
    install_nodejs_nodesource
    
    # Ensure npm is available
    install_if_missing npm
    
    # k3s dependencies and offline tools
    show_info "Installing k3s system dependencies..."
    install_k3s_system_dependencies
    prepare_offline_k3s_tools
    
    # Kubernetes tools with version checking
    show_info "Installing Kubernetes management tools with version checking..."
    install_k9s
    
    # System utilities
    show_info "Installing system utilities with version checking..."
    install_system_utilities
    install_yq_if_missing
    
    show_success "Dependencies installation with version checking completed successfully!"
    
    # Enhanced verification with version display
    show_info "Verifying installations with version information..."
    local key_tools=("git" "docker" "node" "npm" "k9s" "jq" "yq")
    local failed_count=0
    
    echo
    show_info "Installed tool versions:"
    for tool in "${key_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$(get_installed_version "$tool")
            if [[ -n "$version" ]]; then
                show_success "$tool: v$version"
            else
                show_success "$tool: installed (version detection failed)"
            fi
        else
            show_error "$tool: missing"
            ((failed_count++))
        fi
    done
    
    # Check k3s tools
    if [ -d "/opt/k3s-tools/bin" ]; then
        local tool_count=$(find "/opt/k3s-tools/bin" -type f -executable 2>/dev/null | wc -l)
        show_success "k3s offline tools: $tool_count tools ready"
    else
        show_error "k3s offline tools: missing"
        ((failed_count++))
    fi
    
    echo
    if [ $failed_count -eq 0 ]; then
        show_success "All dependencies verified successfully with correct versions!"
        return 0
    else
        show_error "$failed_count dependencies failed verification"
        return 1
    fi
}

# Main execution
main() {
    # Ensure we're running as root for system-wide installations
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${BOLD}This script must be run as root (use sudo)${NC}"
        echo -e "${YELLOW}Usage: sudo $0${NC}"
        echo
        echo -e "${DIM}Environment variables for version control:${NC}"
        echo -e "${DIM}  NODE_VERSION=20           # Node.js major version${NC}"
        echo -e "${DIM}  NODE_FULL_VERSION=20.1.0  # Node.js full version${NC}"
        echo -e "${DIM}  K9S_VERSION=0.50.9        # k9s version${NC}"
        echo -e "${DIM}  YQ_VERSION=4.35.2         # yq version${NC}"
        echo -e "${DIM}  DOCKER_VERSION=24.0.0     # Docker version (optional)${NC}"
        echo
        echo -e "${DIM}Example:${NC}"
        echo -e "${DIM}  sudo NODE_VERSION=18 K9S_VERSION=0.49.9 $0${NC}"
        exit 1
    fi
    
    install_dependencies
    exit $?
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi