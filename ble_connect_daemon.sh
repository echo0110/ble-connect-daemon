#!/bin/bash

FIFO="/tmp/ble_cmd_pipe"
LOG_FILE="/home/gensong/connect-ble-quectel/ble_connect.log"
MAX_ATTEMPTS=3

# === 创建 FIFO 如果不存在 ===
if [ ! -p "$FIFO" ]; then
    mkfifo "$FIFO"
fi

# === 日志函数 ===
log() {
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >> "$LOG_FILE"
}

log "BLE Connect Daemon started. Listening on $FIFO..."

while true; do
    if read -r cmd < "$FIFO"; then
        action=$(echo "$cmd" | awk '{print $1}')
        mac=$(echo "$cmd" | awk '{print $2}')

        if [[ "$action" == "connect" && "$mac" =~ ([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2} ]]; then
            log "Received connect command for $mac"

            for ((i=1; i<=MAX_ATTEMPTS; i++)); do
                log "Attempt $i to connect to $mac..."
                echo -e "scan on\nconnect $mac\ninfo $mac\nexit" | bluetoothctl | tee -a "$LOG_FILE" | grep "Connected:"
                sleep 5

                if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                    log "Successfully connected to $mac"
                    break
                fi
            done

            if ! bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                log "Failed to connect to $mac after $MAX_ATTEMPTS attempts"
            fi
        else
            log "Invalid command: $cmd"
        fi
    fi
done

