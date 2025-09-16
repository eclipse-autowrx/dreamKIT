#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

# source the installation env
source /home/.dk/dk_swupdate/dk_swupdate_env.sh

echo "Env Variables:"
echo "DK_USER: $DK_USER"
echo "ARCH: $ARCH"
echo "HOME_DIR: $HOME_DIR"
echo "DOCKER_SHARE_PARAM: $DOCKER_SHARE_PARAM"
echo "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "DOCKER_AUDIO_PARAM: $DOCKER_AUDIO_PARAM"
echo "LOG_LIMIT_PARAM: $LOG_LIMIT_PARAM"
echo "DOCKER_HUB_NAMESPACE: $DOCKER_HUB_NAMESPACE"
echo "dk_ara_demo: $dk_ara_demo"
echo "dk_ivi_value: $dk_ivi_value"

while true; do
    ##########################################################################################
    ###############  Vehicle.SwUpdate.XipHost.UpdateTrigger ##################################
    ##########################################################################################
    # Use command substitution to capture the output of the child script.
    result=$(/home/.dk/dk_swupdate/dk_kuksa_client.sh getTargetValue Vehicle.SwUpdate.XipHost.UpdateTrigger)
    # Capture the exit code from the child script.
    exit_code=$?
    # Print the output and the exit code.
    echo "The child script returned: '$result'"
    # Execute SW update if true
    if [ $exit_code -eq 0 ]; then
        echo "Child script succeeded."
        if [[ $result == *'true'* ]]; then
            echo "UpdateTrigger is true, executing update command..."
            # Execute your update command here:
            /home/.dk/dk_swupdate/dk_kuksa_client.sh setTargetValue Vehicle.SwUpdate.XipHost.UpdateTrigger False
            ret=$("$HOME_DIR/.dk/dk_swupdate/dk_installation/swpackage/xip/xiphost.sh")
            e_code=$?
            if [ $e_code -eq 0 ]; then
                /home/.dk/dk_swupdate/dk_kuksa_client.sh setValue Vehicle.SwUpdate.XipHost.PercentageDone 100
            else
                /home/.dk/dk_swupdate/dk_kuksa_client.sh setValue Vehicle.SwUpdate.Status 7
            fi
        else
            echo "UpdateTrigger is false. Checking again..."
        fi
    else
        echo "Child script failed with exit code: $exit_code"
    fi


    ##########################################################################################
    ###############  Vehicle.SwUpdate.XipHost.PatchUpdateTrigger ##################################
    ##########################################################################################
    # Use command substitution to capture the output of the child script.
    result=$(/home/.dk/dk_swupdate/dk_kuksa_client.sh getTargetValue Vehicle.SwUpdate.XipHost.PatchUpdateTrigger)
    # Capture the exit code from the child script.
    exit_code=$?
    # Print the output and the exit code.
    echo "The child script returned: '$result'"
    # Execute SW update if true
    if [ $exit_code -eq 0 ]; then
        echo "Child script succeeded."
        if [[ $result == *'true'* ]]; then
            echo "PatchUpdateTrigger is true, executing update command..."
            # Execute your update command here:
            /home/.dk/dk_swupdate/dk_kuksa_client.sh setTargetValue Vehicle.SwUpdate.XipHost.PatchUpdateTrigger False
            ret=$("$HOME_DIR/.dk/dk_swupdate/dk_patch/swpackage/xip/xiphost.sh")
            e_code=$?
            if [ $e_code -eq 0 ]; then
                /home/.dk/dk_swupdate/dk_kuksa_client.sh setValue Vehicle.SwUpdate.XipHost.PercentageDone 100
            else
                /home/.dk/dk_swupdate/dk_kuksa_client.sh setValue Vehicle.SwUpdate.Status 7
            fi
        else
            echo "PatchUpdateTrigger is false. Checking again..."
        fi
    else
        echo "Child script failed with exit code: $exit_code"
    fi

    # Wait before the next check (e.g., 10 seconds)
    sleep 5
done

echo "Exiting update check loop."
