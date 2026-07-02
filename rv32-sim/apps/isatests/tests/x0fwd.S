# See LICENSE for license details.

#*****************************************************************************
# x0fwd.S
#-----------------------------------------------------------------------------
#
# Test that a multicycle instruction with rd == x0 (lw/div/rem/mul/amo* x0)
# never makes a later reader of x0 observe a nonzero value through the
# WriteBack forwarding capture (pu.sv iD_rW capture on the multicycle
# retire path; the x0 zero-mask on the operand muxes only guards the
# gprDat leg, not the forwarding legs).
#
# Readers are streams of `bne x0, s1, fail` (s1 == 0): branches have no rd,
# so they never take the WriteBack slot and the multicycle result retires
# while the stream flows through iD; one branch sits at iD on the retire(+1)
# cycle and samples the forwarded value. A single reader placed "at the
# right distance" would be timing-fragile; a stream is robust.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32U
RVTEST_CODE_BEGIN

  li s1, 0

  #-------------------------------------------------------------
  # div/rem/mul x0 (idiv and imul units)
  #-------------------------------------------------------------

  li TESTNUM, 2
  li a1, 100
  li a2, 3
  div x0, a1, a2        # quotient 33 retires into rd == x0
  .rept 64
  bne x0, s1, fail
  .endr

  li TESTNUM, 3
  rem x0, a1, a2        # remainder 1
  .rept 64
  bne x0, s1, fail
  .endr

  li TESTNUM, 4
  mul x0, a1, a2        # 300
  .rept 64
  bne x0, s1, fail
  .endr

  #-------------------------------------------------------------
  # lw x0 (load unit); warm the line first so the load retires fast
  #-------------------------------------------------------------

  li TESTNUM, 5
  la a3, tdat
  lw t0, 0(a3)
  lw x0, 0(a3)          # 0xdeadbeef
  .rept 32
  bne x0, s1, fail
  .endr

  li TESTNUM, 6
  lw x0, 4(a3)          # 0x12345678
  .rept 32
  bne x0, s1, fail
  .endr

  #-------------------------------------------------------------
  # amoswap.w/amoadd.w x0 (AMO via the load unit); amoadd.w zero
  # is the common lock-free-counter idiom
  #-------------------------------------------------------------

  li TESTNUM, 7
  li t1, 0x55aa55aa
  amoswap.w x0, t1, (a3)   # old value 0xdeadbeef discarded into x0
  .rept 32
  bne x0, s1, fail
  .endr

  li TESTNUM, 8
  amoadd.w x0, t1, (a3)
  .rept 32
  bne x0, s1, fail
  .endr

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

tdat:  .word 0xdeadbeef
       .word 0x12345678
       .word 0

RVTEST_DATA_END
