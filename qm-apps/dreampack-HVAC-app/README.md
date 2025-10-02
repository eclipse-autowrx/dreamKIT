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
│                         DEVELOPMENT WORKFLOW                            │
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
   │ INPUT                                                        │
   │ ┌──────────────────┐  ┌──────────────────────────────────┐ │
   │ │ System VSS Model │  │ Your Application Code            │ │
   │ │ ~/.dk/sdv-       │  │ app/src/main.py                  │ │
   │ │ runtime/vss.json │  │                                  │ │
   │ │   (optional)     │  │                                  │ │
   │ └──────────────────┘  └──────────────────────────────────┘ │
   │                                ↓                            │
   │ PROCESSING LOGIC                                            │
   │ ┌────────────────────────────────────────────────────────┐ │
   │ │ 1. Parse System VSS Model (if available)               │ │
   │ │    • Extract all available signals                     │ │
   │ │    • Build validation dictionary                       │ │
   │ │    • If missing: Skip validation, show warning         │ │
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
   │ │ 3. Validate Signals (if VSS model available)           │ │
   │ │    • Check each used signal exists in system model     │ │
   │ │    • ✅ PASS: Continue build                            │ │
   │ │    • ❌ FAIL: Exit with error listing invalid signals   │ │
   │ │    • No VSS model: Skip validation, continue build     │ │
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
- VSS model at `~/.dk/sdv-runtime/vss.json` (optional)
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
        await self.Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed.set(80)
        await self.Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed.set(80)
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

1. **VSS Model Parsing**: Extracts all 723+ signals from `~/.dk/sdv-runtime/vss.json` (if available)
2. **Code Analysis**:
   - Scans `main.py` for `self.Vehicle.*.get()` → READ
   - Scans `main.py` for `self.Vehicle.*.set()` → WRITE
   - Scans for `subscribe()`/`publish()` patterns → Pubsub topics
3. **Validation**: Verifies all signals exist in system VSS model (if VSS model is available)
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

**Build Output Example (with VSS model):**

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

**Build Output Example (without VSS model):**

```
WARNING: VSS model not found at ~/.dk/sdv-runtime/vss.json
Skipping VSS signal validation...
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
Skipping VSS signal validation (no VSS model available)
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
- Access url: https://marketplace.digitalauto.tech/
- Create a deployment descriptor JSON

```json
{
  "Target": "xip",
  "Platform": "linux/arm64",
  "DockerImageURL": "ghcr.io/eclipse-autowrx/dreampack-hvac-app:latest",
  "RuntimeCfg": {
    "SDV_MIDDLEWARE_TYPE": "native",
    "SDV_VEHICLEDATABROKER_ADDRESS": "grpc://192.168.56.48:55555",
    "SDV_MQTT_ADDRESS": "mqtt://192.168.56.48:1883"
  }
}
```

### Configuration
- **Public Image:** `ghcr.io/eclipse-autowrx/dreampack-hvac-app:latest`
- **Target Node:** `xip`
- **Platform:** `linux/arm64`
- **Runtime Config:** Production settings

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

1. **VSS Signal Validation**: Every signal used in code MUST exist in system VSS model (if VSS model is available)
2. **Access Validation**: Detected access type is recorded (read/write/readwrite)
3. **Build Behavior**:
   - **With VSS model**: Build stops with error if any signal is invalid
   - **Without VSS model**: Build continues with warning, skipping validation
4. **Manifest Generation**: All detected signals are written to AppManifest.json (validated or not)

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

### VSS model not found (Warning)

If no VSS model is found, the build will continue with a warning:

```
WARNING: VSS model not found at ~/.dk/sdv-runtime/vss.json
Skipping VSS signal validation...
```

**What happens:**
- Build continues without VSS signal validation
- AppManifest.json is still updated with detected signals
- Docker image is built successfully
- VSS signals are not validated against system model

**To enable VSS validation:**
```bash
# Ensure VSS model exists
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

### Connection refused to databroker / mqtt-broker

```bash
# Verify databroker is running
netstat -tlnp | grep 55555

# Verify mqtt-broker is running
netstat -tlnp | grep 1883
```

---

## 📚 Additional Resources

- [Eclipse Velocitas Documentation](https://eclipse.dev/velocitas/)
- [VSS Specification](https://covesa.github.io/vehicle_signal_specification/)
- [KUKSA Databroker](https://github.com/eclipse/kuksa.val/tree/master/kuksa_databroker)

---

## 🤝 Contributing

Contributions welcome! Please open an issue or pull request.
