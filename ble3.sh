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

            # A more efficient way to check if you are connected to any device
            #CONNECTED_INFO=$(bluetoothctl info | grep -A1 "Device")
            CONNECTED_INFO=$(bluetoothctl info)

            if [ -n "$CONNECTED_INFO" ] && echo "$CONNECTED_INFO" | grep -q "Connected: yes"; then
                CONNECTED_DEVICE=$(echo "$CONNECTED_INFO" | grep "^Device" | awk '{print $2}')
                DEVICE_NAME=$(echo "$CONNECTED_INFO" | grep "^.*Name:" | cut -d ":" -f2- | xargs)

                if [ "$CONNECTED_DEVICE" != "$mac" ]; then
                    log "Already connected to device: $CONNECTED_DEVICE ($DEVICE_NAME). Skipping connection request for $mac."
                    continue
                else
                    log "Already connected to requested device $mac. No action needed."
                    continue
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