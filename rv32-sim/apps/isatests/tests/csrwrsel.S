# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

#*****************************************************************************
# csrwrsel.S
#-----------------------------------------------------------------------------
#
# Exercise the write-select decode of every CSR whose write enable is not
# already reached by another test or by the C applications. Three of them are
# written by nothing else in the tree at all: stimecmp/stimecmph, stval2, and
# fcsr. fcsr is the interesting one, as it is the single address whose write
# must assert two selects at once, one for fflags and one for frm.
#
# The other shape covered here is the pair of counter-compare CSRs, whose
# decode deliberately ignores address bit 4 and then uses that same bit to pick
# which half of the 64bit value is written; a decode that matched the whole
# address, or that dropped the half select, would pass every other test.
#

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # Scratch registers, as a plain round trip anchoring the rest.
  TEST_CASE( 2, a0, 0x5a5a1234, li a1, 0x5a5a1234; csrw mscratch, a1; csrr a0, mscratch)
  TEST_CASE( 3, a0, 0xa5a54321, li a1, 0xa5a54321; csrw sscratch, a1; csrr a0, sscratch)

  # Second trap value registers. mtval2 is 0x34b and stval2 is 0x14b; neither is
  # a standard number, so both are named numerically. stval2 is written nowhere
  # in the tree at all.
  TEST_CASE( 4, a0, 0x0badc0de, li a1, 0x0badc0de; csrw 0x34b, a1; csrr a0, 0x34b)
  TEST_CASE( 5, a0, 0x0defaced, li a1, 0x0defaced; csrw 0x14b, a1; csrr a0, 0x14b)

  # The two must stay independent of one another: their addresses differ only in
  # the privilege field, so a decode that ignored too many bits would alias them.
  TEST_CASE( 6, a0, 0x12345678, li a1, 0x12345678; csrw 0x34b, a1; \
                                li a1, 0x0badc0de; csrw 0x14b, a1; csrr a0, 0x34b)
  TEST_CASE( 7, a0, 0x0badc0de, csrr a0, 0x14b)

  # Machine timer compare, low half 0x34d and high half 0x35d. The values are
  # chosen so that the compare against the cycle counter cannot match while the
  # test runs, and both halves are set to all ones before moving on.
  li a1, 0x71234567
  csrw 0x34d, a1
  li a1, 0x7fedcba9
  csrw 0x35d, a1
  TEST_CASE( 8, a0, 0x71234567, csrr a0, 0x34d)
  TEST_CASE( 9, a0, 0x7fedcba9, csrr a0, 0x35d)
  # Writing one half must leave the other alone.
  li a1, 0x0f0f0f0f
  csrw 0x34d, a1
  TEST_CASE(10, a0, 0x0f0f0f0f, csrr a0, 0x34d)
  TEST_CASE(11, a0, 0x7fedcba9, csrr a0, 0x35d)
  li a1, -1
  csrw 0x34d, a1
  csrw 0x35d, a1

  # Supervisor timer compare, low half 0x14d and high half 0x15d. Written by no
  # other test and by no application. A supervisor timer interrupt can only be
  # delivered when the corresponding mideleg bit is set, which it is not here,
  # and both halves are left at all ones regardless.
  li a1, 0x61234567
  csrw 0x14d, a1
  li a1, 0x6fedcba9
  csrw 0x15d, a1
  TEST_CASE(12, a0, 0x61234567, csrr a0, 0x14d)
  TEST_CASE(13, a0, 0x6fedcba9, csrr a0, 0x15d)
  li a1, 0x33333333
  csrw 0x14d, a1
  TEST_CASE(14, a0, 0x33333333, csrr a0, 0x14d)
  TEST_CASE(15, a0, 0x6fedcba9, csrr a0, 0x15d)
  li a1, -1
  csrw 0x14d, a1
  csrw 0x15d, a1

  # The interrupt enable register is decoded on the low eight address bits only,
  # so 0x004, 0x104, 0x204 and 0x304 all reach it while only 0x304 and 0x104 read
  # back. Interrupts are disabled around this and the previous value restored, so
  # that enabling a source cannot disturb the rest of the run.
  csrr s0, mstatus
  li a1, MSTATUS_MIE
  csrc mstatus, a1
  csrr s1, mie
  li a1, 0x00000880
  csrw 0x204, a1
  TEST_CASE(16, a0, 0x00000880, csrr a0, 0x304)
  li a1, 0x00000220
  csrw 0x004, a1
  TEST_CASE(17, a0, 0x00000220, csrr a0, 0x304)
  csrw mie, s1
  csrw mstatus, s0

  # fcsr at 0x003 is the one address whose write must assert two selects, since
  # it holds frm in bits 7:5 and fflags in bits 4:0, each of which is also
  # separately addressable. Reading the two back individually is what shows both
  # selects fired; a one hot write select would leave one of them at its old
  # value. The register file only exists when the FPU is built in, so probe it
  # first and skip these checks when it is absent.
  li a1, 0x1f
  csrw 0x001, a1
  csrr a2, 0x001
  beqz a2, 1f

  # Clear both halves through their individual addresses, then write only fcsr.
  csrw 0x001, x0
  csrw 0x002, x0
  li a1, 0x55                   # frm = 2, fflags = 0x15
  csrw 0x003, a1
  TEST_CASE(18, a0, 0x15, csrr a0, 0x001)
  TEST_CASE(19, a0, 0x02, csrr a0, 0x002)
  TEST_CASE(20, a0, 0x55, csrr a0, 0x003)
  # And the reverse direction: writing the two halves individually must compose
  # back into fcsr.
  li a1, 0x0a
  csrw 0x001, a1
  li a1, 0x03
  csrw 0x002, a1
  TEST_CASE(21, a0, 0x6a, csrr a0, 0x003)
  csrw 0x001, x0
  csrw 0x002, x0
1:

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
