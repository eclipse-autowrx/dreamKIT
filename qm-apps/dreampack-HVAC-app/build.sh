#!/bin/bash
# Copyright (c) 2025 Eclipse Foundation.
# 
# This program and the accompanying materials are made available under the
# terms of the MIT License which is available at
# https://opensource.org/licenses/MIT.
#
# SPDX-License-Identifier: MIT

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
VSS_MODEL_PATH="$HOME/.dk/sdv-runtime/vss.json"
MAIN_PY_PATH="./app/src/main.py"
APP_MANIFEST_PATH="./app/AppManifest.json"
DOCKERFILE_PATH="./app/Dockerfile"

echo -e "${GREEN}Starting Velocitas Application Build...${NC}"

# Step 1: Check if VSS model exists (optional)
if [ ! -f "$VSS_MODEL_PATH" ]; then
    echo -e "${YELLOW}WARNING: VSS model not found at $VSS_MODEL_PATH${NC}"
    echo -e "${YELLOW}Skipping VSS signal validation...${NC}"
    VSS_AVAILABLE=false
else
    echo -e "${GREEN}✓ Found VSS model at $VSS_MODEL_PATH${NC}"
    VSS_AVAILABLE=true
fi

# Step 2: Parse system VSS model to extract available signals (if available)
if [ "$VSS_AVAILABLE" = true ]; then
    echo -e "${YELLOW}Parsing system VSS model...${NC}"
else
    echo -e "${YELLOW}Skipping VSS model parsing (no VSS model found)...${NC}"
    SYSTEM_VSS_SIGNALS=""
fi

if [ "$VSS_AVAILABLE" = true ]; then
    # Extract all VSS paths from the system model
    # This handles nested JSON structure and extracts paths
    SYSTEM_VSS_SIGNALS=$(python3 << EOF
import json
import sys

def extract_vss_paths(data, prefix=""):
    """Recursively extract all VSS signal paths from the model."""
    paths = []

    if isinstance(data, dict):
        # Check if this node has children
        if 'children' in data:
            # This is a branch node, process its children
            for key, value in data['children'].items():
                current_path = f"{prefix}.{key}" if prefix else key
                # Check if child is a signal (has datatype or type)
                if isinstance(value, dict) and ('datatype' in value or 'type' in value):
                    signal_type = value.get('datatype', value.get('type', 'unknown'))
                    paths.append(f"{current_path}:{signal_type}")
                # Recursively process if it has children too
                if isinstance(value, dict):
                    paths.extend(extract_vss_paths(value, current_path))

        # Handle root "Vehicle" key specially
        elif 'Vehicle' in data:
            paths.extend(extract_vss_paths(data['Vehicle'], 'Vehicle'))

    return paths

try:
    with open("$VSS_MODEL_PATH", 'r') as f:
        vss_model = json.load(f)

    vss_paths = extract_vss_paths(vss_model)

    # Output as comma-separated list
    for path in vss_paths:
        print(path)

except Exception as e:
    print(f"ERROR: Failed to parse VSS model: {e}", file=sys.stderr)
    sys.exit(1)
EOF
)

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to parse system VSS model${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Parsed $(echo "$SYSTEM_VSS_SIGNALS" | wc -l) VSS signals from system model${NC}"
fi

# Step 3: Parse main.py to extract VSS signal usage and pubsub topics
echo -e "${YELLOW}Analyzing main.py for VSS signal usage and pubsub topics...${NC}"

if [ ! -f "$MAIN_PY_PATH" ]; then
    echo -e "${RED}ERROR: main.py not found at $MAIN_PY_PATH${NC}"
    exit 1
fi

# Extract VSS signals and pubsub topics used in main.py
ANALYSIS_RESULT=$(python3 << EOF
import re
import sys
import json

def analyze_code(file_path):
    """Extract VSS signals and pubsub topics from main.py."""
    vss_usage = []
    pubsub_reads = []
    pubsub_writes = []

    try:
        with open(file_path, 'r') as f:
            content = f.read()

        # Pattern to match self.Vehicle.XXX.YYY...
        # Captures the full path and the operation (.get() or .set())
        vss_pattern = r'self\.Vehicle\.([A-Za-z0-9_.]+)\.(get|set)\s*\('
        matches = re.finditer(vss_pattern, content)

        for match in matches:
            signal_path = f"Vehicle.{match.group(1)}"
            operation = match.group(2)
            access_type = "read" if operation == "get" else "write"

            # Check if already in list
            existing = next((u for u in vss_usage if u['path'] == signal_path), None)
            if existing:
                # If we have both read and write, upgrade to "readwrite"
                if existing['access'] != access_type:
                    existing['access'] = "readwrite"
            else:
                vss_usage.append({
                    'path': signal_path,
                    'access': access_type
                })

        # Pattern to match pubsub subscribe (reads)
        # Common patterns: subscribe_topic(), pubsub_client.subscribe(), await self.subscribe()
        subscribe_patterns = [
            r'subscribe_topic\s*\(\s*["\']([^"\']+)["\']',
            r'\.subscribe\s*\(\s*["\']([^"\']+)["\']',
            r'await\s+self\.subscribe\s*\(\s*["\']([^"\']+)["\']',
        ]

        for pattern in subscribe_patterns:
            matches = re.finditer(pattern, content)
            for match in matches:
                topic = match.group(1)
                if topic not in pubsub_reads:
                    pubsub_reads.append(topic)

        # Pattern to match pubsub publish (writes)
        # Common patterns: publish_event(), pubsub_client.publish(), await self.publish_event()
        publish_patterns = [
            r'publish_event\s*\(\s*["\']([^"\']+)["\']',
            r'\.publish\s*\(\s*["\']([^"\']+)["\']',
            r'await\s+self\.publish_event\s*\(\s*["\']([^"\']+)["\']',
        ]

        for pattern in publish_patterns:
            matches = re.finditer(pattern, content)
            for match in matches:
                topic = match.group(1)
                if topic not in pubsub_writes:
                    pubsub_writes.append(topic)

        return {
            'vss_usage': vss_usage,
            'pubsub_reads': pubsub_reads,
            'pubsub_writes': pubsub_writes
        }

    except Exception as e:
        print(f"ERROR: Failed to analyze main.py: {e}", file=sys.stderr)
        sys.exit(1)

result = analyze_code("$MAIN_PY_PATH")
print(json.dumps(result, indent=2))
EOF
)

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to analyze main.py${NC}"
    exit 1
fi

# Extract VSS usage from the result
USER_VSS_USAGE=$(echo "$ANALYSIS_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(json.dumps(data['vss_usage'], indent=2))")
PUBSUB_READS=$(echo "$ANALYSIS_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(json.dumps(data['pubsub_reads']))")
PUBSUB_WRITES=$(echo "$ANALYSIS_RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(json.dumps(data['pubsub_writes']))")

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to analyze main.py${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Extracted VSS signal usage from main.py${NC}"
echo "$USER_VSS_USAGE"

echo -e "${GREEN}✓ Extracted pubsub topics${NC}"
echo "  Reads: $PUBSUB_READS"
echo "  Writes: $PUBSUB_WRITES"

# Step 4: Validate user VSS signals against system VSS model (if VSS model available)
if [ "$VSS_AVAILABLE" = true ]; then
    echo -e "${YELLOW}Validating VSS signals...${NC}"

    VALIDATION_RESULT=$(python3 << EOF
import json
import sys
import os

# Parse system VSS signals
system_vss = """$SYSTEM_VSS_SIGNALS"""
system_signals = {}

for line in system_vss.strip().split('\n'):
    if ':' in line:
        path, signal_type = line.split(':', 1)
        system_signals[path] = signal_type

# Parse user VSS usage
user_usage = json.loads("""$USER_VSS_USAGE""")

# Validate each signal
invalid_signals = []
valid_signals = []

for usage in user_usage:
    signal_path = usage['path']

    if signal_path not in system_signals:
        invalid_signals.append(signal_path)
    else:
        valid_signals.append(usage)

# Report results
if invalid_signals:
    print("INVALID", file=sys.stderr)
    for signal in invalid_signals:
        print(f"  - {signal}", file=sys.stderr)
    sys.exit(1)
else:
    print("VALID")
    print(json.dumps(valid_signals, indent=2))
EOF
)

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Invalid VSS signals detected:${NC}"
        echo "$VALIDATION_RESULT"
        exit 1
    fi

    echo -e "${GREEN}✓ All VSS signals are valid${NC}"
else
    echo -e "${YELLOW}Skipping VSS signal validation (no VSS model available)${NC}"
    # When no VSS model is available, create a simple validation result with all detected signals
    VALIDATION_RESULT="VALID
$USER_VSS_USAGE"
fi

# Step 5: Update AppManifest.json
echo -e "${YELLOW}Updating AppManifest.json...${NC}"

python3 << EOF
import json
import sys

# Read current AppManifest.json
try:
    with open("$APP_MANIFEST_PATH", 'r') as f:
        manifest = json.load(f)
except Exception as e:
    print(f"ERROR: Failed to read AppManifest.json: {e}", file=sys.stderr)
    sys.exit(1)

# Parse validation result to get valid signals
validation_result = """$VALIDATION_RESULT"""
lines = validation_result.strip().split('\n', 1)
if len(lines) > 1:
    valid_signals = json.loads(lines[1])
else:
    valid_signals = []

# Parse pubsub topics
pubsub_reads = json.loads("""$PUBSUB_READS""")
pubsub_writes = json.loads("""$PUBSUB_WRITES""")

# Update vehicle-signal-interface
vsi_found = False
for interface in manifest.get('interfaces', []):
    if interface.get('type') == 'vehicle-signal-interface':
        vsi_found = True
        # Update required datapoints
        if 'config' not in interface:
            interface['config'] = {}
        if 'datapoints' not in interface['config']:
            interface['config']['datapoints'] = {}

        interface['config']['datapoints']['required'] = [
            {
                'path': signal['path'],
                'access': signal['access']
            }
            for signal in valid_signals
        ]
        break

# Update or remove pubsub interface based on detected usage
pubsub_found = False
for i, interface in enumerate(manifest.get('interfaces', [])):
    if interface.get('type') == 'pubsub':
        pubsub_found = True
        if pubsub_reads or pubsub_writes:
            # Update pubsub config
            if 'config' not in interface:
                interface['config'] = {}
            interface['config']['reads'] = pubsub_reads
            interface['config']['writes'] = pubsub_writes
        else:
            # No pubsub usage detected, remove the interface
            manifest['interfaces'].pop(i)
        break

# If pubsub not found but usage detected, add it
if not pubsub_found and (pubsub_reads or pubsub_writes):
    manifest['interfaces'].append({
        'type': 'pubsub',
        'config': {
            'reads': pubsub_reads,
            'writes': pubsub_writes
        }
    })

# Write updated manifest
try:
    with open("$APP_MANIFEST_PATH", 'w') as f:
        json.dump(manifest, f, indent=4)
    print("SUCCESS")
except Exception as e:
    print(f"ERROR: Failed to write AppManifest.json: {e}", file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to update AppManifest.json${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Updated AppManifest.json${NC}"

# Step 6: Generate Docker image name from parent folder
PARENT_DIR=$(basename "$(pwd)")
# Convert to lowercase and replace invalid characters with hyphens
IMAGE_NAME=$(echo "$PARENT_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')

# Ensure image name doesn't start with invalid characters
IMAGE_NAME=$(echo "$IMAGE_NAME" | sed 's/^[^a-z0-9]*//')

# Add a default prefix if empty
if [ -z "$IMAGE_NAME" ]; then
    IMAGE_NAME="velocitas-app"
fi

echo -e "${YELLOW}Building Docker image: ${IMAGE_NAME}${NC}"

# Step 7: Build Docker image
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo -e "${RED}ERROR: Dockerfile not found at $DOCKERFILE_PATH${NC}"
    exit 1
fi

# Build with app directory as context
docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME:latest" .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully built Docker image: ${IMAGE_NAME}:latest${NC}"
else
    echo -e "${RED}ERROR: Docker build failed${NC}"
    exit 1
fi

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}Image name: ${IMAGE_NAME}:latest${NC}"
