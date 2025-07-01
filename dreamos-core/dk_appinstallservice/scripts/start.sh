# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/sh

echo "Start Installation service"

# Determine the user who ran the command
if [ -n "$SUDO_USER" ]; then
    # Command was run with sudo
    DK_USER=$SUDO_USER
else
    # Command was not run with sudo, fall back to current user
    DK_USER=$USER
fi

# Set Env Variables
HOME_DIR="/home/$DK_USER"
DOCKER_SHARE_PARAM="-v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker"
LOG_LIMIT_PARAM="--log-opt max-size=10m --log-opt max-file=3"

echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_SHARE_PARAM: $DOCKER_SHARE_PARAM"
echo "LOG_LIMIT_PARAM: $LOG_LIMIT_PARAM"

# Update vssmapping_overlay
cd /app
python main.py installCfg.json

echo "End Installation service"

#tail -f /dev/null
