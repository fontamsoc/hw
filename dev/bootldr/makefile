# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

ifeq ($(origin ARCH), undefined)
ARCH := pu32
endif

ifeq ($(origin PREFIX), undefined)
PREFIX := /opt/${ARCH}-toolchain
endif

CC := ${PREFIX}/bin/${ARCH}-elf-gcc
OBJCOPY := ${PREFIX}/bin/${ARCH}-elf-objcopy

CFLAGS := -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -Os -g3

.PHONY: all clean

all: bootldr16.hex bootldr32.hex bootldr64.hex  bootldr128.hex  bootldr256.hex

bootldr16.hex: bootldr.bin
	hexdump -v -e '/2 "%04x "' bootldr.bin > bootldr16.hex # 16bits.

bootldr32.hex: bootldr.bin
	hexdump -v -e '/4 "%08x "' bootldr.bin > bootldr32.hex # 32bits.

bootldr64.hex: bootldr.bin
	hexdump -v -e '/4 "%08x "' bootldr.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > bootldr64.hex # 64bits.

bootldr128.hex: bootldr.bin
	hexdump -v -e '/4 "%08x "' bootldr.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > bootldr128.hex # 128bits.

bootldr256.hex: bootldr.bin
	hexdump -v -e '/4 "%08x "' bootldr.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > bootldr256.hex # 256bits.

bootldr.bin: bootldr.lds bootldr.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o bootldr.elf bootldr.c -Wl,-Tbootldr.lds
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents bootldr.elf bootldr.bin
	chmod -x *.elf *.bin

clean:
	rm -rf *.elf *.bin *.hex
