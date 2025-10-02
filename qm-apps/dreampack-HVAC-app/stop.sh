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

# Generate container name from parent directory
PARENT_DIR=$(basename "$(pwd)")
CONTAINER_NAME=$(echo "$PARENT_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/^[^a-z0-9]*//')

# Add default if empty
if [ -z "$CONTAINER_NAME" ]; then
    CONTAINER_NAME="velocitas-app"
fi

echo -e "${YELLOW}Stopping Velocitas Vehicle App...${NC}"
echo -e "${BLUE}Container: ${CONTAINER_NAME}${NC}"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Container '${CONTAINER_NAME}' does not exist${NC}"
    exit 0
fi

# Check if container is running
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${YELLOW}Stopping container...${NC}"
    docker stop "${CONTAINER_NAME}" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Container stopped${NC}"
    else
        echo -e "${RED}✗ Failed to stop container${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}Container is not running${NC}"
fi

# Remove container
echo -e "${YELLOW}Removing container...${NC}"
docker rm "${CONTAINER_NAME}" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container removed${NC}"
    echo ""
    echo -e "${GREEN}Vehicle app stopped successfully${NC}"
else
    echo -e "${RED}✗ Failed to remove container${NC}"
    exit 1
fi
