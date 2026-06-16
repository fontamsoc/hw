# See LICENSE for license details.
#*****************************************************************************
# maxu.S  -  Zbb: rd = unsigned-max(rs1, rs2)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  maxu, 0x00000005, 0x00000005, 0x00000003 );
  TEST_RR_OP( 3,  maxu, 0xffffffff, 0xffffffff, 0x00000001 );
  TEST_RR_OP( 4,  maxu, 0x80000000, 0x80000000, 0x7fffffff );
  TEST_RR_OP( 5,  maxu, 0xffffffff, 0x00000000, 0xffffffff );
  TEST_RR_OP( 6,  maxu, 0x00000007, 0x00000007, 0x00000007 );
  TEST_RR_OP( 7,  maxu, 0xffffffff, 0x00000001, 0xffffffff );

  TEST_RR_SRC1_EQ_DEST( 8,  maxu, 0xffffffff, 0xffffffff, 0x00000001 );
  TEST_RR_SRC2_EQ_DEST( 9,  maxu, 0xffffffff, 0xffffffff, 0x00000001 );
  TEST_RR_DEST_BYPASS( 10, 0, maxu, 0x80000000, 0x80000000, 0x7fffffff );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
