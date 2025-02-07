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
all: _ostest216.hex _ostest232.hex _ostest264.hex  _ostest2128.hex  _ostest2256.hex

_ostest216.hex: _ostest2.bin
	truncate --size=%2 _ostest2.bin
	hexdump -v -e '/2 "%04x "' _ostest2.bin > _ostest216.hex # 16bits.

_ostest232.hex: _ostest2.bin
	truncate --size=%4 _ostest2.bin
	hexdump -v -e '/4 "%08x "' _ostest2.bin > _ostest232.hex # 32bits.

_ostest264.hex: _ostest2.bin
	truncate --size=%8 _ostest2.bin
	hexdump -v -e '/4 "%08x "' _ostest2.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > _ostest264.hex # 64bits.

_ostest2128.hex: _ostest2.bin
	truncate --size=%16 _ostest2.bin
	hexdump -v -e '/4 "%08x "' _ostest2.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > _ostest2128.hex # 128bits.

_ostest2256.hex: _ostest2.bin
	truncate --size=%32 _ostest2.bin
	hexdump -v -e '/4 "%08x "' _ostest2.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > _ostest2256.hex # 256bits.

_ostest2.bin: _ostest2.c
	${CC} ${CFLAGS} -I ./ -o _ostest2.elf _ostest2.c
	${OBJCOPY} -O binary _ostest2.elf _ostest2.bin
	$(OBJDUMP) -Sdrl _ostest2.elf > _ostest2.elf.objdump
	${READELF} -a _ostest2.elf > _ostest2.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf
