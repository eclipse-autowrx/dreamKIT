#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT


# stop.sh - Stop script for dk_service_can_provider
# Usage: ./stop.sh [local|prod] [options]

set -e

# Default values
ENVIRONMENT=${1:-local}
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

# Stop local development environment
stop_local() {
    print_info "Stopping local development environment..."
    
    # Stop Docker container
    if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
        print_info "Stopping container: ${CONTAINER_NAME}"
        docker kill ${CONTAINER_NAME} >/dev/null 2>&1 || true
        docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
        print_success "Container stopped and removed"
    else
        print_warning "Container ${CONTAINER_NAME} is not running"
    fi
    
    # Stop CAN monitoring if running
    if [ -f "/tmp/candump.pid" ]; then
        CANDUMP_PID=$(cat /tmp/candump.pid)
        if ps -p $CANDUMP_PID > /dev/null 2>&1; then
            print_info "Stopping CAN monitoring (PID: $CANDUMP_PID)"
            kill $CANDUMP_PID >/dev/null 2>&1 || true
            print_success "CAN monitoring stopped"
        fi
        rm /tmp/candump.pid
    fi
    
    # Stop any remaining candump processes
    pkill -f "candump vcan0" >/dev/null 2>&1 || true
    
    print_success "Local environment stopped"
}

# Stop production k3s environment
stop_prod() {
    print_info "Stopping production k3s environment..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found"
        print_info "Make sure kubectl is installed and configured"
        exit 1
    fi
    
    # Delete k3s resources
    if [ -d "manifests" ]; then
        print_info "Removing k3s resources..."
        
        # Delete deployment
        if kubectl get deployment dk-service-can-provider >/dev/null 2>&1; then
            print_info "Deleting deployment..."
            kubectl delete deployment dk-service-can-provider
            print_success "Deployment deleted"
        else
            print_warning "Deployment not found"
        fi
        
        # Delete service if exists
        if kubectl get service dk-service-can-provider >/dev/null 2>&1; then
            print_info "Deleting service..."
            kubectl delete service dk-service-can-provider
            print_success "Service deleted"
        fi
        
        # Delete mirror job
        if kubectl get job mirror-dk-service-can-provider >/dev/null 2>&1; then
            print_info "Deleting mirror job..."
            kubectl delete job mirror-dk-service-can-provider
            print_success "Mirror job deleted"
        else
            print_warning "Mirror job not found"
        fi
        
    else
        print_warning "manifests directory not found, attempting to delete by name..."
        kubectl delete deployment dk-service-can-provider 2>/dev/null || print_warning "Deployment not found"
        kubectl delete service dk-service-can-provider 2>/dev/null || print_warning "Service not found"
        kubectl delete job mirror-dk-service-can-provider 2>/dev/null || print_warning "Mirror job not found"
    fi
    
    # Wait for pods to terminate
    print_info "Waiting for pods to terminate..."
    kubectl wait --for=delete pods -l app=dk-service-can-provider --timeout=60s 2>/dev/null || print_warning "No pods found or timeout waiting for termination"
    
    print_success "Production environment stopped"
}

# Clean up resources
cleanup() {
    case $ENVIRONMENT in
        "local")
            print_info "Cleaning up local resources..."
            
            # Remove any remaining containers
            docker ps -aq -f name=${CONTAINER_NAME} | xargs -r docker rm -f >/dev/null 2>&1 || true
            
            # Clean up virtual CAN if requested
            if [[ "$2" == "--clean-vcan" ]]; then
                if ip link show vcan0 >/dev/null 2>&1; then
                    print_info "Removing virtual CAN interface..."
                    sudo ip link delete vcan0 >/dev/null 2>&1 || true
                    print_success "Virtual CAN interface removed"
                fi
            fi
            
            # Clean up Docker images if requested
            if [[ "$2" == "--clean-images" ]]; then
                print_info "Removing Docker images..."
                docker rmi dk_service_can_provider:latest 2>/dev/null || true
                docker rmi dk_service_can_provider:local 2>/dev/null || true
                print_success "Docker images removed"
            fi
            ;;
        "prod")
            print_info "Cleaning up production resources..."
            
            # Clean up k3s images if requested
            if [[ "$2" == "--clean-images" ]]; then
                print_info "Removing k3s images..."
                sudo k3s ctr images rm dk_service_can_provider:latest 2>/dev/null || true
                sudo k3s ctr images rm dk_service_can_provider:arm64 2>/dev/null || true
                sudo k3s ctr images rm localhost:5000/samtranbosch/dk_service_can_provider:latest 2>/dev/null || true
                print_success "k3s images removed"
            fi
            ;;
    esac
}

# Force stop all related processes
force_stop() {
    print_warning "Force stopping all related processes..."
    
    case $ENVIRONMENT in
        "local")
            # Force kill container
            docker kill ${CONTAINER_NAME} >/dev/null 2>&1 || true
            docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true
            
            # Force kill CAN monitoring
            pkill -9 -f "candump" >/dev/null 2>&1 || true
            
            print_success "Force stop completed for local environment"
            ;;
        "prod")
            # Force delete k3s resources
            kubectl delete deployment dk-service-can-provider --force --grace-period=0 2>/dev/null || true
            kubectl delete pods -l app=dk-service-can-provider --force --grace-period=0 2>/dev/null || true
            kubectl delete job mirror-dk-service-can-provider --force --grace-period=0 2>/dev/null || true
            
            print_success "Force stop completed for production environment"
            ;;
    esac
}

# Show current status
show_status() {
    case $ENVIRONMENT in
        "local")
            print_info "Local environment status:"
            if docker ps -q -f name=${CONTAINER_NAME} | grep -q .; then
                print_warning "Container is still running"
                docker ps -f name=${CONTAINER_NAME}
            else
                print_success "Container is stopped"
            fi
            
            # Check for remaining processes
            if pgrep -f "candump" >/dev/null; then
                print_warning "CAN monitoring processes still running:"
                pgrep -f "candump" || true
            else
                print_success "No CAN monitoring processes running"
            fi
            ;;
        "prod")
            print_info "Production environment status:"
            if kubectl get deployment dk-service-can-provider >/dev/null 2>&1; then
                print_warning "Deployment still exists"
                kubectl get deployment dk-service-can-provider
            else
                print_success "Deployment is removed"
            fi
            
            if kubectl get pods -l app=dk-service-can-provider 2>/dev/null | grep -q "dk-service-can-provider"; then
                print_warning "Pods still exist"
                kubectl get pods -l app=dk-service-can-provider
            else
                print_success "No pods found"
            fi
            ;;
    esac
}

# Show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  local    Stop local development environment"
    echo "  prod     Stop production k3s environment"
    echo ""
    echo "OPTIONS:"
    echo "  --cleanup         Clean up additional resources"
    echo "  --clean-vcan      Remove virtual CAN interface (local only)"
    echo "  --clean-images    Remove Docker/k3s images"
    echo "  --force           Force stop all processes"
    echo "  --status          Show status after stop"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local                    # Stop local development"
    echo "  $0 prod                     # Stop k3s deployment"
    echo "  $0 local --cleanup          # Stop and clean up local resources"
    echo "  $0 local --clean-vcan       # Stop and remove virtual CAN"
    echo "  $0 prod --clean-images      # Stop and remove k3s images"
    echo "  $0 local --force            # Force stop local environment"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    print_info "Stopping dk_service_can_provider..."
    print_info "Environment: $ENVIRONMENT"
    
    # Handle force flag
    if [[ "$2" == "--force" ]]; then
        force_stop
        exit 0
    fi
    
    case $ENVIRONMENT in
        "local")
            stop_local
            ;;
        "prod")
            stop_prod
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            show_usage
            exit 1
            ;;
    esac
    
    # Handle cleanup flags
    if [[ "$2" == "--cleanup" ]] || [[ "$2" == "--clean-vcan" ]] || [[ "$2" == "--clean-images" ]]; then
        cleanup
    fi
    
    # Show status if requested
    if [[ "$2" == "--status" ]] || [[ "$3" == "--status" ]]; then
        echo ""
        show_status
    fi
    
    print_success "Service stopped successfully!"
}

# Run main function with all arguments
main "$@"