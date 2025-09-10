# Goal
Define your demo secnario
What's kind of service that introduce to user's experience
For example with HVAC, where it can befinit for air condition control, etc.

# Setup Overview
- DreamKIT
  + ComputeECU      --> ZonalECUs connectivity, Internet & LAN                                          --> Vehicle Application, Vehicle Service, like IVI, AI, 
  + ZonalECU        --> Classic ECUs connectivity, LAN, vehicle network communication (CAN, LIN, ETH)   --> Vehicle Service, like Kuksa CAN Provider.

- DreamPACK
  + Classic ECUs    --> Actuator role with sesor connectivity, vehicle network communication (CAN, LIN, ETH)

- K3s
  + xip: ComputeECU --> master node which local registry (name as dk_local_registry) to serve the deployment into ZonalECU, where no internet connection.
  + vip: ZonalECU   --> agent node

- DreamOS setup
  + dk_install.sh (installation-scripts/jetson-orin/ folder)
    + Feature: provide the possibility to install DreamOS into DreamKIT
    + Frequently usage cli
```shell
sudo ./dk_install.sh -h                           # Ask for desciption
sudo ./dk_install.sh                              # Full installation with IVI enabled, zonal ECU setup
sudo ./dk_install.sh zecu=false                   # Skip zonal ECU (S32G) setup
sudo ./dk_install.sh zecu=false swupdate=true     # Software update only mode
```

# Design
## Connectivity
Driver / Passenger can able to increase/ decrease fan speed
VSS
- Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed     --> driver side.
- Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed  --> passenger side.
CAN message/ signale
- VCRIGHT_hvacBlowerSpeedRPMReq
- VCLEFT_hvacBlowerRPMTarget

dbc_overlay.vspec
```shell
Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed:
  datatype: int8
  type: actuator
  vss2dbc:
    signal: VCRIGHT_hvacBlowerSpeedRPMReq

Vehicle.Cabin.HVAC.Station.Row1.Passenger.FanSpeed:
  datatype: int8
  type: actuator
  vss2dbc:
    signal: VCLEFT_hvacBlowerRPMTarget
```

## Vehicle Application
User define.

## Vehicle Service

### IVI
Goal to provide the user interface to able interact with vehicle

For example with 'Vehicle.Cabin.HVAC.Station.Row1.Driver.FanSpeed' VSS
- Driver side can adjust the value from 0-100%

Example software: dk-ivi-lite
- UI and Logic handling: dreamos-core/dk-ivi-lite/src/controls/
- Interface to vehicle-api
  + Library: dreamos-core/dk-ivi-lite/src/library/target/{platform}/libKuksaClient.so
  + Interface: dreamos-core/dk-ivi-lite/src/platform/integrations/vehicle-api/


### Kuksa CAN Provider
Goal to enable connection between vehical signal (CAN) to vehical services

Example software: dreampack-HVAC-CAN-provider
- VSS
  + Design: 
    + dbc_overlay.vspec (services/dreampack-HVAC-CAN-provider/prepare-dbc-file/mapping/vss_4.0/ folder) --> design the mapping, signal type, etc.
  + Output
    + vss_dbc.json (services/dreampack-HVAC-CAN-provider/prepare-dbc-file/mapping/vss_4.0/ folder)      --> mapping between VSS <-> CAN signals
    + dbc_default_values.json (services/dreampack-HVAC-CAN-provider/prepare-dbc-file/mapping/ folder)   --> for the default value of related CAN signals. Required for vss actuator type only.
- CAN DBC
  + ModelCAN.dbc (services/dreampack-HVAC-CAN-provider/prepare-dbc-file/ folder)
    + Design your network
    + Signal compute method / raw value (optional)

Detail information, you can refer to the https://github.com/eclipse-kuksa/kuksa-can-provider

### Publish Vehicle Application/Service into Marketplace
The Marketplace is centralized area for all public services, which can benifit for Car user's experience

At DreamKIT, IVI is area for user to fetch the latest services and intall-deploy into their car.

Let's navigate to https://marketplace.digitalauto.tech/
Template Structure (for IVI understanding):
```shell
{
  "Target": "xip",                    // 🎯 Deployment target node. "{xip - ComputeECU}, {vip - ZonalECU}"
  "Platform": "linux/arm64",          // 🏗️ Hardware architecture
  "DockerImageURL": "docker.io/nginx:alpine",  // 📦 Container image
  "RuntimeCfg": {                     // ⚙️ Runtime configuration
    "hostDev": true,                  // 🔌 Hardware device access
    "DISPLAY": ":0",                  // 🖥️ Display connection
    "volumes": [{                     // 💾 Storage mappings
      "hostPath": "/opt/web-content",
      "mountPath": "/usr/share/nginx/html",
      "readOnly": false
    }]
  }
}
```

Example for HVAC - DreamPACK
```shell
{
   "Target": "vip",
   "Platform": "linux/arm64",
   "DockerImageURL": "ghcr.io/samtranbosch/dk_service_can_provider:latest",
   "RuntimeCfg": {
    "CAN_PORT": "can1",
    "MAPPING_FILE": "mapping/vss_4.0/vss_dbc.json",
    "KUKSA_ADDRESS": "192.168.56.48"
   }
}
```

## Actuator (DreamPACK)
Goal to observe the request via dedicated CAN signals and react based on the design.
For example with VCRIGHT_hvacBlowerSpeedRPMReq
- if receive value 10: set related PWM channel to 10% to launch the driver fan motor


# User's experience

Playground <-> DreamKIT
- At DreamKIT, IVI, "App Test Deployment" pages you make see you device id, like: dreamKIT-{8 random digests}. (for example: dreamKIT-e93301da)
- At Playground (https://playground.digital.auto/model/683ebb6bc70fed31d029a1cb/library/prototype/683ebb8ac70fed31d029a23f/dashboard)
  + AddRuntime: Runtime-dreamKIT-e93301da. "Runtime-" is the prefix.
  + SendRequest > "Rebuild Vehicle Modle base on current Vehicle API"

- Result
  + The desired VSS model will be deployed into your DreamKIT machine via sdv-runtime application
  + sdv-runtime application
    + invoke the kuksa-databroker, which is local host on port 55555:55555
    + the application was deployed via k3s yaml file with "hostNetwork: true" option. therefore, it's possible to serve all request related to vss.

At DreamKIT, IVI
- Installation
  + Navigate to Vehicle App/ Vehicle Service sub-pages to search and install your desired one.
  + images:

- Launch the services
  + Navigate to Vehicle App/ Vehicle Service pages to enable to services
  + images:

