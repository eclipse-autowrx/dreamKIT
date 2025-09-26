# DreamPack HVAC App

## 📋 Project Overview

This KUKSA client application demonstrates HVAC control through Vehicle Signal Specification (VSS) signals, designed in two development phases:

- **Phase 1 (Current)**: Direct HVAC control via KUKSA DataBroker
- **Phase 2 (Future)**: AI-powered voice command integration

---

## 🎯 Development Phases

### Phase 1: Direct HVAC Control (Current Implementation)

**Status:** ✅ **Available Now**

**Description:**
Direct control of HVAC fan speeds through KUKSA DataBroker integration. The application demonstrates VSS signal manipulation with simulated climate scenarios.

**Features:**
- Direct VSS signal control
- Automated climate scenario simulation
- KUKSA DataBroker integration
- Real-time fan speed adjustments

**Demo Scenarios:**
| Scenario | Fan Speed | Description |
|----------|-----------|-------------|
| Fresh Air Mode | 0% | AC turned off |
| Gentle Breeze | 25% | Comfortable reading mode |
| Moderate Cooling | 50% | Normal driving comfort |
| High Cooling | 75% | Warm weather response |
| Maximum Cooling | 100% | Hot day quick cooling |
| Custom Adjustment | 40% | Target temperature reached |

### Phase 2: AI-Powered Climate Control (Future Vision)

**Status:** 🚧 **Planned Development**

**Description:**
Integration of AI voice commands with the existing HVAC control system. This phase will add natural language processing and voice recognition capabilities.

**Planned Features:**
- Voice command recognition
- Natural language AI processing
- Context-aware climate adjustments
- Conversational AI responses

**Future Demo Flow:**
| User Command | AI Response | QM App Action |
|--------------|-------------|---------------|
| "Hey AI, I'm feeling hot, turn up the AC!" | "Sure! Increasing fan speed to cool you down." | Sets fan speed to 80% |
| "It's too cold now, reduce airflow please." | "Of course! Reducing fan speed for your comfort." | Sets fan speed to 30% |
| "Turn off the AC, I want fresh air." | "Turning off AC as requested - fresh air mode activated" | Sets fan speed to 0% |

---

## 📡 VSS Signals Controlled

- `Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed` (0-100%)
- `Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed` (0-100%)

---

## 🐳 Docker Deployment Options

Choose the deployment method that matches your environment:

### 📋 Deployment Scenarios

| Scenario | Environment | Use Case | Workflow |
|----------|-------------|----------|----------|
| **Local Development** | x86_64 or ARM64 | Development & Testing | [Quick Start](#-quick-start) |
| **Standalone** | Any Docker Host | Quick Testing | [Quick Start](#-quick-start) |
| **Production** | Marketplace | Public Distribution | [Marketplace Release](#-marketplace-release) |

---

## 🔧 Prerequisites

- **Docker** and **Docker Compose** installed
- **dreamOS** with **sdv-runtime** container running (includes KUKSA databroker)
- **Network connectivity** to sdv-runtime at port 55555

### dreamOS sdv-runtime Verification

```bash
# Manual verification steps:
# 1. Check if sdv-runtime container is running (includes KUKSA databroker)
kubectl get pods | grep sdv-runtime

# 2. Verify KUKSA databroker port accessibility
telnet localhost 55555

# 3. Check sdv-runtime container status
kubectl logs -f sdv-runtime
```

---

## 🚀 Quick Start

### Docker (Recommended)

1. **Build and Run**:
   ```bash
   # Build the image
   ./build.sh

   # Or run directly with custom KUKSA address
   docker run --rm --network=host \
     -e KUKSA_ADDRESS=localhost \
     dreampack-hvac-app:simple-databroker
   ```

2. **Environment Configuration**:
   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit with your settings
   # KUKSA_ADDRESS=localhost
   # KUKSA_PORT=55555
   # LOG_LEVEL=INFO
   ```

### Local Python Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment (optional)
export KUKSA_ADDRESS=localhost

# Run the app
python src/main.py
```

---

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KUKSA_ADDRESS` | `192.168.56.48` | sdv-runtime address (dreamOS) |
| `KUKSA_PORT` | `55555` | KUKSA databroker port |
| `LOG_LEVEL` | `INFO` | Application log level |

### Network Architecture

```
Development (Local Testing):
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   HVAC App      │    │   Host       │    │   dreamOS       │
│   Container     │◄──►│   Network    │◄──►│   sdv-runtime   │
│                 │    │              │    │   (KUKSA:55555) │
└─────────────────┘    └──────────────┘    └─────────────────┘

Production (k3s dreamOS):
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   k3s Pod       │    │   Cluster    │    │   sdv-runtime   │
│   (HVAC App)    │◄──►│   Network    │◄──►│   Pod (KUKSA)   │
│                 │    │              │    │   (192.168.56.48)│
└─────────────────┘    └──────────────┘    └─────────────────┘
```

---

## ✅ Testing & Validation

### Expected Output

```bash
================================================================================
🤖 AI-POWERED HVAC CONTROL DEMO - Simple DataBroker Edition
================================================================================
📋 AI Climate Assistant Demo Started! Press Ctrl+C to stop.

🎤 User Request Detected...
🤖 AI: 'Setting gentle breeze for comfortable reading'
⚙️  DataBroker: Executing AI command → Fan Speed: 25% (ACTIVE)
✅ Climate adjustment complete via DataBroker!

🎤 User Request Detected...
🤖 AI: 'Moderate cooling for normal driving comfort'
⚙️  DataBroker: Executing AI command → Fan Speed: 50% (ACTIVE)
✅ Climate adjustment complete via DataBroker!
```

### Manual VSS Testing

Connect to sdv-runtime (dreamOS) to verify signal updates:

```bash
# Install KUKSA client
pip install kuksa-client

# Connect to dreamOS sdv-runtime
kuksa-client grpc://localhost:55555

# Check current values
get Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed
get Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed

# Manual testing
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed 75

# Health check - verify connection
get Vehicle.Speed  # Basic connectivity test
```

---
## 🌐 Marketplace Release

**When to use:** Publishing to Digital Auto Marketplace for public distribution

### Prerequisites
- Tested and validated service
- GitHub Container Registry access
- Digital Auto Marketplace account

### Workflow
```bash
# 1. Publish the docker image (Docker Hub or Github (this demo))

# 2. Verify image is public
docker pull ghcr.io/eclipse-autowrx/dk_app_dreampack_hvac:latest

# 3. Submit to marketplace with template
```

### Marketplace Template
```json
{
  "Target": "xip",
  "Platform": "linux/arm64",
  "DockerImageURL": "ghcr.io/eclipse-autowrx/dk_app_dreampack_hvac:latest",
  "RuntimeCfg": {
    "KUKSA_ADDRESS": "localhost"
  }
}
```

### Configuration
- **Public Image:** `ghcr.io/eclipse-autowrx/dk_app_dreampack_hvac:latest`
- **Target Node:** `xip` (master node with sdv-runtime locally access)
- **Platform:** `linux/arm64`
- **Runtime Config:** Production settings

---

## 🔍 Troubleshooting

### Common Issues

#### 1. sdv-runtime Connection Failed
```bash
# Check sdv-runtime connectivity
telnet localhost 55555

# Verify sdv-runtime container is running in dreamOS
kubectl get pods | grep sdv-runtime
kubectl logs sdv-runtime

# Health check from container
docker exec dreampack-hvac-app python -c "import socket; s=socket.socket(); s.settimeout(5); print('OK' if s.connect_ex(('localhost', 55555)) == 0 else 'FAIL'); s.close()"
```

#### 2. Container Build Issues
```bash
# Check Docker daemon
systemctl status docker

# Clean build cache
docker system prune -a
```

#### 3. Architecture Mismatch
```bash
# Check current architecture
uname -m
```

#### 4. Permission Issues
```bash
# Make scripts executable
chmod +x build.sh

# Check Docker permissions
sudo usermod -aG docker $USER
```

---

## 📁 File Structure

```
dreampack-HVAC-app/
├── README.md                # This documentation
├── Dockerfile               # Container definition
├── build.sh                 # Build automation script
├── requirements.txt         # Python dependencies
├── src/                     # Application source
│   ├── main.py              # Main application entry
│   └── vehicle.py            # Vehicle model
│   └── databroker_client.py  # databroker_client
```