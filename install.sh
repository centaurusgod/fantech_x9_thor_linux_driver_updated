#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────
#  Fantech X9 Thor Mouse Driver – Installer
# ─────────────────────────────────────────────────
DEFAULT_VENDOR_ID="18f8"
DEFAULT_PRODUCT_ID="0fc0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/set_mouse_config.py"

echo ""
echo "════════════════════════════════════════════════"
echo "   Fantech X9 Thor Mouse Driver  ─  Installer"
echo "════════════════════════════════════════════════"
echo ""

# ── Help text for users who don't know their IDs ──────────────────────────────
echo "To find your mouse's Vendor ID and Product ID, run:"
echo ""
echo "    lsusb"
echo ""
echo "and look for your mouse in the list. Example line:"
echo ""
echo "    Bus 001 Device 007: ID 18f8:0fc0 [Maxxter] USB GAMING MOUSE"
echo "                           ↑↑↑↑ ↑↑↑↑"
echo "               Vendor ID ──┘    └── Product ID"
echo ""
echo "Press Enter to use the default value shown in [brackets]."
echo ""

# ── Prompt for Vendor ID ──────────────────────────────────────────────────────
read -rp "Enter Vendor ID   [default: ${DEFAULT_VENDOR_ID}]: " input_vendor
VENDOR_ID="${input_vendor:-$DEFAULT_VENDOR_ID}"
VENDOR_ID="${VENDOR_ID,,}"   # normalise to lowercase

# ── Prompt for Product ID ─────────────────────────────────────────────────────
read -rp "Enter Product ID  [default: ${DEFAULT_PRODUCT_ID}]: " input_product
PRODUCT_ID="${input_product:-$DEFAULT_PRODUCT_ID}"
PRODUCT_ID="${PRODUCT_ID,,}"

echo ""
echo "  Vendor ID  : 0x${VENDOR_ID}"
echo "  Product ID : 0x${PRODUCT_ID}"
echo ""

# ─────────────────────────────────────────────────
# Step 1 – Verify prerequisites
# ─────────────────────────────────────────────────
echo "[1/5] Checking prerequisites..."

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but was not found."
    echo "Install it with your package manager (e.g. sudo apt install python3)"
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "      python3 ${PYTHON_VERSION} found: $(command -v python3)"

# Ensure python3-venv / ensurepip are available (needed to create the build venv)
if ! python3 -c "import ensurepip" &>/dev/null 2>&1; then
    echo "      python3-venv not found – installing..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y "python${PYTHON_VERSION}-venv" 2>/dev/null \
            || sudo apt-get install -y python3-venv
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 python3-virtualenv
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm python
    else
        echo "Error: cannot install python3-venv automatically."
        echo "Please install it manually and re-run this script."
        exit 1
    fi
fi

# Check for libusb (runtime dependency of pyusb – not bundled by PyInstaller)
LIBUSB_FOUND=false
if python3 -c "import ctypes; ctypes.CDLL('libusb-1.0.so.0')" &>/dev/null 2>&1; then
    LIBUSB_FOUND=true
elif ldconfig -p 2>/dev/null | grep -q "libusb-1\.0\.so"; then
    LIBUSB_FOUND=true
fi

if [ "$LIBUSB_FOUND" = false ]; then
    echo ""
    echo "  WARNING: libusb-1.0 does not appear to be installed."
    echo "  pyusb needs it at runtime. Install with:"
    echo "    Ubuntu/Debian : sudo apt install libusb-1.0-0"
    echo "    Arch Linux    : sudo pacman -S libusb"
    echo "    Fedora/RHEL   : sudo dnf install libusb1"
    echo ""
fi

# ─────────────────────────────────────────────────
# Step 2 – Create isolated build environment
# ─────────────────────────────────────────────────
echo "[2/5] Setting up build environment..."

BUILD_ENV="/tmp/mouse_build_env_$$"
python3 -m venv "$BUILD_ENV"

"$BUILD_ENV/bin/pip" install --quiet --upgrade pip
"$BUILD_ENV/bin/pip" install --quiet pyusb pyinstaller

echo "      Build environment ready."

# ─────────────────────────────────────────────────
# Step 3 – Patch source with user-supplied IDs and compile
# ─────────────────────────────────────────────────
echo "[3/5] Building binary..."

BUILD_SRC="/tmp/mouse_cli_$$.py"
BUILD_DIST="/tmp/mouse_dist_$$"
BUILD_WORK="/tmp/mouse_work_$$"
BUILD_SPEC="/tmp/mouse_spec_$$"

# Copy source and embed the user-supplied IDs
cp "$SOURCE_FILE" "$BUILD_SRC"
sed -i "s/^VENDOR_ID = 0x[0-9a-fA-F]*/VENDOR_ID = 0x${VENDOR_ID}/" "$BUILD_SRC"
sed -i "s/^PRODUCT_ID = 0x[0-9a-fA-F]*/PRODUCT_ID = 0x${PRODUCT_ID}/" "$BUILD_SRC"

# Verify substitution worked
if ! grep -q "VENDOR_ID = 0x${VENDOR_ID}" "$BUILD_SRC"; then
    echo "Error: failed to embed Vendor ID into source. Aborting."
    exit 1
fi
if ! grep -q "PRODUCT_ID = 0x${PRODUCT_ID}" "$BUILD_SRC"; then
    echo "Error: failed to embed Product ID into source. Aborting."
    exit 1
fi

"$BUILD_ENV/bin/pyinstaller" \
    --onefile \
    --name mouse \
    --distpath "$BUILD_DIST" \
    --workpath "$BUILD_WORK" \
    --specpath "$BUILD_SPEC" \
    --clean \
    --log-level WARN \
    "$BUILD_SRC"

echo "      Binary built successfully."

# ─────────────────────────────────────────────────
# Step 4 – Install binary to /usr/local/bin
# ─────────────────────────────────────────────────
echo "[4/5] Installing to /usr/local/bin/mouse..."

sudo install -m 0755 "$BUILD_DIST/mouse" /usr/local/bin/mouse

# Verify the binary is accessible
if ! command -v mouse &>/dev/null; then
    echo "Warning: 'mouse' was installed to /usr/local/bin but is not yet in PATH."
    echo "  Make sure /usr/local/bin is in your PATH, or start a new shell session."
fi

echo "      Installed: $(command -v mouse 2>/dev/null || echo '/usr/local/bin/mouse')"

# Clean up build artifacts
rm -rf "$BUILD_ENV" "$BUILD_SRC" "$BUILD_DIST" "$BUILD_WORK" "$BUILD_SPEC"

# ─────────────────────────────────────────────────
# Step 5 – udev rules and user group
# ─────────────────────────────────────────────────
echo "[5/5] Setting up udev rules..."

UDEV_RULE="SUBSYSTEMS==\"usb\", ATTRS{idVendor}==\"${VENDOR_ID}\", ATTRS{idProduct}==\"${PRODUCT_ID}\", GROUP=\"users\", MODE=\"0660\""

# Ensure the 'users' group exists
if ! getent group users &>/dev/null; then
    echo "      Creating 'users' group..."
    sudo groupadd users
fi

sudo usermod -aG users "$USER"

echo "$UDEV_RULE" | sudo tee /etc/udev/rules.d/50-fantechdriver.rules > /dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "      udev rule installed: /etc/udev/rules.d/50-fantechdriver.rules"

# ─────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
echo "   Installation complete!"
echo "════════════════════════════════════════════════"
echo ""
echo "Usage:"
echo "  mouse                      # DPI=2000, LED off (defaults)"
echo "  mouse -c red               # Red LED"
echo "  mouse -d 3200              # Set DPI to 3200"
echo "  mouse -c red -d 3000       # Red LED + DPI 3000"
echo "  mouse --help               # Show all options"
echo ""
echo "Supported colors : red, green, blue, yellow, cyan, violet, white, off"
echo "Supported DPIs   : 200 400 600 800 1000 1200 1600 2000 2400 3200 4000 4800"
echo ""
echo "⚠  Please log out and back in (or reboot) for group membership to take"
echo "   effect, then run 'mouse' without sudo."
echo ""
