# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

import argparse
import sys
import time
import threading
import subprocess
import os
import json
from bluetooth.ble import GATTRequester, DiscoveryService

# For Kuksa client
from kuksa_client.grpc import Datapoint
from kuksa_client.grpc import VSSClient
from kuksa_client.grpc import DataEntry
from kuksa_client.grpc import DataType
from kuksa_client.grpc import EntryUpdate
from kuksa_client.grpc import Field
from kuksa_client.grpc import Metadata

# Replace with the actual host and port
#BROKER_HOST = 'VEHICLEDATABROKER'
BROKER_HOST = '127.0.0.1'
BROKER_PORT = 55555

# Path to the cfg.json file
file_path = "/app/runtime/runtimecfg.json"
address_value = "ff:ff:ff:ff:ff:ff"

def getDeviceAddress():
    global address_value
    # Read the JSON data from the file
    with open(file_path, 'r') as file:
        data = json.load(file)
    # Get the address value from the parsed JSON
    address_value = data.get('address')
    print(f"The address value is: {address_value}")

def connect_to_vss_client(host, port):
    """Continuously attempt to connect to the VSS server until successful."""
    while True:
        try:
            # Attempt to connect to the server
            client = VSSClient(host, port)
            print("Successfully connected to the VSS server.")
            return client  # Return the connected client
        except Exception as e:
            print(f"Connection error: {e}. Retrying...")

        # Wait before trying again
        time.sleep(3)

# Keep trying to connect until successful
client = connect_to_vss_client(BROKER_HOST, BROKER_PORT)
print("Connection established, proceeding with operations.")
print("Service Started!!!!!")


API_COFFEE_STARTBREW = "Vehicle.BYOD.CoffeeMachine.Brew"
client = VSSClient(BROKER_HOST, BROKER_PORT)
client.connect()

def is_text_in_file(file_path, text):
    """
    Check if the specified text is present in the file.

    Parameters:
    file_path (str): The path to the file to be read.
    text (str): The text to search for in the file.

    Returns:
    bool: True if the text is found in the file, False otherwise.
    """
    try:
        with open(file_path, 'r') as file:
            for line in file:
                if text in line:
                    return True
        return False
    except FileNotFoundError:
        print(f"The file {file_path} does not exist.")
        return False

def makeCofee():
    os.system("> coffee.log")
    #cmd = 'python3 press.py -d f4:66:b6:ff:b1:34 -c press > coffee.log'
    cmd = f'python3 press.py -d {address_value} -c press > coffee.log'
    print(f"Executing command: {cmd}")

    os.system(cmd)
    ret1 = is_text_in_file("coffee.log", "Connected!")
    ret2 = is_text_in_file("coffee.log", "Command execution successful")
    return ret1 & ret2

MAX_TRIES = 3  # Define the maximum number of attempts

def main():
    try:
        with VSSClient(BROKER_HOST, BROKER_PORT) as client:
            for updates in client.subscribe_target_values([
                API_COFFEE_STARTBREW,
            ]):
                if updates[API_COFFEE_STARTBREW] is not None:
                    currentText = updates[API_COFFEE_STARTBREW].value
                    if currentText == True:
                        ret = False
                        attempts = 0  # Initialize the attempts counter
                        while ret == False and attempts < MAX_TRIES:
                            getDeviceAddress()
                            ret = makeCofee()
                            attempts += 1
                            time.sleep(1)
                        print('Command "start brewing" execution successful')
                    else:
                        print('Command "stop brewing" execution successful')
    finally:
        print("end !!!") 

if __name__ == '__main__':
    main()
