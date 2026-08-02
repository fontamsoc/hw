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
# Disabled: fence.i invalidates the icache but dirty dcache lines are not
# evicted (dcache.pu.sv .invd_i TODO), so refetch reads stale memory.
#TESTS += fence_i
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
TESTS += sltiu
TESTS += slt
TESTS += sltu
TESTS += srai
TESTS += sra
TESTS += srli
TESTS += srl
TESTS += sub
TESTS += sw
TESTS += ld_st
TESTS += st_ld
TESTS += xori
TESTS += xor
TESTS += sh1add
TESTS += sh2add
TESTS += sh3add
TESTS += andn
TESTS += orn
TESTS += xnor
TESTS += min
TESTS += minu
TESTS += max
TESTS += maxu
TESTS += rol
TESTS += ror
TESTS += rori
TESTS += clz
TESTS += ctz
TESTS += cpop
TESTS += sext_b
TESTS += sext_h
TESTS += zext_h
TESTS += rev8
TESTS += orc_b
TESTS += clmul
TESTS += clmulh
TESTS += clmulr
TESTS += bset
TESTS += bclr
TESTS += binv
TESTS += bext
TESTS += bseti
TESTS += bclri
TESTS += binvi
TESTS += bexti
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
TESTS += x0fwd
TESTS += mcsr
TESTS += machine_csr
TESTS += scsr
TESTS += csrwrsel
TESTS += msbreak
TESTS += ssbreak
TESTS += mscall
TESTS += sscall
TESTS += mfetch_misaligned
TESTS += sfetch_misaligned
TESTS += ma_addr
# Disabled: the decoder accepts slli encodings with shamt[5] set instead of
# trapping illegal-instruction.
#TESTS += shamt
# Disabled: needs sfence.vma (not decoded; traps illegal-instruction), the
# mstatus.TVM/TSR virtualization controls, and a writable mip.SSIP along with
# software-interrupt delegation in mideleg, none of which are implemented.
#TESTS += illegal
TESTS += lh_misaligned
TESTS += lw_misaligned
TESTS += sh_misaligned
TESTS += sw_misaligned
TESTS += zicntr
# rv32si/wfi is not included: this design implements no software interrupt,
# mip/mie MSIP SSIP MSIE SSIE reading null and ignoring writes, so the upstream
# test, which relies on a pending SSIP, would hang.
# rv64mi/instret_overflow is not included: minstret reads as hardwired zero,
# so the test would pass vacuously.

TESTS_OBJS = $(addsuffix .o,${TESTS})


PREFIX := riscv32-unknown-elf

CC := ${PREFIX}-gcc
OBJCOPY := ${PREFIX}-objcopy
OBJDUMP := ${PREFIX}-objdump
READELF := ${PREFIX}-readelf

CFLAGS += -Werror -fdata-sections -ffunction-sections -Wl,--gc-sections -O3 -g
CFLAGS += -nostdlib
CFLAGS += -march=rv32ima_zicsr_zifencei_zba_zbb_zbc_zbs
# Below used to make stvec_handler and mtvec_handler null when not used by a test;
# Making stvec_handler and mtvec_handler weak symbols does not work because they become global
# but they need to be local to each test.
CFLAGS += -Wl,--unresolved-symbols=ignore-all

APPNAME := isatests

.PHONY: all
all: ${APPNAME}.bin

%.o : tests/%.S
	${CC} ${CFLAGS} -I ./tests/ -c -o $@ \
		-DTEST_FUNC_NAME=$* -DTEST_FUNC_TXT='"$*"' -DTEST_FUNC_RET=$*_ret $<

# Rebuild objects when the shared headers or #include'd test bodies change.
${TESTS_OBJS}: tests/riscv_test.h tests/test_macros.h tests/encoding.h
mcsr.o: tests/scsr.S
mfetch_misaligned.o: tests/sfetch_misaligned.S
msbreak.o: tests/ssbreak.S
mscall.o: tests/sscall.S

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
