
#ifndef RISCV_TEST_H
#define RISCV_TEST_H

#include "encoding.h"

#ifndef TEST_FUNC_NAME
#define TEST_FUNC_NAME mytest
#define TEST_FUNC_TXT "mytest"
#define TEST_FUNC_RET mytest_ret
#endif

#define RVTEST_RV32U \
	.macro init; \
	.endm;

#define RVTEST_RV32S \
	.macro init; \
	RVTEST_ENABLE_SUPERVISOR; \
	.endm;

#define RVTEST_RV32M \
	.macro init; \
	RVTEST_ENABLE_MACHINE; \
	.endm;

#define TESTNUM x3

#define INIT_XREG \
	li x1, 0; \
	li x2, 0; \
	li x3, 0; \
	li x4, 0; \
	li x5, 0; \
	li x6, 0; \
	li x7, 0; \
	li x8, 0; \
	li x9, 0; \
	li x10, 0; \
	li x11, 0; \
	li x12, 0; \
	li x13, 0; \
	li x14, 0; \
	li x15, 0; \
	li x16, 0; \
	li x17, 0; \
	li x18, 0; \
	li x19, 0; \
	li x20, 0; \
	li x21, 0; \
	li x22, 0; \
	li x23, 0; \
	li x24, 0; \
	li x25, 0; \
	li x26, 0; \
	li x27, 0; \
	li x28, 0; \
	li x29, 0; \
	li x30, 0; \
	li x31, 0;

#define MULTICORE_DISABLE \
	csrr a0, mhartid; \
1:	bnez a0, 1b;

#define DELEGATE_NO_TRAPS \
	csrwi mie, 0; \
	la t0, 1f; \
	csrw mtvec, t0; \
	csrwi medeleg, 0; \
	csrwi mideleg, 0; \
1:

#define RVTEST_ENABLE_SUPERVISOR \
	li a0, MSTATUS_MPP & (MSTATUS_MPP >> 1); \
	csrs mstatus, a0; \
	li a0, SIP_SSIP | SIP_STIP; \
	csrs mideleg, a0;

#define RVTEST_ENABLE_MACHINE \
	li a0, MSTATUS_MPP; \
	csrs mstatus, a0;

#define __SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)

#define RVTEST_CODE_BEGIN \
	.text; \
	.global TEST_FUNC_NAME; \
	.global TEST_FUNC_RET; \
TEST_FUNC_NAME: \
	j reset_vector; \
trap_vector: \
	csrr t5, mcause; \
	li t6, CAUSE_USER_ECALL; \
	beq t5, t6, ecall_handler; \
	li t6, CAUSE_SUPERVISOR_ECALL; \
	beq t5, t6, ecall_handler; \
	li t6, CAUSE_MACHINE_ECALL; \
	beq t5, t6, ecall_handler; \
	la t6, mtvec_handler; \
	beqz t6, 1f; \
	jr t6; \
1:	csrw mtvec, x0; /* needed to indefinitely halt on ebreak */ \
	ebreak; \
ecall_handler: \
	bnez a0, 1b; \
	j TEST_FUNC_RET; \
reset_vector: \
	INIT_XREG; \
	MULTICORE_DISABLE; \
	DELEGATE_NO_TRAPS; \
	la t0, trap_vector; \
	csrw mtvec, t0; \
	la t0, stvec_handler; \
	beqz t0, 1f; \
	csrw stvec, t0; \
	li t0, (1 << CAUSE_LOAD_PAGE_FAULT) | \
	       (1 << CAUSE_STORE_PAGE_FAULT) | \
	       (1 << CAUSE_FETCH_PAGE_FAULT) | \
	       (1 << CAUSE_MISALIGNED_FETCH) | \
	       (1 << CAUSE_BREAKPOINT); \
	csrw medeleg, t0; \
1:	csrwi mstatus, 0; \
	init; \
	la t0, 1f; \
	csrw mepc, t0; \
	mret; \
1:	la a0, test_name; \
	li a2, __SERIAL0_ADDR; \
prname_next: \
	lb a1, 0(a0); \
	beqz a1, prname_done; \
	sw a1, 0(a2); \
	addi a0, a0, 1; \
	j prname_next; \
test_name: \
	.ascii TEST_FUNC_TXT; \
	.byte 0x00; \
	.balign 4, 0; \
prname_done: \
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
	li a0, 0; \
	ecall;

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
	li a0, 1; \
	ecall;

#define RVTEST_CODE_END
#define RVTEST_DATA_BEGIN .balign 4;
#define RVTEST_DATA_END

#endif
