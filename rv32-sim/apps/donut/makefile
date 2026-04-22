# SPDX-License-Identifier: GPL-2.0-only
# 20251224 (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
#CFLAGS += -specs=nano.specs
CFLAGS += -Wl,-z,max-page-size=4

APPNAME := donut

.PHONY: all
all: ${APPNAME}.32.hex ${APPNAME}.64.hex ${APPNAME}.128.hex ${APPNAME}.256.hex

#${APPNAME}.16.hex: ${APPNAME}.bin
#	truncate --size=%2 $<
#	hexdump -v -e '/2 "%04x "' $< > $@ # 16bits.

${APPNAME}.32.hex: ${APPNAME}.bin
	truncate --size=%4 $<
	hexdump -v -e '/4 "%08x "' $< > $@ # 32bits.

${APPNAME}.64.hex: ${APPNAME}.bin
	truncate --size=%8 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > $@ # 64bits.

${APPNAME}.128.hex: ${APPNAME}.bin
	truncate --size=%16 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > $@ # 128bits.

${APPNAME}.256.hex: ${APPNAME}.bin
	truncate --size=%32 $<
	hexdump -v -e '/4 "%08x "' $< | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > $@ # 256bits.

${APPNAME}.bin: ${APPNAME}.c
	${CC} ${CFLAGS} -I ./ -o ${APPNAME}.elf $<
	${OBJCOPY} -O binary ${APPNAME}.elf $@
	chmod -x ${APPNAME}.elf $@
	$(OBJDUMP) -Sdrl ${APPNAME}.elf > ${APPNAME}.elf.objdump
	${READELF} -a ${APPNAME}.elf > ${APPNAME}.elf.readelf

.PHONY: clean
clean:
	rm -rf *.su *.elf *.bin *.hex *.objdump *.readelf
