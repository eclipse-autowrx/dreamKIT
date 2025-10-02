#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate image and container names from parent directory
PARENT_DIR=$(basename "$(pwd)")
IMAGE_NAME=$(echo "$PARENT_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/^[^a-z0-9]*//')
CONTAINER_NAME="${IMAGE_NAME}"

# Add default if empty
if [ -z "$IMAGE_NAME" ]; then
    IMAGE_NAME="velocitas-app"
    CONTAINER_NAME="velocitas-app"
fi

# Environment variables (can be overridden)
SDV_MIDDLEWARE_TYPE="${SDV_MIDDLEWARE_TYPE:-native}"
SDV_MQTT_ADDRESS="${SDV_MQTT_ADDRESS:-mqtt://localhost:1883}"
SDV_VEHICLEDATABROKER_ADDRESS="${SDV_VEHICLEDATABROKER_ADDRESS:-grpc://localhost:55555}"

# Duration to follow logs (seconds), default 30s
LOG_DURATION="${LOG_DURATION:-30}"

echo -e "${GREEN}Starting Velocitas Vehicle App...${NC}"
echo -e "${BLUE}Image: ${IMAGE_NAME}:latest${NC}"
echo -e "${BLUE}Container: ${CONTAINER_NAME}${NC}"
echo ""

# Check if image exists
if ! docker image inspect "${IMAGE_NAME}:latest" >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker image '${IMAGE_NAME}:latest' not found${NC}"
    echo -e "${YELLOW}Please run ./build.sh first to build the image${NC}"
    exit 1
fi

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Container '${CONTAINER_NAME}' already exists${NC}"
    echo -e "${YELLOW}Stopping and removing existing container...${NC}"
    docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ Removed existing container${NC}"
fi

# Run the container
echo -e "${YELLOW}Starting container with environment:${NC}"
echo -e "  SDV_MIDDLEWARE_TYPE: ${SDV_MIDDLEWARE_TYPE}"
echo -e "  SDV_MQTT_ADDRESS: ${SDV_MQTT_ADDRESS}"
echo -e "  SDV_VEHICLEDATABROKER_ADDRESS: ${SDV_VEHICLEDATABROKER_ADDRESS}"
echo ""

docker run \
    --name "${CONTAINER_NAME}" \
    -d \
    --network host \
    -e SDV_MIDDLEWARE_TYPE="${SDV_MIDDLEWARE_TYPE}" \
    -e SDV_MQTT_ADDRESS="${SDV_MQTT_ADDRESS}" \
    -e SDV_VEHICLEDATABROKER_ADDRESS="${SDV_VEHICLEDATABROKER_ADDRESS}" \
    "${IMAGE_NAME}:latest"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started successfully${NC}"
    echo ""

    # Wait a moment for container to initialize
    sleep 2

    # Check if container is still running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${GREEN}✓ Container is running${NC}"
        echo -e "${BLUE}Following logs for ${LOG_DURATION} seconds (Press Ctrl+C to stop earlier)...${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Follow logs for specified duration
        timeout "${LOG_DURATION}s" docker logs -f "${CONTAINER_NAME}" 2>&1 || true

        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}Container is still running in background${NC}"
        echo -e "${BLUE}Useful commands:${NC}"
        echo -e "  View logs:       ${YELLOW}docker logs -f ${CONTAINER_NAME}${NC}"
        echo -e "  Stop container:  ${YELLOW}./stop.sh${NC}"
        echo -e "  Container stats: ${YELLOW}docker stats ${CONTAINER_NAME}${NC}"
    else
        echo -e "${RED}✗ Container stopped unexpectedly${NC}"
        echo -e "${YELLOW}Last logs:${NC}"
        docker logs "${CONTAINER_NAME}" 2>&1
        exit 1
    fi
else
    echo -e "${RED}✗ Failed to start container${NC}"
    exit 1
fi
