# SPDX-License-Identifier: GPL-2.0-only
PREFIX := riscv32-unknown-elf
CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -fdata-sections -ffunction-sections -Wl,--gc-sections -O2 -g
CFLAGS += -Wl,-z,max-page-size=4
CFLAGS += -march=rv32ima_zfinx_zicsr_zifencei -mabi=ilp32

APPNAME ?= fputests

.PHONY: all
all: ${APPNAME}.bin

vectors.h: gen.sh
	bash gen.sh

${APPNAME}.bin: ${APPNAME}.c vectors.h
	${CC} ${CFLAGS} -I ./ -o ${APPNAME}.elf ${APPNAME}.c
	${OBJCOPY} -O binary ${APPNAME}.elf $@
	chmod -x ${APPNAME}.elf $@
	$(OBJDUMP) -Sdrl ${APPNAME}.elf > ${APPNAME}.elf.objdump
	${READELF} -a ${APPNAME}.elf > ${APPNAME}.elf.readelf
	truncate --size=%4 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin > ${APPNAME}.32.hex # 32bits.
	truncate --size=%8 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > ${APPNAME}.64.hex # 64bits.

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf vectors.h
