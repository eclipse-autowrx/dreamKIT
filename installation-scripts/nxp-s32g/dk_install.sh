#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT


# Enable the Service to Start at Boot
cp ./.dk/nxp-s32g/scripts/dreamos-setup.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable dreamos-setup.service
systemctl start dreamos-setup.service
systemctl status dreamos-setup.service

# Setup on client machines
cp ./.dk/nxp-s32g/scripts/daemon.json /etc/docker/daemon.json
# Restart docker daemon
systemctl restart docker


CMD="cp ./.dk/nxp-s32g/scripts/k3s.service /lib/systemd/system/k3s.service"
echo $CMD; $CMD

CMD="mkdir -p /etc/rancher/k3s/"
echo $CMD; $CMD
CMD="cp ./.dk/nxp-s32g/scripts/registries.yaml /etc/rancher/k3s/registries.yaml"
echo $CMD; $CMD

CMD="systemctl daemon-reload"
echo $CMD; $CMD
# CMD="systemctl restart k3s"
# echo $CMD; $CMD


# Can ultilities
chmod +x ./.dk/nxp-s32g/tools/.
CMD="cp -r ./.dk/nxp-s32g/tools/* /usr/local/bin"
echo $CMD; $CMD

