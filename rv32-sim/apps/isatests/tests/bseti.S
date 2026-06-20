# See LICENSE for license details.
#*****************************************************************************
# bseti.S  -  Zbs: rd = rs1 | (1 << shamt)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_IMM_OP( 2,  bseti, 0x00000001, 0x00000000, 0 );
  TEST_IMM_OP( 3,  bseti, 0x00000020, 0x00000000, 5 );
  TEST_IMM_OP( 4,  bseti, 0x80000001, 0x00000001, 31 );
  TEST_IMM_OP( 5,  bseti, 0x12345678, 0x12345678, 3 );

  TEST_IMM_SRC1_EQ_DEST( 6, bseti, 0x00000020, 0x00000000, 5 );
  TEST_IMM_DEST_BYPASS(  7, 0, bseti, 0x80000001, 0x00000001, 31 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
