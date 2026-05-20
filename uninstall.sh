#!/usr/bin/env bash
set -euo pipefail

echo "Removing Fantech X9 Thor mouse driver..."

# Define file paths
DRIVER_BIN="/usr/local/bin/mouse"
UDEV_RULE="/etc/udev/rules.d/50-fantechdriver.rules"

# Check if either file exists
if [ -f "$DRIVER_BIN" ] || [ -f "$UDEV_RULE" ]; then
    sudo rm -f "$DRIVER_BIN"
    sudo rm -f "$UDEV_RULE"
    
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "Driver components removed successfully."
else
    echo "Driver does not appear to be installed (files not found)."
fi

echo "Done. You may want to remove yourself from the 'users' group manually if needed:"
echo "  sudo gpasswd -d $USER users"
