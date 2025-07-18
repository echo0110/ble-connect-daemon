#!/bin/bash

LOG_FILE="/home/gensong/connect-ble-quectel/ble_connect.log"

# === Configuration ===
BT_FILE="/opt/AGV_LOG/VehicleLog/Peripheral/Bt/bt_log.log"  # Log file path

# === Log function with timestamp ===
log() {
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >> "$LOG_FILE"
}

# === Extract TARGET_ADDR from the log file (from the end of the file) ===
TARGET_ADDR=$(tac "$BT_FILE" | grep -m 1 "bt is connecting to" | awk '{print $6}')
if [ -z "$TARGET_ADDR" ]; then
    log "No Bluetooth device found in the log. Exiting."
    exit 1
fi
log "Found TARGET_ADDR: $TARGET_ADDR"

MAX_ATTEMPTS=3                   # Maximum number of connection attempts
SCAN_DURATION=16                 # Scan time in seconds

# === Reset Bluetooth adapter ===
log "Resetting Bluetooth adapter..."
bluetoothctl -- power off
sleep 2
bluetoothctl -- power on
sleep 2

# === Remove old pairing/connection info ===
log "Removing previous record of device $TARGET_ADDR..."
bluetoothctl -- remove $TARGET_ADDR
sleep 3
nohup bluetoothctl -- scan on &  # Start scanning in the background
SCAN_PID=$!  # Get the process ID of the scan command

# Wait for the scan to run for the specified duration
sleep $SCAN_DURATION

# Stop scanning after the specified duration
log "Stopping scan..."
kill $SCAN_PID  # Kill the background process after SCAN_DURATION seconds

# === Connection logic ===
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    log "Attempt $i: trying to connect to $TARGET_ADDR..."

    bluetoothctl -- connect $TARGET_ADDR
    sleep 5

    # Check connection status
    INFO_RESULT=$(bluetoothctl -- info $TARGET_ADDR)
    if echo "$INFO_RESULT" | grep -q "Connected: yes"; then
        log "Successfully connected to $TARGET_ADDR"
        exit 0
    else
        log "Connection failed, attempting to pair..."

        bluetoothctl -- pair $TARGET_ADDR
        sleep 2

        log "Retrying connection to $TARGET_ADDR..."
        bluetoothctl -- connect $TARGET_ADDR
        sleep 3

        INFO_RESULT=$(bluetoothctl -- info $TARGET_ADDR)
        if echo "$INFO_RESULT" | grep -q "Connected: yes"; then
            log "Successfully connected to $TARGET_ADDR after pairing"
            exit 0
        else
            log "Failed to connect after pairing (attempt $i)"
        fi
    fi
done

log "Failed to connect after $MAX_ATTEMPTS attempts. Exiting."
exit 1
