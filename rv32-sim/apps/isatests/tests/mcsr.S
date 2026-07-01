# See LICENSE for license details.

#include "riscv_test.h"
#undef RVTEST_RV32S
#define RVTEST_RV32S RVTEST_RV32M
#define __MACHINE_MODE

#include "scsr.S"
