# See LICENSE for license details.
#*****************************************************************************
# bclr.S  -  Zbs: rd = rs1 & ~(1 << (rs2 & (XLEN-1)))
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  bclr, 0xfffffffe, 0xffffffff, 0 );
  TEST_RR_OP( 3,  bclr, 0x7fffffff, 0xffffffff, 31 );
  TEST_RR_OP( 4,  bclr, 0x00000000, 0x00000000, 5 );
  TEST_RR_OP( 5,  bclr, 0xfffffffd, 0xffffffff, 0x41 ); # 0x41 & 31 == 1
  TEST_RR_OP( 6,  bclr, 0x12345670, 0x12345678, 3 );

  TEST_RR_SRC1_EQ_DEST( 7, bclr, 0xfffffffe, 0xffffffff, 0 );
  TEST_RR_SRC2_EQ_DEST( 8, bclr, 0x7fffffff, 0xffffffff, 31 );
  TEST_RR_DEST_BYPASS(  9, 0, bclr, 0x7fffffff, 0xffffffff, 31 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
