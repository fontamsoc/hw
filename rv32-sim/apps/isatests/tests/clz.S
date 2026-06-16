# See LICENSE for license details.
#*****************************************************************************
# clz.S  -  Zbb: rd = count-leading-zeros(rs1)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  clz, 31, 0x00000001 );
  TEST_R_OP( 3,  clz, 0,  0x80000000 );
  TEST_R_OP( 4,  clz, 0,  0xffffffff );
  TEST_R_OP( 5,  clz, 32, 0x00000000 );
  TEST_R_OP( 6,  clz, 16, 0x0000ffff );
  TEST_R_OP( 7,  clz, 16, 0x00008000 );
  TEST_R_OP( 8,  clz, 1,  0x40000000 );
  TEST_R_OP( 9,  clz, 24, 0x00000080 );

  TEST_R_SRC1_EQ_DEST( 10, clz, 31, 0x00000001 );
  TEST_R_DEST_BYPASS( 11, 0, clz, 16, 0x0000ffff );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
