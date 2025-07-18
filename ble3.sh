#!/bin/bash

FIFO="/tmp/ble_cmd_pipe"
LOG_FILE="/home/gensong/connect-ble-quectel/ble_connect.log"
MAX_ATTEMPTS=3
SCAN_DURATION=15
CURRENT_CONNECTED_MAC=""

# Create FIFO if it doesn't exist
if [ ! -p "$FIFO" ]; then
    mkfifo "$FIFO"
fi

# Logging function
log() {
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >> "$LOG_FILE"
}

log "BLE Connect Daemon started. Listening on $FIFO..."

# Infinite loop to listen for commands
while true; do
    if read -r cmd < "$FIFO"; then
        action=$(echo "$cmd" | awk '{print $1}')
        mac=$(echo "$cmd" | awk '{print $2}')

        if [[ "$action" == "connect" && "$mac" =~ ([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2} ]]; then
            log "Received connect command for $mac"

            # Skip connection if already connected to the same MAC
            if [ "$CURRENT_CONNECTED_MAC" == "$mac" ]; then
                IS_STILL_CONNECTED=$(bluetoothctl info "$mac" | grep "Connected: yes")
                if [ -n "$IS_STILL_CONNECTED" ]; then
                    log "Already connected to $mac. Skipping connection."
                    continue
                else
                    log "Previously connected to $mac but now disconnected. Reconnecting..."
                    CURRENT_CONNECTED_MAC=""
                fi
            fi

            # Start scan and wait for device to be discovered
            log "Starting scan for $SCAN_DURATION seconds..."
            # Start scan in background
            bluetoothctl -- scan on > /dev/null 2>&1 &
            SCAN_PID=$!
            
            # Wait for device to be discovered
            DEVICE_FOUND=false
            for ((wait=1; wait<=$SCAN_DURATION; wait++)); do
                if bluetoothctl devices | grep -q "$mac"; then
                    log "Device $mac found in scan"
                    DEVICE_FOUND=true
                    break
                fi
                sleep 1
            done
            
            log "Stopping scan..."
            bluetoothctl -- scan off > /dev/null 2>&1
            kill $SCAN_PID 2>/dev/null
            
            # Only attempt connection if device was found
            if [ "$DEVICE_FOUND" = true ]; then
                # Try connecting up to MAX_ATTEMPTS
                for ((i=1; i<=MAX_ATTEMPTS; i++)); do
                    log "Attempt $i to connect to $mac..."
                    echo -e "connect $mac\ninfo $mac\nexit" | bluetoothctl | tee -a "$LOG_FILE"
                    sleep 5

                    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                        log "Successfully connected to $mac"
                        CURRENT_CONNECTED_MAC="$mac"
                        break
                    fi
                done
            else
                log "Device $mac not found during scan. Cannot connect."
            fi

            if ! bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                log "Failed to connect to $mac after $MAX_ATTEMPTS attempts"
            fi
        else
            log "Invalid command received: $cmd"
        fi
    fi
done

