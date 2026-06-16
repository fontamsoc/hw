# See LICENSE for license details.
#*****************************************************************************
# orn.S  -  Zbb: rd = rs1 | ~rs2
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  orn, 0xf0fff0ff, 0x00ff00ff, 0x0f0f0f0f );
  TEST_RR_OP( 3,  orn, 0xffffffff, 0x00000000, 0x00000000 );
  TEST_RR_OP( 4,  orn, 0x00000000, 0x00000000, 0xffffffff );
  TEST_RR_OP( 5,  orn, 0xffffffff, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 6,  orn, 0x1234ffff, 0x12340000, 0xffff0000 );
  TEST_RR_OP( 7,  orn, 0xffffffff, 0x12345678, 0x00000000 );

  TEST_RR_SRC1_EQ_DEST( 8,  orn, 0xf0fff0ff, 0x00ff00ff, 0x0f0f0f0f );
  TEST_RR_SRC2_EQ_DEST( 9,  orn, 0xf0fff0ff, 0x00ff00ff, 0x0f0f0f0f );
  TEST_RR_DEST_BYPASS( 10, 0, orn, 0xf0fff0ff, 0x00ff00ff, 0x0f0f0f0f );
  TEST_RR_DEST_BYPASS( 11, 1, orn, 0xffffffff, 0x00000000, 0x00000000 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
