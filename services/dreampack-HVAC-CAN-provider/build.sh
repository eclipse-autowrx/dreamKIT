#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT


# build.sh - Docker build script for dk_service_can_provider
# Usage: ./build.sh [local|prod] [version]

set -e

# Default values
ENVIRONMENT=${1:-local}
VERSION=${2:-latest}
IMAGE_NAME="dk_service_can_provider"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fix shell script permissions and line endings
fix_scripts() {
    print_info "Fixing shell script line endings and permissions..."
    if [ -f "*.sh" ]; then
        sed -i -e 's/\r$//' *.sh
        chmod +x *.sh
    fi
}

# Build for local development (current machine architecture)
build_local() {
    # Detect current architecture
    CURRENT_ARCH=$(uname -m)
    case $CURRENT_ARCH in
        x86_64)
            PLATFORM="linux/amd64"
            ARCH_TAG="amd64"
            ;;
        aarch64|arm64)
            PLATFORM="linux/arm64"
            ARCH_TAG="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $CURRENT_ARCH"
            exit 1
            ;;
    esac
    
    print_info "Building for local development environment..."
    print_info "Target: $CURRENT_ARCH ($PLATFORM) with localhost kuksa-databroker"
    
    docker build \
        --platform $PLATFORM \
        -t ${IMAGE_NAME}:${VERSION} \
        -t ${IMAGE_NAME}:local \
        -t ${IMAGE_NAME}:${ARCH_TAG} \
        --file Dockerfile .
    
    print_success "Local build completed: ${IMAGE_NAME}:${VERSION}"
    print_info "Architecture: $CURRENT_ARCH ($PLATFORM)"
    print_info "Configuration: KUKSA_ADDRESS=localhost, CAN_PORT=vcan0"
}

# Build for production (Jetson Orin + k3s deployment)
build_prod() {
    print_info "Building for production environment..."
    print_info "Target: ARM64 for Jetson Orin + k3s deployment"
    
    # Create buildx builder if not exists
    if ! docker buildx ls | grep -q "dk_service_can_provider_build"; then
        print_info "Creating buildx builder..."
        docker buildx create --name dk_service_can_provider_build --use
    else
        docker buildx use dk_service_can_provider_build
    fi
    
    # Build for ARM64
    docker buildx build \
        --platform linux/arm64 \
        -t ${IMAGE_NAME}:${VERSION} \
        -t ${IMAGE_NAME}:arm64 \
        -t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:${VERSION} \
        -t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:latest \
        --load \
        --file Dockerfile .
    
    print_success "Production build completed: ${IMAGE_NAME}:${VERSION}"
    print_info "Configuration: KUKSA_ADDRESS=192.168.56.48, CAN_PORT=can1"
    
    # Create tar file for k3s import
    print_info "Creating image tar file for k3s import..."
    docker save ${IMAGE_NAME}:${VERSION} > ${IMAGE_NAME}.tar
    print_success "Image saved to: ${IMAGE_NAME}.tar"
    print_info "Use: sudo k3s ctr images import ${IMAGE_NAME}.tar"
}

# Build for both environments
build_both() {
    print_info "Building for both environments..."
    build_local
    build_prod
}

# Push to GitHub Container Registry
push_ghcr() {
    if [ "$ENVIRONMENT" != "prod" ]; then
        print_error "Can only push production builds to GHCR"
        exit 1
    fi
    
    print_info "Pushing to GitHub Container Registry..."
    docker buildx build \
        --platform linux/arm64 \
        -t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:${VERSION} \
        -t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:latest \
        --push \
        --file Dockerfile .
    
    print_success "Image pushed to GHCR: ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:${VERSION}"
    print_info "Remember to update mirror-remote.yaml with your GHCR URL"
}

# Show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [VERSION] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local    Build for local development (Ubuntu x86_64)"
    echo "  prod     Build for production (ARM64 k3s deployment)"
    echo "  both     Build for both environments"
    echo ""
    echo "VERSION:"
    echo "  latest   Use latest tag (default)"
    echo "  v1.0.0   Use specific version tag"
    echo ""
    echo "OPTIONS:"
    echo "  --push   Push production build to GHCR (only with prod)"
    echo "  --help   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local                    # Build for local development"
    echo "  $0 prod v1.0.0             # Build production version v1.0.0"
    echo "  $0 prod latest --push      # Build and push to GHCR"
    echo "  $0 both                     # Build for both environments"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in current directory"
        exit 1
    fi
    
    # Fix scripts first
    fix_scripts
    
    print_info "Starting build process..."
    print_info "Environment: $ENVIRONMENT"
    print_info "Version: $VERSION"
    
    case $ENVIRONMENT in
        "local")
            build_local
            ;;
        "prod")
            build_prod
            # Check if push flag is set
            if [[ "$3" == "--push" ]]; then
                push_ghcr
            fi
            ;;
        "both")
            build_both
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Build process completed!"
    
    # Show next steps
    case $ENVIRONMENT in
        "local")
            echo ""
            print_info "Next steps for local development:"
            echo "  1. ./start.sh local"
            echo "  2. Test with: kuksa-client grpc://127.0.0.1:55555"
            ;;
        "prod")
            echo ""
            print_info "Next steps for production deployment:"
            echo "  1. sudo k3s ctr images import ${IMAGE_NAME}.tar"
            echo "  2. kubectl apply -f manifests/"
            echo "  3. ./start.sh prod"
            ;;
        "both")
            echo ""
            print_info "Both builds completed. Choose your deployment:"
            echo "  Local: ./start.sh local"
            echo "  Prod:  sudo k3s ctr images import ${IMAGE_NAME}.tar && kubectl apply -f manifests/"
            ;;
    esac
}

# Run main function with all arguments
main "$@"