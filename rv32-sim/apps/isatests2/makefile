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
TESTS += mcsr
TESTS += scsr
TESTS += mfetch_misaligned
TESTS += sfetch_misaligned
TESTS += ma_addr
TESTS += lh_misaligned
TESTS += lw_misaligned
TESTS += sh_misaligned
TESTS += sw_misaligned

TESTS_OBJS = $(addsuffix .o,${TESTS})

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
CFLAGS += -nostdlib
# Below used to make stvec_handler and mtvec_handler null when not used by a test;
# Making stvec_handler and mtvec_handler weak symbols does not work because they become global
# but they need to be local to each test.
CFLAGS += -Wl,--unresolved-symbols=ignore-all

APPNAME := isatests2

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

%.o : tests/%.S
	${CC} ${CFLAGS} -I ./tests/ -c -o $@ \
		-DTEST_FUNC_NAME=$* -DTEST_FUNC_TXT='"$*"' -DTEST_FUNC_RET=$*_ret $<

${APPNAME}.bin: ${APPNAME}.S ${TESTS_OBJS}
	${CC} ${CFLAGS} -I ./ -o ${APPNAME}.elf -Wl,-T${APPNAME}.lds $^
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents ${APPNAME}.elf $@
	$(OBJDUMP) -Sdrl ${APPNAME}.elf > ${APPNAME}.elf.objdump
	${READELF} -a ${APPNAME}.elf > ${APPNAME}.elf.readelf

.PHONY: clean
clean:
	rm -rf *.o *.elf *.bin *.hex *.objdump *.readelf
