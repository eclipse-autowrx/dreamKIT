# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import json
import os
import glob
import subprocess

# Task 1: Read can_channel from runtimecfg.json
file_path = "/app/runtime/runtimecfg.json"

# Load and read the JSON file
with open(file_path, 'r') as file:
    config_data = json.load(file)

# Extract the can_channel value
can_channel = config_data.get("can_channel", None)
print("CAN Channel:", can_channel)

# Task 2: Find the first .dbc file in package_path
package_path = "/app/runtime/package"

# Use glob to find .dbc files and get the first one
dbc_files = glob.glob(os.path.join(package_path, "*.dbc"))
first_dbc_file = dbc_files[0] if dbc_files else None

print("First DBC File:", first_dbc_file)

# Ensure we have valid values before proceeding
if can_channel and first_dbc_file:
    # Task 3: Execute the command
    command = f"""
    cd /dist && \
    ./dbcfeeder --val2dbc --dbc2val --use-socketcan \
    --canport {can_channel} \
    --dbcfile {first_dbc_file} \
    --dbc-default /app/vss/dbc_default_values.json \
    --mapping /app/vss/vss.json
    """
    print(f"cmd: {command}")
    # result = subprocess.run(command, shell=True, text=True, capture_output=True)
    result = subprocess.run(command, shell=True, text=True)

    # Print the output and error (if any) of the command
    print("Command Output:", result.stdout)
    if result.stderr:
        print("Command Error:", result.stderr)
else:
    print("Error: Missing can_channel or .dbc file path.")
