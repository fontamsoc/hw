/* SPDX-License-Identifier: GPL-2.0-only
   (c) William Fonkou Tambe */

/* Written from:
   https://www.ustcpetergu.com/MyBlog/experience/2021/07/09/about-riscv-testing.html
   https://github.com/YosysHQ/picorv32/tree/main/tests
   https://github.com/riscv-software-src/riscv-tests */

	.section .text._start
	.global  _start
	.type    _start, @function
_start:

#define TEST(n) \
	.global n; \
	j n; \
	.global n##_ret; \
	n##_ret:

	TEST(simple)

	TEST(addi)
	TEST(add)
	TEST(andi)
	TEST(and)
	TEST(auipc)
	TEST(beq)
	TEST(bge)
	TEST(bgeu)
	TEST(blt)
	TEST(bltu)
	TEST(bne)
	TEST(div)
	TEST(divu)
	TEST(jalr)
	TEST(jal)
	TEST(j)
	TEST(lb)
	TEST(lbu)
	TEST(lh)
	TEST(lhu)
	TEST(lui)
	TEST(lw)
	TEST(mulh)
	TEST(mulhsu)
	TEST(mulhu)
	TEST(mul)
	TEST(ori)
	TEST(or)
	TEST(rem)
	TEST(remu)
	TEST(sb)
	TEST(sh)
	TEST(slli)
	TEST(sll)
	TEST(slti)
	TEST(slt)
	TEST(srai)
	TEST(sra)
	TEST(srli)
	TEST(srl)
	TEST(sub)
	TEST(sw)
	TEST(xori)
	TEST(xor)
	TEST(sh1add)
	TEST(sh2add)
	TEST(sh3add)
	TEST(amoswap_w)
	TEST(amoadd_w)
	TEST(amoand_w)
	TEST(amoor_w)
	TEST(amoxor_w)
	TEST(amomin_w)
	TEST(amomax_w)
	TEST(amominu_w)
	TEST(amomaxu_w)
	TEST(lrsc)

	csrw mtvec, x0; /* needed to indefinitely halt on ebreak */
	ebreak;
