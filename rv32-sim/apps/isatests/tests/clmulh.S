# See LICENSE for license details.
#*****************************************************************************
# clmulh.S  -  Zbc: rd = high word of the carry-less product rs1 (x) rs2
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  clmulh, 0x00000000, 0x00000003, 0x00000003 );
  TEST_RR_OP( 3,  clmulh, 0x55555555, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 4,  clmulh, 0x00000001, 0x80000000, 0x00000002 );
  TEST_RR_OP( 5,  clmulh, 0x40000000, 0x80000000, 0x80000000 );
  TEST_RR_OP( 6,  clmulh, 0x0c42fde8, 0xdeadbeef, 0x12345678 );
  TEST_RR_OP( 7,  clmulh, 0x00000000, 0x00000001, 0xffffffff );

  TEST_RR_SRC1_EQ_DEST(  8, clmulh, 0x55555555, 0xffffffff, 0xffffffff );
  TEST_RR_SRC2_EQ_DEST(  9, clmulh, 0x00000001, 0x80000000, 0x00000002 );
  TEST_RR_SRC12_EQ_DEST( 10, clmulh, 0x40000000, 0x80000000 );

  TEST_RR_DEST_BYPASS( 11, 0, clmulh, 0x55555555, 0xffffffff, 0xffffffff );
  TEST_RR_DEST_BYPASS( 12, 1, clmulh, 0x0c42fde8, 0xdeadbeef, 0x12345678 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
