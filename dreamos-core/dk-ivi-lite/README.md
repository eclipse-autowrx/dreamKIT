
# Table of Contents

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [QT library](#qt-library)
  - [System Dependency](#system-dependency)


# Overview

dk_ivi is a comprehensive In-Vehicle Infotainment System UI application designed for seamless user interaction with the dreamKIT automotive platform. This modern IVI system serves as the central interface for vehicle applications and services within the dreamKIT ecosystem.

## DreamKIT Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ComputeECU    │────│   ZonalECU      │────│   DreamPACK     │
│  (Jetson Orin)  │LAN │  (S32G Box)     │CAN │  (Classic ECUs) │
│                 │    │                 │LIN │                 │
│  192.168.56.48  │    │  192.168.56.49  │ETH │   Actuators     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        │ Internet               │ Vehicle Networks       │ Sensors
        │ K3s Master             │ CAN/LIN Gateway        │ Motors
        │ Local Registry         │ K3s Agent              │ Controls
```

## Key Features

### 1. Marketplace Connectivity
dk_ivi integrates with the [Digital Auto Marketplace](https://marketplace.digitalauto.tech/) to provide:
- Access to the latest vehicle applications and services
- Seamless discovery of automotive software components
- Streamlined process for installing, deploying, and remotely managing applications within the dreamKIT platform
- Real-time updates and version management for deployed services

### 2. Playground Integration
The system connects to [Digital Auto Playground](https://playground.digital.auto) through the sdv-runtime container, featuring:
- Integration with kuksa-databroker server for vehicle data management
- Support for deploying custom VSS (Vehicle Signal Specification) models
- Interactive experience with demo HVAC controls including:
  - LowBeam and HighBeam lighting controls
  - HazardLight management
  - Driver and Passenger fan speed controls
  - Seat position adjustments
- Real-time vehicle signal monitoring and control capabilities


# Prerequisites

## QT library

For the CMake or Docker build
- The user need to have the refer to the Dockerfile and 'apt-get' to get all necessary library

For the QT creator
- The project is compatible with QT6 6.9.0
  

## System Dependency

Install dreamOS without dk_ivi (\installation-scripts\jetson-orin\dk_install.sh)


# Development Scenarios

## Scenario 1: Local Development

For local development and testing, dk_ivi provides a streamlined K3s-based workflow using utility scripts:

### Build Process
Build the dk_ivi Docker image and prepare it for deployment:
```shell
./build.sh
```
This script:
- Builds the Docker image `dk_ivi:latest` using the Dockerfile
- Prepares the image for local K3s deployment
- Provides feedback on the build status

### Start Process
Deploy and run dk_ivi in the local K3s cluster:
```shell
./start.sh
```
This script:
- Automatically detects the environment (architecture, user configuration)
- Sets up required environment variables for dreamKIT integration
- Imports the Docker image into K3s container runtime
- Applies Kubernetes manifests with environment variable substitution
- Deploys the application as a K3s pod

### Stop Process
Stop and clean up the dk_ivi deployment:
```shell
./stop.sh
```
This script:
- Terminates any running Docker containers
- Removes the K3s deployment
- Cleans up resources while preserving the built image for future use

### Environment Configuration
The scripts automatically detect and configure:
- **Architecture**: AMD64 or ARM64 based on the host system
- **User Environment**: Supports Jetson (sdv-orin), development (developer), or current user
- **Display Configuration**: X11 forwarding for GUI applications
- **dreamKIT Integration**: Proper environment variables and volume mounts


