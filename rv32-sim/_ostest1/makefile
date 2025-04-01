# SPDX-License-Identifier: GPL-2.0-only
# 20250110 (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -march=rv32ima_zicsr -ftls-model=local-exec
CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g

.PHONY: all
all: _ostest116.hex _ostest132.hex _ostest164.hex  _ostest1128.hex  _ostest1256.hex

_ostest116.hex: _ostest1.bin
	truncate --size=%2 _ostest1.bin
	hexdump -v -e '/2 "%04x "' _ostest1.bin > _ostest116.hex # 16bits.

_ostest132.hex: _ostest1.bin
	truncate --size=%4 _ostest1.bin
	hexdump -v -e '/4 "%08x "' _ostest1.bin > _ostest132.hex # 32bits.

_ostest164.hex: _ostest1.bin
	truncate --size=%8 _ostest1.bin
	hexdump -v -e '/4 "%08x "' _ostest1.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > _ostest164.hex # 64bits.

_ostest1128.hex: _ostest1.bin
	truncate --size=%16 _ostest1.bin
	hexdump -v -e '/4 "%08x "' _ostest1.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > _ostest1128.hex # 128bits.

_ostest1256.hex: _ostest1.bin
	truncate --size=%32 _ostest1.bin
	hexdump -v -e '/4 "%08x "' _ostest1.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > _ostest1256.hex # 256bits.

_ostest1.bin: _ostest1.c
	${CC} ${CFLAGS} -I ./ -o _ostest1.elf _ostest1.c
	${OBJCOPY} -O binary _ostest1.elf _ostest1.bin
	$(OBJDUMP) -Sdrl _ostest1.elf > _ostest1.elf.objdump
	${READELF} -a _ostest1.elf > _ostest1.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf
