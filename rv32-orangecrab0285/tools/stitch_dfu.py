#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# 20261014 (c) William Fonkou Tambe

# Stitch extra firmware into an OrangeCrab DFU image so that it lands at a
# chosen SPI flash address when flashed with:
# 	dfu-util --alt 0 -D combined.dfu
#
# The OrangeCrab bootloader writes alt 0 linearly from flash 0x80000 (byte N of
# the image goes to 0x80000 + N), so firmware meant for 0x200000 has to sit at
# image offset 0x180000. The gap after the bitstream is filled with 0xFF and the
# DFU suffix is rebuilt (keeping the original VID/PID).
#
# Usage:
# 	python3 stitch_dfu.py orangecrab0285.dfu firmware.bin -o combined.dfu
# 	python3 stitch_dfu.py orangecrab0285.dfu firmware.bin --addr 0x200000 -o combined.dfu

import argparse
import struct
import sys
import zlib

ALT_BASES = {0x080000: 0, 0x100000: 1} # OrangeCrab bootloader: flash base -> DFU alt
FLASH_MAX_ADDR = 0xF80000 # r0.2: 16 MiB - 512 KiB; bootloader refuses writes past this
DEFAULT_VID, DEFAULT_PID = 0x1209, 0x5AF0


# DFU suffix CRC: CRC-32 with init 0xFFFFFFFF and no final XOR.
def dfu_crc(data):
	return (zlib.crc32(data) ^ 0xFFFFFFFF)


# Return (payload, (bcdDevice, idProduct, idVendor, bcdDFU)) or (blob, None).
def split_suffix(blob):
	if len(blob) >= 16 and blob[-8:-5] == b"UFD":
		length = blob[-5]
		if 16 <= length <= len(blob):
			ids = struct.unpack("<HHHH", blob[-16:-8])
			if struct.unpack("<I", blob[-4:])[0] != dfu_crc(blob[:-4]):
				print("warning: DFU suffix CRC in input is wrong; stripping it anyway", file=sys.stderr)
			return blob[:-length], ids
	return blob, None


def add_suffix(payload, bcd_device, pid, vid, bcd_dfu=0x0100):
	body = (payload + struct.pack("<HHHH3sB", bcd_device, pid, vid, bcd_dfu, b"UFD", 16))
	return (body + struct.pack("<I", dfu_crc(body)))


# An integer in any base Python accepts, ie: 0x200000.
def hexint(s):
	return int(s, 0)


def main():
	ap = argparse.ArgumentParser(description="Append firmware to a DFU image at a given flash address.")
	ap.add_argument("image", help="existing .dfu (or raw .bit) that dfu-util writes at --base")
	ap.add_argument("firmware", help="raw binary to place at --addr")
	ap.add_argument("-o", "--output", required=True, help="output .dfu")
	ap.add_argument("--addr", type=hexint, default=0x200000,
		help="flash address for the firmware (default 0x200000)")
	ap.add_argument("--base", type=hexint, default=0x080000,
		help="flash address the DFU alt starts at (alt 0 = 0x80000)")
	args = ap.parse_args()

	try:
		with open(args.image, "rb") as f:
			gateware, ids = split_suffix(f.read())
		with open(args.firmware, "rb") as f:
			firmware = f.read()

		offset = (args.addr - args.base)
		gw_end = (args.base + len(gateware))
		fw_end = (args.addr + len(firmware))
		if offset < 0:
			sys.exit("error: --addr %#x is below --base %#x" % (args.addr, args.base))
		if gw_end > args.addr:
			sys.exit("error: image is %#x bytes and runs to %#x, past %#x; "
				"it must be at most %#x bytes (try ecppack --compress)"
				% (len(gateware), gw_end, args.addr, offset))
		if fw_end > FLASH_MAX_ADDR:
			sys.exit("error: firmware would end at %#x; the bootloader stops at %#x" % (fw_end, FLASH_MAX_ADDR))

		payload = (gateware + (b"\xff" * (offset - len(gateware))) + firmware)

		if ids is None:
			print("note: input has no DFU suffix; using VID:PID %04x:%04x" % (DEFAULT_VID, DEFAULT_PID),
				file=sys.stderr)
			ids = (0xFFFF, DEFAULT_PID, DEFAULT_VID, 0x0100)
		with open(args.output, "wb") as f:
			f.write(add_suffix(payload, *ids))

		print("%#08x-%#08x  %s (%d bytes)" % (args.base, gw_end, args.image, len(gateware)))
		print("%#08x-%#08x  0xFF padding (%d bytes)" % (gw_end, args.addr, (offset - len(gateware))))
		print("%#08x-%#08x  %s (%d bytes)" % (args.addr, fw_end, args.firmware, len(firmware)))
		print("VID:PID %04x:%04x  ->  %s" % (ids[2], ids[1], args.output))
		alt = ALT_BASES.get(args.base)
		if alt is not None:
			print("flash with: dfu-util --alt %d -D %s" % (alt, args.output))
	except OSError as e:
		sys.exit("error: %s%s" % ((("%s: " % e.filename) if e.filename else ""), e.strerror))


if __name__ == "__main__":
	main()
