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


## K3s Cluster Overview

DreamKIT uses a distributed K3s cluster with Jetson Orin as the master node and NXP-S32G as the worker node. The setup is fully automated through the main installation process (steps 8-9).

### Cluster Architecture

**Master Node (Jetson Orin):**
- Node name: `xip`
- Runs K3s server with embedded device optimizations
- Hosts local Docker registry for worker node image distribution
- Manages SDV services deployment and orchestration

**Worker Node (NXP-S32G):**
- Node name: `vip`
- IP: `192.168.56.49`
- Automatically configured through remote deployment from master
- Uses registry mirror for efficient container image access

### Automated Setup Process

The K3s cluster setup is handled automatically during DreamKIT installation:

1. **Step 8** (`k3s-master-prepare.sh`): Sets up master node and generates worker artifacts
2. **Step 9** (`k3s-agent-offline-install.sh`): Remotely deploys and configures worker node

**Result:** Complete distributed K3s cluster ready for SDV service deployment

### K3s Master Setup and Worker Node Preparation

#### Impact on Jetson Orin (Master Node)
The `scripts/k3s-master-prepare.sh` script configures the Jetson Orin as the K3s master with the following system changes:

**Network Configuration:**
- Detects and binds K3s to the network interface (e.g., `eth0`)
- Configures the node name as `xip`
- Sets up network wait scripts for interface availability

**System Services:**
- Installs K3s server with embedded device optimizations
- Creates systemd overrides with network dependencies
- Configures kernel modules (br_netfilter, overlay)
- Sets up extended timeouts for embedded hardware

**User Access:**
- Automatically configures kubectl access for the original user
- Sets up both `/etc/rancher/k3s/k3s.yaml` and `~/.kube/config`

#### Impact on NXP-S32G (Worker Node)
When network interface is detected, the script generates worker node artifacts for remote deployment:

**Generated Configuration Files:**
- `k3s.service` - systemd service for K3s agent
- `dreamos-setup.service` - system initialization service
- `registries.yaml` - registry mirror configuration
- `daemon.json` - containerd registry settings
- `dreamos_setup.sh` - network and time sync script

**Worker Node Configuration:**
- Node name: `vip`
- IP: `192.168.56.49`
- Registry mirror: Uses master IP for efficient image access
- Gateway: Routes traffic through master node

The `scripts/k3s-agent-offline-install.sh` script automatically transfers these files and remotely configures the NXP-S32G worker node without manual intervention.

### Integration with DreamKIT Services

The K3s cluster provides the foundation for running DreamOS services:
- **Container Orchestration**: Manages SDV runtime, DK manager, and DK IVI services
- **Service Discovery**: Enables communication between distributed services
- **Load Balancing**: Distributes workloads across cluster nodes
- **Registry Integration**: Uses local registry for efficient image distribution to worker nodes

### K3s Cluster Troubleshooting

**Check Cluster Status:**
```shell
# Verify both nodes are ready
kubectl get nodes -o wide

# Expected output:
# NAME   STATUS   ROLES                       AGE   VERSION        INTERNAL-IP     EXTERNAL-IP
# xip    Ready    control-plane,etcd,master   1h    v1.33.4+k3s1   192.168.56.48   <none>
# vip    Ready    <none>                      1h    v1.22.6-k3s1   192.168.56.49   <none>
```

**Worker Node Connection Issues:**
```shell
# Check if worker node is reachable
ping -c 3 192.168.56.49

# Test SSH connectivity to worker
ssh root@192.168.56.49 "systemctl status k3s"

# Check worker node logs remotely
ssh root@192.168.56.49 "journalctl -u k3s -f"
```

**Registry Connectivity Problems:**
```shell
# Verify registry is accessible from worker node
ssh root@192.168.56.49 "curl -v http://192.168.56.48:5000/v2/_catalog"

# Check registry mirror configuration on worker
ssh root@192.168.56.49 "cat /etc/rancher/k3s/registries.yaml"
```

**Node Join Issues:**
```shell
# Check master node token
sudo cat /var/lib/rancher/k3s/server/node-token

# Manually rejoin worker node (if needed)
ssh root@192.168.56.49 "systemctl stop k3s"
ssh root@192.168.56.49 "rm -rf /var/lib/rancher/k3s/agent"
ssh root@192.168.56.49 "systemctl start k3s"
```

**Service Deployment Issues:**
```shell
# Check if services are running on correct nodes
kubectl get pods -o wide --all-namespaces

# Verify node labels and taints
kubectl describe node xip
kubectl describe node vip

# Check resource availability
kubectl top nodes
kubectl describe node vip | grep -A 5 "Allocated resources"
```

**Network Connectivity Troubleshooting:**
```shell
# Test pod-to-pod communication across nodes
kubectl run test-pod --image=busybox --rm -it -- ping <pod-ip-on-other-node>

# Check flannel network status
kubectl get pods -n kube-system | grep flannel
kubectl logs -n kube-system daemonset/flannel

# Verify network routes
ssh root@192.168.56.49 "ip route show"
```

**Worker Node Recovery:**
```shell
# Complete worker node reset and rejoin
ssh root@192.168.56.49 "systemctl stop k3s"
ssh root@192.168.56.49 "rm -rf /var/lib/rancher/k3s"
ssh root@192.168.56.49 "systemctl restart k3s"

# If automatic rejoin fails, re-run worker setup
scripts/k3s-agent-offline-install.sh
```

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