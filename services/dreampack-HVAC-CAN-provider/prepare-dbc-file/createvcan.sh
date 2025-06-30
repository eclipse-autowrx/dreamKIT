# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

#
# Set up virtual can device "elmcan" as sink
# for the elm2canbridge
#

#Default dev, can be overridden by commandline
DEV=elmcan

if [ -n "$1" ]
then
    DEV=$1
fi

echo "createvcan: Preparing to bring up vcan interface $DEV"

virtualCanConfigure() {
	echo "createvcan: Setting up VIRTUAL CAN"
	sudo  modprobe -n --first-time vcan &> /dev/null
	loadmod=$?
	if [ $loadmod -eq 0 ]
	then
		echo "createvcan: Virtual CAN module not yet loaded. Loading......"
		sudo modprobe vcan
	fi


	ifconfig "$DEV" &> /dev/null
	noif=$?
	if [ $noif -eq 1 ]
	then
		echo "createvcan: Virtual CAN interface not yet existing. Creating..."
		sudo ip link add dev "$DEV" type vcan
	fi
	sudo ip link set "$DEV" up
}



#If up?
up=$(ifconfig "$DEV" 2> /dev/null | grep NOARP | grep -c RUNNING)

if [ $up -eq 1 ]
then
   echo "createvcan: Interface already up. Exiting"
   exit
fi

virtualCanConfigure

echo "createvcan: Done."
