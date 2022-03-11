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

litedram.hex: litedram.lds litedram.c
	${CC} -nostdlib -I. ${CFLAGS} -o litedram.elf litedram.c -Wl,-Tlitedram.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents litedram.elf litedram.bin
	chmod -x litedram.elf litedram.bin
	hexdump -v -e '/4 "%08x "' litedram.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > litedram.hex

clean:
	rm -rf *.su litedram.elf litedram.bin litedram.hex
