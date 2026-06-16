# See LICENSE for license details.
#*****************************************************************************
# min.S  -  Zbb: rd = signed-min(rs1, rs2)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  min, 0x00000003, 0x00000005, 0x00000003 );
  TEST_RR_OP( 3,  min, 0x00000003, 0x00000003, 0x00000005 );
  TEST_RR_OP( 4,  min, 0xffffffff, 0xffffffff, 0x00000001 );
  TEST_RR_OP( 5,  min, 0x80000000, 0x80000000, 0x7fffffff );
  TEST_RR_OP( 6,  min, 0xffffffff, 0x00000000, 0xffffffff );
  TEST_RR_OP( 7,  min, 0x00000007, 0x00000007, 0x00000007 );
  TEST_RR_OP( 8,  min, 0x80000000, 0x7fffffff, 0x80000000 );

  TEST_RR_SRC1_EQ_DEST( 9,  min, 0x00000003, 0x00000005, 0x00000003 );
  TEST_RR_SRC2_EQ_DEST( 10, min, 0x00000003, 0x00000005, 0x00000003 );
  TEST_RR_DEST_BYPASS( 11, 0, min, 0xffffffff, 0xffffffff, 0x00000001 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
