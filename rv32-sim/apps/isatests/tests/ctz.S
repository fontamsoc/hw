# See LICENSE for license details.
#*****************************************************************************
# ctz.S  -  Zbb: rd = count-trailing-zeros(rs1)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  ctz, 0,  0x00000001 );
  TEST_R_OP( 3,  ctz, 31, 0x80000000 );
  TEST_R_OP( 4,  ctz, 0,  0xffffffff );
  TEST_R_OP( 5,  ctz, 32, 0x00000000 );
  TEST_R_OP( 6,  ctz, 16, 0xffff0000 );
  TEST_R_OP( 7,  ctz, 16, 0x00010000 );
  TEST_R_OP( 8,  ctz, 1,  0x00000002 );
  TEST_R_OP( 9,  ctz, 7,  0x00000080 );

  TEST_R_SRC1_EQ_DEST( 10, ctz, 31, 0x80000000 );
  TEST_R_DEST_BYPASS( 11, 0, ctz, 16, 0xffff0000 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
