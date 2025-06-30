# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/sh

echo "Start dk_ivi"
# start local mqtt server
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/app/exec/lib:/app/exec/lib/qt6/lib/
export QML2_IMPORT_PATH=/app/exec/lib/qt6/qml
export QT_PLUGIN_PATH=/app/exec/lib/qt6/plugins/
#export QT_QUICK_BACKEND=software
cd /app/exec
./dk_ivi
echo "End dk_ivi"

#tail -f /dev/null
