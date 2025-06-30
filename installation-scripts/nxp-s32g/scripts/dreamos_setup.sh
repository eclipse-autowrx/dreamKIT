# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/bash
set -e
 
# Configure CAN0
ip link set can0 type can bitrate 500000 sample-point 0.7 dbitrate 2000000 fd on
ip link set can0 up
ifconfig can0 txqueuelen 65536
 
# Configure CAN1
#ip link set can1 type can bitrate 500000
ip link set can1 type can bitrate 500000 sample-point 0.75 dbitrate 2000000 fd on
ip link set can1 up
ifconfig can1 txqueuelen 65536
 
insmod /home/root/.dk/nxp-s32g/library/can-isotp-s32g-ewaol.ko
 
ifconfig eth0 192.168.56.49
