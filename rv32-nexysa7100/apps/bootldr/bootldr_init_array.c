// SPDX-License-Identifier: GPL-2.0-only
// 20261020 (c) William Fonkou Tambe

// The functions which bootldr calls before loading the data, as bootldr.c
// describes: litedram_init(), of ../../litedram/litedram.c, initializes and
// calibrates the DDR2 SDRAM of the Nexys A7, which follows its SRAM, and
// raises the end of memory to the end of the DDR2 SDRAM.

#include <stdint.h>

uintptr_t litedram_init (void);

uintptr_t (*const __bootldr_init_array[])(void) = {litedram_init, 0};
