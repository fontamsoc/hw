# SPDX-License-Identifier: GPL-2.0-only
# 20251224 (c) William Fonkou Tambe

TESTS += simple
TESTS += addi
TESTS += add
TESTS += andi
TESTS += and
TESTS += auipc
TESTS += beq
TESTS += bge
TESTS += bgeu
TESTS += blt
TESTS += bltu
TESTS += bne
TESTS += div
TESTS += divu
TESTS += jalr
TESTS += jal
TESTS += j
TESTS += lb
TESTS += lbu
TESTS += lh
TESTS += lhu
TESTS += lui
TESTS += lw
TESTS += mulh
TESTS += mulhsu
TESTS += mulhu
TESTS += mul
TESTS += ori
TESTS += or
TESTS += rem
TESTS += remu
TESTS += sb
TESTS += sh
TESTS += slli
TESTS += sll
TESTS += slti
TESTS += slt
TESTS += srai
TESTS += sra
TESTS += srli
TESTS += srl
TESTS += sub
TESTS += sw
TESTS += xori
TESTS += xor
TESTS += sh1add
TESTS += sh2add
TESTS += sh3add
TESTS += amoswap_w
TESTS += amoadd_w
TESTS += amoand_w
TESTS += amoor_w
TESTS += amoxor_w
TESTS += amomin_w
TESTS += amomax_w
TESTS += amominu_w
TESTS += amomaxu_w
TESTS += lrsc

TESTS_OBJS = $(addsuffix .o,${TESTS})

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
CFLAGS += -nostdlib
CFLAGS += -march=rv32ima_zba_zicsr_zifencei

APPNAME := isatests

.PHONY: all
all: ${APPNAME}.bin

%.o : tests/%.S
	${CC} ${CFLAGS} -I ./tests/ -c -o $@ \
		-DTEST_FUNC_NAME=$* -DTEST_FUNC_TXT='"$*"' -DTEST_FUNC_RET=$*_ret $<

${APPNAME}.bin: ${APPNAME}.S ${TESTS_OBJS}
	${CC} ${CFLAGS} -I ./ -o ${APPNAME}.elf -Wl,-T${APPNAME}.lds $^
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents ${APPNAME}.elf $@
	chmod -x ${APPNAME}.elf $@
	$(OBJDUMP) -Sdrl ${APPNAME}.elf > ${APPNAME}.elf.objdump
	${READELF} -a ${APPNAME}.elf > ${APPNAME}.elf.readelf
	#truncate --size=%2 ${APPNAME}.bin
	#hexdump -v -e '/2 "%04x "' ${APPNAME}.bin > ${APPNAME}.16.hex # 16bits.
	truncate --size=%4 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin > ${APPNAME}.32.hex # 32bits.
	truncate --size=%8 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > ${APPNAME}.64.hex # 64bits.
	truncate --size=%16 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > ${APPNAME}.128.hex # 128bits.
	truncate --size=%32 ${APPNAME}.bin
	hexdump -v -e '/4 "%08x "' ${APPNAME}.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > ${APPNAME}.256.hex # 256bits.

.PHONY: clean
clean:
	rm -rf *.o *.elf *.bin *.hex *.objdump *.readelf
