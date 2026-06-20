# See LICENSE for license details.
#*****************************************************************************
# bexti.S  -  Zbs: rd = (rs1 >> shamt) & 1
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_IMM_OP( 2,  bexti, 0x00000001, 0x80000000, 31 );
  TEST_IMM_OP( 3,  bexti, 0x00000000, 0x80000000, 30 );
  TEST_IMM_OP( 4,  bexti, 0x00000001, 0xffffffff, 0 );
  TEST_IMM_OP( 5,  bexti, 0x00000001, 0x12345678, 3 );

  TEST_IMM_SRC1_EQ_DEST( 6, bexti, 0x00000001, 0x80000000, 31 );
  TEST_IMM_DEST_BYPASS(  7, 0, bexti, 0x00000000, 0x80000000, 30 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
