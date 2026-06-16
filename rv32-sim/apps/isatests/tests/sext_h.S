# See LICENSE for license details.
#*****************************************************************************
# sext_h.S  -  Zbb: rd = sign-extend halfword (sext.h)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  sext.h, 0x00007fff, 0x00007fff );
  TEST_R_OP( 3,  sext.h, 0xffff8000, 0x00008000 );
  TEST_R_OP( 4,  sext.h, 0xffffffff, 0x0000ffff );
  TEST_R_OP( 5,  sext.h, 0x00005678, 0x12345678 );
  TEST_R_OP( 6,  sext.h, 0xffffabcd, 0x1234abcd );
  TEST_R_OP( 7,  sext.h, 0x00000000, 0x00000000 );
  TEST_R_OP( 8,  sext.h, 0x00000001, 0xffff0001 );

  TEST_R_SRC1_EQ_DEST( 9,  sext.h, 0xffff8000, 0x00008000 );
  TEST_R_DEST_BYPASS( 10, 0, sext.h, 0xffff8000, 0x00008000 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
