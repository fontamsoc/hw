# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS := -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
CFLAGS += -march=rv32ima_zicsr -mabi=ilp32
CFLAGS += -nostdlib
# Below used to make stvec_handler and mtvec_handler null when not used by a test;
# Making stvec_handler and mtvec_handler weak symbols does not work because they become global
# but they need to be local to each test.
CFLAGS += -Wl,--unresolved-symbols=ignore-all

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

.PHONY: all
all: isatests216.hex isatests232.hex isatests264.hex  isatests2128.hex  isatests2256.hex

isatests216.hex: isatests2.bin
	truncate --size=%2 isatests2.bin
	hexdump -v -e '/2 "%04x "' isatests2.bin > isatests216.hex # 16bits.

isatests232.hex: isatests2.bin
	truncate --size=%4 isatests2.bin
	hexdump -v -e '/4 "%08x "' isatests2.bin > isatests232.hex # 32bits.

isatests264.hex: isatests2.bin
	truncate --size=%8 isatests2.bin
	hexdump -v -e '/4 "%08x "' isatests2.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > isatests264.hex # 64bits.

isatests2128.hex: isatests2.bin
	truncate --size=%16 isatests2.bin
	hexdump -v -e '/4 "%08x "' isatests2.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > isatests2128.hex # 128bits.

isatests2256.hex: isatests2.bin
	truncate --size=%32 isatests2.bin
	hexdump -v -e '/4 "%08x "' isatests2.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > isatests2256.hex # 256bits.

%.o : tests/%.S
	${CC} ${CFLAGS} -I ./tests/ -c -o $@ \
		-DTEST_FUNC_NAME=$* -DTEST_FUNC_TXT='"$*"' -DTEST_FUNC_RET=$*_ret $<

isatests2.bin: isatests2.S ${TESTS_OBJS}
	${CC} ${CFLAGS} -I ./ -o isatests2.elf -Wl,-Tisatests2.lds isatests2.S ${TESTS_OBJS}
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents isatests2.elf isatests2.bin
	$(OBJDUMP) -Sdrl isatests2.elf > isatests2.elf.objdump
	${READELF} -a isatests2.elf > isatests2.elf.readelf

.PHONY: clean
clean:
	rm -rf *.o *.elf *.bin *.hex *.objdump *.readelf
