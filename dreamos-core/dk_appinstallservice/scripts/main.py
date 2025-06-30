# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import json
import os
import sys
import yaml
import time
import requests
import subprocess
import zipfile

# Define the modify_vss_entry function
def modify_vss_entry(action, vss_api, vss_type=None, datatype=None, description=None, dbc_signal=None, vss2dbc_signal=None, dbc2vss_signal=None, interval_ms=None):
    """
    Modifies a VSS entry in the given YAML file with a flat structure.

    :param action: 'add', 'update', or 'remove' to perform the respective action.
    :param vss_api: The VSS API path, e.g., 'Vehicle.Abc.Def.Texttospeech'.
    :param vss_type: (Optional) The type of the entry, e.g., 'sensor', 'actuator'.
    :param datatype: (Optional) The datatype of the entry, e.g., 'string', 'uint8'.
    :param description: (Optional) A description of the entry.
    :param dbc_signal: (Optional) Signal information for the DBC (DataBase CAN) mapping.
    :param vss2dbc_signal: (Optional) Signal information for VSS to DBC mapping.
    :param dbc2vss_signal: (Optional) Signal information for DBC to VSS mapping.
    """
    # Construct the target file path using the HOME environment variable
    # home_directory = os.getenv('HOME')
    # vss_file = os.path.join(home_directory, '.dk/dk_manager/vssmapping/vssmapping_overlay.vspec')
    vss_file = "/app/.dk/dk_manager/vssmapping/vssmapping_overlay.vspec"

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
                    dbc2vss_entry = {'signal': dbc2vss_signal}
                    if interval_ms is not None:
                        dbc2vss_entry['interval_ms'] = interval_ms
                    entry['dbc2vss'] = dbc2vss_entry
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

def cmd_execute(cmd):
    # Run the command and store the result
    result = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    # Check if the command was successful
    if result.returncode == 0:
        print("Command executed successfully.")
        print("Output:\n", result.stdout)
        return True
    else:
        print(f"Command failed with return code {result.returncode}")
        print("Error:\n", result.stderr)
        return False

def create_installedapps_file_if_missing(installedappsJson):
    # Check if the file exists
    if not os.path.exists(installedappsJson):
        print(f"{installedappsJson} not found. Creating with default content '[]'.")
        # Create the file with default content: []
        with open(installedappsJson, 'w') as file:
            json.dump([], file)
    else:
        print(f"{installedappsJson} already exists.")

# Load the current contents of supportedvssapi.json
def load_supported_vss_api(file_path):
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            return json.load(file)
    else:
        return []

# Save the updated list to supportedvssapi.json
def save_supported_vss_api(file_path, vss_api_list):
    with open(file_path, 'w') as file:
        json.dump(vss_api_list, file, indent=4)

# Main function to integrate modify_vss_entry with data.json
def main():
    # Check if the file path is passed as an argument
    if len(sys.argv) != 2:
        print("Usage: python main.py <data.json>")
        return
    
    # Get the file path from the command-line arguments
    json_installcfg_path = sys.argv[1]

    ######################################################################################################
    ######################################################################################################
    DK_SYS_CFG_FILE = f"/app/.dk/dk_manager/dk_system_cfg.json"
    # Read and parse the JSON file
    with open(DK_SYS_CFG_FILE, 'r') as f:
        data = json.load(f)

    # Access individual fields:
    DK_XIP_IP = data.get("xip", {}).get("ip")
    vip_info = data.get("vip", {})
    DK_VIP_IP = vip_info.get("ip")
    DK_VIP_USER = vip_info.get("user")
    DK_VIP_PWD = vip_info.get("pwd")

    print("\nExtracted information:")
    print(f"xip ip: {DK_XIP_IP}")
    print(f"vip ip: {DK_VIP_IP}")
    print(f"vip user: {DK_VIP_USER}")
    print(f"vip pwd: {DK_VIP_PWD}")
    ######################################################################################################
    ######################################################################################################
    
    # Read data.json
    try:
        with open(json_installcfg_path, 'r') as file:
            json_data = json.load(file)
    except FileNotFoundError:
        print(f"Error: {json_installcfg_path} file not found.")
        return
    except json.JSONDecodeError as e:
        print(f"Error: Failed to parse {json_installcfg_path} - {e}")
        return
        
    '''
        "_id": "66f4403288c998ad9aa31d19",
        "name": "Coffee Machine Service",
        "category": "vehicle-service",
    '''
    # Check if some configs exists in json_data
    if '_id' not in json_data:
        print("Error: '_id' not found in JSON data.")
        return
    if 'name' not in json_data:
        print("Error: 'name' not found in JSON data.")
        return
    if 'category' not in json_data:
        print("Error: 'category' not found in JSON data.")
        return
    if 'dashboardConfig' not in json_data:
        print("Error: 'dashboardConfig' not found in JSON data.")
        return
    dashboard_config = json_data['dashboardConfig']
    if 'DockerImageURL' not in dashboard_config:
        print("Warning: 'DockerImageURL' not found in dashboard_config.")
        # return

     # Parse dashboardConfig as it is a string
    try:
        dashboard_config = json.loads(json_data['dashboardConfig'])
    except json.JSONDecodeError as e:
        print(f"Warning: Failed to parse 'dashboardConfig' - {e}")
        # return

    if 'DockerImageURL' not in dashboard_config:
        print("Warning: 'DockerImageURL' not found in dashboard_config.")
        DockerImageURL = "NOT_AVAILABLE"
    else:
        DockerImageURL = dashboard_config['DockerImageURL']
        # return

    if 'Target' not in dashboard_config:
        print("Warning: 'Target' not found in dashboard_config.")
        DeployTarget = "xip"
    else:
        DeployTarget = dashboard_config['Target']

    if 'Platform' not in dashboard_config:
        print("Warning: 'Platform' not found in dashboard_config.")
        TargetPlatform = "linux/arm64"
    else:
        TargetPlatform = dashboard_config['Platform']
    
    _id = json_data['_id']
    name = json_data['name']
    category = json_data['category']
    
    print(f"_id: {_id}")
    print(f"name: {name}")
    print(f"category: {category}")
    print(f"DockerImageURL: {DockerImageURL}")
    print(f"DeployTarget: {DeployTarget}")
    print(f"TargetPlatform: {TargetPlatform}")

    rootFolder = "/app/.dk/dk_installedapps/"
    appFolder = f"{rootFolder}{_id}"
    installedappsJson = f"{rootFolder}installedapps.json"
    runtimeCfgJson = f"{appFolder}/runtimecfg.json"
    supported_vss_api_path = "/app/.dk/dk_manager/prototypes/supportedvssapi.json"

    if category == "vehicle":
        rootFolder = "/app/.dk/dk_installedapps/"
        appFolder = f"{rootFolder}{_id}"
        installedappsJson = f"{rootFolder}installedapps.json"
        runtimeCfgJson = f"{appFolder}/runtimecfg.json"
        print("Installing vehicle app ...")
    elif category == "vehicle-service":
        rootFolder = "/app/.dk/dk_installedservices/"
        appFolder = f"{rootFolder}{_id}"
        installedappsJson = f"{rootFolder}installedservices.json"
        runtimeCfgJson = f"{appFolder}/runtimecfg.json"
        print("Installing vehicle service ...")
    else:
        print("Error: the app is not in the supported category to be installed in this target device")
        return

    print('-' * 50)
    # create app folder
    cmd = f"mkdir -p {appFolder}"
    result = cmd_execute(cmd)
    if result == False:
        print(f"Error: can't create folder {appFolder}")
        return
    # Create the installedappsJson file if it does not exist
    create_installedapps_file_if_missing(installedappsJson)
    print("Successfully create app folder")
    
    print('-' * 50)
    # pull the app/service
    cmd = f"docker pull {DockerImageURL}"
    print(f"cmd: {cmd}")
    if (DeployTarget == "vip"):
        cmd = f"docker pull --platform {TargetPlatform} {DockerImageURL}"
    result = cmd_execute(cmd)
    if result == False:
        print(f"Error: can't pull the docker image {DockerImageURL}")
        return
    else:
        cmd = f"docker image prune -f"
        cmd_execute(cmd)
        print("Successfully download the app/service")
        if (DeployTarget == "vip"):
            # store image into local registry
            cmd = f"docker tag {DockerImageURL} localhost:5000/{DockerImageURL}"
            result = cmd_execute(cmd)
            if result == False:
                print(f"Error: can't execute {cmd}")
            cmd = f"docker push localhost:5000/{DockerImageURL}"
            result = cmd_execute(cmd)
            if result == False:
                print(f"Error: can't execute {cmd}")

            # vip pull image from xip host registry
            cmd = f"sshpass -p '{DK_VIP_PWD}' ssh -o StrictHostKeyChecking=no {DK_VIP_USER}@{DK_VIP_IP} 'docker pull {DK_XIP_IP}:5000/{DockerImageURL} ; mkdir -p ~/.dk/dk_installedservices'"
            result = cmd_execute(cmd)
            if result == False:
                print(f"Error: can't execute {cmd}")
                return
            cmd = f"sshpass -p '{DK_VIP_PWD}' ssh -o StrictHostKeyChecking=no {DK_VIP_USER}@{DK_VIP_IP} 'docker image prune -f'"
            cmd_execute(cmd)

    print('-' * 50)
    # Check if 'RuntimeCfg' exists
    if 'RuntimeCfg' in dashboard_config:
        # Extract RuntimeCfg
        runtime_cfg = dashboard_config.get("RuntimeCfg", {})
        with open(runtimeCfgJson, 'w') as f:
            json.dump(runtime_cfg, f, indent=4)
        print(f"RuntimeCfg exists: {runtime_cfg}")
    else:
        # If RuntimeCfg doesn't exist, create a file with "{}" content
        print("RuntimeCfg does not exist. Creating a file with empty content.")
        with open(runtimeCfgJson, 'w') as file:
            json.dump({}, file, indent=4)
        print(f"File '{runtimeCfgJson}' created with empty content: {{}}")
    print("Successfully update RuntimeCfg.")

    # if the installation is for app, then stop here !!!
    if category == "vehicle":
        print('-' * 50)
        # Add installed app into installedapps.json to manage all installed apps/services.
        cmd = f"python updateappmgrfile.py add {installedappsJson} {json_installcfg_path}"
        result = cmd_execute(cmd)
        if result == False:
            print(f"Error: can't update updateappmgrfile.py. cmd: {cmd}")
            return
        else:
            print("Successfully update updateappmgrfile.py")

        print(f"Successfully install vehicle app {_id} : {name}")
        return

    print('-' * 50)
    zip_file_path = f"{appFolder}/package.zip"
    packageFolder = os.path.join(appFolder, 'package')
    # Create the package folder if it doesn't exist
    os.makedirs(packageFolder, exist_ok=True)
    # Download the .zip package if needed.
    if 'downloadUrl' in json_data:
        print("Downloading .zip package...")
        downloadUrl = json_data['downloadUrl']
        # Download the file using requests
        try:
            response = requests.get(downloadUrl, stream=True)
            response.raise_for_status()  # Raise an error if download failed
    
            # Save the file to appFolder
            with open(zip_file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            print("Successfully downloaded .zip package.")
        except requests.RequestException as e:
            print(f"Error: can't download the package from {downloadUrl}.\n{e}")
            return
    
        # Unzip the package in appFolder
        try:
            with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
                zip_ref.extractall(packageFolder)
            print("Successfully unzipped the package.")
            # Optionally, delete the downloaded .zip file after extraction
            os.remove(zip_file_path)
        except zipfile.BadZipFile:
            print("Error: Failed to unzip, the file is not a valid .zip archive.")
    else:
        print("Warning: 'downloadUrl' not found in JSON data.")

    # Get the first .dbc file in packageFolder, if it exists
    dbc_file = None
    for file_name in os.listdir(packageFolder):
        if file_name.endswith('.dbc'):
            dbc_file = os.path.join(packageFolder, file_name)  # Get full path
            break
    if dbc_file:
        print(f"The first .dbc file found: {dbc_file}")
    else:
        print("No .dbc files found in the package folder.")
    

    # print('-' * 50)
    # dbcDefaultValue_file = "/app/.dk/dk_manager/vssmapping/dbc_default_values.json"
    # # Update vssmapping overlay and supported api list
    # supported_vss_api = load_supported_vss_api(supported_vss_api_path)
    # # Check if SignalList exists in dashboardConfig
    # if 'SignalList' not in dashboard_config:
    #     print("Warning: 'SignalList' not found in dashboardConfig.")
    #     # return
    # # Iterate over the SignalList to modify VSS entries
    # for signal in dashboard_config['SignalList']:
    #     # Extract necessary fields from the signal
    #     vss_api = signal.get('vss_api')
    #     if vss_api and vss_api not in supported_vss_api:
    #         supported_vss_api.append(vss_api)

    #     vss_type = signal.get('vss_type')
    #     datatype = signal.get('datatype')
    #     description = signal.get('description')
    #     dbc_signal = signal.get('dbc_signal')
    #     vss2dbc_signal = signal.get('vss2dbc_signal')
    #     dbc2vss_signal = signal.get('dbc2vss_signal')
    #     interval_ms = signal.get('interval_ms')
        
    #     # Call modify_vss_entry function
    #     modify_vss_entry(
    #         action='add',
    #         vss_api=vss_api,
    #         vss_type=vss_type,
    #         datatype=datatype,
    #         description=description,
    #         dbc_signal=dbc_signal,
    #         vss2dbc_signal=vss2dbc_signal,
    #         dbc2vss_signal=dbc2vss_signal,
    #         interval_ms=interval_ms
    #     )

    #     # update dbc default value.
    #     if dbc_file is not None and vss2dbc_signal != "":
    #         # python updateDbcDefaultValue.py VCLEFT_turnSignalStatus1 Model3CAN.dbc dbc_default_values_test.json
    #         cmd = f"python updateDbcDefaultValue.py {vss2dbc_signal} {dbc_file} {dbcDefaultValue_file}"
    #         result = cmd_execute(cmd)
    #         if result == False:
    #             print(f"Error: can't update update dbc default value of {vss2dbc_signal}. cmd: {cmd}")
    #             return
    #         else:
    #             print("Successfully update update dbc default value of {vss2dbc_signal}. cmd: {cmd}")

    # # Save the updated list back to the supportedvssapi.json file
    # save_supported_vss_api(supported_vss_api_path, supported_vss_api)
    # print("Successfully update vssmapping overlay.")

    # time.sleep(0.5)
    # print('-' * 50)
    # # restart vssgen to update new api lib
    # cmd = f"docker restart vssgen"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't restart vssgen")
    #     return
    # else:
    #     print("Successfully restart vssgen")

    # time.sleep(0.5)
    # cmd = f"sync"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't update vssgen")
    #     return
    # time.sleep(0.5)

    # print('-' * 50)
    # # restart vehicledatabroker to reload new api set
    # cmd = f"docker stop vehicledatabroker"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't stop vehicledatabroker")
    #     return
    # time.sleep(0.5)
    # cmd = f"docker start vehicledatabroker"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't restart vehicledatabroker")
    #     return
    # else:
    #     print("Successfully restart vehicledatabroker")

    # print('-' * 50)
    # # restart dk_manager to reload new api set
    # cmd = f"docker restart dk_manager"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't restart dk_manager")
    #     return
    # else:
    #     print("Successfully restart dk_manager")

    # print('-' * 50)
    # # restart dk_manager to reload new api set
    # cmd = f"docker kill dk_ivi;docker start dk_ivi"
    # result = cmd_execute(cmd)
    # if result == False:
    #     print(f"Error: can't restart dk_ivi")
    #     return
    # else:
    #     print("Successfully restart dk_ivi")

    print('-' * 50)
    if (DeployTarget == "vip"):
        # copy runtime folder to target
        # cmd = f"sshpass -p '{DK_VIP_PWD}' scp -o StrictHostKeyChecking=no -r {dbcDefaultValue_file} {DK_VIP_USER}@{DK_VIP_IP}:/home/.dk/dk_vss/"
        # result = cmd_execute(cmd)
        # if result == False:
        #     print(f"Error: can't execute {cmd}")

        vss_file = "/app/.dk/dk_vssgeneration/vss.json"
        cmd = f"sshpass -p '{DK_VIP_PWD}' scp -o StrictHostKeyChecking=no -r {vss_file} {DK_VIP_USER}@{DK_VIP_IP}:/home/.dk/dk_vss/"
        result = cmd_execute(cmd)
        if result == False:
            print(f"Error: can't execute {cmd}")

        # copy runtime folder to target
        cmd = f"sshpass -p '{DK_VIP_PWD}' scp -o StrictHostKeyChecking=no -r {appFolder} {DK_VIP_USER}@{DK_VIP_IP}:~/.dk/dk_installedservices"
        result = cmd_execute(cmd)
        if result == False:
            print(f"Error: can't execute {cmd}")

        print("Successfully update vss on vip")

    print('-' * 50)
    # Add installed app into installedapps.json to manage all installed apps/services.
    cmd = f"python updateappmgrfile.py add {installedappsJson} {json_installcfg_path}"
    result = cmd_execute(cmd)
    if result == False:
        print(f"Error: can't update updateappmgrfile.py. cmd: {cmd}")
        return
    else:
        print("Successfully update updateappmgrfile.py")

    print(f"Successfully install vehicle service {_id} : {name}")

if __name__ == "__main__":
    main()
