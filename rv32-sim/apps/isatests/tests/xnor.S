# See LICENSE for license details.
#*****************************************************************************
# xnor.S  -  Zbb: rd = ~(rs1 ^ rs2)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  xnor, 0x0ff00ff0, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_OP( 3,  xnor, 0xffffffff, 0x00000000, 0x00000000 );
  TEST_RR_OP( 4,  xnor, 0x00000000, 0xffffffff, 0x00000000 );
  TEST_RR_OP( 5,  xnor, 0xffffffff, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 6,  xnor, 0xffffffff, 0x12345678, 0x12345678 );
  TEST_RR_OP( 7,  xnor, 0x00000000, 0x12345678, 0xedcba987 );

  TEST_RR_SRC1_EQ_DEST( 8,  xnor, 0x0ff00ff0, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_SRC2_EQ_DEST( 9,  xnor, 0x0ff00ff0, 0xff00ff00, 0x0f0f0f0f );
  TEST_RR_SRC12_EQ_DEST( 10, xnor, 0xffffffff, 0x12345678 );
  TEST_RR_DEST_BYPASS( 11, 0, xnor, 0x0ff00ff0, 0xff00ff00, 0x0f0f0f0f );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
