# SPDX-License-Identifier: GPL-2.0-only
# 20250110 (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
#CFLAGS += -specs=nano.specs

XWORDBITSZ ?= 32

.PHONY: all
all: tinyraytracer.hex

tinyraytracer.hex: tinyraytracer.${XWORDBITSZ}.he_
	ln -nf $< $@

tinyraytracer.16.he_: tinyraytracer.bin
	truncate --size=%2 $<
	hexdump -v -e '/2 "%04x "' $< > $@ # 16bits.

tinyraytracer.32.he_: tinyraytracer.bin
	truncate --size=%4 $<
	hexdump -v -e '/4 "%08x "' $< > $@ # 32bits.

tinyraytracer.64.he_: tinyraytracer.bin
	truncate --size=%8 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > $@ # 64bits.

tinyraytracer.128.he_: tinyraytracer.bin
	truncate --size=%16 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > $@ # 128bits.

tinyraytracer.256.he_: tinyraytracer.bin
	truncate --size=%32 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > $@ # 256bits.

tinyraytracer.bin: tinyraytracer.c
	${CC} ${CFLAGS} -I ./ -o tinyraytracer.elf $< -lm
	${OBJCOPY} -O binary tinyraytracer.elf $@
	$(OBJDUMP) -Sdrl tinyraytracer.elf > tinyraytracer.elf.objdump
	${READELF} -a tinyraytracer.elf > tinyraytracer.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.he{_,x} *.objdump *.readelf
