# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import cantools
import json
import os
import argparse

# Set up argument parsing
parser = argparse.ArgumentParser(description="Update DBC default values for a specified signal.")
parser.add_argument("target_signal_name", help="The name of the signal to look for in the DBC file.")
parser.add_argument("dbc_file_path", help="Path to the DBC file.")
parser.add_argument("json_file_path", help="Path to the JSON file for saving defaults.")

args = parser.parse_args()

# Load the .dbc file
db = cantools.database.load_file(args.dbc_file_path)

# Define the default value for signals
default_value = 0

# Load existing JSON file if it exists and is not empty; otherwise, start with an empty dictionary
if os.path.exists(args.json_file_path) and os.path.getsize(args.json_file_path) > 0:
    with open(args.json_file_path, 'r') as json_file:
        dbc_defaults = json.load(json_file)
else:
    dbc_defaults = {}

# Search for the signal across all messages
message_found = None
for message in db.messages:
    if any(signal.name == args.target_signal_name for signal in message.signals):
        message_found = message
        break

# If the signal is found, add all signals from the message to dbc_defaults
if message_found:
    for signal in message_found.signals:
        dbc_defaults[signal.name] = default_value
else:
    print(f"Signal '{args.target_signal_name}' not found in any message in the .dbc file.")

# Write updated defaults to the JSON file
with open(args.json_file_path, 'w') as json_file:
    json.dump(dbc_defaults, json_file, indent=2)

print(f"Updated '{args.json_file_path}' with signals from the message containing '{args.target_signal_name}'.")
