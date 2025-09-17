#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT


# start.sh - Start script for dk_service_can_provider
# Usage: ./start.sh [local|prod] [options]

set -e

# Default values
ENVIRONMENT=${1:-local}
IMAGE_NAME="dk_service_can_provider"
CONTAINER_NAME="dk_service_can_provider"

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

# Check if virtual CAN exists, create if not
setup_vcan() {
    if ! ip link show vcan0 >/dev/null 2>&1; then
        print_info "Creating virtual CAN interface..."
        if [ -f "./prepare-dbc-file/createvcan.sh" ]; then
            ./prepare-dbc-file/createvcan.sh vcan0
        else
            print_warning "createvcan.sh not found, creating vcan0 manually..."
            sudo modprobe vcan
            sudo ip link add dev vcan0 type vcan
            sudo ip link set up vcan0
        fi
        print_success "Virtual CAN interface vcan0 created"
    else
        print_info "Virtual CAN interface vcan0 already exists"
    fi
}

# Start local development environment
start_local() {
    print_info "Starting local development environment..."
    
    # Setup virtual CAN
    setup_vcan
    
    # Check if kuksa-databroker is running
    if ! netstat -ln | grep -q ":55555"; then
        print_warning "KUKSA databroker not detected on localhost:55555"
        print_info "Make sure kuksa-databroker is running before starting the service"
    fi
    
    # Stop existing container if running
    if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
        print_info "Stopping existing container..."
        docker kill ${CONTAINER_NAME} >/dev/null 2>&1 || true
        docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
    fi
    
    # Start container
    print_info "Starting dk_service_can_provider container..."
    docker run -d -it \
        --name ${CONTAINER_NAME} \
        --net=host \
        --privileged \
        -e KUKSA_ADDRESS=localhost \
        -e CAN_PORT=vcan0 \
        -e MAPPING_FILE=mapping/vss_4.0/vss_dbc.json \
        -e LOG_LEVEL=INFO \
        ${IMAGE_NAME}:latest
    
    print_success "Container started successfully"
    
    # Start CAN monitoring in background
    print_info "Starting CAN monitoring (candump vcan0)..."
    candump vcan0 &
    CANDUMP_PID=$!
    echo $CANDUMP_PID > /tmp/candump.pid
    
    # Show container logs
    sleep 2
    print_info "Container logs:"
    docker logs ${CONTAINER_NAME}
    
    print_success "Local environment started!"
    print_info "Test with: kuksa-client grpc://127.0.0.1:55555"
    print_info "CAN monitoring PID: $CANDUMP_PID (saved to /tmp/candump.pid)"
}

# Start production k3s environment
start_prod() {
    print_info "Starting production k3s environment..."
    
    # Check if k3s is running
    if ! systemctl is-active --quiet k3s; then
        print_error "k3s service is not running"
        print_info "Start k3s with: sudo systemctl start k3s"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        print_info "Make sure kubectl is installed and configured"
        exit 1
    fi
    
    # Determine which mirror job to use
    local use_local_image=false
    if docker image inspect dk_service_can_provider:latest >/dev/null 2>&1; then
        print_info "Local image found: dk_service_can_provider:latest"
        use_local_image=true
    else
        print_info "Local image not found, will use remote image from GHCR"
        use_local_image=false
    fi
    
    # Apply k3s manifests
    if [ -d "manifests" ]; then
        print_info "Applying k3s manifests..."
        
        # Apply appropriate mirror job
        if [ "$use_local_image" = true ]; then
            print_info "Using local image mirror job..."
            kubectl apply -f manifests/mirror-local.yaml
            JOB_NAME="mirror-dk-service-can-provider-local"
        else
            print_info "Using remote image mirror job..."
            kubectl apply -f manifests/mirror-remote.yaml
            JOB_NAME="mirror-dk-service-can-provider-remote"
        fi
        
        # Wait for mirror job to complete
        if [ ! -z "$JOB_NAME" ]; then
            print_info "Waiting for mirror job ($JOB_NAME) to complete..."
            kubectl wait --for=condition=complete --timeout=300s job/$JOB_NAME
            
            if [ $? -eq 0 ]; then
                print_success "Mirror job completed successfully"
            else
                print_error "Mirror job failed or timed out"
                kubectl logs job/$JOB_NAME
                exit 1
            fi
        fi
        
        # Apply deployment
        if [ "$use_local_image" = true ]; then
            print_info "Applying deployment..."
            kubectl apply -f manifests/deployment-local.yaml
            JOB_NAME="mirror-dk-service-can-provider-local"
        else
            print_info "Using remote image mirror job..."
            kubectl apply -f manifests/deployment-remote.yaml
            JOB_NAME="mirror-dk-service-can-provider-remote"
        fi

        # Wait for deployment to be ready
        print_info "Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/dk-service-can-provider
        
        if [ $? -eq 0 ]; then
            print_success "Deployment is ready"
        else
            print_error "Deployment failed or timed out"
            kubectl describe deployment dk-service-can-provider
            exit 1
        fi
        
    else
        print_error "manifests directory not found"
        print_info "Make sure manifests/ directory exists with k3s YAML files"
        exit 1
    fi
    
    print_success "Production environment started!"
    
    # Show deployment status
    print_info "Deployment status:"
    kubectl get deployments dk-service-can-provider
    kubectl get pods -l app=dk-service-can-provider
    
    # Show logs
    print_info "Recent logs:"
    kubectl logs -l app=dk-service-can-provider --tail=20
}

# Import Docker image to k3s
import_to_k3s() {
    local tar_file="${IMAGE_NAME}.tar"
    
    if [ ! -f "$tar_file" ]; then
        print_error "Image tar file not found: $tar_file"
        print_info "Run './build.sh prod' first to create the image"
        exit 1
    fi
    
    print_info "Importing Docker image to k3s..."
    sudo k3s ctr images import "$tar_file"
    
    if [ $? -eq 0 ]; then
        print_success "Image imported successfully"
        rm "$tar_file"
        print_info "Removed tar file: $tar_file"
    else
        print_error "Failed to import image to k3s"
        exit 1
    fi
}

# Show status of the service
show_status() {
    case $ENVIRONMENT in
        "local")
            print_info "Local environment status:"
            if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
                print_success "Container is running"
                docker ps -f name=${CONTAINER_NAME}
                echo ""
                print_info "Recent logs:"
                docker logs --tail=10 ${CONTAINER_NAME}
            else
                print_warning "Container is not running"
            fi
            
            # Check CAN interface
            if ip link show vcan0 >/dev/null 2>&1; then
                print_success "Virtual CAN interface vcan0 is up"
            else
                print_warning "Virtual CAN interface vcan0 is not available"
            fi
            ;;
        "prod")
            print_info "Production environment status:"
            kubectl get deployments dk-service-can-provider 2>/dev/null || print_warning "Deployment not found"
            kubectl get pods -l app=dk-service-can-provider 2>/dev/null || print_warning "Pods not found"
            ;;
    esac
}

# Show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local    Start local development environment"
    echo "  prod     Start production k3s environment"
    echo ""
    echo "OPTIONS:"
    echo "  --import     Import Docker image to k3s (with prod)"
    echo "  --status     Show service status"
    echo "  --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local                    # Start local development"
    echo "  $0 prod --import           # Import image and start k3s deployment"
    echo "  $0 local --status          # Show local service status"
    echo "  $0 prod --status           # Show k3s deployment status"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    # Check for status flag
    if [[ "$2" == "--status" ]] || [[ "$1" == "--status" ]]; then
        show_status
        exit 0
    fi
    
    print_info "Starting dk_service_can_provider..."
    print_info "Environment: $ENVIRONMENT"
    
    # Handle import flag for production
    if [[ "$ENVIRONMENT" == "prod" ]] && [[ "$2" == "--import" ]]; then
        import_to_k3s
    fi
    
    case $ENVIRONMENT in
        "local")
            start_local
            ;;
        "prod")
            start_prod
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Service started successfully!"
    print_info "Use './stop.sh $ENVIRONMENT' to stop the service"
    print_info "Use './start.sh $ENVIRONMENT --status' to check status"
}

# Run main function with all arguments
main "$@"