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
CFLAGS += -fstack-usage

.PHONY: clean

all: dcacheinit32.hex dcacheinit64.hex dcacheinit128.hex dcacheinit256.hex

dcacheinit32.hex: dcacheinit.bin
	hexdump -v -e '/4 "%08x "' dcacheinit.bin > dcacheinit32.hex # 32bits.

dcacheinit64.hex: dcacheinit.bin
	hexdump -v -e '/4 "%08x "' dcacheinit.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > dcacheinit64.hex # 64bits.

dcacheinit128.hex: dcacheinit.bin
	hexdump -v -e '/4 "%08x "' dcacheinit.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > dcacheinit128.hex # 128bits.

dcacheinit256.hex: dcacheinit.bin
	hexdump -v -e '/4 "%08x "' dcacheinit.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > dcacheinit256.hex # 256bits.

dcacheinit.bin: dcacheinit.lds dcacheinit.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o dcacheinit.elf dcacheinit.c -Wl,-Tdcacheinit.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents dcacheinit.elf dcacheinit.bin

clean:
	rm -rf *.su *.elf *.bin *.hex
