# See LICENSE for license details.
#*****************************************************************************
# binv.S  -  Zbs: rd = rs1 ^ (1 << (rs2 & (XLEN-1)))
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  binv, 0x00000001, 0x00000000, 0 );
  TEST_RR_OP( 3,  binv, 0x00000020, 0x00000000, 5 );
  TEST_RR_OP( 4,  binv, 0xffffffdf, 0xffffffff, 5 );
  TEST_RR_OP( 5,  binv, 0x00000000, 0x80000000, 31 );
  TEST_RR_OP( 6,  binv, 0x12345670, 0x12345678, 3 );

  TEST_RR_SRC1_EQ_DEST( 7, binv, 0x00000001, 0x00000000, 0 );
  TEST_RR_SRC2_EQ_DEST( 8, binv, 0x00000020, 0x00000000, 5 );
  TEST_RR_DEST_BYPASS(  9, 0, binv, 0x00000000, 0x80000000, 31 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
