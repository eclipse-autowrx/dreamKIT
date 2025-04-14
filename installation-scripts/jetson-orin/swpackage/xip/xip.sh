#!/bin/bash

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Start dreamOS SW Update  !!!!!!!!!!!!!"
echo "------------------------------------------------------------------------------------------------------------------------------------"

# source the installation env
source $DK_HOME/.dk/dk_swupdate/dk_swupdate_env.sh

echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "ARCH: $ARCH"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_SHARE_PARAM: $DOCKER_SHARE_PARAM"
echo "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "DOCKER_AUDIO_PARAM: $DOCKER_AUDIO_PARAM"
echo "LOG_LIMIT_PARAM: $LOG_LIMIT_PARAM"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"
echo "dk_ara_demo: $dk_ara_demo"
echo "dk_ivi_value: $dk_ivi_value"

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install base image for velocitas py app ..."
docker pull $DOCKER_HUB_NAMESPACE/dk_app_python_template:baseimage

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install dk_manager ..."
docker pull $DOCKER_HUB_NAMESPACE/dk_manager:latest
docker stop dk_manager; docker rm dk_manager; docker run -d -it --name dk_manager $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM  -v $HOME_DIR/.dk:/app/.dk --restart unless-stopped -e USER=$DK_USER -e DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE -e ARCH=$ARCH $DOCKER_HUB_NAMESPACE/dk_manager:latest

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install vss_generation ..."
docker pull $DOCKER_HUB_NAMESPACE/dk_vssgeneration_image:vss4.0
docker rm vssgen;docker run -it --name vssgen -v $HOME_DIR/.dk/dk_vssgeneration/:/app/dk_vssgeneration -v $HOME_DIR/.dk/dk_manager/vssmapping/vssmapping_overlay.vspec:/app/.dk/dk_manager/vssmapping/vssmapping_overlay.vspec:ro $LOG_LIMIT_PARAM $DOCKER_HUB_NAMESPACE/dk_vssgeneration_image:vss4.0

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install vehicle data broker ... "
docker pull ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4
docker stop vehicledatabroker ; docker rm vehicledatabroker ; docker run -d -it --name vehicledatabroker -e KUKSA_DATA_BROKER_METADATA_FILE=/app/.dk/dk_vssgeneration/vss.json -e KUKSA_DATA_BROKER_PORT=55555 -e 50001 -e 3500 -v $HOME_DIR/.dk/dk_vssgeneration/vss.json:/app/.dk/dk_vssgeneration/vss.json --restart unless-stopped --network dk_network -p 55555:55555 $LOG_LIMIT_PARAM ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4 --insecure --vss /app/.dk/dk_vssgeneration/vss.json

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install App/service installation service ... "
docker pull $DOCKER_HUB_NAMESPACE/dk_appinstallservice:latest

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install OS SW Update service ... "
docker pull ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Remove Only Dangling Images (No Tags)"
docker image prune -f

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Please reboot your system for dreamSW to take effect !!!!!!!!!!!!!"
echo "------------------------------------------------------------------------------------------------------------------------------------"
