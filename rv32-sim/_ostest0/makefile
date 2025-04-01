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
all: _ostest016.hex _ostest032.hex _ostest064.hex  _ostest0128.hex  _ostest0256.hex

_ostest016.hex: _ostest0.bin
	truncate --size=%2 _ostest0.bin
	hexdump -v -e '/2 "%04x "' _ostest0.bin > _ostest016.hex # 16bits.

_ostest032.hex: _ostest0.bin
	truncate --size=%4 _ostest0.bin
	hexdump -v -e '/4 "%08x "' _ostest0.bin > _ostest032.hex # 32bits.

_ostest064.hex: _ostest0.bin
	truncate --size=%8 _ostest0.bin
	hexdump -v -e '/4 "%08x "' _ostest0.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > _ostest064.hex # 64bits.

_ostest0128.hex: _ostest0.bin
	truncate --size=%16 _ostest0.bin
	hexdump -v -e '/4 "%08x "' _ostest0.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > _ostest0128.hex # 128bits.

_ostest0256.hex: _ostest0.bin
	truncate --size=%32 _ostest0.bin
	hexdump -v -e '/4 "%08x "' _ostest0.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > _ostest0256.hex # 256bits.

_ostest0.bin: _ostest0.c
	${CC} ${CFLAGS} -I ./ -o _ostest0.elf _ostest0.c
	${OBJCOPY} -O binary _ostest0.elf _ostest0.bin
	$(OBJDUMP) -Sdrl _ostest0.elf > _ostest0.elf.objdump
	${READELF} -a _ostest0.elf > _ostest0.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf
