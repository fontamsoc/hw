# See LICENSE for license details.
#*****************************************************************************
# clmulr.S  -  Zbc: rd = reversed word of the carry-less product rs1 (x) rs2
#               (clmulr(a,b) == rev(clmul(rev(a),rev(b))))
#*****************************************************************************
#include "riscv_test.h"
#include "test_macros.h"
RVTEST_RV32U
RVTEST_CODE_BEGIN

  TEST_RR_OP( 2,  clmulr, 0x00000000, 0x00000003, 0x00000003 );
  TEST_RR_OP( 3,  clmulr, 0xaaaaaaaa, 0xffffffff, 0xffffffff );
  TEST_RR_OP( 4,  clmulr, 0x00000002, 0x80000000, 0x00000002 );
  TEST_RR_OP( 5,  clmulr, 0x80000000, 0x80000000, 0x80000000 );
  TEST_RR_OP( 6,  clmulr, 0x1885fbd1, 0xdeadbeef, 0x12345678 );

  TEST_RR_SRC1_EQ_DEST(  7, clmulr, 0xaaaaaaaa, 0xffffffff, 0xffffffff );
  TEST_RR_SRC2_EQ_DEST(  8, clmulr, 0x00000002, 0x80000000, 0x00000002 );
  TEST_RR_SRC12_EQ_DEST( 9, clmulr, 0x80000000, 0x80000000 );

  TEST_RR_DEST_BYPASS( 10, 0, clmulr, 0xaaaaaaaa, 0xffffffff, 0xffffffff );
  TEST_RR_DEST_BYPASS( 11, 1, clmulr, 0x1885fbd1, 0xdeadbeef, 0x12345678 );

  TEST_PASSFAIL
RVTEST_CODE_END
  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
