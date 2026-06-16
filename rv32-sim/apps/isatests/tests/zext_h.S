# See LICENSE for license details.
#*****************************************************************************
# zext_h.S  -  Zbb: rd = zero-extend halfword (zext.h)
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_R_OP( 2,  zext.h, 0x0000ffff, 0xffffffff );
  TEST_R_OP( 3,  zext.h, 0x00005678, 0x12345678 );
  TEST_R_OP( 4,  zext.h, 0x0000abcd, 0x0000abcd );
  TEST_R_OP( 5,  zext.h, 0x00000000, 0xffff0000 );
  TEST_R_OP( 6,  zext.h, 0x00008000, 0x00008000 );
  TEST_R_OP( 7,  zext.h, 0x0000ffff, 0x0000ffff );

  TEST_R_SRC1_EQ_DEST( 8,  zext.h, 0x0000ffff, 0xffffffff );
  TEST_R_DEST_BYPASS( 9, 0, zext.h, 0x00005678, 0x12345678 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
