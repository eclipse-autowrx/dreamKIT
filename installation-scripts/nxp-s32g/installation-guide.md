# Getting started

## Prerequisites:

### Yocto BSP
The S32G Goldbox is s32g274ardb2.
If users self-prepare the Yocto BSP, ensure the following:
- URL: https://gitlab.com/soafee/ewaol/meta-ewaol-machine
- Docker + K3s enabled
- Static IPv4 address 192.168.56.49. Users can access via TeraTerm - UART0 (Speed: 115200)

## Installation guide

For distributed DreamKIT deployment, the NXP S32G acts as a K3s worker node connected to a Jetson Orin master.
The remote installation to the NXP-S32G worker node is a fully automated process that occurs during **Step 9** of the main installation. This process copies all necessary artifacts from the `nxp-s32g` folder and executes the complete DreamKIT installation on the remote ECU.

**Prerequisites:**
1. Jetson Orin must be set up as K3s master first (see [Jetson Orin Installation Guide](../jetson-orin/installation-guide.md#automated-setup-process))
2. Network connectivity between devices (192.168.56.48 ↔ 192.168.56.49)


### What Happens During Remote Installation (via k3s-agent-offline-install.sh)

**Phase 1: Artifact Transfer**
- All files from the `installation-scripts/nxp-s32g/` directory are copied to `~/.dk/nxp-s32g/` on the remote S32G device
- K3s agent configuration files (generated in Step 8) are transferred
- DreamKIT installation scripts and manifests are copied
- Docker registry configuration and certificates are transferred

**Phase 2: Remote System Configuration**
```shell
# The script executes remotely on 192.168.56.49:
ssh root@192.168.56.49 "cd ~/.dk/nxp-s32g && ./dk_install.sh"
```

**Phase 3: K3s Worker Node Setup**
- Installs and configures K3s agent service
- Sets up registry mirror pointing to Jetson Orin (`192.168.56.48:5000`)
- Configures network routes and time synchronization
- Joins the K3s cluster as worker node `vip`

**Phase 4: Service Deployment**
- Deploys DreamKIT services to the worker node
- Configures container runtime with proper registry access
- Establishes communication with master node services

#### Files Transferred to NXP-S32G

The following artifacts are automatically copied from `installation-scripts/nxp-s32g/` to the remote ECU:

**Core Installation Files:**
- `dk_install.sh` - Main installation script for S32G
- `scripts/` - All installation scripts adapted for S32G environment
- `manifests/` - Kubernetes manifests for worker node services

**K3s Configuration Files:**
- `k3s.service` - Systemd service definition for K3s agent
- `registries.yaml` - Docker registry mirror configuration
- `daemon.json` - Containerd registry settings
- `dreamos-setup.service` - System initialization service
- `dreamos_setup.sh` - Network and time sync configuration

**Runtime Configuration:**
- Environment variable files for S32G-specific settings
- Network configuration for cluster communication
- Registry certificates and authentication

#### Verification of Remote Installation

After the remote installation completes, you can verify the setup:

```shell
# Check worker node status from master
kubectl get nodes -o wide

# Expected output should show both nodes:
# NAME   STATUS   ROLES                       AGE   VERSION        INTERNAL-IP     EXTERNAL-IP
# xip    Ready    control-plane,etcd,master   1h    v1.33.4+k3s1   192.168.56.48   <none>
# vip    Ready    <none>                      1h    v1.22.6-k3s1   192.168.56.49   <none>

# Verify services running on worker node
kubectl get pods -o wide --all-namespaces | grep 192.168.56.49

# Check worker node logs remotely
ssh root@192.168.56.49 "journalctl -u k3s -n 20"

# Verify registry access from worker
ssh root@192.168.56.49 "curl -v http://192.168.56.48:5000/v2/_catalog"
```

#### Remote Installation Troubleshooting

**SSH Connection Issues:**
```shell
# Test SSH connectivity before installation
ssh root@192.168.56.49 "echo 'Connection successful'"

# Check SSH key authentication
ssh-keygen -R 192.168.56.49  # Remove old host key if needed
ssh root@192.168.56.49 "whoami"
```

**File Transfer Problems:**
```shell
# Manually verify file transfer
scp -r installation-scripts/nxp-s32g/* root@192.168.56.49:~/.dk/nxp-s32g/

# Check transferred files
ssh root@192.168.56.49 "ls -la ~/.dk/nxp-s32g/"
```

**Worker Node Join Issues:**
```shell
# Check K3s agent status on worker
ssh root@192.168.56.49 "systemctl status k3s"

# View K3s agent logs
ssh root@192.168.56.49 "journalctl -u k3s -f"

# Restart K3s service on worker
ssh root@192.168.56.49 "systemctl restart k3s"
```

#### Manual Remote Installation

If automatic remote installation fails, you can perform manual installation:

```shell
# 1. Copy artifacts manually
scp -r installation-scripts/nxp-s32g/* root@192.168.56.49:~/.dk/nxp-s32g/

# 2. Execute remote installation
ssh root@192.168.56.49 "cd ~/.dk/nxp-s32g && chmod +x *.sh && ./dk_install.sh"

# 3. Delete the existing node if reconnecting
kubectl delete node vip --ignore-not-found

# 4. Verify worker node joined cluster
kubectl get nodes

# 5. Check service deployment
kubectl get pods --all-namespaces -o wide
```

**What the Worker Node Setup Includes:**
- **DreamOS Setup Service**: Configures CAN interfaces, network, and system time
- **K3s Agent Service**: Joins the cluster as worker node "vip"
- **Registry Mirror**: Uses Jetson Orin as container registry mirror
- **Network Configuration**: Static IP (192.168.56.49) with gateway via master (192.168.56.48)

**Verification:**
```shell
# Check service status
root@s32g274ardb2:~# systemctl status dreamos-setup.service k3s.service

# Verify cluster connection (from Jetson Orin)
sdv-orin@ubuntu:~$ kubectl get nodes
NAME   STATUS   ROLES                       AGE     VERSION
vip    Ready    <none>                      16s     v1.22.6-k3s1
xip    Ready    control-plane,etcd,master   2m11s   v1.33.4+k3s1
```

**Note:**
- If facing problems executing .sh files, use the following commands to fix line endings and permissions:
```shell
sed -i -e 's/\r$//' *.sh
chmod +x *.sh
```


## System Health Check & Environment Analysis

### Essential System Health Commands

**Check Network Configuration:**
```shell
# Verify static IP configuration
root@s32g274ardb2:~# ip addr show eth0
root@s32g274ardb2:~# ip route show

# Test connectivity to K3s master
root@s32g274ardb2:~# ping -c 3 192.168.56.48

# Check network interface status
root@s32g274ardb2:~# ifconfig eth0
```

**Check K3s Worker Node Status:**
```shell
# K3s service status
root@s32g274ardb2:~# systemctl status k3s.service
root@s32g274ardb2:~# systemctl status dreamos-setup.service

# K3s logs
root@s32g274ardb2:~# journalctl -u k3s.service -f
root@s32g274ardb2:~# journalctl -u dreamos-setup.service -f

# Check K3s node registration
root@s32g274ardb2:~# kubectl get nodes    # (if kubectl available)
```

**Check CAN Interface Status:**
```shell
# CAN interfaces status
root@s32g274ardb2:~# ip link show can0
root@s32g274ardb2:~# ip link show can1

# CAN traffic monitoring
root@s32g274ardb2:~# candump can0 &
root@s32g274ardb2:~# candump can1 &

# CAN interface configuration
root@s32g274ardb2:~# cat /sys/class/net/can0/operstate
root@s32g274ardb2:~# cat /sys/class/net/can1/operstate
```

**Check Docker & Container Status:**
```shell
# Docker service status
root@s32g274ardb2:~# systemctl status docker

# Running containers
root@s32g274ardb2:~# docker ps -a

# Docker registry connectivity
root@s32g274ardb2:~# curl -v http://192.168.56.48:5000/v2/_catalog

# Container logs (if any containers running)
root@s32g274ardb2:~# docker logs <container_name>
```

**System Resource Check:**
```shell
# System resources
root@s32g274ardb2:~# free -h
root@s32g274ardb2:~# df -h
root@s32g274ardb2:~# top

# System uptime and load
root@s32g274ardb2:~# uptime
root@s32g274ardb2:~# w
```

### Expected Healthy System Output

**Network Interface (eth0):**
```shell
root@s32g274ardb2:~# ifconfig eth0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.56.49  netmask 255.255.255.0  broadcast 192.168.56.255
        inet6 fe80::5039:dff:fe0d:fd62  prefixlen 64  scopeid 0x20<link>
        ether 52:39:0d:0d:fd:62  txqueuelen 1000  (Ethernet)
        RX packets 3321704  bytes 218268935 (208.1 MiB)
        RX errors 0  dropped 1  overruns 0  frame 0
        TX packets 181544  bytes 26359342 (25.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

**CAN Interfaces (can0, can1):**
```shell
root@s32g274ardb2:~# ifconfig can0 can1
can0: flags=193<UP,RUNNING,NOARP>  mtu 72
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 65536  (UNSPEC)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

can1: flags=193<UP,RUNNING,NOARP>  mtu 72
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 65536  (UNSPEC)
        RX packets 1265729  bytes 9992599 (9.5 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 14  bytes 112 (112.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

**CAN Traffic Monitoring:**
```shell
root@s32g274ardb2:~# candump can1 &
[2] 53146
root@s32g274ardb2:~#   can1  055   [8]  7F FF 7F F6 F0 00 FE 00
  can1  082   [8]  FF FF FF FF 01 FF FF 30
```

### Troubleshooting Common Issues

**K3s Worker Node Connection Issues:**
```shell
# Check K3s token and server configuration
root@s32g274ardb2:~# cat /etc/systemd/system/k3s.service | grep K3S_TOKEN
root@s32g274ardb2:~# cat /etc/systemd/system/k3s.service | grep K3S_URL

# Restart K3s services
root@s32g274ardb2:~# systemctl stop k3s.service
root@s32g274ardb2:~# systemctl start dreamos-setup.service
root@s32g274ardb2:~# systemctl start k3s.service

# Check connectivity to master
root@s32g274ardb2:~# telnet 192.168.56.48 6443
```

**Network Configuration Issues:**
```shell
# Fix static IP if not configured
root@s32g274ardb2:~# ip addr add 192.168.56.49/24 dev eth0
root@s32g274ardb2:~# ip route add default via 192.168.56.48

# Check network time sync
root@s32g274ardb2:~# date
root@s32g274ardb2:~# systemctl status systemd-timesyncd
```

**CAN Interface Issues:**
```shell
# Restart CAN interfaces
root@s32g274ardb2:~# ip link set can0 down
root@s32g274ardb2:~# ip link set can0 up type can bitrate 500000

root@s32g274ardb2:~# ip link set can1 down
root@s32g274ardb2:~# ip link set can1 up type can bitrate 500000

# Check CAN driver modules
root@s32g274ardb2:~# lsmod | grep can
root@s32g274ardb2:~# dmesg | grep -i can
```

**Docker Registry Issues:**
```shell
# Test registry connectivity
root@s32g274ardb2:~# curl -v http://192.168.56.48:5000/v2/_catalog

# Check registry configuration
root@s32g274ardb2:~# cat /etc/rancher/k3s/registries.yaml
root@s32g274ardb2:~# cat /etc/docker/daemon.json

# Restart Docker service
root@s32g274ardb2:~# systemctl restart docker
```

### System Verification Checklist

After installation, verify these components:

1. **Network Connectivity:** `ping 192.168.56.48` (K3s master reachable)
2. **Static IP Configuration:** `ip addr show eth0` (192.168.56.49 configured)
3. **K3s Services:** `systemctl status k3s dreamos-setup` (both active)
4. **CAN Interfaces:** `ip link show can0 can1` (both UP)
5. **Docker Registry:** `curl http://192.168.56.48:5000/v2/_catalog` (accessible)
6. **System Time:** `date` (synchronized with master node)
7. **System Resources:** `free -h && df -h` (sufficient memory/disk)
