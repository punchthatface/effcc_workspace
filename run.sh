#!/usr/bin/env bash

set -euo pipefail

APP="${1:-}"

if [ -z "$APP" ]; then
    echo "Usage: ./run.sh <app_name>"
    echo ""
    echo "Available apps:"
    echo "  quickstart"
    echo "  i2c_scan"
    exit 1
fi

if [ ! -d "apps/$APP" ]; then
    echo "ERROR: app directory apps/$APP does not exist"
    exit 1
fi

echo "================================"
echo "Setting up effcc toolchain"
echo "================================"

export EFFTOOLS_DIR="$HOME/effcc"
export PATH="$PATH:$EFFTOOLS_DIR/bin"

if [ ! -d "$EFFTOOLS_DIR" ]; then
    echo "ERROR: EFFTOOLS_DIR does not exist: $EFFTOOLS_DIR"
    exit 1
fi

if ! command -v eff-flash >/dev/null 2>&1; then
    echo "ERROR: eff-flash not found in PATH"
    echo "Expected under: $EFFTOOLS_DIR/bin"
    exit 1
fi

echo "EFFTOOLS_DIR=$EFFTOOLS_DIR"
echo "eff-flash found at: $(command -v eff-flash)"

echo ""
echo "================================"
echo "Detecting EVK serial ports"
echo "================================"

PORTS=$(ls /dev/ttyACM* 2>/dev/null || true)

if [ -z "$PORTS" ]; then
    echo "WARNING: No /dev/ttyACM devices detected right now."
    echo "You can still build, but flashing/serial will fail unless the EVK is connected."
else
    echo "Detected ports:"
    echo "$PORTS"
fi

# Usually the highest-numbered ACM port is STDIO on this board.
STDIO_PORT=$(ls /dev/ttyACM* 2>/dev/null | sort | tail -n 1 || true)

echo ""
echo "================================"
echo "Building project"
echo "================================"

mkdir -p build
cd build

cmake -G Ninja .. -DEFF_STDIO_PORT=3
ninja

echo ""
echo "================================"
echo "Locating firmware"
echo "================================"

HEX_PATH=$(find . -path "*/$APP/scalar/$APP.hex" | head -n 1)

if [ -z "$HEX_PATH" ]; then
    echo "Could not find exact path for $APP.hex, trying broad search..."
    HEX_PATH=$(find . -name "$APP.hex" | head -n 1)
fi

if [ -z "$HEX_PATH" ]; then
    echo "ERROR: Could not find $APP.hex after build"
    exit 1
fi

echo "Firmware found:"
echo "$HEX_PATH"

echo ""
echo "================================"
echo "Ready to flash"
echo "================================"
echo "Before flashing, make sure:"
echo "  1. EVK is connected over USB"
echo "  2. Power switch SW2 is ON"
echo "  3. Boot switches are set to 101 for SPI programming"
echo "  4. Reset button has been pressed after setting boot switches"
echo ""

read -rp "Flash $APP to SRAM now? [y/N] " RESP

if [[ "$RESP" =~ ^[Yy]$ ]]; then
    eff-flash "$HEX_PATH" sram
else
    echo "Skipping flash."
    exit 0
fi

if [ -z "$STDIO_PORT" ]; then
    echo "No ttyACM port detected for serial monitor."
    echo "If the board is connected, run: ls /dev/ttyACM*"
    exit 0
fi

echo ""
echo "================================"
echo "Opening serial monitor"
echo "================================"
echo "Using STDIO port: $STDIO_PORT"
echo "Press Ctrl+A then X to exit minicom"

minicom -b 115200 -D "$STDIO_PORT"