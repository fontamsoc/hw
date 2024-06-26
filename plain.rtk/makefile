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
CFLAGS += -include crt0.h
CFLAGS += -include serial0.h
CFLAGS += -include stdio.h

.PHONY: clean

all: rtk32.hex rtk64.hex rtk128.hex rtk256.hex

rtk32.hex: rtk.bin
	hexdump -v -e '/4 "%08x "' rtk.bin > rtk32.hex # 32bits.

rtk64.hex: rtk.bin
	hexdump -v -e '/4 "%08x "' rtk.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > rtk64.hex # 64bits.

rtk128.hex: rtk.bin
	hexdump -v -e '/4 "%08x "' rtk.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > rtk128.hex # 128bits.

rtk256.hex: rtk.bin
	hexdump -v -e '/4 "%08x "' rtk.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > rtk256.hex # 256bits.

rtk.bin: rtk.lds rtk.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o rtk.elf rtk.c -Wl,-Trtk.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents rtk.elf rtk.bin

clean:
	rm -rf *.su *.elf *.bin *.hex
