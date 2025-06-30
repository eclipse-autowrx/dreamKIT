# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/bash

# Enable the Service to Start at Boot
cp scripts/dreamos-setup.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable dreamos-setup.service
systemctl start dreamos-setup.service
systemctl status dreamos-setup.service

# Setup on client machines
cp /scripts/daemon.json /etc/docker/daemon.json
# Restart docker daemon
systemctl restart docker

# Can ultilities
chmod +x tools/.
cp -r tools/* /usr/local/bin
