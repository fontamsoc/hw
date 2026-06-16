# See LICENSE for license details.
#*****************************************************************************
# rev8.S  -  Zbb: rd = byte-reverse(rs1)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  rev8, 0x04030201, 0x01020304 );
  TEST_R_OP( 3,  rev8, 0xefbeadde, 0xdeadbeef );
  TEST_R_OP( 4,  rev8, 0x00000000, 0x00000000 );
  TEST_R_OP( 5,  rev8, 0xffffffff, 0xffffffff );
  TEST_R_OP( 6,  rev8, 0x78563412, 0x12345678 );
  TEST_R_OP( 7,  rev8, 0xff000000, 0x000000ff );
  TEST_R_OP( 8,  rev8, 0x000000ff, 0xff000000 );

  TEST_R_SRC1_EQ_DEST( 9,  rev8, 0x78563412, 0x12345678 );
  TEST_R_DEST_BYPASS( 10, 0, rev8, 0xefbeadde, 0xdeadbeef );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
