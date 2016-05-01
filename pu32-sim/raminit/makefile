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

raminit.hex: raminit.lds raminit.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o raminit.elf raminit.c -Wl,-Traminit.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents raminit.elf raminit.bin
	#hexdump -v -e '/4 "%08x "' raminit.bin | \
	#	{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > raminit.hex # 64bits.
	hexdump -v -e '/4 "%08x "' raminit.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > raminit.hex # 128bits.

clean:
	rm -rf *.su raminit.elf raminit.bin raminit.hex
