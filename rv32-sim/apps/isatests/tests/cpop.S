# See LICENSE for license details.
#*****************************************************************************
# cpop.S  -  Zbb: rd = popcount(rs1)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  cpop, 0,  0x00000000 );
  TEST_R_OP( 3,  cpop, 32, 0xffffffff );
  TEST_R_OP( 4,  cpop, 1,  0x00000001 );
  TEST_R_OP( 5,  cpop, 16, 0x55555555 );
  TEST_R_OP( 6,  cpop, 16, 0xaaaaaaaa );
  TEST_R_OP( 7,  cpop, 13, 0x12345678 );
  TEST_R_OP( 8,  cpop, 16, 0x0000ffff );
  TEST_R_OP( 9,  cpop, 8,  0x0f0f0000 );

  TEST_R_SRC1_EQ_DEST( 10, cpop, 32, 0xffffffff );
  TEST_R_DEST_BYPASS( 11, 0, cpop, 16, 0x55555555 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
