# Getting started

## Prerequisites:

### System Requirements
- Ubuntu 18.04/20.04/22.04 or compatible Linux distribution
- Minimum 4GB RAM, 8GB recommended
- 20GB+ free disk space
- Internet connectivity for downloading container images
- Root/sudo access for system configuration

### Network Requirements
- **WiFi/Ethernet**: Internet connection for downloading components
- **LAN Connection (S32G)**: Network connectivity to zonal ECU at `192.168.56.49`
- **Network Interface**: `eth0` or similar for K3s cluster communication

Test S32G connectivity:
```shell
# Test ECU reachability
sdv-orin@ubuntu:~$ ping 192.168.56.49
PING 192.168.56.49 (192.168.56.49) 56(84) bytes of data.
64 bytes from 192.168.56.49: icmp_seq=1 ttl=64 time=1.04 ms
64 bytes from 192.168.56.49: icmp_seq=2 ttl=64 time=1.03 ms
^C
--- 192.168.56.49 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.026/1.034/1.042/0.008 ms

# Test SSH access to ECU
sdv-orin@ubuntu:~$ ssh root@192.168.56.49
root@s32g274ardb2:~#
```

### Software Dependencies
Install required packages on your target system:
```shell
sudo apt update
sudo apt install docker.io sshpass curl wget openssl
```

### Display Environment (for IVI Interface)
If connecting via SSH, ensure X11 forwarding is configured:
```shell
# Check display environment
echo $DISPLAY

# For SSH connections, enable X11 forwarding
ssh -X username@hostname

# Or set display manually (if needed)
export DISPLAY=:0
```

## Installation Guide

### DreamOS Installation Suite - Features & Configuration

The `dk_install.sh` script provides a professional installation suite with configurable parameters for different deployment scenarios.

#### Available Parameters

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `dk_ivi` | `true`/`false` | `true` | Install In-Vehicle Infotainment interface |
| `zecu` | `true`/`false` | `true` | Setup zonal ECU (S32G) integration |
| `swupdate` | `true`/`false` | `false` | Software update only mode |

#### Installation Modes

**Full Installation (Default)**
```shell
cd installation-scripts/jetson-orin
sudo ./dk_install.sh
```

**Custom Configuration Examples**
```shell
# Full installation with IVI enabled, zonal ECU setup
sudo ./dk_install.sh

# Skip zonal ECU (S32G) setup
sudo ./dk_install.sh zecu=false

# Software update only mode
sudo ./dk_install.sh zecu=false swupdate=true

# Install without IVI interface
sudo ./dk_install.sh dk_ivi=false

# Minimal setup (no ECU, no IVI)
sudo ./dk_install.sh dk_ivi=false zecu=false
```

#### Installation Steps Overview

The installation process includes 13 comprehensive steps with their corresponding scripts:

1. **Environment Detection** - System configuration analysis
2. **Docker Setup** - Container environment configuration
3. **Runtime Configuration** - DreamOS runtime setup
4. **Directory Structure** - Create required directories
5. **Network Setup** - Docker network infrastructure
6. **Dependencies** - `scripts/install_dependencies.sh` + `scripts/dk_enable_xhost.sh`
7. **Local Docker Registry** - `scripts/setup_local_docker_registry.sh`
8. **K3s Installation** - `scripts/k3s-master-prepare.sh`
9. **NXP-S32G Setup** - `scripts/k3s-agent-offline-install.sh` (conditional) + **Complete K3s worker node setup**
10. **SDV Runtime** - `manifests/sdv-runtime*.yaml` + `scripts/setup_default_vss.sh`
11. **DreamKit Manager** - `manifests/dk-manager*.yaml`
12. **IVI Interface** - `manifests/dk-ivi*.yaml` (conditional)
13. **Cluster Information** - Display final system status

#### Software Update Mode

When `swupdate=true`, only steps 10-12 are executed for updating existing components:
- SDV Runtime update
- DreamKit Manager update
- IVI Interface update (if `dk_ivi=true`)

### Quick Start

```shell
# Navigate to installation directory
cd installation-scripts/jetson-orin

# Make script executable (if needed)
chmod +x dk_install.sh

# Run full installation
sudo ./dk_install.sh

# View help and usage examples
sudo ./dk_install.sh --help
```

### Troubleshooting Common Issues

#### Script Execution Problems
If facing problems with executing the .sh file:
```shell
# Fix line endings (Windows/Linux compatibility)
sed -i -e 's/\r$//' *.sh

# Make scripts executable
chmod +x *.sh
```

#### Display/X11 Issues (IVI Interface)
If launching dk_ivi fails with `$DISPLAY` errors when connecting via SSH:
```shell
# Check current display setting
echo $DISPLAY

# For SSH connections, use X11 forwarding
ssh -X username@hostname

# Or manually set display (console users)
export DISPLAY=:0   # or :1 depending on environment

# Test X11 forwarding
xhost +local:docker
```

#### Network Interface Detection
If K3s setup fails to detect network interface:
```shell
# Check available interfaces
ip addr show

# Manually specify interface in k3s setup
sudo DK_USER="$USER" scripts/k3s-master-prepare.sh eth0
```

## Advanced Configuration & Management

### K3s Manifest Management

**Source Manifests Location:** `manifests/` folder
- Contains K3s YAML template files for all services
- Users can modify Docker image versions here before installation
- Templates use environment variables (e.g., `${DOCKER_HUB_NAMESPACE}`)

**Parsed Manifests Location:** `tmp/dk_manifests/` folder
- Contains processed YAML files after environment variable substitution
- Generated during installation process
- Used for actual K3s deployments

### Manual Service Management

To restart or update specific services after installation:

```shell
# Navigate to installation directory
cd installation-scripts/jetson-orin

# Delete existing service
kubectl delete -f tmp/dk_manifests/parsed_<service>.yaml

# Reapply service (will pull latest image if changed)
kubectl apply -f tmp/dk_manifests/parsed_<service>.yaml

# Examples:
kubectl delete -f tmp/dk_manifests/parsed_sdv-runtime.yaml
kubectl apply -f tmp/dk_manifests/parsed_sdv-runtime.yaml
```

### K3s Scripts Integration with NXP-S32G Setup

#### Step 8: K3s Master Preparation (`scripts/k3s-master-prepare.sh`)
This script:
- Installs K3s master on Jetson Orin with optimized settings
- Detects network interface (e.g., `eth0`) and binds K3s to detected IP
- **Generates worker node artifacts** for NXP-S32G deployment
- Creates necessary configuration files in `../nxp-s32g/scripts/`:
  - `k3s.service` - systemd service for K3s agent
  - `dreamos-setup.service` - system initialization service
  - `registries.yaml` - registry mirror configuration
  - `daemon.json` - containerd registry settings
  - `dreamos_setup.sh` - network and time sync script

#### Step 9: Automated Worker Node Deployment (`scripts/k3s-agent-offline-install.sh`)
This script automatically:
- **Transfers generated files** from Step 8 to NXP-S32G ECU
- **Remotely installs K3s binary** on target device
- **Configures systemd services** for automatic startup
- **Validates connectivity** and cluster joining
- **Complete hands-off setup** - no manual intervention needed on ECU

**Important Linkage:**
```shell
# Step 8 generates files needed for Step 9
scripts/k3s-master-prepare.sh eth0        # Generates worker artifacts
scripts/k3s-agent-offline-install.sh      # Uses generated artifacts to setup worker

# Files flow: Jetson Orin → NXP-S32G
# Generated on Jetson:     ../nxp-s32g/scripts/k3s.service
# Deployed to S32G:        /etc/systemd/system/k3s.service
```

**Result:** Complete distributed K3s cluster with Jetson Orin (master) + NXP-S32G (worker)

## K3s Master Setup and Worker Node Preparation

The `scripts/k3s-master-prepare.sh` script provides automated K3s master setup and worker node artifact generation for multi-device deployments.

### Usage

```shell
# Basic usage with network interface detection
sudo scripts/k3s-master-prepare.sh eth0

# With custom user specification
sudo DK_USER="username" scripts/k3s-master-prepare.sh eth0

# Master-only mode (when network interface is unavailable)
sudo scripts/k3s-master-prepare.sh eth0  # Will automatically detect and switch to master-only
```

### System Impact on Jetson Orin (Master Node)

**Network Configuration:**
- Detects IP address from specified network interface (e.g., `eth0`)
- Configures K3s to bind to the detected IP address
- Sets up network wait scripts for interface availability
- Handles multi-homed network configurations

**K3s Master Installation:**
- Installs K3s server with embedded device optimizations
- Node name: `xip`
- Disables problematic components (Traefik, metrics-server, etc.)
- Configures proper resource limits for embedded hardware
- Sets up flannel networking with host-gateway backend

**System Services:**
- Creates systemd override for K3s service with network dependencies
- Installs network preparation scripts in `/usr/local/bin/`
- Configures kernel module loading (br_netfilter, overlay)
- Sets up extended timeouts for embedded hardware

**User Access:**
- Automatically configures kubectl access for the original user
- Sets up both `/etc/rancher/k3s/k3s.yaml` and `~/.kube/config`
- Supports auto-detection when run via sudo or directly

### Worker Node Artifact Generation

When a valid network interface is detected, the script generates deployment artifacts for the NXP S32G worker node in `../nxp-s32g/scripts/`:

**Generated Files:**
- `k3s.service` - systemd service for K3s agent
- `dreamos-setup.service` - systemd service for DreamOS initialization
- `registries.yaml` - K3s registry mirror configuration
- `daemon.json` - containerd registry mirror configuration
- `dreamos_setup.sh` - network and system setup script (updated with current time/gateway)

**Worker Node Configuration:**
- IP: `192.168.56.49` (NXP S32G)
- Interface: `eth0`
- Node name: `vip`
- Registry mirror: Uses detected master IP as registry mirror
- Gateway: Routes traffic through master node

### Operational Modes

**Normal Mode (Network Interface Available):**
- Full K3s master setup with network binding
- Complete worker node artifact generation
- Registry mirror service for container images
- Multi-node cluster preparation

**Master-Only Mode (Network Interface Unavailable):**
- Standalone K3s master without specific network binding
- No worker node artifacts generated
- Suitable for single-node deployments or testing
- Automatic fallback when interface detection fails

### Integration with DreamKIT Installation

The K3s setup integrates with the main DreamKIT installation:
- Provides container orchestration for SDV services
- Enables distributed deployment across Jetson Orin (master) and NXP S32G (worker)
- Supports the SDV runtime environment with proper networking
- Facilitates service discovery and load balancing

## Un-Installation guide
```shell
sudo ./dk_uninstall.sh
```

## Health check
Following dockerfile will be installed into your machine.
At this release version, it's required user to double check the heathy state for them
- sdv-runtime
- dk_ivi
- dk_local_registry
- dk_manager
- dk_appinstallservice (default with off state. dk_ivi will call when needed)
- ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2


### sdv-runtime

The RUNTIMENAME is "dreamKIT-{randum-serial-number}", which will be referred by https://playground.digital.auto/ later.
User can freely adjust via navigate to "RUNTIME_NAME="dreamKIT-${serial_number: -8}"" from dk_install.sh script.


```shell
sdv-orin@ubuntu:~$ docker logs sdv-runtime
...
Node.js v18.5.0
2025-06-04T02:43:13.974739Z  WARN databroker: TLS is not enabled. Default behavior of accepting insecure connections when TLS is not configured may change in the future! Please use --insecure to explicitly enable this behavior.
2025-06-04T02:43:13.974778Z  WARN databroker: Authorization is not enabled.
2025-06-04T02:43:13.974863Z  INFO databroker::broker: Starting housekeeping task
2025-06-04T02:43:13.974885Z  INFO databroker::grpc::server: Listening on 0.0.0.0:55555
2025-06-04T02:43:13.974891Z  INFO databroker::grpc::server: TLS is not enabled
2025-06-04T02:43:13.974893Z  INFO databroker::grpc::server: Authorization is not enabled.
INFO:mock_service:Initialization ...
INFO:mock_service:Connecting to Data Broker [127.0.0.1:55555]
INFO:kuksa_client.grpc:No Root CA present, it will not be possible to use a secure connection!
INFO:kuksa_client.grpc:Establishing insecure channel
INFO:mock_service:Databroker connected!
INFO:mock_service:Subscribing to 0 mocked datapoints...
RunTime display name: RunTime-DreamKIT_BGSV
Connecting to Kit Server: https://kit.digitalauto.tech
Kuksa connected True
Connected to Kit Server 
sdv-orin@ubuntu:~$ 
```

### dk_ivi

```shell
sdv-orin@ubuntu:~$ docker logs sdv-runtime
...
Start dk_ivi
Connected to 127.0.0.1:55555
Server Info:
  Name:    databroker
  Version: 0.4.4
Connected to server 127.0.0.1:55555
ServicesAsync @ 178  : DK_INSTALLED_SERVICE_FOLDER:  "/app/.dk/dk_installedservices/"
DK_XIP_IP:  "192.168.56.48"
DK_VIP_IP:  "192.168.56.49"
DK_VIP_USER:  "root"
DK_VIP_PWD:  ""
...
DigitalAutoAppAsync 149 serialNo:  "dreamKIT-7de10f4b"
DigitalAutoAppAsync 150  DK_VCU_USERNAME :  "sdv-orin"
DigitalAutoAppAsync 151  DK_CONTAINER_ROOT :  "/app/.dk/"
DigitalAutoAppCheckThread 42  m_filewatcher :  "/app/.dk/dk_manager/prototypes/prototypes.json"
...
appendMarketplaceUrlList:  "BGSV Marketplace"
...
sdv-orin@ubuntu:~$ 
```

### dk_manager

```shell
sdv-orin@ubuntu:~$ docker logs dk_manager
...
Start dk_manager
dk-manager verion 1.0.0 !!!
DkManger 101  : setup socket.io
InitDigitalautoFolder 168
InitDigitalautoFolder 212  cmd =  "mkdir -p /app/.dk/dk_manager/log/cmd/ /app/.dk/dk_manager/prototypes/ /app/.dk/dk_manager/download/ /app/.dk/dk_manager/vssmapping/ /app/.dk/dk_manager/vssmapping/ /app/.dk/dk_marketplace/ /app/.dk/dk_installedservices/ /app/.dk/dk_installedapps/;rm /app/.dk/dk_manager/log/cmd/*;touch /app/.dk/dk_manager/vssmapping/stop_kuksa_feeder_script.sh;touch /app/.dk/dk_manager/vssmapping/start_kuksa_feeder_script.sh;chmod 777 -R /app/.dk/dk_manager/vssmapping/;"
rm: cannot remove '/app/.dk/dk_manager/log/cmd/*': No such file or directory
InitUserInfo 163  : DK_VCU_USERNAME =  "sdv-orin"
URL:  https://kit.digitalauto.tech
...
[2025-06-04 02:07:41] [connect] Successful connection
[2025-06-04 02:07:41] [connect] WebSocket Connection 168.63.44.238:443 v-2 "WebSocket++/0.8.2" /socket.io/?EIO=4&transport=websocket&t=1749002860 101
get_dreamkit_code 92 serialNo:  "7de10f4b"
```

## System Health Check & Troubleshooting

### Essential System Health Commands

**Check K3s Master Status:**
```shell
# K3s service status
sudo systemctl status k3s
sudo systemctl restart k3s
sudo journalctl -u k3s -f

# K3s cluster health
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info
```

**Check DreamOS Services:**
```shell
# All deployments status
kubectl get deployments --all-namespaces

# Service logs
kubectl logs deployment/sdv-runtime
kubectl logs deployment/dk-manager
kubectl logs deployment/dk-ivi

# Detailed service information
kubectl describe deployment sdv-runtime
kubectl describe deployment dk-manager
```

**Check Docker Registry (Zonal ECU image sharing):**
```shell
# Verify local registry is running
curl -v http://192.168.56.48:5000/v2/_catalog

# Check registry service
docker ps | grep registry
docker logs registry
```

**Check Network Connectivity:**
```shell
# Test ECU connectivity
ping -c 3 192.168.56.49

# Check network interfaces
ip addr show
ip route show

# Test K3s cluster networking
kubectl get svc --all-namespaces
```

### Common Issues & Solutions

**K3s Permission Issues:**
```shell
# Warning: Unable to read /etc/rancher/k3s/k3s.yaml permission denied
# Solution - Fix kubeconfig permissions:

# Method 1: Change file permissions
sudo chown $USER:$USER /etc/rancher/k3s/k3s.yaml

# Method 2: Copy to user's kube config (recommended)
sudo mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

**Service Deployment Issues:**
```shell
# Check failed pods
kubectl get pods --field-selector=status.phase=Failed --all-namespaces

# Describe problematic pods
kubectl describe pod <pod-name>

# Check events for issues
kubectl get events --sort-by=.metadata.creationTimestamp

# Force restart deployment
kubectl rollout restart deployment/sdv-runtime
```

**Container Registry Issues:**
```shell
# Check registry connectivity from worker node
curl -v http://192.168.56.48:5000/v2/_catalog

# Restart local registry
docker restart registry

# Check registry logs
docker logs registry -f
```

**Image Pull Issues:**
```shell
# Check available images
docker images | grep -E "(sdv-runtime|dk-manager|dk-ivi)"

# Manually pull images
docker pull ghcr.io/eclipse-autowrx/sdv-runtime:latest

# Check image pull jobs status
kubectl get jobs
kubectl logs job/sdv-runtime-pull
```

### System Verification Checklist

After installation, verify these components are working:

1. **K3s Cluster:** `kubectl get nodes` (should show master node ready)
2. **Core Services:** `kubectl get deployments` (sdv-runtime, dk-manager running)
3. **Network Connectivity:** `ping 192.168.56.49` (if using ECU)
4. **Registry Service:** `curl http://192.168.56.48:5000/v2/_catalog`
5. **IVI Interface:** Check logs with `kubectl logs deployment/dk-ivi` (if enabled)