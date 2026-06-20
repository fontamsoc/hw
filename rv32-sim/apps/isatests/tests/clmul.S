# See LICENSE for license details.
#*****************************************************************************
# clmul.S  -  Zbc: rd = low word of the carry-less product rs1 (x) rs2
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  clmul, 0x00000005, 0x00000003, 0x00000003 );
  TEST_RR_OP( 3,  clmul, 0x0000000f, 0x00000005, 0x00000003 );
  TEST_RR_OP( 4,  clmul, 0x55555555, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 5,  clmul, 0x00000000, 0x80000000, 0x00000002 );
  TEST_RR_OP( 6,  clmul, 0xde112da8, 0xdeadbeef, 0x12345678 );
  TEST_RR_OP( 7,  clmul, 0x00000000, 0x00000000, 0xffffffff );
  TEST_RR_OP( 8,  clmul, 0x12345678, 0x12345678, 0x00000001 );

  TEST_RR_SRC1_EQ_DEST(  9, clmul, 0x00000005, 0x00000003, 0x00000003 );
  TEST_RR_SRC2_EQ_DEST( 10, clmul, 0x0000000f, 0x00000005, 0x00000003 );
  TEST_RR_SRC12_EQ_DEST( 11, clmul, 0x00000005, 0x00000003 );

  TEST_RR_DEST_BYPASS( 12, 0, clmul, 0x55555555, 0xffffffff, 0xffffffff );
  TEST_RR_DEST_BYPASS( 13, 1, clmul, 0xde112da8, 0xdeadbeef, 0x12345678 );
  TEST_RR_DEST_BYPASS( 14, 2, clmul, 0x0000000f, 0x00000005, 0x00000003 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
