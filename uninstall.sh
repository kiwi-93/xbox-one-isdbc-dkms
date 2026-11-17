#!/bin/bash
set -e

MODULE="xbox-one-isdbc"
VERSION="1.0.0"
SRC_DIR="/usr/src/${MODULE}-${VERSION}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root (e.g. sudo ./uninstall.sh)" >&2
    exit 1
fi

echo "=== 1. Removing DKMS module ==="
dkms remove -m "${MODULE}" -v "${VERSION}" --all 2>/dev/null || true

if [ -d "${SRC_DIR}" ]; then
    rm -rf "${SRC_DIR}"
fi

echo "=== 2. Reloading stock kernel drivers ==="
if lsmod | grep -q dvb_usb_dib0700; then
    modprobe -r dvb_usb_dib0700 mn88472 tda18250 2>/dev/null || true
fi
modprobe dvb_usb_dib0700

echo "=== Uninstallation complete ==="
