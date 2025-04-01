# SPDX-License-Identifier: GPL-2.0-only
# 20250110 (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -march=rv32ima_zicsr -ftls-model=local-exec
CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g

WORDBITSZ ?= 32

.PHONY: all
all: donut.hex

donut.hex: donut.${WORDBITSZ}.he_
	ln -nf $< $@

donut.16.he_: donut.bin
	truncate --size=%2 $<
	hexdump -v -e '/2 "%04x "' $< > $@ # 16bits.

donut.32.he_: donut.bin
	truncate --size=%4 $<
	hexdump -v -e '/4 "%08x "' $< > $@ # 32bits.

donut.64.he_: donut.bin
	truncate --size=%8 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > $@ # 64bits.

donut.128.he_: donut.bin
	truncate --size=%16 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > $@ # 128bits.

donut.256.he_: donut.bin
	truncate --size=%32 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > donut256.hex # 256bits.

donut.bin: donut.c
	${CC} ${CFLAGS} -I ./ -o donut.elf $<
	${OBJCOPY} -O binary donut.elf $@
	$(OBJDUMP) -Sdrl donut.elf > donut.elf.objdump
	${READELF} -a donut.elf > donut.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.he{_,x} *.objdump *.readelf
