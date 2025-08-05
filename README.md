

# BLE Connect Daemon

This is a simple BASH script that acts as a daemon to manage Bluetooth Low Energy (BLE) connections on Linux systems, specifically designed for Quectel modules but adaptable to other platforms. It listens for commands to connect to a specific BLE device, automates the scanning and connection process, and logs all activities.

-----

## Features

  * **Daemonized Operation**: Runs continuously in the background, listening for commands.
  * **FIFO-based Communication**: Uses a named pipe (`/tmp/ble_cmd_pipe`) for safe and reliable inter-process communication.
  * **Automatic Scanning**: Initiates a BLE scan to find the target device before attempting to connect.
  * **Connection Retries**: Attempts to connect to a device up to a configurable number of times (`MAX_ATTEMPTS`) to handle temporary connection failures.
  * **Connection State Management**: Checks if a device is already connected and avoids redundant connection attempts.
  * **Comprehensive Logging**: All actions, including daemon startup, commands received, connection attempts, and connection status, are logged to a file (`ble_connect.log`).

-----

## Prerequisites

  * A Linux-based system with `bash`
  * `bluetoothctl` (part of the `bluez` package)
  * `awk` (typically installed by default)

To install `bluez` on a Debian/Ubuntu system, you can use:

```bash
sudo apt-get update
sudo apt-get install bluez
```

-----

## Configuration

You can customize the script's behavior by modifying the following variables at the beginning of the `ble_connect.sh` file:

| Variable | Description | Default Value |
| :--- | :--- | :--- |
| `FIFO` | The path to the named pipe used for communication. | `/tmp/ble_cmd_pipe` |
| `LOG_FILE` | The path to the log file. | `/home/gensong/connect-ble-quectel/ble_connect.log` |
| `MAX_ATTEMPTS` | The number of times the script will try to connect to a device. | `3` |
| `SCAN_DURATION` | The duration, in seconds, for which the script will scan for devices. | `15` |

-----

## Usage

### 1\. Running the Daemon

To start the daemon, simply run the script in the background:

```bash
/path/to/your/ble_connect.sh &
```

This will start the script and detach it from your current terminal session. The script will create the FIFO and start listening for commands.

### 2\. Sending Connection Commands

To connect to a specific BLE device, send a command to the named pipe using `echo`. The command format is `connect <MAC_ADDRESS>`.

For example, to connect to a device with the MAC address `12:34:56:78:90:AB`:

```bash
echo "connect 12:34:56:78:90:AB" > /tmp/ble_cmd_pipe
```

The script will then process this command, log the action, scan for the device, and attempt to connect.

### 3\. Monitoring

All daemon activities are logged to the file specified by `LOG_FILE`. You can monitor the daemon's activity in real time using the `tail` command:

```bash
tail -f /home/gensong/connect-ble-quectel/ble_connect.log
```

This is useful for debugging and confirming that connections are being made correctly.

-----

## How it Works

1.  **Initialization**: The script first checks if the FIFO exists and creates it if necessary.
2.  **Listening Loop**: It enters an infinite `while` loop, waiting to read a command from the FIFO. This is a blocking operation, so it won't consume CPU when idle.
3.  **Command Parsing**: When a command is received, the script parses it to get the action (`connect`) and the target MAC address.
4.  **Connection Logic**:
      * It first checks the current connection status using `bluetoothctl info` to see if a device is already connected. If the requested device is already connected, it logs the information and exits the connection logic.
      * If no device is connected (or a different one is), it starts a BLE scan for `SCAN_DURATION` seconds.
      * It checks for the target MAC address within the scan results.
      * If the device is found, it attempts to connect up to `MAX_ATTEMPTS` times.
      * After each attempt, it verifies the connection status.
5.  **Logging**: All steps, from receiving the command to the final connection outcome, are written to the `LOG_FILE`, providing a detailed history of operations.

This structured approach makes it easy to understand, configure, and use your script, and it provides a great foundation for anyone looking to automate BLE connections. Do you want to add any other sections or details to the README, or are you happy with this version?
