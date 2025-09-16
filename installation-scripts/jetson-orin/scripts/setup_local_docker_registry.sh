#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

DAEMON_JSON="/etc/docker/daemon.json"
REGISTRY="localhost:5000"

if [ ! -f "$DAEMON_JSON" ]; then
  echo "File $DAEMON_JSON does not exist. Creating with insecure-registries set to [\"$REGISTRY\"]"
  tee "$DAEMON_JSON" > /dev/null <<EOF
{
  "insecure-registries": ["$REGISTRY"]
}
EOF
else
  echo "File $DAEMON_JSON exists. Backing up and inserting insecure-registries"
  cp "$DAEMON_JSON" "${DAEMON_JSON}.bak.$(date +%s)"
  echo "Backup saved."

  # Check if insecure-registries already present
  if grep -q '"insecure-registries"' "$DAEMON_JSON"; then
    echo "insecure-registries already exists, skipping insert."
  else
    # Insert insecure-registries line after first opening brace {
    echo "Insert insecure-registries."
    sed -i "0,/{/s/{/{\n  \"insecure-registries\": [\"$REGISTRY\"],/" "$DAEMON_JSON"
  fi
fi


echo "Done. Restart Docker daemon to apply changes:"
systemctl restart docker
echo "Restart Docker daemon done."

echo "start docker registry"
docker volume create local-registry-data
docker kill dk_local_registry
docker rm dk_local_registry
docker run -d -p 5000:5000 --restart=unless-stopped --name dk_local_registry -v local-registry-data:/var/lib/registry registry:2

