#!/usr/bin/env python3

import usb.core
import usb.util
import argparse
import sys

# Default vendor/product IDs — replaced at build time by install.sh
VENDOR_ID = 0x18f8
PRODUCT_ID = 0x0fc0


class MouseDriver:
    def __init__(self):
        self.x9_vendorid = VENDOR_ID
        self.x9_productid = PRODUCT_ID
        self.bmRequestType = 0x21
        self.bRequest = 0x09
        self.wValue = 0x0307
        self.wIndex = 0x0001
        self.mouse = None
        self.conquered = False
        self.device_busy = bool()
        self.current_active_profile = 1
        self.profile_states = [1, 1, 1, 1, 1, 1]
        self.supported_dpis = [200, 400, 600, 800, 1000, 1200, 1600,
                               2000, 2400, 3200, 4000, 4800]
        self.cyclic_colors = {
            "Yellow": 1, "Blue": 1, "Violet": 1,
            "Green": 1, "Red": 1, "Cyan": 1, "White": 1,
        }
        self.supported_colors = {
            "red":    (255, 0, 0),
            "green":  (0, 255, 0),
            "blue":   (0, 0, 255),
            "yellow": (255, 255, 0),
            "cyan":   (0, 255, 255),
            "violet": (255, 0, 255),
            "white":  (255, 255, 255),
        }

    def find_device(self):
        self.mouse = usb.core.find(idVendor=self.x9_vendorid, idProduct=self.x9_productid)

    def device_state(self):
        try:
            self.device_busy = self.mouse.is_kernel_driver_active(self.wIndex)
        except usb.core.USBError as e:
            if e.errno == 13:
                print("Permission denied. Add a udev rule or run with sudo.")
            else:
                print(e.strerror)
            return -1
        except AttributeError:
            print(f"Device not found "
                  f"(VID: 0x{self.x9_vendorid:04x}, PID: 0x{self.x9_productid:04x}).")
            print("Try replugging the mouse. Check connected USB devices with: lsusb")
            return -2
        return 1

    def conquer(self):
        if self.device_busy and not self.conquered:
            self.mouse.detach_kernel_driver(self.wIndex)
            usb.util.claim_interface(self.mouse, self.wIndex)
            self.conquered = True

    def liberate(self):
        if self.conquered:
            try:
                usb.util.release_interface(self.mouse, self.wIndex)
                self.mouse.attach_kernel_driver(self.wIndex)
                self.conquered = False
            except Exception:
                print("Failed to release device back to kernel.")

    def _init_payload(self, instruction_code):
        return [0x07, instruction_code]

    def _add_zero_bytes(self, payload, count):
        payload.extend([0x00] * count)

    def _set_cyclic_colors(self):
        keys = list(self.cyclic_colors.keys())
        return sum(self.cyclic_colors[k] * (2 ** i) for i, k in enumerate(keys))

    def _set_active_profiles(self):
        return sum(self.profile_states[i] * (2 ** i) for i in range(6))

    def find_closest_dpi(self, dpi):
        if dpi in self.supported_dpis:
            return dpi
        return min(self.supported_dpis, key=lambda x: abs(x - dpi))

    def _dpi_to_internal(self, dpi):
        dpi_map = {
            200: 1, 400: 2, 600: 3, 800: 4, 1000: 5, 1200: 6,
            1600: 7, 2000: 9, 2400: 0xb, 3200: 0xd, 4000: 0xe, 4800: 0xf,
        }
        return dpi_map.get(self.find_closest_dpi(dpi), 0)

    def create_dpi_profile_config(self, dpi, profile_slot=1):
        payload = self._init_payload(0x09)
        payload.append(0x40 - 1 + self.current_active_profile)
        internal_dpi = self._dpi_to_internal(dpi)
        payload.append((internal_dpi * 16) + (profile_slot + 7))
        payload.append(self._set_active_profiles())
        self._add_zero_bytes(payload, 3)
        return payload

    def create_color_profile_config(self, profile, red, green, blue):
        payload = self._init_payload(0x14)
        internal_profile = (profile - 1) * 2
        ir = int((255 - red) / 16)
        ig = int((255 - green) / 16)
        ib = int((255 - blue) / 16)
        payload.append(internal_profile * 16 + ig)
        payload.append(ir * 16 + ib)
        payload.append(self._set_active_profiles())
        self._add_zero_bytes(payload, 3)
        return payload

    def create_rgb_lights_config(self, scheme, time_duration=1):
        payload = self._init_payload(0x13)
        payload.append(self._set_cyclic_colors())
        scheme_map = {
            "Fixed":  0x86 - time_duration,
            "Cyclic": 0x96 - time_duration,
            "Static": 0x86,
            "Off":    0x87,
        }
        payload.append(scheme_map.get(scheme, 0x87))
        self._add_zero_bytes(payload, 4)
        return payload

    def send(self, payload):
        self.mouse.ctrl_transfer(
            self.bmRequestType, self.bRequest,
            self.wValue, self.wIndex, payload,
        )


def main():
    parser = argparse.ArgumentParser(
        prog="mouse",
        description="Configure Fantech X9 Thor gaming mouse LED and DPI",
        epilog=(
            "Examples:\n"
            "  mouse                   # default: DPI=2000, LED off\n"
            "  mouse -c red            # red LED\n"
            "  mouse -d 3200           # set DPI to 3200\n"
            "  mouse -c blue -d 1600   # blue LED + DPI 1600"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-c", "--color",
        type=str,
        metavar="COLOR",
        help="LED color: red, green, blue, yellow, cyan, violet, white, off",
    )
    parser.add_argument(
        "-d", "--dpi",
        type=int,
        metavar="DPI",
        help="DPI (200–4800; nearest supported value used)",
    )

    args = parser.parse_args()

    # No args → use defaults
    if args.color is None and args.dpi is None:
        args.dpi = 2000
        args.color = "off"

    driver = MouseDriver()
    driver.find_device()

    status = driver.device_state()
    if status != 1:
        sys.exit(1)

    driver.conquer()
    exit_code = 0
    try:
        if args.dpi is not None:
            payload = driver.create_dpi_profile_config(args.dpi, 1)
            driver.send(payload)
            actual = driver.find_closest_dpi(args.dpi)
            msg = f"DPI set to {actual}"
            if actual != args.dpi:
                msg += f" (closest to requested {args.dpi})"
            print(msg)

        if args.color is not None:
            color = args.color.lower()
            if color == "off":
                driver.send(driver.create_rgb_lights_config("Off"))
                print("LED turned off")
            elif color in driver.supported_colors:
                r, g, b = driver.supported_colors[color]
                driver.send(driver.create_color_profile_config(1, r, g, b))
                driver.send(driver.create_rgb_lights_config("Static"))
                print(f"LED color set to {color}")
            else:
                print(f"Unsupported color: '{color}'")
                print("Supported colors: " + ", ".join(driver.supported_colors) + ", off")
                exit_code = 1
    except Exception as e:
        print(f"Error configuring mouse: {e}")
        exit_code = 1
    finally:
        driver.liberate()

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
