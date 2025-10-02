# Velocitas Vehicle Application - Development & Deployment Guide

A streamlined workflow for developing, building, and deploying vehicle applications using the Eclipse Velocitas framework with automated VSS signal validation and Docker containerization.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Development Workflow](#development-workflow)
3. [System Architecture](#system-architecture)
4. [Quick Start](#quick-start)
5. [Detailed Usage](#detailed-usage)
6. [Marketplace Deployment](#marketplace-deployment)

---

## 🎯 Overview

This template provides an end-to-end solution for developing vehicle applications that interact with VSS (Vehicle Signal Specification) signals. The automated build system validates your code against the system VSS model and generates deployment-ready Docker images.

### Key Features

- ✅ **Automated VSS Validation**: Ensures your app only uses signals available in the system
- ✅ **Auto-generated Manifests**: AppManifest.json updated based on detected signal usage
- ✅ **Pubsub Detection**: Automatically detects and configures MQTT topics
- ✅ **Docker Packaging**: One-command build to containerized application
- ✅ **Easy Debugging**: Built-in scripts for local testing with live logs
- ✅ **Marketplace Ready**: Simple deployment to production environments

---

## 🔄 Development Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPMENT WORKFLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

1️⃣  DEFINE USE CASE
   ┌─────────────────────────────────────────────┐
   │ Current: AI-powered HVAC climate control    │
   │ Controls fan speed based on AI scenarios    │
   └─────────────────────────────────────────────┘
                          ↓
2️⃣  WRITE APPLICATION LOGIC
   ┌─────────────────────────────────────────────────────────────┐
   │ File: app/src/main.py                                       │
   │                                                             │
   │ • TestApp class with on_start() method                      │
   │ • Uses: self.Vehicle.Cabin.HVAC.Station.Row1.Driver.        │
   │         FanSpeed.set()                              [WRITE] │
   │ • Uses: self.Vehicle.Cabin.HVAC.Station.Row1.Passenger.     │
   │         FanSpeed.set()                              [WRITE] │
   │ • Optional: publish_event()/subscribe()                     │
   └─────────────────────────────────────────────────────────────┘
                          ↓
3️⃣  BUILD SYSTEM (./build.sh)
   ┌──────────────────────────────────────────────────────────────┐
   │ INPUT                                                         │
   │ ┌──────────────────┐  ┌──────────────────────────────────┐ │
   │ │ System VSS Model │  │ Your Application Code            │ │
   │ │ ~/.dk/sdv-       │  │ app/src/main.py                  │ │
   │ │ runtime/vss.json │  │                                  │ │
   │ └──────────────────┘  └──────────────────────────────────┘ │
   │                                ↓                             │
   │ PROCESSING LOGIC                                            │
   │ ┌────────────────────────────────────────────────────────┐ │
   │ │ 1. Parse System VSS Model                              │ │
   │ │    • Extract all available signals                     │ │
   │ │    • Build validation dictionary                       │ │
   │ │                                                        │ │
   │ │ 2. Analyze Application Code (main.py)                  │ │
   │ │    • Detect: self.Vehicle.*.get()  → READ access       │ │
   │ │    • Detect: self.Vehicle.*.set()  → WRITE access      │ │
   │ │    • Found: Vehicle.Cabin.HVAC.Station.Row1.Driver.    │ │
   │ │             FanSpeed → WRITE                           │ │
   │ │    • Found: Vehicle.Cabin.HVAC.Station.Row1.Passenger. │ │
   │ │             FanSpeed → WRITE                           │ │
   │ │    • Detect: subscribe()/publish() → Pubsub topics     │ │
   │ │                                                        │ │
   │ │ 3. Validate Signals                                    │ │
   │ │    • Check each used signal exists in system model     │ │
   │ │    • ✅ PASS: Continue build                            │ │
   │ │    • ❌ FAIL: Exit with error listing invalid signals   │ │
   │ │                                                        │ │
   │ │ 4. Generate Artifacts                                  │ │
   │ │    • Update app/AppManifest.json with:                 │ │
   │ │      - Required VSS signals + access permissions       │ │
   │ │      - Pubsub topics (if detected)                     │ │
   │ │                                                        │ │
   │ │ 5. Build Docker Image                                  │ │
   │ │    • Image name: <parent-folder-name>:latest           │ │
   │ │    • Example: dreampack-hvac-app:latest                │ │
   │ └────────────────────────────────────────────────────────┘ │
   │                                ↓                             │
   │ OUTPUT                                                       │
   │ ┌──────────────────────────────────────────────────────────┐│
   │ │ ✅ Updated app/AppManifest.json                          ││
   │ │ ✅ Docker Image: dreampack-hvac-app:latest               ││
   │ └──────────────────────────────────────────────────────────┘│
   └──────────────────────────────────────────────────────────────┘
                          ↓
4️⃣  LOCAL TESTING (./start.sh)
   ┌─────────────────────────────────────────────┐
   │ • Starts Docker container                   │
   │ • Connects to local databroker              │
   │ • Shows live logs for 30 seconds            │
   │ • Container continues running in background │
   └─────────────────────────────────────────────┘
                          ↓
5️⃣  DEBUG & ITERATE
   ┌─────────────────────────────────────────────┐
   │ • View logs: docker logs -f <container>     │
   │ • Stop app: ./stop.sh                       │
   │ • Modify code → rebuild → restart           │
   └─────────────────────────────────────────────┘
                          ↓
6️⃣  DEPLOY TO MARKETPLACE
   ┌─────────────────────────────────────────────┐
   │ • Tag and push Docker image to registry     │
   │ • Update marketplace web page with config   │
   │ • Deploy to target nodes                    │
   └─────────────────────────────────────────────┘
```

---

## 🏗️ System Architecture

### Wire View: Data Flow & Component Interaction

```
┌───────────────────────────────────────────────────────────────────────────┐
│                        SYSTEM ARCHITECTURE                                 │
└───────────────────────────────────────────────────────────────────────────┘

DEVELOPMENT PHASE
═════════════════════════════════════════════════════════════════════════════

┌─────────────────┐         ┌────────────────────┐
│  Developer      │         │   System VSS Model │
│                 │         │ ~/.dk/sdv-runtime/ │
│  Writes Code:   │         │      vss.json      │
│  main.py        │         │                    │
│                 │         │                    │
│ (TestApp class) │         │   (VSS signals)    │
└────────┬────────┘         └──────────┬─────────┘
         │                             │
         └──────────┬──────────────────┘
                    ↓
         ┌──────────────────────┐
         │    build.sh          │
         │                      │
         │  1. Parse VSS Model  │
         │  2. Analyze Code     │
         │  3. Validate Signals │
         │  4. Update Manifest  │
         │  5. Build Docker     │
         └──────────┬───────────┘
                    ↓
         ┌──────────────────────────┐
         │   ARTIFACTS              │
         │                          │
         │ • AppManifest.json       │
         │ • Docker Image:          │
         │   dreampack-hvac-app     │
         └──────────────────────────┘


RUNTIME PHASE (Local Testing)
═════════════════════════════════════════════════════════════════════════════

┌──────────────────┐
│   ./start.sh     │
└────────┬─────────┘
         ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Container                              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           Vehicle Application (main.py)                 │    │
│  │                                                         │    │
│  │  ┌──────────────────────────────────────────────┐     │    │
│  │  │  Velocitas SDK                                │     │    │
│  │  │  • Vehicle Signal Interface                   │     │    │
│  │  │  • Pubsub Messaging (optional)                │     │    │
│  │  └──────────┬────────────────────┬───────────────┘     │    │
│  └─────────────┼────────────────────┼─────────────────────┘    │
│                │                    │                           │
│  Environment:  │                    │                           │
│  • SDV_MIDDLEWARE_TYPE=native      │                           │
│  • SDV_VEHICLEDATABROKER_ADDRESS   │                           │
│  • SDV_MQTT_ADDRESS                │                           │
└────────────────┼────────────────────┼───────────────────────────┘
                 │                    │
                 │ gRPC               │ MQTT
                 │ (VSS Signals)      │ (Pubsub)
                 ↓                    ↓
    ┌────────────────────┐  ┌────────────────────┐
    │ Vehicle Data Broker│  │   MQTT Broker      │
    │  (localhost:55555) │  │ (localhost:1883)   │
    │                    │  │                    │
    │ • Vehicle.Speed    │  │ • app/topic/cmd    │
    │ • Vehicle.*.HVAC.* │  │ • app/topic/data   │
    └────────────────────┘  └────────────────────┘


PRODUCTION PHASE (Marketplace Deployment)
═════════════════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                    Container Registry                            │
│              (ghcr.io / Docker Hub)                             │
│                                                                  │
│   ghcr.io/your-org/dreampack-hvac-app:latest                    │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                │ Pull Image
                                ↓
┌────────────────────────────────────────────────────────────────────┐
│                     Target Edge Node                                │
│                  (Deployment via Marketplace)                      │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  Runtime Configuration (from Marketplace)                  │   │
│  │  {                                                         │   │
│  │    "Target": "xip",                                        │   │
│  │    "Platform": "linux/arm64",                              │   │
│  │    "DockerImageURL": "ghcr.io/.../app:latest",             │   │
│  │    "RuntimeCfg": {                                         │   │
│  │      "SDV_MIDDLEWARE_TYPE": "native",                      │   │
│  │      "SDV_VEHICLEDATABROKER_ADDRESS": "grpc://127.0.0.1:55555", │   │
│  │      "SDV_MQTT_ADDRESS": "mqtt://127.0.0.1:1883"           │   │
│  │    }                                                       │   │
│  │  }                                                         │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │         Running Container                                  │   │
│  │  • Connected to vehicle databroker                         │   │
│  │  • Reading/Writing VSS signals                             │   │
│  │  • Publishing/Subscribing to MQTT topics                   │   │
│  └───────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Docker installed
- VSS model at `~/.dk/sdv-runtime/vss.json`
- Vehicle Data Broker running (for local testing)

### 3-Step Development

```bash
# 1. Write your application logic
vim app/src/main.py

# 2. Build (validates VSS signals, updates manifest, creates Docker image)
./build.sh

# 3. Test locally
./start.sh
```

---

## 📖 Detailed Usage

### Step 1: Write Application Logic

Edit `app/src/main.py` with your vehicle application code.

#### Example 1: HVAC Climate Control (Current Implementation)

```python
from vehicle import Vehicle, vehicle
from velocitas_sdk.vehicle_app import VehicleApp

class HVACController(VehicleApp):
    def __init__(self, vehicle_client: Vehicle):
        super().__init__()
        self.Vehicle = vehicle_client

    async def on_start(self):
        # AI-powered HVAC control - sets fan speed based on scenarios
        # Detected as WRITE access to HVAC fan speed signals
        await self.Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed.set(75)
        await self.Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed.set(75)
```

#### Example 2: Read Vehicle Speed (Alternative)

```python
class SpeedMonitor(VehicleApp):
    async def on_start(self):
        while True:
            # This will be detected as READ access to Vehicle.Speed
            speed = await self.Vehicle.Speed.get()
            print(f"Current speed: {speed.value} km/h")
            await asyncio.sleep(5)
```

#### Example 3: Pubsub Messaging

```python
class MessagingApp(VehicleApp):
    async def on_start(self):
        # Subscribe pattern detected as pubsub READ
        await self.subscribe("vehicle/commands")

    async def handle_command(self, data):
        # Publish pattern detected as pubsub WRITE
        await self.publish_event("vehicle/status", {"state": "ok"})
```

### Step 2: Build Your Application

```bash
./build.sh
```

**What happens during build:**

1. **VSS Model Parsing**: Extracts all 723+ signals from `~/.dk/sdv-runtime/vss.json`
2. **Code Analysis**:
   - Scans `main.py` for `self.Vehicle.*.get()` → READ
   - Scans `main.py` for `self.Vehicle.*.set()` → WRITE
   - Scans for `subscribe()`/`publish()` patterns → Pubsub topics
3. **Validation**: Verifies all signals exist in system VSS model
4. **Manifest Update**: Automatically updates `app/AppManifest.json`:
   ```json
   {
     "interfaces": [
       {
         "type": "vehicle-signal-interface",
         "config": {
           "datapoints": {
             "required": [
               {"path": "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed", "access": "write"},
               {"path": "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed", "access": "write"}
             ]
           }
         }
       },
       {
         "type": "pubsub",
         "config": {
           "reads": ["vehicle/commands"],
           "writes": ["vehicle/status"]
         }
       }
     ]
   }
   ```
5. **Docker Build**: Creates image named after parent folder

**Build Output Example:**

```
✓ Found VSS model at /home/developer/.dk/sdv-runtime/vss.json
✓ Parsed 723 VSS signals from system model
✓ Extracted VSS signal usage from main.py
[
  {
    "path": "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed",
    "access": "write"
  },
  {
    "path": "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed",
    "access": "write"
  }
]
✓ Extracted pubsub topics
  Reads: []
  Writes: []
✓ All VSS signals are valid
✓ Updated AppManifest.json
✓ Successfully built Docker image: dreampack-hvac-app:latest
```

### Step 3: Local Testing

```bash
# Start app and follow logs for 30 seconds
./start.sh

# Custom log duration (60 seconds)
LOG_DURATION=60 ./start.sh

# Custom databroker address
SDV_VEHICLEDATABROKER_ADDRESS=grpc://192.168.56.48:55555 ./start.sh
```

**What `start.sh` does:**

- Removes any existing container with same name
- Starts container in detached mode with `--network host`
- Sets environment variables for middleware connection
- Follows logs for 30 seconds (configurable)
- Leaves container running in background

**Useful debugging commands:**

```bash
# View live logs
docker logs -f dreampack-hvac-app

# Stop and remove container
./stop.sh

# Check container status
docker ps | grep dreampack-hvac-app

# View container resource usage
docker stats dreampack-hvac-app
```

### Step 4: Stop Your Application

```bash
./stop.sh
```

Stops and removes the Docker container gracefully.

---

## 🌐 Marketplace Deployment

### Overview

Once your application is tested locally, deploy it to production nodes via the marketplace system.

### Deployment Process

#### 1. Tag and Push Docker Image

```bash
# Tag your image for registry
IMAGE_NAME="dreampack-hvac-app"
REGISTRY="ghcr.io/your-organization"
VERSION="v1.0.0"

docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:${VERSION}
docker tag ${IMAGE_NAME}:latest ${REGISTRY}/${IMAGE_NAME}:latest

# Push to registry
docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
docker push ${REGISTRY}/${IMAGE_NAME}:latest
```

#### 2. Create Marketplace Configuration

Create a deployment descriptor JSON file:

```json
{
  "name": "AI-Powered HVAC Control",
  "description": "AI-driven climate control with automated HVAC fan speed adjustment",
  "version": "1.0.0",
  "target": "vip",
  "platform": "linux/arm64",
  "dockerImageURL": "ghcr.io/your-organization/dreampack-hvac-app:latest",
  "runtimeCfg": {
    "SDV_MIDDLEWARE_TYPE": "native",
    "SDV_VEHICLEDATABROKER_ADDRESS": "grpc://192.168.56.48:55555",
    "SDV_MQTT_ADDRESS": "mqtt://192.168.56.48:1883"
  },
  "resources": {
    "cpu": "0.5",
    "memory": "512Mi"
  },
  "vssSignals": {
    "required": [
      {"path": "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed", "access": "write"},
      {"path": "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed", "access": "write"}
    ]
  }
}
```

#### 3. Marketplace Configuration Fields

| Field | Description | Example |
|-------|-------------|---------|
| `target` | Target edge node identifier | `vip`, `edge-node-1` |
| `platform` | Container platform architecture | `linux/arm64`, `linux/amd64` |
| `dockerImageURL` | Full path to container image | `ghcr.io/org/app:latest` |
| `runtimeCfg` | Environment variables for runtime | See example above |
| `resources` | CPU/memory limits | `{"cpu": "0.5", "memory": "512Mi"}` |
| `vssSignals` | VSS signals used (from AppManifest) | Copied from `app/AppManifest.json` |

#### 4. Deploy to Marketplace

```bash
# Option A: Update marketplace web page with configuration
curl -X POST https://marketplace.example.com/api/apps \
  -H "Content-Type: application/json" \
  -d @marketplace-config.json

# Option B: Upload via marketplace UI
# Navigate to marketplace dashboard → Add Application → Upload JSON
```

#### 5. Verify Deployment

```bash
# Check deployment status on target node
ssh target-node
docker ps | grep dreampack-hvac-app

# View application logs on target
docker logs -f dreampack-hvac-app
```

### Production Configuration Examples

#### Example 1: CAN Bus Provider Service

```json
{
  "target": "vip",
  "platform": "linux/arm64",
  "dockerImageURL": "ghcr.io/eclipse-autowrx/dk_service_can_provider:latest",
  "runtimeCfg": {
    "CAN_PORT": "can1",
    "MAPPING_FILE": "mapping/vss_4.0/vss_dbc.json",
    "KUKSA_ADDRESS": "192.168.56.48"
  }
}
```

#### Example 2: HVAC Control Service

```json
{
  "target": "cabin-control-unit",
  "platform": "linux/arm64",
  "dockerImageURL": "ghcr.io/your-org/hvac-controller:latest",
  "runtimeCfg": {
    "SDV_MIDDLEWARE_TYPE": "native",
    "SDV_VEHICLEDATABROKER_ADDRESS": "grpc://localhost:55555",
    "SDV_MQTT_ADDRESS": "mqtt://localhost:1883",
    "AI_MODEL_ENDPOINT": "http://ai-service:8080"
  },
  "vssSignals": {
    "required": [
      {"path": "Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed", "access": "write"},
      {"path": "Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed", "access": "write"}
    ]
  }
}
```

---

## 📁 Project Structure

```
dreampack-hvac-app/
├── app/
│   ├── src/
│   │   └── main.py              # Your application logic
│   ├── AppManifest.json         # Auto-generated by build.sh
│   ├── Dockerfile               # Container build definition
│   ├── requirements.txt         # Python dependencies
│   └── requirements-velocitas.txt
├── build.sh                     # Build and validate system
├── start.sh                     # Start container for testing
├── stop.sh                      # Stop and remove container
└── README.md                    # This file
```

---

## 🔍 Build System Rules & Logic

### VSS Signal Detection Rules

| Pattern in Code | Detected As | Access Type |
|----------------|-------------|-------------|
| `self.Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed.set(value)` | `Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed` | `write` |
| `self.Vehicle.Speed.get()` | `Vehicle.Speed` | `read` |
| Both `.get()` and `.set()` on same signal | Signal path | `readwrite` |

### Pubsub Topic Detection Rules

| Pattern in Code | Detected As | Topic Type |
|----------------|-------------|-----------|
| `subscribe("topic")` | `topic` | `read` |
| `self.subscribe("topic")` | `topic` | `read` |
| `publish_event("topic", data)` | `topic` | `write` |
| `self.publish_event("topic", data)` | `topic` | `write` |

### Validation Rules

1. **VSS Signal Validation**: Every signal used in code MUST exist in system VSS model
2. **Access Validation**: Detected access type is recorded (read/write/readwrite)
3. **Build Failure**: If any signal is invalid, build stops with error listing invalid signals
4. **Manifest Generation**: Only validated signals are written to AppManifest.json

---

## ⚙️ Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SDV_MIDDLEWARE_TYPE` | `native` | Middleware connection type |
| `SDV_VEHICLEDATABROKER_ADDRESS` | `grpc://localhost:55555` | Databroker gRPC endpoint |
| `SDV_MQTT_ADDRESS` | `mqtt://localhost:1883` | MQTT broker address |
| `LOG_DURATION` | `30` | Seconds to follow logs in start.sh |

### Customizing Build

Edit paths in `build.sh`:

```bash
# Default paths
VSS_MODEL_PATH="$HOME/.dk/sdv-runtime/vss.json"
MAIN_PY_PATH="./app/src/main.py"
APP_MANIFEST_PATH="./app/AppManifest.json"
```

---

## 🐛 Troubleshooting

### Build fails with "VSS model not found"

```bash
# Check VSS model exists
ls ~/.dk/sdv-runtime/vss.json

# If missing, download or generate VSS model
```

### Build fails with "Invalid VSS signals detected"

```
ERROR: Invalid VSS signals detected:
  - Vehicle.Invalid.Signal
```

**Solution**: Update your code to use only signals from the system VSS model.

### Container starts but stops immediately

```bash
# Check container logs
docker logs dreampack-hvac-app

# Common issues:
# 1. Databroker not running
# 2. Wrong databroker address
# 3. Python syntax errors in main.py
```

### Connection refused to databroker

```bash
# Verify databroker is running
netstat -tlnp | grep 55555

# Check databroker address matches
echo $SDV_VEHICLEDATABROKER_ADDRESS
```

---

## 📚 Additional Resources

- [Eclipse Velocitas Documentation](https://eclipse.dev/velocitas/)
- [VSS Specification](https://covesa.github.io/vehicle_signal_specification/)
- [KUKSA Databroker](https://github.com/eclipse/kuksa.val/tree/master/kuksa_databroker)

---

## 📝 License

Apache License 2.0 - See LICENSE file for details

---

## 🤝 Contributing

Contributions welcome! Please open an issue or pull request.
