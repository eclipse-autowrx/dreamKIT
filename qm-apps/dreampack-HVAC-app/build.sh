#!/bin/bash
#
# Docker build script for DreamPack HVAC Simple DataBroker App
#

echo "🐳 Building DreamPack HVAC Simple DataBroker Docker Image"
echo "========================================================"

# Set variables
IMAGE_NAME="dreampack-hvac-app"
IMAGE_TAG="simple-databroker"
FULL_IMAGE_NAME="$IMAGE_NAME:$IMAGE_TAG"

# Check if we're in the right directory
if [ ! -f "Dockerfile" ]; then
    echo "❌ Error: Please run this script from the dreampack-HVAC-app directory"
    echo "   Current directory: $(pwd)"
    exit 1
fi

echo "📋 Build Information:"
echo "   Image Name: $FULL_IMAGE_NAME"
echo "   Context: $(pwd)"
echo ""

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t "$FULL_IMAGE_NAME" .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Docker image built successfully: $FULL_IMAGE_NAME"
    echo ""
    echo "📖 Usage Options:"
    echo "  1. Using docker run directly:"
    echo "     docker run --rm --network=host $FULL_IMAGE_NAME"
    echo ""
    echo "  2. With custom KUKSA address:"
    echo "     docker run --rm --network=host -e KUKSA_ADDRESS=192.168.56.48 $FULL_IMAGE_NAME"
    echo ""
    echo "🔧 Environment Variables:"
    echo "   KUKSA_ADDRESS - DataBroker address (default: localhost)"
    echo "   KUKSA_PORT    - DataBroker port (default: 55555)"
    echo "   LOG_LEVEL     - Logging level (default: INFO)"
else
    echo ""
    echo "❌ Docker image build failed!"
    exit 1
fi