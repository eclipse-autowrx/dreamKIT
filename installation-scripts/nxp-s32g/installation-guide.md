# Getting started

## Prerequisites:

### Yocto BSP
The S32G Goldbox is s32g274ardb2.
If user refer self-prepare the Yocto BSP, let's ensure the following
- url: https://gitlab.com/soafee/ewaol/meta-ewaol-machine
- Docker + K3s enabled
- Static IP.v4 address 192.168.56.49. User can refer to TeraTerm - UART0 (Speed: 115200)

## Installation guide

### Option 1: Standalone Installation

Let's copy the whole 'nxp-s32g' folder into the S32G, ~/.dk/ folder.
Then executing 'dk_install.sh' script from their

```shell
# At Host Machine (Jetson Orin or Ubuntu)
sdv-orin@ubuntu:~$ scp -r {root_path}/dreamKIT/installation-scripts/nxp-s32g root@192.168.56.49:~/.dk/
sdv-orin@ubuntu:~$ ssh root@192.168.56.49

# At S32 Machine
root@s32g274ardb2:~#
root@s32g274ardb2:~# cd ~/.dk/nxp-s32g
root@s32g274ardb2:~# ./dk_install.sh
```

### Option 2: K3s Worker Node Installation (Recommended)

For distributed DreamKIT deployment, the NXP S32G acts as a K3s worker node connected to a Jetson Orin master. This setup is automatically configured when you run the K3s master preparation script on the Jetson Orin.

**Prerequisites:**
1. Jetson Orin must be set up as K3s master first (see [Jetson Orin Installation Guide](../jetson-orin/installation-guide.md#k3s-master-setup-and-worker-node-preparation))
2. Network connectivity between devices (192.168.56.48 ↔ 192.168.56.49)

**Worker Node Setup Process:**

```shell
# 1. On Jetson Orin - Generate worker node artifacts
sudo scripts/k3s-master-prepare.sh eth0

# 2. Transfer generated files to S32G
sdv-orin@ubuntu:~$ scp -r installation-scripts/nxp-s32g/scripts root@192.168.56.49:~/.dk/nxp-s32g/

# 3. On S32G - Install K3s and configure as worker
root@s32g274ardb2:~# cd ~/.dk/nxp-s32g

# Install K3s binary
root@s32g274ardb2:~# curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -

# Install generated service files
root@s32g274ardb2:~# cp scripts/k3s.service /etc/systemd/system/
root@s32g274ardb2:~# cp scripts/dreamos-setup.service /etc/systemd/system/
root@s32g274ardb2:~# mkdir -p /etc/rancher/k3s
root@s32g274ardb2:~# cp scripts/registries.yaml /etc/rancher/k3s/
root@s32g274ardb2:~# cp scripts/daemon.json /etc/docker/

# Enable and start services
root@s32g274ardb2:~# systemctl daemon-reload
root@s32g274ardb2:~# systemctl enable dreamos-setup.service k3s.service
root@s32g274ardb2:~# systemctl start dreamos-setup.service
root@s32g274ardb2:~# systemctl start k3s.service
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

Note:
- If facing problem with executing the .sh file, following are the referrence command to fix it
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
