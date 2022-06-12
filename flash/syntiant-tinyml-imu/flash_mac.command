#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
BOARD=arduino:samd:mkrzero
ARDUINO_CLI=$(which arduino-cli || true)
DIRNAME="$(basename "$SCRIPTPATH")"
EXPECTED_CLI_MAJOR=0
EXPECTED_CLI_MINOR=13

NDP_CMD="ndp10x_flash/ndp10x_flash_mac"
BIN_FILE="ei_model*.bin"

if [ ! -x "$ARDUINO_CLI" ]; then
    echo "Cannot find 'arduino-cli' in your PATH. Install the Arduino CLI before you continue."
    echo "Installation instructions: https://arduino.github.io/arduino-cli/latest/"
    exit 1
fi

CLI_MAJOR=$(arduino-cli version | cut -d. -f1 | rev | cut -d ' '  -f1)
CLI_MINOR=$(arduino-cli version | cut -d. -f2)
CLI_REV=$(arduino-cli version | cut -d. -f3 | cut -d ' '  -f1)

if (( CLI_MINOR < EXPECTED_CLI_MINOR)); then
    echo "You need to upgrade your Arduino CLI version (now: $CLI_MAJOR.$CLI_MINOR.$CLI_REV, but required: $EXPECTED_CLI_MAJOR.$EXPECTED_CLI_MINOR.x or higher)"
    echo "See https://arduino.github.io/arduino-cli/installation/ for upgrade instructions"
    exit 1
fi

if (( CLI_MAJOR != EXPECTED_CLI_MAJOR || CLI_MINOR != EXPECTED_CLI_MINOR )); then
    echo "You're using an untested version of Arduino CLI, this might cause issues (found: $CLI_MAJOR.$CLI_MINOR.$CLI_REV, expected: $EXPECTED_CLI_MAJOR.$EXPECTED_CLI_MINOR.x)"
fi

echo "Finding Arduino SAMD core v1.8.9..."

has_arduino_core() {
    arduino-cli core list | grep -e "arduino:samd.*1.8.9" || true
}
HAS_ARDUINO_CORE="$(has_arduino_core)"
if [ -z "$HAS_ARDUINO_CORE" ]; then
    echo "Installing Arduino SAMD core..."
    arduino-cli core update-index
    arduino-cli core install arduino:samd@1.8.9
    echo "Installing Arduino SAMD core OK"
else
    echo "Finding Arduino SAMD OK"
fi

echo "Finding Arduino MKRZero..."

has_serial_port() {
    (arduino-cli board list | grep "Arduino MKRZERO" || true) | cut -d ' ' -f1
}
SERIAL_PORT=$(has_serial_port)

if [ -z "$SERIAL_PORT" ]; then
    echo "Cannot find a connected Arduino MKRZero development board (via 'arduino-cli board list')."
    echo "If your board is connected, double-tap on the RESET button to bring the board in recovery mode."
    exit 1
fi

echo "Finding Arduino MKRZero OK"

cd "$SCRIPTPATH"

echo "Flashing Arduino firmware..."
arduino-cli upload -p $SERIAL_PORT --fqbn $BOARD --input-file firmware.ino.bin

echo "Flashed your Arduino MKRZero development board. Board restarting..."
sleep 5

echo "Writing NN model to flash..."
$NDP_CMD -s $SERIAL_PORT -Q -a 0x00 -w $BIN_FILE -v $BIN_FILE

echo "Writing NN model OK"

echo ""
echo "Press reset button to start the application"

