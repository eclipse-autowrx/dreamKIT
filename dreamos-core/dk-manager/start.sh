# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/sh

echo "Start dk_manager"
# start local mqtt server
cd /app/exec
export DKCODE=dreamKIT
./dk_manager
echo "End dk_manager"

#tail -f /dev/null
