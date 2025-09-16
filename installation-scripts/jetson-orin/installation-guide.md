# Getting started

## Prerequisites:

### Connection
Ensure the connectivity to Wifi and LAN (S32G) are good
At S32G, we are referring to 'ping' and 'ssh' command

```shell
sdv-orin@ubuntu:~$ ping 192.168.56.49
PING 192.168.56.49 (192.168.56.49) 56(84) bytes of data.
64 bytes from 192.168.56.49: icmp_seq=1 ttl=64 time=1.04 ms
64 bytes from 192.168.56.49: icmp_seq=2 ttl=64 time=1.03 ms
^C
--- 192.168.56.49 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 1.026/1.034/1.042/0.008 ms
sdv-orin@ubuntu:~$ 
sdv-orin@ubuntu:~$ ssh root@192.168.56.49
root@s32g274ardb2:~# 
```

### Environment
Install Docker on your target system.
```shell
sudo apt update; sudo apt install docker.io; sudo apt-get install sshpass
```

## Installation guide

Let's navigate to 'installation-scripts\jetson-orin' and following instructions pop out when executing 'dk_install.sh' script

```shell
cd installation-scripts\jetson-orin
sudo ./dk_install.sh
```

Note:
- If facing problem with executing the .sh file, following are the referrence command to fix it
```shell
sed -i -e 's/\r$//' *.sh
chmod +x *.sh
```
- If facing problem with launching the dk_ivi (cpp/qt application), the potential error with '$DISPLAY' may be empty.
That is one of input variable for the dk_ivi application. User may face the probem when connecting remotely via SSH.
Let's install from machine's console directly or update the 'dk_install.sh' with replace '$DISPLAY' by ':0' or ':1' (depending on your environment).
Related command
```shell
echo $DISPLAY
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

### Debug

```shell

curl -v http://192.168.56.48:5000/v2/_catalog
```

```shell

sudo systemctl restart k3s
sudo journalctl -u k3s -f
sudo systemctl status k3s

```
