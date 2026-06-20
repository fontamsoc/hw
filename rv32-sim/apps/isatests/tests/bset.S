# See LICENSE for license details.
#*****************************************************************************
# bset.S  -  Zbs: rd = rs1 | (1 << (rs2 & (XLEN-1)))
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  bset, 0x00000001, 0x00000000, 0 );
  TEST_RR_OP( 3,  bset, 0x00000002, 0x00000000, 33 );  # 33 & 31 == 1
  TEST_RR_OP( 4,  bset, 0x80000001, 0x00000001, 31 );
  TEST_RR_OP( 5,  bset, 0xffffffff, 0xffffffff, 0 );
  TEST_RR_OP( 6,  bset, 0x12345678, 0x12345678, 3 );   # bit already set

  TEST_RR_SRC1_EQ_DEST(  7, bset, 0x00000002, 0x00000000, 1 );
  TEST_RR_SRC2_EQ_DEST(  8, bset, 0x00000020, 0x00000000, 5 );
  TEST_RR_DEST_BYPASS(  9, 0, bset, 0x80000001, 0x00000001, 31 );
  TEST_RR_DEST_BYPASS( 10, 1, bset, 0x00000002, 0x00000000, 33 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
