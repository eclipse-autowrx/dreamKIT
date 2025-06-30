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
from bluetooth.ble import GATTRequester, DiscoveryService

def create_connection(device, bt_interface, timeout):
    req = GATTRequester(device, False, bt_interface if bt_interface else None)
    try:
        req.connect(True, 'random')  # True for a blocking call
        start_time = time.time()
        while not req.is_connected():
            if time.time() - start_time > timeout:
                raise ConnectionError(f"Connection to {device} timed out after {timeout} seconds")
        return req
    except Exception as e:
        print(f"Failed to connect: {str(e)}")
        return None

class Driver:
    handles = {
        'press': 0x16,
        'on': 0x16,
        'off': 0x16,
        'open': 0x0D,
        'close': 0x0D,
        'pause': 0x0D,
    }
    commands = {
        'press': b'\x57\x01\x00',
        'on': b'\x57\x01\x01',
        'off': b'\x57\x01\x02',
        'open': b'\x57\x0F\x45\x01\x05\xFF\x00',
        'close': b'\x57\x0F\x45\x01\x05\xFF\x64',
        'pause': b'\x57\x0F\x45\x01\x00\xFF',
    }

    def __init__(self, device, bt_interface=None, timeout_secs=5):
        self.device = device
        self.bt_interface = bt_interface
        self.timeout_secs = timeout_secs
        self.connection = None

    def connect(self):
        if not self.connection:
            self.connection = create_connection(self.device, self.bt_interface, self.timeout_secs)
            if self.connection and self.connection.is_connected():
                print('Connected!')

    def run_command(self, command):
        if not self.connection:
            print('not connected')
            self.connect()
        if self.connection and self.connection.is_connected():
            self.connection.write_by_handle(self.handles[command], self.commands[command])
            print('Command execution successful')

    def disconnect(self):
        if self.connection and self.connection.is_connected():
            self.connection.disconnect()
            print('Disconnected!')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--device', required=True, help="Specify the Bluetooth address of the device")
    parser.add_argument('-c', '--command', required=True, choices=['press', 'on', 'off', 'open', 'close', 'pause'], help="Command to send")
    parser.add_argument('-i', '--interface', default='hci0', help="Bluetooth interface, default 'hci0'")
    opts = parser.parse_args()

    driver = Driver(opts.device, opts.interface)
    try:
        driver.connect()
        driver.run_command(opts.command)
    finally:
        driver.disconnect()

if __name__ == '__main__':
    main()
