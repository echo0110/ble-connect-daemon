#!/bin/bash

FIFO="/tmp/ble_cmd_pipe"
LOG_FILE="/home/gensong/connect-ble-quectel/ble_connect.log"
MAX_ATTEMPTS=3
CURRENT_CONNECTED_MAC=""  # 状态：当前连接的 MAC

# 创建 FIFO（命名管道）
if [ ! -p "$FIFO" ]; then
    mkfifo "$FIFO"
fi

# 日志函数
log() {
    echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1" >> "$LOG_FILE"
}

log "BLE Connect Daemon started. Listening on $FIFO..."

# 无限循环监听命令
while true; do
    if read -r cmd < "$FIFO"; then
        action=$(echo "$cmd" | awk '{print $1}')
        mac=$(echo "$cmd" | awk '{print $2}')

        if [[ "$action" == "connect" && "$mac" =~ ([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2} ]]; then
            log "Received connect command for $mac"

            # 如果当前已经连接了目标设备，跳过
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

            # 未连接则尝试连接
            for ((i=1; i<=MAX_ATTEMPTS; i++)); do
                log "Attempt $i to connect to $mac..."
                echo -e "scan on\nconnect $mac\ninfo $mac\nexit" | bluetoothctl | tee -a "$LOG_FILE" | grep "Connected:"
                sleep 5

                if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                    log "Successfully connected to $mac"
                    CURRENT_CONNECTED_MAC="$mac"
                    break
                fi
            done

            if ! bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                log "Failed to connect to $mac after $MAX_ATTEMPTS attempts"
            fi
        else
            log "Invalid command received: $cmd"
        fi
    fi
done

