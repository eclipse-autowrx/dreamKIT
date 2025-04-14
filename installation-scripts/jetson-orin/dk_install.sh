#!/bin/bash

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Start dreamOS installation !!!!!!!!!!!!!"
echo "------------------------------------------------------------------------------------------------------------------------------------"
# Determine the user who ran the command
if [ -n "$SUDO_USER" ]; then
    # Command was run with sudo
    DK_USER=$SUDO_USER
else
    # Command was not run with sudo, fall back to current user
    DK_USER=$USER
fi

# Get the current directory path
CURRENT_DIR=$(pwd)

# Add current user to sudo group of docker
# Check if the docker group exists
if getent group docker > /dev/null 2>&1; then
    echo "Docker: Docker group exists, proceeding..."
else
    echo "Docker: Docker group does not exist. Creating docker group..."
    sudo groupadd docker
fi
# Add the user to the docker group
if sudo usermod -aG docker "$DK_USER"; then
    echo "Docker: User '$DK_USER' has been added to the docker group."
else
    echo "Docker: Failed to add user '$DK_USER' to the docker group."
    exit 1
fi
# Inform the user that they need to log out and back in for the changes to take effect
echo "Docker: Please log out and log back in for the group changes to take effect."

# Detect the system architecture
ARCH_DETECT=$(uname -m)
# Set ARCH variable based on the detected architecture
if [[ "$ARCH_DETECT" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH_DETECT" == "aarch64" ]]; then
    ARCH="arm64"
else
    ARCH="unknown"
fi

# Get XDG_RUNTIME_DIR for the user (not root)
XDG_RUNTIME_DIR=$(sudo -u "$DK_USER" env | grep XDG_RUNTIME_DIR | cut -d= -f2)
# If empty, manually set it
if [ -z "$XDG_RUNTIME_DIR" ]; then
    XDG_RUNTIME_DIR="/run/user/$(id -u "$DK_USER")"
fi
echo "Detected XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"

# Set Env Variables
HOME_DIR="/home/$DK_USER"
DOCKER_SHARE_PARAM="-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker"
DOCKER_AUDIO_PARAM="--device /dev/snd --group-add audio -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native -v $HOME_DIR/.config/pulse/cookie:/root/.config/pulse/cookie"
LOG_LIMIT_PARAM="--log-opt max-size=10m --log-opt max-file=3"
DOCKER_HUB_NAMESPACE="phongbosch"

echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "ARCH: $ARCH"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_SHARE_PARAM: $DOCKER_SHARE_PARAM"
echo "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "DOCKER_AUDIO_PARAM: $DOCKER_AUDIO_PARAM"
echo "LOG_LIMIT_PARAM: $LOG_LIMIT_PARAM"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"

echo "Create dk directoties ..."
mkdir -p /home/$DK_USER/.dk/dk_manager/vssmapping /home/$DK_USER/.dk/dk_vssgeneration /home/$DK_USER/.dk/dk_swupdate /home/$DK_USER/.dk/dk_swupdate/dk_patch /home/$DK_USER/.dk/dk_swupdate/dk_current /home/$DK_USER/.dk/dk_swupdate/dk_current_patch
cp $CURRENT_DIR/data/dksystem_vssmapping_overlay.vspec /home/$DK_USER/.dk/dk_manager/vssmapping/

echo "Create dk_network ..."
docker network create dk_network

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install required utils"
echo "Installing git ..."
# Check if git is available
if command -v git >/dev/null 2>&1; then
    echo "Git is already installed."
else
    echo "Git is not installed. Installing using apt-get..."

    # Update package lists
    apt-get update

    # Install git without prompting for confirmation
    apt-get install -y git

    # Verify installation
    if command -v git >/dev/null 2>&1; then
        echo "Git has been installed successfully."
    else
        echo "There was an error installing Git."
        exit 1
    fi
fi

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install installation repo"
DK_INSTALLATION_DIR="$HOME_DIR/.dk/dk_swupdate"
if [ ! -d "$DK_INSTALLATION_DIR/dk_installation" ]; then
    # Folder does not exist, do something
    echo "Folder $DK_INSTALLATION_DIR does not exist. Downloading ..."
    cd $DK_INSTALLATION_DIR
    git clone https://github.com/ppa2hc/dk_installation.git
else
    echo "Folder $DK_INSTALLATION_DIR already exists."
fi

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install APP Python SDK"
APP_PY_SDK_DIR="$HOME_DIR/.dk/dk_app_python_template"
if [ ! -d "$APP_PY_SDK_DIR" ]; then
    # Folder does not exist, do something
    echo "Folder $APP_PY_SDK_DIR does not exist. Downloading ..."
    cd "$HOME_DIR/.dk"
    git clone https://github.com/ppa2hc/dk_app_python_template.git
else
    echo "Folder $APP_PY_SDK_DIR already exists."
fi

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install base image for velocitas py app ..."
docker pull $DOCKER_HUB_NAMESPACE/dk_app_python_template:baseimage

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install kuksa-client ..."
docker pull ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2

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

echo "Install vss_generation for dksystem..."
docker rm dksystem_vssgen;docker run -it --name dksystem_vssgen -v $HOME_DIR/.dk/dk_vssgeneration/:/app/dk_vssgeneration -v $HOME_DIR/.dk/dk_manager/vssmapping/dksystem_vssmapping_overlay.vspec:/app/.dk/dk_manager/vssmapping/vssmapping_overlay.vspec:ro $LOG_LIMIT_PARAM -e VSS_NAME=dksystem_vss.json -e VEHICLE_GEN=dksystem_vehicle_gen $DOCKER_HUB_NAMESPACE/dk_vssgeneration_image:vss4.0

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install vehicle data broker ... "
docker pull ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4
docker stop vehicledatabroker ; docker rm vehicledatabroker ; docker run -d -it --name vehicledatabroker -e KUKSA_DATA_BROKER_METADATA_FILE=/app/.dk/dk_vssgeneration/vss.json -e KUKSA_DATA_BROKER_PORT=55555 -e 50001 -e 3500 -v $HOME_DIR/.dk/dk_vssgeneration/vss.json:/app/.dk/dk_vssgeneration/vss.json --restart unless-stopped --network dk_network -p 55555:55555 $LOG_LIMIT_PARAM ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4 --insecure --vss /app/.dk/dk_vssgeneration/vss.json

echo "Install dksystem vehicle data broker ... "
docker pull ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4
docker stop dksystem_vehicledatabroker ; docker rm dksystem_vehicledatabroker ; docker run -d -it --name dksystem_vehicledatabroker -e KUKSA_DATA_BROKER_METADATA_FILE=/app/.dk/dk_vssgeneration/vss.json -e KUKSA_DATA_BROKER_PORT=55555 -e 50001 -e 3500 -v $HOME_DIR/.dk/dk_vssgeneration/dksystem_vss.json:/app/.dk/dk_vssgeneration/vss.json --restart unless-stopped --network dk_network -p 55569:55555 $LOG_LIMIT_PARAM ghcr.io/eclipse-kuksa/kuksa-databroker:0.4.4 --insecure --vss /app/.dk/dk_vssgeneration/vss.json

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
# Install dk_ara_demo
dk_ara_demo=""
# Loop through all input arguments
for arg in "$@"; do
    # Check if the argument starts with dk_ara_demo=
    if [[ "$arg" == dk_ara_demo=* ]]; then
        # Extract the value after the equal sign
        dk_ara_demo="${arg#*=}"
    fi
done
if [[ "$dk_ara_demo" == "true" ]]; then
    echo "Install APP CPP SDK"
    APP_CPP_SDK_DIR="$HOME_DIR/.dk/dk_app_cpp_template"
    if [ ! -d "$APP_CPP_SDK_DIR" ]; then
        # Folder does not exist, do something
        echo "Folder $APP_CPP_SDK_DIR does not exist. Downloading ..."
        cd "$HOME_DIR/.dk"
        git clone https://github.com/ppa2hc/dk_app_cpp_template.git
    else
        echo "Folder $APP_CPP_SDK_DIR already exists."
    fi

    echo "Install base image for adaptive AR cpp app ..."
    docker pull $DOCKER_HUB_NAMESPACE/dk_app_cpp_template:latest

    echo "Install kuksa.val for vss ara::provider demo"
    docker pull ghcr.io/eclipse/kuksa.val/kuksa-val:0.2.5
    docker stop kuksa_val_server ; docker rm kuksa_val_server ; docker run -d --name kuksa_val_server --restart unless-stopped -it -p 50051:50051 -p 8090:8090 $LOG_LIMIT_PARAM -e LOG_LEVEL=ALL -e KUKSAVAL_OPTARGS="--insecure" ghcr.io/eclipse/kuksa.val/kuksa-val:0.2.5
fi

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install App/service installation service ... "
docker pull $DOCKER_HUB_NAMESPACE/dk_appinstallservice:latest

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
# Install dk_ivi
dk_ivi_value=""
# Loop through all input arguments
for arg in "$@"; do
    # Check if the argument starts with dk_ivi=
    if [[ "$arg" == dk_ivi=* ]]; then
        # Extract the value after the equal sign
        dk_ivi_value="${arg#*=}"
    fi
done
if [[ "$dk_ivi_value" == "true" ]]; then
    echo "enable xhost local"
	$CURRENT_DIR/scripts/dk_enable_xhost.sh
    echo "Instal dk_ivi ..."
    docker pull $DOCKER_HUB_NAMESPACE/dk_ivi:latest

    echo "Checking for NVIDIA Target Board..."
    if [ -f "/etc/nv_tegra_release" ]; then
        echo "NVIDIA Jetson board detected."
        docker stop dk_ivi; docker rm dk_ivi ; docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR -e QT_QUICK_BACKEND=software --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT="/app/.dk/" $DOCKER_HUB_NAMESPACE/dk_ivi:latest
    else
        echo "Not NVIDIA board."
        docker stop dk_ivi; docker rm dk_ivi ; docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR --device /dev/dri:/dev/dri --restart unless-stopped $LOG_LIMIT_PARAM $DOCKER_SHARE_PARAM -v $HOME_DIR/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_DOCKER_HUB_NAMESPACE=$DOCKER_HUB_NAMESPACE -e DK_ARCH=$ARCH -e DK_CONTAINER_ROOT="/app/.dk/" $DOCKER_HUB_NAMESPACE/dk_ivi:latest
    fi
else
    echo "To Install dk_ivi, run './dk_install dk_ivi=true'"
fi


echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Store environment variables"

# Define the output file (you can change the path as needed)
mkdir -p /home/.dk/dk_swupdate
DK_ENV_FILE="/home/.dk/dk_swupdate/dk_swupdate_env.sh"
> $DK_ENV_FILE

# Write the actual values of the variables to the output file
cat <<EOF > "${DK_ENV_FILE}"
#!/bin/bash

DK_USER="${DK_USER}"
ARCH="${ARCH}"
HOME_DIR="${HOME_DIR}"
DOCKER_SHARE_PARAM="${DOCKER_SHARE_PARAM}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
DOCKER_AUDIO_PARAM="${DOCKER_AUDIO_PARAM}"
LOG_LIMIT_PARAM="${LOG_LIMIT_PARAM}"
DOCKER_HUB_NAMESPACE="${DOCKER_HUB_NAMESPACE}"
dk_ara_demo="${dk_ara_demo}"
dk_ivi_value="${dk_ivi_value}"
EOF

# make the output file executable
chmod +x "${DK_ENV_FILE}"
cp $DK_ENV_FILE "${HOME_DIR}/.dk/dk_swupdate/dk_swupdate_env.sh"
chmod +x "$CURRENT_DIR/scripts/dk_kuksa_client.sh"
cp $CURRENT_DIR/scripts/dk_kuksa_client.sh /home/.dk/dk_swupdate/
chmod +x "$CURRENT_DIR/scripts/dk_xiphost.sh"
cp $CURRENT_DIR/scripts/dk_xiphost.sh /home/.dk/dk_swupdate/
$CURRENT_DIR/scripts/create_dk_xiphost_service.sh

echo "Environment variables with actual values have been saved to ${DK_ENV_FILE}"

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Create sw history file for the first time"

DK_SWHISTORY_FILE="/home/$DK_USER/.dk/dk_swupdate/dk_swhistory.json"

> $DK_SWHISTORY_FILE

# Get current UTC timestamp in ISO 8601 format (e.g. 2023-10-01T10:15:30Z)
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create dk_swhistory.json with the JSON content and the actual timestamp
cat <<EOF > $DK_SWHISTORY_FILE
{
  "MetaData": {
      "timestamp": "${timestamp}",
      "description": "Initial software.",
      "currentVersion": "0.0.0",
      "patch": ""
  },
  "SwUpdateHistory": [
    {
      "id": 1,
      "timestamp": "${timestamp}",
      "description": "Initial software.",
      "version": "0.0.0",
      "patch": ""
    }
  ],
  "LastFailure": {
      "timestamp": "",
      "description": "",
      "version": "",
      "patch": ""
  }
}
EOF

echo "$DK_SWHISTORY_FILE created with timestamp ${timestamp}"

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Install OS SW Update service ... "
docker pull $DOCKER_HUB_NAMESPACE/dk_swupdate:latest
docker stop dk_swupdate; docker rm dk_swupdate; docker run -d -it --name dk_swupdate $LOG_LIMIT_PARAM -v /var/run/docker.sock:/var/run/docker.sock --network host -v $HOME_DIR/.dk:/app/.dk --restart unless-stopped -e DK_HOME="/app" $DOCKER_HUB_NAMESPACE/dk_swupdate:latest

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Remove Only Dangling Images (No Tags)"
docker image prune -f

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------------------"

echo "------------------------------------------------------------------------------------------------------------------------------------"
echo "Please reboot your system for dreamSW to take effect !!!!!!!!!!!!!"
echo "------------------------------------------------------------------------------------------------------------------------------------"
