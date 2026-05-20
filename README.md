# Fantech X9 Thor RGB Gaming Mouse Driver

This open-source driver, designed for Linux systems (also compatible with environments supporting GTK), enables enhanced control of the Fantech X9 Thor RGB gaming mouse.

### Requirements

Ensure you have the following prerequisites:

- Python 3
- `Gtk3` and `gobject-introspection` (check your distro's documentation)
- Python module: `pyusb` (install with `pip install pyusb`)

### Usage

Clone the repository:

```bash
git clone https://github.com/muharamdani/FantechX9ThorDriver.git
```

Run the driver frontend:

```bash
python3 driver_frontend.py
```

### Configuration

Check your mouse's product ID and vendor ID using `lsusb`. Modify `driver_backend.py` if different from defaults. Example:

```bash
Bus 001 Device 007: ID 18f8:0fc0 [Maxxter] USB GAMING MOUSE
```

Vendor ID: `18f8`, Product ID: `0fc0`

### USB Device Access

For proper USB device access:

1. Set UDEV rules (recommended method):

```bash
echo "SUBSYSTEMS==\"usb\", ATTRS{idVendor}==\"18f8\", ATTRS{idProduct}==\"0fc0\", GROUP=\"users\", MODE=\"0660\"" | sudo tee /etc/udev/rules.d/50-fantechdriver.rules
```

Ensure your system has a group named `users`, and your user is part of this group.

2. Alternative method (not recommended):

Run as root (not recommended for security reasons):

```bash
sudo python driver_frontend.py
```

### CLI Mode

Install the `mouse` command:

```bash
chmod +x install.sh && ./install.sh
```

The installer will prompt for your Vendor ID and Product ID (defaults: `18f8`/`0fc0`). Reboot after installation.

**Usage:**

```bash
mouse                    # DPI=2000, LED off
mouse -c red             # Set LED color
mouse -d 3200            # Set DPI
mouse -c blue -d 1600    # Set both
```

**Supported colors:** `red` `green` `blue` `yellow` `cyan` `violet` `white` `off`

**Supported DPIs:** 200, 400, 600, 800, 1000, 1200, 1600, 2000, 2400, 3200, 4000, 4800


**To uninstall:**

```bash
chmod +x uninstall.sh && ./uninstall.sh
```
---

### Configuration Persistence

The current configuration is saved in **driver.conf** upon pressing the "Save Configuration" button.

#### Preview:

![example](https://i.imgur.com/nSshQe8.png)

### License
This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
