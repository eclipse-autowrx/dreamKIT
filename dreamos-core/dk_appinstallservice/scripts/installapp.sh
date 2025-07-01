# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/bash

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

echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "HOME_DIR: $HOME_DIR"

OVERLAYFILEPATH="$HOME_DIR/.dk/dk_app_python_template/scripts/"
OVERLAYFILENAME="main.py"

#### pip install pip install PyYAML

# Update vssmapping_overlay
cd $HOME_DIR/.dk/dk_app_python_template/scripts/
python $OVERLAYFILEPATH$OVERLAYFILENAME 

# regenerate vahicle model
docker restart vssgen

# restart vehicledatabroker
docker restart vehicledatabroker

