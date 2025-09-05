# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#!/bin/sh

echo "Start dk service can provider"

# Wait time for can network up
sleep 0.1

# cd /app/
# python main.py
# cd /dist/
./dbcfeeder --val2dbc --dbc2val --use-socketcan

echo "End dk service can provider"

#tail -f /dev/null
