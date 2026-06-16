# See LICENSE for license details.
#*****************************************************************************
# andn.S  -  Zbb: rd = rs1 & ~rs2
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  andn, 0xf000f000, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_OP( 3,  andn, 0xffffffff, 0xffffffff, 0x00000000 );
  TEST_RR_OP( 4,  andn, 0x00000000, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 5,  andn, 0x12345678, 0x12345678, 0x00000000 );
  TEST_RR_OP( 6,  andn, 0x00000000, 0x00000000, 0x12345678 );
  TEST_RR_OP( 7,  andn, 0x00ff0000, 0x00ffff00, 0x0000ff00 );

  TEST_RR_SRC1_EQ_DEST( 8,  andn, 0xf000f000, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_SRC2_EQ_DEST( 9,  andn, 0xf000f000, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_DEST_BYPASS( 10, 0, andn, 0xf000f000, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_DEST_BYPASS( 11, 1, andn, 0xffffffff, 0xffffffff, 0x00000000 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
