#!/usr/bin/expect

set timeout 20
set LOG_FILE "/home/gensong/connect-ble-quectel/ble_connect.log"
set BT_FILE "/opt/AGV_LOG/VehicleLog/Peripheral/Bt/bt_log.log"
set MAX_ATTEMPTS 3
set SCAN_DURATION 16

# === Log function with timestamp ===
proc log {message} {
    global LOG_FILE
    set timestamp [exec date "+%Y-%m-%d %H:%M:%S"]
    set log_message "[${timestamp}] $message"
    exec echo $log_message >> $LOG_FILE
}

# === Extract TARGET_ADDR from the log file ===
set TARGET_ADDR [exec tac $BT_FILE | grep -m 1 "bt is connecting to" | awk '{print $11}']
if {[string length $TARGET_ADDR] == 0} {
    log "No Bluetooth device found in the log. Exiting."
    exit 1
}

log "Found TARGET_ADDR: $TARGET_ADDR"

# === Reset Bluetooth adapter ===
log "Resetting Bluetooth adapter..."
spawn bluetoothctl -- power off
expect "#"
send "power on\r"
expect "#"
sleep 2

# === Remove old pairing/connection info ===
log "Removing previous record of device $TARGET_ADDR..."
spawn bluetoothctl -- remove $TARGET_ADDR
expect "#"
sleep 3

# === Start scanning in the background ===
log "Starting scan in the background..."
spawn bluetoothctl -- scan on
set SCAN_PID [exec echo $spawn_id]
sleep $SCAN_DURATION

# === Stop scanning after the specified duration ===
log "Stopping scan..."
send "scan off\r"
expect "#"

# === Connection logic ===
for {set i 1} {$i <= $MAX_ATTEMPTS} {incr i} {
    log "Attempt $i: trying to connect to $TARGET_ADDR..."
    
    # Try connecting to the device
    spawn bluetoothctl -- connect $TARGET_ADDR
    expect {
        "Connection successful" {
            log "Successfully connected to $TARGET_ADDR"
            exit 0
        }
        timeout {
            log "Connection failed, attempting to pair..."
            # Try pairing if connection failed
            spawn bluetoothctl -- pair $TARGET_ADDR
            expect "#"
            sleep 2
            
            log "Retrying connection to $TARGET_ADDR..."
            spawn bluetoothctl -- connect $TARGET_ADDR
            expect {
                "Connection successful" {
                    log "Successfully connected to $TARGET_ADDR after pairing"
                    exit 0
                }
                timeout {
                    log "Failed to connect after pairing (attempt $i)"
                }
            }
        }
    }
}

log "Failed to connect after $MAX_ATTEMPTS attempts. Exiting."
exit 1

