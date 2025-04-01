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

TESTS_OBJS = $(addsuffix .o,${TESTS})

.PHONY: all
all: isatests16.hex isatests32.hex isatests64.hex  isatests128.hex  isatests256.hex

isatests16.hex: isatests.bin
	truncate --size=%2 isatests.bin
	hexdump -v -e '/2 "%04x "' isatests.bin > isatests16.hex # 16bits.

isatests32.hex: isatests.bin
	truncate --size=%4 isatests.bin
	hexdump -v -e '/4 "%08x "' isatests.bin > isatests32.hex # 32bits.

isatests64.hex: isatests.bin
	truncate --size=%8 isatests.bin
	hexdump -v -e '/4 "%08x "' isatests.bin | \
		{ while IFS=' ' read -n 18 V0 V1; do echo -n "$$V1$$V0 "; done; } > isatests64.hex # 64bits.

isatests128.hex: isatests.bin
	truncate --size=%16 isatests.bin
	hexdump -v -e '/4 "%08x "' isatests.bin | \
		{ while IFS=' ' read -n 36 V0 V1 V2 V3; do echo -n "$$V3$$V2$$V1$$V0 "; done; } > isatests128.hex # 128bits.

isatests256.hex: isatests.bin
	truncate --size=%32 isatests.bin
	hexdump -v -e '/4 "%08x "' isatests.bin | \
		{ while IFS=' ' read -n 72 V0 V1 V2 V3 V4 V5 V6 V7; do echo -n "$$V7$$V6$$V5$$V4$$V3$$V2$$V1$$V0 "; done; } > isatests256.hex # 256bits.

%.o : tests/%.S
	${CC} ${CFLAGS} -I ./tests/ -c -o $@ \
		-DTEST_FUNC_NAME=$* -DTEST_FUNC_TXT='"$*"' -DTEST_FUNC_RET=$*_ret $<

isatests.bin: isatests.S ${TESTS_OBJS}
	${CC} ${CFLAGS} -I ./ -o isatests.elf -Wl,-Tisatests.lds isatests.S ${TESTS_OBJS}
	${OBJCOPY} -O binary --set-section-flags .bss=alloc,load,contents isatests.elf isatests.bin
	$(OBJDUMP) -Sdrl isatests.elf > isatests.elf.objdump
	${READELF} -a isatests.elf > isatests.elf.readelf

.PHONY: clean
clean:
	rm -rf *.o *.elf *.bin *.hex *.objdump *.readelf
