#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# 20261012 (c) William Fonkou Tambe

# Format data as apps/bootldr expects it at the word BOOTLDR_FIRSTU32 of its
# storage, the SPI flash or an SD card. The data, typically the .bin of an app
# linked at 0x1000, ie: rv32-sim/apps/helloworld/helloworld.bin, becomes the
# payload which apps/bootldr loads to 0x1000, then starts by a system reset.
# The words of the result, little-endian, are as follow:
# 	word 0: the signature 0x52444c42, ie: the bytes "BLDR";
# 	word 1: n, the count of words of the payload, at least 1;
# 	words 2 to n+1: the payload, ie: the data padded with null bytes
# 	to a multiple of 4 bytes;
# 	word n+2: the CRC32 of the 4*n bytes of the payload, that of zlib.
#
# The data is read from the file given, else from stdin; the result is written
# to the file given with -o, else to stdout. The result is then to be written
# at the byte (4*BOOTLDR_FIRSTU32) of the storage, ie: using dd for an SD card,
# or using the flash programmer of Vivado for the configuration flash, the
# result being named *.bldr.bin, which write_cfgmem takes as raw data.
#
# Usage:
# 	tools/mkBootldrDat.py -o app.bldr.bin app.bin
# 	tools/mkBootldrDat.py < app.bin > app.bldr.bin
# Writing it to an SD card partitioned using an MBR, either at the block 1, in
# the gap before the first partition, ie: BOOTLDR_FIRSTU32=128, or at the
# beginning of its second partition, ie: BOOTLDR_FIRSTU32=-1:
# 	sudo dd if=app.bldr.bin of=/dev/sdX bs=512 seek=1 conv=fsync
# 	sudo dd if=app.bldr.bin of=/dev/sdX2 conv=fsync

import argparse
import struct
import sys
import zlib

SIGNATURE = 0x52444c42 # The bytes "BLDR" read as a little-endian word.


def main():
	p = argparse.ArgumentParser(
		description="format data as apps/bootldr loads it")
	p.add_argument("-o", metavar="path/to/file",
		help="file to write the result to (default: stdout)")
	p.add_argument("path", nargs="?", metavar="path/to/file",
		help="file to read the data from (default: stdin)")
	args = p.parse_args()

	try:
		if args.path is None:
			data = sys.stdin.buffer.read()
		else:
			with open(args.path, "rb") as f:
				data = f.read()
		if not data:
			sys.exit("mkBootldrDat.py: no data")

		payload = (data + bytes(-len(data) % 4))
		out = (struct.pack("<II", SIGNATURE, (len(payload) // 4)) + payload +
			struct.pack("<I", zlib.crc32(payload)))

		if args.o is None:
			sys.stdout.buffer.write(out)
			sys.stdout.buffer.flush()
		else:
			with open(args.o, "wb") as f:
				f.write(out)
	except OSError as e:
		sys.exit("mkBootldrDat.py: %s%s" % ((("%s: " % e.filename) if e.filename else ""), e.strerror))


if __name__ == "__main__":
	main()
