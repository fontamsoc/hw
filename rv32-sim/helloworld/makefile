# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS := -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
CFLAGS += -ftls-model=local-exec

.PHONY: all
all: helloworld16.hex helloworld32.hex helloworld64.hex  helloworld128.hex  helloworld256.hex

helloworld16.hex: helloworld.bin
	truncate --size=%2 helloworld.bin
	hexdump -v -e '/2 "%04x "' helloworld.bin > helloworld16.hex # 16bits.

helloworld32.hex: helloworld.bin
	truncate --size=%4 helloworld.bin
	hexdump -v -e '/4 "%08x "' helloworld.bin > helloworld32.hex # 32bits.

helloworld64.hex: helloworld.bin
	truncate --size=%8 helloworld.bin
	hexdump -v -e '/4 "%08x "' helloworld.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > helloworld64.hex # 64bits.

helloworld128.hex: helloworld.bin
	truncate --size=%16 helloworld.bin
	hexdump -v -e '/4 "%08x "' helloworld.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > helloworld128.hex # 128bits.

helloworld256.hex: helloworld.bin
	truncate --size=%32 helloworld.bin
	hexdump -v -e '/4 "%08x "' helloworld.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > helloworld256.hex # 256bits.

helloworld.bin: helloworld.c
	${CC} ${CFLAGS} -I ./ -o helloworld.elf helloworld.c
	${OBJCOPY} -O binary helloworld.elf helloworld.bin
	$(OBJDUMP) -Sdrl helloworld.elf > helloworld.elf.objdump
	${READELF} -a helloworld.elf > helloworld.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf
