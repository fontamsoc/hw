# See LICENSE for license details.
#*****************************************************************************
# bext.S  -  Zbs: rd = (rs1 >> (rs2 & (XLEN-1))) & 1
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  bext, 0x00000001, 0x80000000, 31 );
  TEST_RR_OP( 3,  bext, 0x00000000, 0x80000000, 30 );
  TEST_RR_OP( 4,  bext, 0x00000001, 0xffffffff, 0 );
  TEST_RR_OP( 5,  bext, 0x00000001, 0x12345678, 3 );
  TEST_RR_OP( 6,  bext, 0x00000000, 0x00000000, 0 );
  TEST_RR_OP( 7,  bext, 0x00000001, 0x00000002, 33 ); # 33 & 31 == 1

  TEST_RR_SRC1_EQ_DEST( 8, bext, 0x00000001, 0x80000000, 31 );
  TEST_RR_SRC2_EQ_DEST( 9, bext, 0x00000000, 0x80000000, 30 );
  TEST_RR_DEST_BYPASS( 10, 0, bext, 0x00000001, 0xffffffff, 0 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
