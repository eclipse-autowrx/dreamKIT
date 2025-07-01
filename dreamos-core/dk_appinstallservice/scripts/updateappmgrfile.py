# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import json
import sys
import os

# Load JSON files
def load_json_file(file_path):
    if not os.path.exists(file_path):
        print(f"Error: The file {file_path} does not exist.")
        sys.exit(1)
    
    with open(file_path, 'r') as file:
        return json.load(file)

# Save JSON file
def save_json_file(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=4)

# Add or Update app (if _id exists, it updates; if not, it adds)
def add_or_update_app(installed_app_data, app_cfg_data):
    app_id = app_cfg_data['_id']
    for i, app in enumerate(installed_app_data):
        if app['_id'] == app_id:
            installed_app_data[i] = app_cfg_data
            print(f"App with _id: {app_id} has been updated.")
            return installed_app_data
    # If no matching _id, add the new app
    installed_app_data.append(app_cfg_data)
    print(f"App with _id: {app_id} has been added.")
    return installed_app_data

# Remove an app
def remove_app(installed_app_data, app_id):
    for i, app in enumerate(installed_app_data):
        if app['_id'] == app_id:
            del installed_app_data[i]
            print(f"App with _id: {app_id} has been removed.")
            return installed_app_data
    print(f"No app with _id: {app_id} found to remove.")
    return installed_app_data

# Main function to handle the operation
def main(operation, installed_app_path, app_cfg_path):
    # Check if the files exist
    if not os.path.exists(installed_app_path):
        print(f"Error: The file {installed_app_path} does not exist.")
        sys.exit(1)

    if not os.path.exists(app_cfg_path):
        print(f"Error: The file {app_cfg_path} does not exist.")
        sys.exit(1)

    # Load the JSON data
    installed_app_data = load_json_file(installed_app_path)
    app_cfg_data = load_json_file(app_cfg_path)

    if operation == 'add' or operation == 'update':
        # Automatically handles add or update
        installed_app_data = add_or_update_app(installed_app_data, app_cfg_data)
    elif operation == 'remove':
        app_id = app_cfg_data['_id']  # Remove based on _id from appCfg
        installed_app_data = remove_app(installed_app_data, app_id)
    else:
        print("Invalid operation. Please use 'add', 'update', or 'remove'.")

    # Save the updated installedapp.json
    save_json_file(installed_app_path, installed_app_data)

# Entry point
if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: python script.py <add/update/remove> <installedapp.json> <appCfg.json>")
    else:
        operation = sys.argv[1].lower()
        installed_app_path = sys.argv[2]
        app_cfg_path = sys.argv[3]
        main(operation, installed_app_path, app_cfg_path)
