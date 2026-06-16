# See LICENSE for license details.
#*****************************************************************************
# orc_b.S  -  Zbb: rd = OR-combine within each byte (orc.b)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  orc.b, 0x00000000, 0x00000000 );
  TEST_R_OP( 3,  orc.b, 0xffffffff, 0xffffffff );
  TEST_R_OP( 4,  orc.b, 0xffffffff, 0x01020304 );
  TEST_R_OP( 5,  orc.b, 0x00ff00ff, 0x00ff00ff );
  TEST_R_OP( 6,  orc.b, 0xff00ff00, 0x01000200 );
  TEST_R_OP( 7,  orc.b, 0xff0000ff, 0x10000001 );
  TEST_R_OP( 8,  orc.b, 0xffffffff, 0x80808080 );

  TEST_R_SRC1_EQ_DEST( 9,  orc.b, 0xff00ff00, 0x01000200 );
  TEST_R_DEST_BYPASS( 10, 0, orc.b, 0xffffffff, 0x01020304 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
