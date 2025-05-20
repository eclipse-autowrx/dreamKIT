
# Table of Contents

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [QT library](#qt-library)
  - [System Dependency](#system-dependency)
- [Build \& Launch](#build--launch)
  - [With Docker](#with-docker)
    - [Notes:](#notes)
  - [Natively with CMake](#natively-with-cmake)
  - [Natively with QT Creator](#natively-with-qt-creator)


# Overview

> Info: This repo provides a guideline to build image for dk_ivi app. dk_ivi is a simple In-Vehicle Infotainment System UI app for User Interaction with dreamKIT system.


# Prerequisites

## QT library

For the CMake or Docker build
- The user need to have the refer to the Dockerfile and 'apt-get' to get all necessary library

For the QT creator
- The project is compatible with QT6 6.9.0
  

## System Dependency

Install dreamOS without dk_ivi (\installation-scripts\jetson-orin\dk_install.sh)


# Build & Launch

## With Docker

Local-arch build:  
```shell
docker build -t dk_ivi:latest --file Dockerfile .
```

Run local:  
```shell
docker stop dk_ivi; docker rm dk_ivi ; docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --device /dev/dri:/dev/dri --restart unless-stopped dk_ivi:latest

docker stop dk_ivi; docker rm dk_ivi ; docker run --entrypoint /bin/bash -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --device /dev/dri:/dev/dri --restart unless-stopped dk_ivi:latest
```

Multi-arch build and push to docker hub:  
```shell
docker buildx create --name dk_ivi_multiarch_build --use
docker buildx use dk_ivi_multiarch_build 
docker buildx build --platform linux/amd64,linux/arm64 -t phongbosch/dk_ivi:latest --push -f Dockerfile .
```

Run from docker hub
```shell
docker pull phongbosch/dk_ivi:latest
docker stop dk_ivi; docker rm dk_ivi ; docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --device /dev/dri:/dev/dri --restart unless-stopped phongbosch/dk_ivi:latest
```

```shell
// export to run with docker container
export DKCODE="dreamKIT"
export DK_USER=$USER
export DK_DOCKER_HUB_NAMESPACE="phongbosch"
export DK_ARCH="amd64"
export DK_CONTAINER_ROOT="/app/.dk/"
docker stop dk_ivi; docker rm dk_ivi ; docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --device /dev/dri:/dev/dri --restart unless-stopped -v ~/.dk:/app/.dk -e DKCODE=dreamKIT -e DK_USER=$DK_USER -e DK_DOCKER_HUB_NAMESPACE=$DK_DOCKER_HUB_NAMESPACE -e DK_ARCH=$DK_ARCH -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker -e DK_CONTAINER_ROOT=$DK_CONTAINER_ROOT dk_ivi:latest
```

### Notes:

This image is tested well on Raspi5 and Micorsoft Surface devices.  
In some systems like Nvidia Ubuntu, by default they don't have /dev/dri. Nvidia system might use different way to render display with hardward acceleration.  
Below is in testing mode using nvidia-docker with option "--gpus all". if it doesn't work by default (like in Jetson Nano), the option "-e QT_QUICK_BACKEND=software" should be used.  
Example on Jetson nano:  
```shell
nvidia-docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --gpus all -e QT_QUICK_BACKEND=software --device /dev/dri:/dev/dri phongbosch/dk_ivi:latest
```

Example on Jetson Orin AGX:  can run the ivi but there is a flickering issue on the display.  
```shell
nvidia-docker run -d -it --name dk_ivi -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --gpus all --device /dev/dri:/dev/dri phongbosch/dk_ivi:latest
```

## Natively with CMake

```shell
// build natively.
cd src
mkdir build
cd build
cmake -DNATIVE_TESTING=ON ..
make -j

./dk_ivi
```

```shell
// export to run natively 
export DKCODE="dreamKIT"
export DK_USER=$USER
export DK_DOCKER_HUB_NAMESPACE="phongbosch"
export DK_ARCH="amd64"
export DK_CONTAINER_ROOT=~/.dk/
export XDG_RUNTIME_DIR="/run/user/$(id -u "$DK_USER")"
export DISPLAY=:0
sudo -E ./dk_ivi
```


## Natively with QT Creator

From QT6 Creator IDE (v6.9.0), Let's open the dreamos-core\dk-ivi-lite\src\dk_ivi.pro

