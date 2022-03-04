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

smem.hex: smem.lds smem.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o smem.elf smem.c -Wl,-Tsmem.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents smem.elf smem.bin
	hexdump -v -e '/4 "%08x "' smem.bin > smem.hex # 32bits.

clean:
	rm -rf *.su smem.elf smem.bin smem.hex
