#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

COMMAND="$1"
PATH_ARG="$2"
# Combine command-line arguments into one command.
#echo "Executing command: \"$CMD\""
CMD="$@"

if [ "$COMMAND" = "getValue" ] || [ "$COMMAND" = "getTargetValue" ]; then
  # Run the command inside the Docker container and capture all output.
  raw_output=$(echo "$@" | docker run --rm -i --network host ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2 grpc://127.0.0.1:55569 2>&1)
  # echo "raw_output: $raw_output"
  
  extracted=""
  while IFS= read -r line; do
    if [[ $line == *'"value"'* ]]; then
      # Skip the line that is just the JSON object open: "value": {
      if [[ $line == *'{'* ]]; then
        continue
      fi
      extracted=$(echo "$line" | cut -d ':' -f2- | xargs)
      break
    fi
  done <<< "$raw_output"
  
  if [ -z "$extracted" ]; then
    echo "ERROR: Could not extract the signal value."
    exit 1
  else
    echo "$extracted"
    exit 0
  fi
elif [ "$COMMAND" = "setValue" ] || [ "$COMMAND" = "setTargetValue" ]; then
  # Run the command inside the Docker container and capture all output.
  raw_output=$(echo "$@" | docker run --rm -i --network host ghcr.io/eclipse/kuksa.val/kuksa-client:0.4.2 grpc://127.0.0.1:55569 2>&1)
  echo "OK"
else
  echo "invalue command: $CMD"
  exit 1
fi




