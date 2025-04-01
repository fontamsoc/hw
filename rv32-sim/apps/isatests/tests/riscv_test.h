
#ifndef RISCV_TEST_H
#define RISCV_TEST_H

#ifndef TEST_FUNC_NAME
#define TEST_FUNC_NAME mytest
#define TEST_FUNC_TXT "mytest"
#define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U
#define TESTNUM x28

#define __SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)

#define RVTEST_CODE_BEGIN \
	.text; \
	.global TEST_FUNC_NAME; \
	.global TEST_FUNC_RET; \
TEST_FUNC_NAME: \
	li TESTNUM, 0; \
	la a0, .test_name; \
	li a2, __SERIAL0_ADDR; \
.prname_next: \
	lb a1, 0(a0); \
	beqz a1, .prname_done; \
	sw a1, 0(a2); \
	addi a0, a0, 1; \
	j .prname_next; \
.test_name: \
	.ascii TEST_FUNC_TXT; \
	.byte 0x00; \
	.balign 4, 0; \
.prname_done: \
	addi a1, x0, '.'; \
	sw a1,0(a2); \
	sw a1,0(a2);

#define RVTEST_PASS \
	li a0, __SERIAL0_ADDR; \
	addi a1, x0, 'o'; \
	addi a2, x0, 'k'; \
	addi a3, x0, '\n'; \
	sw a1,0(a0); \
	sw a2,0(a0); \
	sw a3,0(a0); \
	j TEST_FUNC_RET;

#define RVTEST_FAIL \
	li a0, __SERIAL0_ADDR; \
	addi a1, x0, 'e'; \
	addi a2, x0, 'r'; \
	addi a3, x0, 'o'; \
	addi a4, x0, '\n'; \
	sw a1,0(a0); \
	sw a2,0(a0); \
	sw a2,0(a0); \
	sw a3,0(a0); \
	sw a2,0(a0); \
	sw a4,0(a0); \
	ebreak;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END

#endif
