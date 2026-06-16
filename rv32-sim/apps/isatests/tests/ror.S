# See LICENSE for license details.
#*****************************************************************************
# ror.S  -  Zbb: rd = rotate-right(rs1, rs2[4:0])
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  ror, 0x80000000, 0x00000001, 0x00000001 );
  TEST_RR_OP( 3,  ror, 0x00000001, 0x00000002, 0x00000001 );
  TEST_RR_OP( 4,  ror, 0x81234567, 0x12345678, 0x00000004 );
  TEST_RR_OP( 5,  ror, 0x12345678, 0x12345678, 0x00000000 );
  TEST_RR_OP( 6,  ror, 0xefdeadbe, 0xdeadbeef, 0x00000008 );
  TEST_RR_OP( 7,  ror, 0x00000001, 0x80000000, 0x0000001f );
  TEST_RR_OP( 8,  ror, 0x80000000, 0x00000001, 0x00000021 );

  TEST_RR_SRC1_EQ_DEST( 9,  ror, 0x81234567, 0x12345678, 0x00000004 );
  TEST_RR_SRC2_EQ_DEST( 10, ror, 0x81234567, 0x12345678, 0x00000004 );
  TEST_RR_DEST_BYPASS( 11, 0, ror, 0xefdeadbe, 0xdeadbeef, 0x00000008 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
