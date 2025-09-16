#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# Description   : Enhanced script to set up the default VSS configuration for the SDV runtime
#                 with intelligent existence checking and backup functionality
# Usage         : sudo ./setup_default_vss.sh
# Output        : ${HOME_DIR}/.dk/sdv-runtime/vss.json

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

# Function to show info message
show_info() {
    local message=$1
    echo -e "${BLUE} ${ARROW} ${message}${NC}"
}

# Function to show success message
show_success() {
    local message=$1
    echo -e "${GREEN}${BOLD} ${CHECKMARK} ${message}${NC}"
}

# Function to show warning message
show_warning() {
    local message=$1
    echo -e "${YELLOW}${BOLD} ⚠ ${message}${NC}"
}

# Function to show error message
show_error() {
    local message=$1
    echo -e "${RED}${BOLD} ${CROSS} ${message}${NC}"
}

# Function to validate JSON structure
validate_json() {
    local json_file=$1
    
    if ! command -v jq >/dev/null 2>&1; then
        # Fallback validation using python if jq is not available
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null
            return $?
        elif command -v python >/dev/null 2>&1; then
            python -c "import json; json.load(open('$json_file'))" 2>/dev/null
            return $?
        else
            # Basic validation - just check if file is readable and not empty
            [ -s "$json_file" ]
            return $?
        fi
    else
        # Use jq for validation
        jq empty "$json_file" >/dev/null 2>&1
        return $?
    fi
}

# Function to check if VSS file has meaningful content
check_vss_content() {
    local vss_file=$1
    
    # Check if file exists and is readable
    if [ ! -f "$vss_file" ]; then
        return 1
    fi
    
    # Check if file is not empty
    if [ ! -s "$vss_file" ]; then
        show_warning "VSS file exists but is empty"
        return 1
    fi
    
    # Validate JSON structure
    if ! validate_json "$vss_file"; then
        show_warning "VSS file exists but contains invalid JSON"
        return 1
    fi
    
    # Check for minimal VSS content (basic structure indicators)
    local has_content=false
    
    if command -v jq >/dev/null 2>&1; then
        # Use jq to check for meaningful content
        local key_count=$(jq 'keys | length' "$vss_file" 2>/dev/null || echo "0")
        if [ "$key_count" -gt 0 ]; then
            has_content=true
            show_info "VSS file contains $key_count top-level keys"
        fi
    else
        # Fallback: basic content check
        if grep -q '"Vehicle"' "$vss_file" 2>/dev/null || \
           grep -q '"Signal"' "$vss_file" 2>/dev/null || \
           grep -q '"Branch"' "$vss_file" 2>/dev/null; then
            has_content=true
            show_info "VSS file appears to contain vehicle signal definitions"
        fi
    fi
    
    if [ "$has_content" = true ]; then
        return 0
    else
        show_warning "VSS file exists but appears to lack meaningful vehicle signal content"
        return 1
    fi
}

# Function to create backup of existing VSS file
backup_existing_vss() {
    local vss_file=$1
    local backup_dir="$(dirname "$vss_file")/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/vss_backup_$timestamp.json"
    
    # Create backup directory if it doesn't exist
    sudo mkdir -p "$backup_dir"
    
    # Copy existing file to backup
    if sudo cp "$vss_file" "$backup_file" 2>/dev/null; then
        show_success "Existing VSS file backed up to: $backup_file"
        # Set proper permissions
        sudo chown "${DK_USER}:${DK_USER}" "$backup_file"
        sudo chmod 644 "$backup_file"
        return 0
    else
        show_error "Failed to create backup of existing VSS file"
        return 1
    fi
}

# Function to get file size and modification time
get_file_info() {
    local file=$1
    
    if [ -f "$file" ]; then
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "unknown")
        local mtime=$(stat -f%Sm "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null | cut -d' ' -f1,2 || echo "unknown")
        
        echo "Size: ${size} bytes, Last modified: ${mtime}"
    fi
}

# Main VSS setup function
setup_vss_configuration() {
    # Use variables from parent script or defaults
    show_info "Setting up VSS configuration for user: ${BOLD}$DK_USER${NC}"
    show_info "Home directory: ${BOLD}$HOME_DIR${NC}"

    # Create the host directory structure
    local vss_dir="${HOME_DIR}/.dk/sdv-runtime"
    local vss_file="${vss_dir}/vss.json"
    
    sudo mkdir -p "$vss_dir"
    
    # Get the current script directory to find the manifest
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    MANIFEST_PATH="${SCRIPT_DIR}/../manifests/default_vss.json"
    
    # Check if default VSS manifest exists
    if [ ! -f "$MANIFEST_PATH" ]; then
        show_error "Default VSS manifest not found at: $MANIFEST_PATH"
        show_info "Creating minimal VSS structure..."
        
        # Create a basic VSS structure
        local minimal_vss='{
  "Vehicle": {
    "type": "branch",
    "description": "High-level vehicle data.",
    "children": {
      "Speed": {
        "type": "sensor",
        "unit": "km/h",
        "datatype": "float",
        "description": "Vehicle speed."
      },
      "SwUpdate": {
        "type": "branch",
        "description": "Software update related signals.",
        "children": {
          "Status": {
            "type": "actuator",
            "datatype": "uint8",
            "description": "Software update status."
          },
          "XipHost": {
            "type": "branch",
            "description": "XIP Host update signals.",
            "children": {
              "UpdateTrigger": {
                "type": "actuator",
                "datatype": "boolean",
                "description": "Trigger for XIP host update."
              },
              "PatchUpdateTrigger": {
                "type": "actuator", 
                "datatype": "boolean",
                "description": "Trigger for XIP host patch update."
              },
              "PercentageDone": {
                "type": "sensor",
                "datatype": "uint8",
                "unit": "percent", 
                "description": "Update progress percentage."
              }
            }
          }
        }
      }
    }
  }
}'
        echo "$minimal_vss" | sudo tee "$vss_file" > /dev/null
        show_success "Created minimal VSS configuration"
    else
        # Check if VSS file already exists and has valid content
        if [ -f "$vss_file" ]; then
            show_info "Existing VSS file found: $vss_file"
            local file_info=$(get_file_info "$vss_file")
            show_info "File details: $file_info"
            
            if check_vss_content "$vss_file"; then
                show_success "Existing VSS file is valid and contains meaningful content"
                show_info "Skipping default VSS setup to preserve existing configuration"
                
                # Optionally show what's in the existing file
                if command -v jq >/dev/null 2>&1; then
                    local key_count=$(jq 'keys | length' "$vss_file" 2>/dev/null || echo "0")
                    local vehicle_signals=$(jq -r 'try (.Vehicle.children | keys | length) catch 0' "$vss_file" 2>/dev/null || echo "0")
                    show_info "Current VSS contains $key_count root keys and $vehicle_signals vehicle signals"
                fi
                
                # Set proper permissions on existing file
                sudo chown "${DK_USER}:${DK_USER}" "$vss_file"
                sudo chmod 666 "$vss_file"
                
                return 0
            else
                show_warning "Existing VSS file is invalid or incomplete"
                show_info "Choose action:"
                echo -e "${WHITE}  1) Replace with default configuration${NC}"
                echo -e "${WHITE}  2) Backup existing and use default${NC}"
                echo -e "${WHITE}  3) Keep existing file as-is${NC}"
                
                read -p "Enter choice (1-3, default: 2): " choice
                choice=${choice:-2}
                
                case "$choice" in
                    1)
                        show_info "Replacing existing VSS file with default..."
                        ;;
                    2)
                        show_info "Backing up existing VSS file..."
                        if backup_existing_vss "$vss_file"; then
                            show_info "Proceeding with default configuration..."
                        else
                            show_error "Backup failed, keeping existing file"
                            return 1
                        fi
                        ;;
                    3)
                        show_info "Keeping existing VSS file unchanged"
                        sudo chown "${DK_USER}:${DK_USER}" "$vss_file"
                        sudo chmod 666 "$vss_file"
                        return 0
                        ;;
                    *)
                        show_warning "Invalid choice, defaulting to backup and replace"
                        backup_existing_vss "$vss_file"
                        ;;
                esac
            fi
        else
            show_info "No existing VSS file found, setting up default configuration..."
        fi
        
        # Copy the default VSS configuration
        if sudo cp "$MANIFEST_PATH" "$vss_file"; then
            show_success "Default VSS configuration copied successfully"
            
            # Validate the copied configuration
            if validate_json "$vss_file"; then
                show_success "VSS configuration validated successfully"
            else
                show_error "Copied VSS configuration is invalid JSON"
                return 1
            fi
        else
            show_error "Failed to copy default VSS configuration"
            return 1
        fi
    fi
    
    # Set proper permissions
    sudo chown -R "${DK_USER}:${DK_USER}" "${HOME_DIR}/.dk/"
    sudo chmod -R 755 "$vss_dir"
    sudo chmod 666 "$vss_file"
    
    # Final validation and summary
    if [ -f "$vss_file" ]; then
        local final_info=$(get_file_info "$vss_file")
        show_success "VSS setup completed successfully"
        show_info "VSS file location: $vss_file"
        show_info "Final file details: $final_info"
        
        # Show content summary if possible
        if command -v jq >/dev/null 2>&1; then
            local summary=$(jq -r 'keys | length' "$vss_file" 2>/dev/null || echo "unknown")
            show_info "VSS contains $summary top-level configurations"
            
            # Check for specific dreamOS signals
            if jq -e '.Vehicle.SwUpdate' "$vss_file" >/dev/null 2>&1; then
                show_success "dreamOS software update signals detected in VSS"
            fi
        fi
    else
        show_error "VSS file not found after setup"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    # Check if required variables are set (from parent script or environment)
    if [ -z "$DK_USER" ] || [ -z "$HOME_DIR" ]; then
        show_warning "Required variables not set, attempting to detect..."
        
        # Fallback detection
        if [ -n "$SUDO_USER" ]; then
            DK_USER=$SUDO_USER
        else
            DK_USER=$USER
        fi
        
        HOME_DIR="/home/$DK_USER"
        
        show_info "Using detected values: DK_USER=$DK_USER, HOME_DIR=$HOME_DIR"
    fi
    
    # Verify user exists
    if ! id "$DK_USER" >/dev/null 2>&1; then
        show_error "User '$DK_USER' does not exist on this system"
        exit 1
    fi
    
    # Setup VSS configuration
    if setup_vss_configuration; then
        show_success "VSS configuration setup completed successfully"
        exit 0
    else
        show_error "VSS configuration setup failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi