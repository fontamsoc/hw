# See LICENSE for license details.
#*****************************************************************************
# binvi.S  -  Zbs: rd = rs1 ^ (1 << shamt)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_IMM_OP( 2,  binvi, 0x00000001, 0x00000000, 0 );
  TEST_IMM_OP( 3,  binvi, 0xffffffdf, 0xffffffff, 5 );
  TEST_IMM_OP( 4,  binvi, 0x00000000, 0x80000000, 31 );
  TEST_IMM_OP( 5,  binvi, 0x00000020, 0x00000000, 5 );

  TEST_IMM_SRC1_EQ_DEST( 6, binvi, 0x00000020, 0x00000000, 5 );
  TEST_IMM_DEST_BYPASS(  7, 0, binvi, 0x00000000, 0x80000000, 31 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
