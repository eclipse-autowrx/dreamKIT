# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# syntax=docker/dockerfile:1.2

# Build stage, to create the executable
FROM --platform=$TARGETPLATFORM ghcr.io/eclipse-velocitas/devcontainer-base-images/python:v0.4 as builder
ARG TARGETARCH

RUN apt-get update && apt-get install -y python3-dev

COPY ./.velocitas.json /workspace/.velocitas.json
COPY ./app /workspace/app

# Remove this installation for Arm64 once staticx has a prebuilt wheel for Arm64
RUN /bin/bash -c 'set -ex && \
    ARCH=`uname -m` && \
    if [ "$ARCH" == "aarch64" ]; then \
    echo "ARM64" && \
    apt-get install -y gcc && \
    pip3 install --no-cache-dir scons; \
    fi'

RUN pip3 install --no-cache-dir pyinstaller==6.9 \
    && pip3 install --no-cache-dir patchelf==0.17.0.0 \
    && pip3 install --no-cache-dir staticx \
    && pip3 install --no-cache-dir -r ./workspace/app/requirements.txt \
    && pip3 install --no-cache-dir -r ./workspace/app/requirements-velocitas.txt \
    && pip3 install --no-cache-dir -r ./workspace/app/requirements-links.txt

WORKDIR /workspace

RUN velocitas init -v

WORKDIR /workspace/app

# CORRECTED COMMAND: Added --collect-all to bundle the velocitas_sdk
RUN pyinstaller --clean -F -s -p src --collect-all velocitas_sdk src/main.py

WORKDIR /workspace/app/dist

RUN staticx main run-exe

# Runner stage, to copy the executable
FROM alpine:latest

COPY --from=builder ./workspace/app/dist/run-exe /dist/

WORKDIR /tmp
WORKDIR /dist

ENV PATH="/dist:$PATH"

LABEL org.opencontainers.image.source="https://github.com/eclipse-velocitas/vehicle-app-python-template"

CMD ["./run-exe"]
