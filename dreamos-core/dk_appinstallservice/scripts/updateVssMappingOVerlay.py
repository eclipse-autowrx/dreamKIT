# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import yaml
import os

def modify_vss_entry(action, vss_api, vss_type=None, datatype=None, description=None, dbc_signal=None, vss2dbc_signal=None, dbc2vss_signal=None):
    """
    Modifies a VSS entry in the given YAML file with a flat structure.

    :param action: 'add', 'update', or 'remove' to perform the respective action.
    :param vss_api: The VSS API path, e.g., 'Vehicle.Abc.Def.Texttospeech'.
    :param vss_type: (Optional) The type of the entry, e.g., 'sensor', 'actuator'.
    :param datatype: (Optional) The datatype of the entry, e.g., 'string', 'uint8'.
    :param description: (Optional) A description of the entry.
    :param dbc_signal: (Optional) Signal information for the DBC (DataBase CAN) mapping.
    :param vss2dbc_signal: (Optional) Signal information for VSS to DBC mapping.
    """
    # Construct the target file path using the HOME environment variable
    home_directory = os.getenv('HOME_PATH')
    vss_file = os.path.join(home_directory, '.dk/dk_manager/vssmapping/vssmapping_overlay.vspec')

    # Ensure the target directory exists
    target_directory = os.path.dirname(vss_file)
    os.makedirs(target_directory, exist_ok=True)

    # Try to load the existing data from the YAML file, or create an empty structure
    try:
        with open(vss_file, 'r') as file:
            data = yaml.safe_load(file)
            if data is None:
                data = {}
    except FileNotFoundError:
        # If the file does not exist, create an empty structure
        data = {}

    # Split the VSS API into its hierarchical parts
    keys = vss_api.split('.')

    if action in ['add', 'update']:
        # For each level in the hierarchy, create a separate entry
        for i in range(1, len(keys) + 1):
            current_key = '.'.join(keys[:i])
            # Check if it's the final key to decide the type (branch or actual node)
            if i == len(keys):
                entry = {
                    'type': vss_type if vss_type else 'branch',
                    'description': description if description else ''
                }
                if datatype:
                    entry['datatype'] = datatype
                if dbc_signal:
                    entry['dbc'] = {'signal': dbc_signal}
                if vss2dbc_signal:
                    entry['vss2dbc'] = {'signal': vss2dbc_signal}
                if dbc2vss_signal:
                    entry['dbc2vss'] = {'signal': dbc2vss_signal}
            else:
                # Create a branch entry for intermediate levels
                entry = {
                    'type': 'branch',
                    'description': ''
                }
            
            # Update or add the entry
            data[current_key] = entry

    elif action == 'remove':
        # Remove the entry and its sub-entries if it exists
        keys_to_remove = [key for key in data if key.startswith(vss_api)]
        for key in keys_to_remove:
            del data[key]

    # Write the updated data back to the file
    with open(vss_file, 'w') as file:
        yaml.dump(data, file, default_flow_style=False, sort_keys=False)

    print(f"{action.capitalize()} operation completed for {vss_api} in {vss_file}.")

# Example usage

# Add or update an entry with separated flat structure
modify_vss_entry(
    action='add',
    vss_api='Vehicle.Abc.Def.TextToSpeech',
    vss_type='actuator',
    datatype='string',
    description='Text to speech API',
    vss2dbc_signal='',
    dbc2vss_signal=''
)

# Remove an entry and its sub-entries
# modify_vss_entry(
#     action='remove',
#     vss_api='Vehicle.Abc.Def'
# )
