# See LICENSE for license details.
#*****************************************************************************
# rori.S  -  Zbb: rd = rotate-right(rs1, imm[4:0])
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_IMM_OP( 2,  rori, 0x80000000, 0x00000001, 1 );
  TEST_IMM_OP( 3,  rori, 0x81234567, 0x12345678, 4 );
  TEST_IMM_OP( 4,  rori, 0x12345678, 0x12345678, 0 );
  TEST_IMM_OP( 5,  rori, 0xefdeadbe, 0xdeadbeef, 8 );
  TEST_IMM_OP( 6,  rori, 0x00000002, 0x00000001, 31 );
  TEST_IMM_OP( 7,  rori, 0x08000000, 0x80000000, 4 );

  TEST_IMM_SRC1_EQ_DEST( 8,  rori, 0x81234567, 0x12345678, 4 );
  TEST_IMM_DEST_BYPASS( 9, 0, rori, 0xefdeadbe, 0xdeadbeef, 8 );
  TEST_IMM_DEST_BYPASS( 10, 1, rori, 0x80000000, 0x00000001, 1 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
