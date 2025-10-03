#!/bin/bash

# VSS (Vehicle Signal Specification) Setup and Generation Script
# This script manages VSS repository, generates vss_dbc.json, and updates default values

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DREAMKIT_ROOT="$SCRIPT_DIR/../../.."
VSS_REPO_DIR="$DREAMKIT_ROOT/vehicle_signal_specification"
VSS_BRANCH="4.X"
VSS_REPO_URL="https://github.com/COVESA/vehicle_signal_specification"
DBC_OVERLAY="$SCRIPT_DIR/prepare-dbc-file/mapping/vss_4.0/dbc_overlay.vspec"
VSS_OUTPUT="$SCRIPT_DIR/prepare-dbc-file/mapping/vss_4.0/vss_dbc.json"
DBC_DEFAULTS="$SCRIPT_DIR/prepare-dbc-file/mapping/dbc_default_values.json"
DBC_FILE="$SCRIPT_DIR/prepare-dbc-file/ModelCAN.dbc"

show_help() {
    cat << EOF
VSS (Vehicle Signal Specification) Setup and Generation Script

Usage: $0 [OPTIONS]

This script manages the VSS repository, generates vss_dbc.json mapping file,
and updates default CAN signal values for VSS actuators.

OPTIONS:
    -h, --help          Show this help message

WORKFLOW:

1. VSS Repository Setup:
   - Checks if vehicle_signal_specification repository exists in dreamKIT/ folder
   - If not, clones from: $VSS_REPO_URL (branch: $VSS_BRANCH)
   - Location: $DREAMKIT_ROOT/vehicle_signal_specification
   - Note: Repository contains submodules including vss-tools

2. VSS to DBC Mapping Generation:
   - Executes vspec2json.py to generate vss_dbc.json
   - Uses dbc_overlay.vspec for custom mappings
   - Supports both sensor (CAN->VSS) and actuator (VSS->CAN) types

3. Default Values Update:
   - Scans dbc_overlay.vspec for VSS actuators
   - Parses ModelCAN.dbc to find all signals in related CAN messages
   - Updates dbc_default_values.json with default values (0) for all CAN signals

VSS SIGNAL TYPES:

┌─────────────────────────────────────────────────────────────────────────────┐
│ SENSOR TYPE (CAN → VSS)                                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ Direction: CAN signal → VSS path (read from vehicle)                       │
│                                                                             │
│ Example in dbc_overlay.vspec:                                              │
│   Vehicle.Speed:                                                           │
│     type: sensor                                                           │
│     datatype: float                                                        │
│     dbc2vss:                                                               │
│       signal: DI_uiSpeed                                                   │
│       interval_ms: 5000                                                    │
│                                                                             │
│ Field Explanations:                                                        │
│   - type: sensor          → Read-only signal from CAN bus                 │
│   - datatype: float       → VSS data type for the signal                  │
│   - dbc2vss:              → Mapping from DBC to VSS                       │
│   - signal: DI_uiSpeed    → CAN signal name from DBC file                 │
│   - interval_ms: 5000     → Update interval (5 seconds)                   │
│                                                                             │
│ Testing Workflow (DI_uiSpeed example):                                     │
│   1. CAN Message: ID257DIspeed (ID: 0x257, DLC: 8 bytes)                  │
│   2. Signal Position: bit 24 on CAN frame                                 │
│   3. Send test message:                                                    │
│      $ cansend vcan1 257#0000000001000000                                 │
│   4. Monitor in KUKSA:                                                     │
│      kuksa-client> subscribe Vehicle.Speed                                │
│      (Observe the value update)                                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ ACTUATOR TYPE (VSS → CAN)                                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ Direction: VSS path → VSS signal (write to vehicle)                        │
│                                                                             │
│ Example in dbc_overlay.vspec:                                              │
│   Vehicle.Body.Lights.Beam.Low.IsOn:                                       │
│     type: actuator                                                         │
│     datatype: boolean                                                      │
│     vss2dbc:                                                               │
│       signal: DAS_lowBeamRequest                                           │
│       transform:                                                           │
│         mapping:                                                           │
│           - from: true                                                     │
│             to: DAS_HEADLIGHT_REQUEST_ON                                   │
│           - from: false                                                    │
│             to: DAS_HEADLIGHT_REQUEST_OFF                                  │
│                                                                             │
│ Field Explanations:                                                        │
│   - type: actuator            → Writable signal to CAN bus                │
│   - datatype: boolean         → VSS data type for the signal              │
│   - vss2dbc:                  → Mapping from VSS to DBC                   │
│   - signal: DAS_lowBeamRequest → CAN signal name in DBC file             │
│   - transform:                → Optional value transformation             │
│   - mapping:                  → Maps VSS values to CAN enum values        │
│                                                                             │
│ Testing Workflow (DAS_lowBeamRequest example):                             │
│   1. CAN Message: ID3E9DAS_bodyControls (ID: 0x3E9, DLC: 8 bytes)         │
│   2. Signal Position: bit 0 (DAS_lowBeamRequest)                          │
│   3. Set value in KUKSA:                                                   │
│      kuksa-client> setTargetValue Vehicle.Body.Lights.Beam.Low.IsOn true  │
│   4. Monitor CAN bus:                                                      │
│      $ candump vcan1                                                       │
│      (Observe: 3E9#XX, where bit 0 = 1 indicates the change)              │
└─────────────────────────────────────────────────────────────────────────────┘

FILES:
    Input (User-designed):
        - $DBC_OVERLAY
          Manual design file for VSS-to-CAN mapping (USER DESIGNED)
        - $DBC_FILE
          CAN database file with signal definitions (USER PROVIDED)

    Output (Generated):
        - $VSS_OUTPUT
          Generated VSS-DBC mapping file (AUTO-GENERATED)
        - $DBC_DEFAULTS
          Default values for all CAN signals in actuator messages (AUTO-GENERATED)

NOTES:
    - All CAN signals from actuator messages are added to dbc_default_values.json
    - The script parses ModelCAN.dbc to find ALL signals in each CAN message
    - The dbc_overlay.vspec must be manually designed by the user (INPUT)
    - The vss_dbc.json and dbc_default_values.json are auto-generated (OUTPUT)
    - VSS repository includes vss-tools as a submodule
    - Python package 'anytree' is required (install: pip3 install -r requirements.txt)

EXAMPLES:
    # Run the complete workflow
    $ $0

    # Show this help
    $ $0 -h

EOF
}

# Parse command line arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

echo "======================================================================"
echo "VSS Setup and Generation Script"
echo "======================================================================"
echo ""

# Step 1: Check and clone VSS repository
echo "[1/3] Checking VSS repository..."
if [ ! -d "$VSS_REPO_DIR" ]; then
    echo "VSS repository not found. Cloning from $VSS_REPO_URL (branch: $VSS_BRANCH)..."
    git clone --recurse-submodules -b "$VSS_BRANCH" "$VSS_REPO_URL" "$VSS_REPO_DIR"
    echo "✓ VSS repository cloned successfully"
else
    echo "✓ VSS repository already exists"
    # Update submodules if needed
    echo "  Updating submodules..."
    cd "$VSS_REPO_DIR"
    git submodule update --init --recursive
    cd "$SCRIPT_DIR"
fi

# Verify vss-tools exists
if [ ! -f "$VSS_REPO_DIR/vss-tools/vspec2json.py" ]; then
    echo "ERROR: vss-tools not found. Please check submodules."
    exit 1
fi

echo ""

# Step 2: Generate vss_dbc.json
echo "[2/3] Generating vss_dbc.json..."
if [ ! -f "$DBC_OVERLAY" ]; then
    echo "ERROR: dbc_overlay.vspec not found at: $DBC_OVERLAY"
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "$VSS_OUTPUT")"

# Run vspec2json.py
echo "  Running vspec2json.py..."
python3 "$VSS_REPO_DIR/vss-tools/vspec2json.py" \
    -e vss2dbc,dbc2vss,dbc \
    -o "$DBC_OVERLAY" \
    -u "$VSS_REPO_DIR/spec/units.yaml" \
    --json-pretty \
    "$VSS_REPO_DIR/spec/VehicleSignalSpecification.vspec" \
    "$VSS_OUTPUT"

echo "✓ vss_dbc.json generated successfully at: $VSS_OUTPUT"
echo ""

# Step 3: Update dbc_default_values.json for actuators
echo "[3/3] Updating dbc_default_values.json with actuator default values..."

# Check if DBC file exists
if [ ! -f "$DBC_FILE" ]; then
    echo "ERROR: DBC file not found at: $DBC_FILE"
    exit 1
fi

# Parse dbc_overlay.vspec for actuator signals
actuator_signals=()

# Simple parsing of YAML-like structure
current_signal=""
in_vss2dbc=false

while IFS= read -r line; do
    # Check if line defines a VSS path (starts with Vehicle.)
    if [[ $line =~ ^[A-Z][a-zA-Z0-9.]+:$ ]]; then
        current_signal=""
        in_vss2dbc=false
    fi

    # Check for actuator type
    if [[ $line =~ type:[[:space:]]*actuator ]]; then
        # We're in an actuator block
        continue
    fi

    # Check for vss2dbc section
    if [[ $line =~ vss2dbc: ]]; then
        in_vss2dbc=true
        continue
    fi

    # Extract signal name from vss2dbc section
    if [ "$in_vss2dbc" = true ] && [[ $line =~ signal:[[:space:]]*([A-Za-z0-9_]+) ]]; then
        signal_name="${BASH_REMATCH[1]}"
        actuator_signals+=("$signal_name")
        in_vss2dbc=false
    fi
done < "$DBC_OVERLAY"

# Function to get all signals from a CAN message containing a specific signal
get_all_signals_from_message() {
    local target_signal="$1"
    local message_id=""
    local in_message=false
    local found_target=false
    local -a temp_signals=()

    # Find the message containing the target signal
    while IFS= read -r line; do
        # Check if this is a message definition
        if [[ $line =~ ^BO_[[:space:]]+[0-9]+[[:space:]]+([A-Za-z0-9_]+): ]]; then
            # If we were in a message and found the target, output all signals and return
            if [[ $found_target == true ]]; then
                for sig in "${temp_signals[@]}"; do
                    echo "$sig"
                done
                return 0
            fi

            # Start new message
            message_name="${BASH_REMATCH[1]}"
            in_message=true
            found_target=false
            temp_signals=()
        fi

        # Check if this line contains a signal definition
        if [[ $in_message == true ]] && [[ $line =~ ^[[:space:]]*SG_[[:space:]]+([A-Za-z0-9_]+) ]]; then
            signal="${BASH_REMATCH[1]}"
            temp_signals+=("$signal")

            # If we found our target signal, mark it
            if [[ "$signal" == "$target_signal" ]]; then
                found_target=true
            fi
        fi
    done < "$DBC_FILE"

    # Check if we found the target in the last message
    if [[ $found_target == true ]]; then
        for sig in "${temp_signals[@]}"; do
            echo "$sig"
        done
        return 0
    fi
}

# Collect all signals from messages containing actuator signals
all_can_signals=()
declare -A seen_signals

if [ ${#actuator_signals[@]} -gt 0 ]; then
    echo "  Found ${#actuator_signals[@]} actuator signals in dbc_overlay.vspec"
    echo "  Parsing ModelCAN.dbc to find all related CAN signals..."

    for actuator_sig in "${actuator_signals[@]}"; do
        echo "    Processing: $actuator_sig"

        # Get all signals from the message containing this actuator signal
        while IFS= read -r related_signal; do
            if [[ -n "$related_signal" ]] && [[ -z "${seen_signals[$related_signal]}" ]]; then
                all_can_signals+=("$related_signal")
                seen_signals[$related_signal]=1
                echo "      Found related signal: $related_signal"
            fi
        done < <(get_all_signals_from_message "$actuator_sig")
    done

    echo "  Total CAN signals to add: ${#all_can_signals[@]}"

    # Create or update dbc_default_values.json
    echo "  Creating dbc_default_values.json..."
    echo "{" > "$DBC_DEFAULTS"

    # Sort signals alphabetically for better readability
    IFS=$'\n' sorted_signals=($(sort <<<"${all_can_signals[*]}"))
    unset IFS

    for i in "${!sorted_signals[@]}"; do
        signal="${sorted_signals[$i]}"
        if [ $i -eq $((${#sorted_signals[@]} - 1)) ]; then
            # Last item, no comma
            echo "  \"$signal\" : 0" >> "$DBC_DEFAULTS"
        else
            echo "  \"$signal\" : 0," >> "$DBC_DEFAULTS"
        fi
    done

    echo "}" >> "$DBC_DEFAULTS"
    echo "✓ dbc_default_values.json created with ${#all_can_signals[@]} signals"
else
    echo "  No actuator signals found in dbc_overlay.vspec"
fi

echo ""
echo "======================================================================"
echo "✓ VSS setup and generation completed successfully!"
echo "======================================================================"
echo ""
echo "Generated files:"
echo "  - $VSS_OUTPUT"
echo "  - $DBC_DEFAULTS (updated)"
echo ""
echo "Next steps:"
echo "  1. Review the generated vss_dbc.json file"
echo "  2. Test sensor signals with: cansend vcan1 <msg_id>#<data>"
echo "  3. Test actuator signals in KUKSA client: setTargetValue <path> <value>"
echo "  4. Monitor CAN bus with: candump vcan1"
echo ""