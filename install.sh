#!/bin/bash
set -e

MODULE="xbox-one-isdbc"
VERSION="1.0.0"
SRC_DIR="/usr/src/${MODULE}-${VERSION}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (e.g. sudo ./install.sh)" >&2
    exit 1
fi

echo "=== 1. Checking dependencies ==="
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq dkms build-essential linux-headers-"$(uname -r)"
fi

echo "=== 2. Checking firmware ==="
FW_OK=true
if [ ! -f /lib/firmware/dvb-usb-dib0700-1.20.fw ]; then
    echo "Notice: /lib/firmware/dvb-usb-dib0700-1.20.fw not found."
    echo "Downloading dib0700 firmware..."
    curl -fsSL -o /lib/firmware/dvb-usb-dib0700-1.20.fw \
        "https://raw.githubusercontent.com/LibreELEC/dvb-firmware/master/firmware/dvb-usb-dib0700-1.20.fw" || FW_OK=false
fi
if [ ! -f /lib/firmware/dvb-demod-mn88472-02.fw ]; then
    echo "Notice: /lib/firmware/dvb-demod-mn88472-02.fw not found."
    echo "Downloading mn88472 firmware..."
    curl -fsSL -o /lib/firmware/dvb-demod-mn88472-02.fw \
        "https://raw.githubusercontent.com/LibreELEC/dvb-firmware/master/firmware/dvb-demod-mn88472-02.fw" || FW_OK=false
fi
if [ "$FW_OK" != true ]; then
    echo "Error: Failed to download required firmware files to /lib/firmware/." >&2
    exit 1
fi
echo "Firmware files present in /lib/firmware/."

echo "=== 3. Staging module source to ${SRC_DIR} ==="
mkdir -p "${SRC_DIR}"
# Copy files excluding git directory
tar --exclude='.git' -cf - . | tar -xf - -C "${SRC_DIR}"

echo "=== 4. Registering and building DKMS module ==="
dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true
dkms add -m "${MODULE}" -v "${VERSION}"
dkms build -m "${MODULE}" -v "${VERSION}"
dkms install -m "${MODULE}" -v "${VERSION}"

echo "=== 5. Reloading kernel drivers ==="
for mod in dvb_usb_dib0700 mn88472 tda18250; do
    if lsmod | grep -q "^${mod}[[:space:]]"; then
        if ! modprobe -r "$mod"; then
            echo "Error: Failed to unload kernel module '$mod' (tuner may be in use)." >&2
            echo "Stop any service using the tuner (e.g. denpa tuner-agent) or reboot to apply the new driver." >&2
            exit 1
        fi
    fi
done
modprobe dvb_usb_dib0700

echo "=== 6. Verification ==="
dkms status -m "${MODULE}"
if [ -d /dev/dvb/adapter0 ]; then
    echo "Success: /dev/dvb/adapter0 is available."
    ls -l /dev/dvb/adapter0/
else
    echo "Note: /dev/dvb/adapter0 not created yet. Please ensure the Xbox One Tuner is plugged in."
fi

echo "=== Installation complete ==="
