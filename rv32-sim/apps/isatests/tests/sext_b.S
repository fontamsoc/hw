# See LICENSE for license details.
#*****************************************************************************
# sext_b.S  -  Zbb: rd = sign-extend byte (sext.b)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  sext.b, 0x0000007f, 0x0000007f );
  TEST_R_OP( 3,  sext.b, 0xffffff80, 0x00000080 );
  TEST_R_OP( 4,  sext.b, 0xffffffff, 0x000000ff );
  TEST_R_OP( 5,  sext.b, 0x00000078, 0x12345678 );
  TEST_R_OP( 6,  sext.b, 0xffffffff, 0x123456ff );
  TEST_R_OP( 7,  sext.b, 0x00000000, 0x00000000 );
  TEST_R_OP( 8,  sext.b, 0x00000001, 0xffffff01 );

  TEST_R_SRC1_EQ_DEST( 9,  sext.b, 0xffffff80, 0x00000080 );
  TEST_R_DEST_BYPASS( 10, 0, sext.b, 0xffffff80, 0x00000080 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
