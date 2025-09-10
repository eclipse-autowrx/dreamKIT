# dk_service_can_provider

> **Overview**  
> This Docker service provides CAN bus communication based on CAN signals defined in `.dbc` files and VSS (Vehicle Signal Specification) signals. It bridges CAN bus messages with KUKSA databroker for vehicle data management.

## 🎯 Development Scenarios & Workflows

Choose the workflow that matches your development environment and goals:

### 📋 Scenario Overview

| Scenario | Environment | Architecture | Use Case | Workflow |
|----------|-------------|--------------|----------|----------|
| **Local Dev (x86)** | Ubuntu x86_64 | amd64 | Development & Testing | [Local Development](#-scenario-1-local-development-x86_64) |
| **Local Dev (ARM)** | Jetson Orin | arm64 | Native ARM Testing | [ARM Development](#-scenario-2-arm-development-jetson-orin) |
| **Production** | k3s Cluster | arm64 | Production Deployment | [Production Deployment](#-scenario-3-production-deployment-k3s) |
| **Marketplace** | Public Release | arm64 | Public Distribution | [Marketplace Release](#-scenario-4-marketplace-release) |

---

## 🖥️ Scenario 1: Local Development (x86_64)

**When to use:** Developing and testing on Ubuntu x86_64 with virtual CAN

### Prerequisites
- Ubuntu x86_64 system
- Docker installed
- KUKSA databroker running on localhost:55555
- CAN utilities: `sudo apt install can-utils`

### Workflow
```bash
# 1. Build for current architecture (auto-detected)
./build.sh local

# 2. Start development environment
./start.sh local

# 3. Test the service
kuksa-client grpc://127.0.0.1:55555
# Test commands:
setTargetValue Vehicle.Body.Lights.Beam.Low.IsOn true

# 4. Monitor CAN traffic
candump vcan0

# 5. Stop when done
./stop.sh local
```

### Configuration
- **KUKSA Address:** `localhost:55555`
- **CAN Interface:** `vcan0` (virtual)
- **VSS Mapping:** `mapping/vss_4.0/vss_dbc.json`
- **Architecture:** Auto-detected (amd64)

---

## 💻 Scenario 2: ARM Development (Jetson Orin)

**When to use:** Testing directly on ARM64 hardware before production deployment

### Prerequisites
- Jetson Orin with Ubuntu ARM64
- Docker installed
- KUKSA databroker running
- Physical CAN interface or virtual CAN

### Workflow
```bash
# 1. Build for current architecture (ARM64 auto-detected)
./build.sh local

# 2. Start with virtual CAN for testing
./start.sh local

# OR start with physical CAN
docker run -d -it --name dk_service_can_provider --net=host --privileged \
  -e KUKSA_ADDRESS=localhost \
  -e CAN_PORT=can1 \
  -e MAPPING_FILE=mapping/vss_4.0/vss_dbc.json \
  dk_service_can_provider:latest

# 3. Test the service
kuksa-client grpc://127.0.0.1:55555

# 4. Monitor CAN traffic
candump can1  # or vcan0

# 5. Stop when done
./stop.sh local
```

### Configuration
- **KUKSA Address:** `localhost:55555`
- **CAN Interface:** `can1` (physical) or `vcan0` (virtual)
- **VSS Mapping:** `mapping/vss_4.0/vss_dbc.json`
- **Architecture:** ARM64 (auto-detected)

---

## 🚀 Scenario 3: Production Deployment (k3s)

**When to use:** Deploying to production k3s cluster with distributed nodes

### Prerequisites
- k3s cluster running
- Jetson Orin as master (192.168.56.48)
- S32G as agent node with CAN interface
- kubectl configured

### Option A: Using Pre-built Image (Recommended)
```bash
# 1. Build and push to GitHub Container Registry
./build.sh prod --push

# 2. Deploy to k3s (pulls from GHCR)
kubectl apply -f manifests/mirror-remote.yaml    # Pull image to local registry
kubectl apply -f manifests/deployment.yaml # Deploy service
kubectl apply -f manifests/service.yaml   # Create service

# 3. Monitor deployment
kubectl get pods -l app=dk-service-can-provider
kubectl logs -f -l app=dk-service-can-provider

# 4. Test the service
kuksa-client grpc://192.168.56.48:55555
```

### Option B: Using Local Image Import
```bash
# 1. Build for production
./build.sh prod

# 2. Import to k3s and deploy
./start.sh prod --import

# 3. Monitor deployment
./start.sh prod --status
```

### Option C: Manual Image Import (Your Method)
```bash
# 1. Build production image
./build.sh prod

# 2. Save and import image
docker save dk_service_can_provider:latest > dk_service_can_provider.tar
sudo k3s ctr images import dk_service_can_provider.tar
rm dk_service_can_provider.tar

# 3. Deploy manifests
kubectl apply -f manifests/mirror-local.yaml
kubectl apply -f manifests/deployment.yaml
```

### Configuration
- **KUKSA Address:** `192.168.56.48:55555`
- **CAN Interface:** `can1` (physical on S32G)
- **VSS Mapping:** `mapping/vss_4.0/vss_dbc.json`
- **Architecture:** ARM64
- **Node Assignment:** Service runs on `vip` node

---

## 🌐 Scenario 4: Marketplace Release

**When to use:** Publishing to Digital Auto Marketplace for public distribution

### Prerequisites
- Tested and validated service
- GitHub Container Registry access
- Digital Auto Marketplace account

### Workflow
```bash
# 1. Build and test locally (ARM64)
./build.sh local  # On Jetson Orin

# 2. Build and push production image
./build.sh prod v1.0.0 --push

# 3. Verify image is public
docker pull ghcr.io/eclipse-autowrx/dk_service_can_provider:v1.0.0

# 4. Submit to marketplace with template
```

### Marketplace Template
```json
{
  "Target": "vip",
  "Platform": "linux/arm64",
  "DockerImageURL": "ghcr.io/eclipse-autowrx/dk_service_can_provider:latest",
  "RuntimeCfg": {
    "CAN_PORT": "can1",
    "MAPPING_FILE": "mapping/vss_4.0/vss_dbc.json",
    "KUKSA_ADDRESS": "192.168.56.48"
  }
}
```

### Configuration
- **Public Image:** `ghcr.io/eclipse-autowrx/dk_service_can_provider:latest`
- **Target Node:** `vip` (agent node with CAN access)
- **Platform:** `linux/arm64`
- **Runtime Config:** Production settings

---

## 🛠️ Build Script Reference

### Commands
```bash
# Auto-detect architecture and build for local development
./build.sh local [version]

# Build for production (ARM64) deployment
./build.sh prod [version] [--push]

# Build for both environments
./build.sh both [version]
```

### Architecture Detection
- **x86_64 → linux/amd64** (Ubuntu development)
- **aarch64/arm64 → linux/arm64** (Jetson Orin/Production)

### Examples
```bash
./build.sh local              # Current arch, latest tag
./build.sh local v1.0.0       # Current arch, specific version
./build.sh prod               # ARM64, latest tag
./build.sh prod v1.0.0 --push # ARM64, push to GHCR
./build.sh both               # Both architectures
```

---

## 📊 Service Management

### Start Service
```bash
./start.sh local              # Local development
./start.sh prod               # Production deployment
./start.sh prod --import      # Import image and deploy
./start.sh [env] --status     # Check status
```

### Stop Service
```bash
./stop.sh local               # Stop local container
./stop.sh prod                # Stop k3s deployment
./stop.sh [env] --cleanup     # Stop and cleanup
./stop.sh [env] --force       # Force stop
```

### Monitor Service
```bash
# Local
docker logs -f dk_service_can_provider
candump vcan0

# Production
kubectl logs -f -l app=dk-service-can-provider
kubectl get pods -l app=dk-service-can-provider
```

---

## 🔧 Configuration Reference

### Environment Variables

| Variable | Local | Production | Description |
|----------|-------|------------|-------------|
| `KUKSA_ADDRESS` | `localhost` | `192.168.56.48` | KUKSA databroker address |
| `CAN_PORT` | `vcan0` | `can1` | CAN interface name |
| `MAPPING_FILE` | `mapping/vss_3.0/vss_dbc.json` | `mapping/vss_4.0/vss_dbc.json` | VSS mapping file |
| `LOG_LEVEL` | `INFO` | `INFO` | Logging verbosity |
| `DBC_FILE` | `ModelCAN.dbc` | `ModelCAN.dbc` | DBC definition file |

### Network Architecture

```
Development (Local):
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Developer     │    │   Docker     │    │   KUKSA         │
│   Machine       │◄──►│   Container  │◄──►│   Databroker    │
│   (vcan0)       │    │              │    │   (localhost)   │
└─────────────────┘    └──────────────┘    └─────────────────┘

Production (k3s):
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   S32G          │    │   k3s Pod    │    │   Jetson Orin   │
│   (can0/can1)   │◄──►│   (vip node) │◄──►│   KUKSA Server  │
│                 │    │              │    │   (192.168.56.48)│
└─────────────────┘    └──────────────┘    └─────────────────┘
```

---

## 🧪 Testing & Validation

### VSS Signal Testing

#### VSS 4.x (Default Model)
```bash
kuksa-client grpc://127.0.0.1:55555
# or
kuksa-client grpc://192.168.56.48:55555

# Light Controls
setTargetValue Vehicle.Body.Lights.Beam.Low.IsOn true
setTargetValue Vehicle.Body.Lights.Beam.High.IsOn false
setTargetValue Vehicle.Body.Lights.Hazard.IsSignaling true

# Seat Position (0-10)
setTargetValue Vehicle.Cabin.Seat.Row1.DriverSide.Position 5

# HVAC Fan Speed (0-100)
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed 75
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed 50
```

#### VSS 3.x (Alternative Model)
```bash
kuksa-client grpc://127.0.0.1:55555
# or
kuksa-client grpc://192.168.56.48:55555

# Light Controls
setTargetValue Vehicle.Body.Lights.IsLowBeamOn true
setTargetValue Vehicle.Body.Lights.IsBrakeOn true
setTargetValue Vehicle.Body.Lights.IsHazardOn true

# Seat Position
setTargetValue Vehicle.Cabin.Seat.Row1.Pos1.Position 5

# HVAC Fan Speed
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Left.FanSpeed 75
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Right.FanSpeed 50
```

### Expected CAN Messages
```bash
# Low Beam On
can1  3E9   [8]  01 00 00 00 00 00 00 00

# Hazard On  
can1  3E9   [8]  04 00 00 00 00 00 00 00

# Seat Position 5
can1  3C3   [8]  14 00 00 00 00 00 00 00

# HVAC Driver Fan 75%
can1  20C   [8]  00 00 4B 00 0A 00 05 00
```

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Architecture Mismatch
```bash
# Check current architecture
uname -m

# Rebuild for correct architecture
./build.sh local
```

#### 2. CAN Interface Issues
```bash
# Check CAN interface
ip link show can1        # Physical
ip link show vcan0       # Virtual

# Create virtual CAN
sudo modprobe vcan
sudo ip link add dev vcan0 type vcan
sudo ip link set up vcan0
```

#### 3. KUKSA Connection Issues
```bash
# Test KUKSA connectivity
telnet 192.168.56.48 55555  # Production
telnet localhost 55555      # Local

# Check KUKSA logs
docker logs sdv-runtime
```

#### 4. k3s Deployment Issues
```bash
# Check k3s status
sudo systemctl status k3s

# Check node status
kubectl get nodes

# Check pod logs
kubectl logs -l app=dk-service-can-provider

# Check image import
sudo k3s ctr images ls | grep dk_service_can_provider
```

#### 5. Mirror Job Issues
```bash
# Check mirror job logs
kubectl logs job/mirror-dk-service-can-provider

# Manually verify image
sudo k3s ctr images ls | grep localhost:5000/dk_service_can_provider
```

---

## 📚 File Structure

```
dk_service_can_provider/
├── README.md                 # This file
├── DEPLOYMENT.md            # Detailed deployment guide
├── Dockerfile               # Container definition
├── build.sh                 # Build script
├── start.sh                 # Start script  
├── stop.sh                  # Stop script
├── manifests/               # k3s deployment files
│   ├── mirror-local.yaml    # Local image mirror job
│   ├── mirror-remote.yaml   # Remote image mirror job
│   ├── deployment.yaml      # Service deployment
│   └── service.yaml         # Service configuration
├── prepare-dbc-file/        # DBC preparation scripts
│   └── createvcan.sh        # Virtual CAN setup
├── mapping/                 # VSS mapping files
│   ├── vss_3.0/            # VSS 3.x mappings
│   └── vss_4.0/            # VSS 4.x mappings
├── config/                  # Configuration files
│   └── dbc_feeder.ini       # DBC feeder configuration
```

---

## 🚀 Quick Reference

### Development Cycle
```bash
# 1. Choose your scenario
./build.sh local           # Current architecture
./build.sh prod            # Production ARM64

# 2. Start service
./start.sh local           # Development
./start.sh prod --import   # Production with import

# 3. Test and validate
kuksa-client grpc://[address]:55555

# 4. Stop and cleanup
./stop.sh [env] --cleanup
```

### Production Release
```bash
# 1. Final testing on ARM64
./build.sh local           # On Jetson Orin

# 2. Create release
./build.sh prod v1.0.0 --push

# 3. Submit to marketplace
# Use marketplace template with GHCR URL
```

This comprehensive guide ensures you can successfully develop, test, and deploy the dk_service_can_provider service across all scenarios and environments.