# See LICENSE for license details.
#*****************************************************************************
# bclri.S  -  Zbs: rd = rs1 & ~(1 << shamt)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_IMM_OP( 2,  bclri, 0xfffffffe, 0xffffffff, 0 );
  TEST_IMM_OP( 3,  bclri, 0x7fffffff, 0xffffffff, 31 );
  TEST_IMM_OP( 4,  bclri, 0x00000000, 0x00000000, 5 );
  TEST_IMM_OP( 5,  bclri, 0x12345670, 0x12345678, 3 );

  TEST_IMM_SRC1_EQ_DEST( 6, bclri, 0x7fffffff, 0xffffffff, 31 );
  TEST_IMM_DEST_BYPASS(  7, 0, bclri, 0xfffffffe, 0xffffffff, 0 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
