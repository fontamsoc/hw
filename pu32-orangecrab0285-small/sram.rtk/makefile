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

#rtk.hex: rtk.bin
#	hexdump -v -e '/4 "%08x "' rtk.bin > rtk.hex # 32bits.
#	#hexdump -v -e '/4 "%08x "' rtk.bin | \
#	#	{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > rtk.hex # 64bits.
#	#hexdump -v -e '/4 "%08x "' rtk.bin | \
#	#	{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > rtk.hex # 128bits.

rtk.bin: rtk.lds rtk.c
	${CC} -nostdlib -I ./ ${CFLAGS} -o rtk.elf rtk.c -Wl,-Trtk.lds
	@echo ==== Stack Usage ====
	@cat *.su
	@echo =====================
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents rtk.elf rtk.bin

clean:
	rm -rf *.su rtk.elf rtk.bin
	#rm -rf rtk.hex
