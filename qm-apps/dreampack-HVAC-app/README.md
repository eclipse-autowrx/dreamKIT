# DreamPack HVAC App

> **Overview**
> This KUKSA client application demonstrates AI-powered HVAC control through Vehicle Signal Specification (VSS) signals. It simulates an intelligent climate control system that responds to voice commands and automatically adjusts fan speeds based on AI decisions.

## <� Demo Scenarios & Features

### > AI-Powered Climate Control

This demo simulates real-world scenarios where an AI assistant responds to user voice commands for climate control:

| User Command | AI Response | QM App Action |
|--------------|-------------|---------------|
| "Hey AI, I'm feeling hot, turn up the AC!" | "Sure! Increasing fan speed to cool you down." | Sets fan speed to 80% |
| "It's too cold now, reduce airflow please." | "Of course! Reducing fan speed for your comfort." | Sets fan speed to 30% |
| "Turn off the AC, I want fresh air." | "Turning off AC as requested - fresh air mode activated" | Sets fan speed to 0% |

### =� VSS Signals Controlled

- `Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed` (0-100%)
- `Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed` (0-100%)

### <� Demo Simulation

The application cycles through various AI-driven climate scenarios:
- **Gentle Breeze** (25%) - Comfortable reading mode
- **Moderate Cooling** (50%) - Normal driving comfort
- **High Cooling** (75%) - Warm weather response
- **Maximum Cooling** (100%) - Hot day quick cooling
- **Custom Adjustments** (40%) - Target temperature reached

---

## =3 Docker Deployment Options

Choose the deployment method that matches your environment:

### =� Deployment Scenarios

| Scenario | Environment | Use Case | Command |
|----------|-------------|----------|---------|
| **Local Development** | x86_64 Ubuntu | Development & Testing | `docker compose up` |
| **Production** | ARM64 k3s | Production Deployment | `./build.sh prod --push` |
| **Standalone** | Any Docker Host | Quick Testing | `docker run` |

---

## =� Prerequisites

- **Docker** and **Docker Compose** installed
- **dreamOS** with **sdv-runtime** container running (includes KUKSA databroker)
- **Network connectivity** to sdv-runtime at port 55555

### dreamOS sdv-runtime Verification

```bash
# Manual verification steps:
# 1. Check if sdv-runtime container is running (includes KUKSA databroker)
kubectl get pods | grep sdv-runtime

# 2. Verify KUKSA databroker port accessibility
telnet 192.168.56.48 55555

# 3. Check sdv-runtime container status
kubectl logs -f sdv-runtime
```

---

## =� Quick Start

### Docker (Recommended)

1. **Build and Run**:
   ```bash
   # Build the image
   ./build.sh

   # Or run directly with custom KUKSA address
   docker run --rm --network=host \
     -e KUKSA_ADDRESS=192.168.56.48 \
     dreampack-hvac-app:simple-databroker
   ```

2. **Environment Configuration**:
   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit with your settings
   # KUKSA_ADDRESS=192.168.56.48
   # KUKSA_PORT=55555
   # LOG_LEVEL=INFO
   ```

### Local Python Development

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment (optional)
export KUKSA_ADDRESS=192.168.56.48

# Run the app
python src/main.py
```

---

## � Configuration

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

## >� Testing & Validation

### Expected Output

```bash
================================================================================
> AI-POWERED HVAC CONTROL DEMO
================================================================================
=� AI Climate Assistant Demo Started! Press Ctrl+C to stop.

<� User Request Detected...
> AI: 'Setting gentle breeze for comfortable reading'
�  QM App: Executing AI command � Fan Speed: 25% (ACTIVE)
 Climate adjustment complete!

<� User Request Detected...
> AI: 'Moderate cooling for normal driving comfort'
�  QM App: Executing AI command � Fan Speed: 50% (ACTIVE)
 Climate adjustment complete!
```

### Manual VSS Testing

Connect to sdv-runtime (dreamOS) to verify signal updates:

```bash
# Install KUKSA client
pip install kuksa-client

# Connect to dreamOS sdv-runtime
kuksa-client grpc://192.168.56.48:55555

# Check current values
get Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed
get Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed

# Manual testing
setTargetValue Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed 75

# Health check - verify connection
get Vehicle.Speed  # Basic connectivity test
```

---

## =
 Troubleshooting

### Common Issues

#### 1. sdv-runtime Connection Failed
```bash
# Check sdv-runtime connectivity
telnet 192.168.56.48 55555

# Verify sdv-runtime container is running in dreamOS
kubectl get pods | grep sdv-runtime
kubectl logs sdv-runtime

# Health check from container
docker exec dreampack-hvac-app python -c "import socket; s=socket.socket(); s.settimeout(5); print('OK' if s.connect_ex(('192.168.56.48', 55555)) == 0 else 'FAIL'); s.close()"
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

## =� File Structure

```
dreampack-HVAC-app/
── README.md                # This documentation
── Dockerfile               # Container definition
── build.sh                 # Build automation script
── requirements.txt         # Python dependencies
── src/                     # Application source
│   ── main.py              # Main application entry
│   └── vehicle.py            # Vehicle model 
│   └── databroker_client.py  # databroker_client
```

---
