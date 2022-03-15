// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

// Block device commands.
#define BLKDEV_RESET	0
#define BLKDEV_SWAP	1
#define BLKDEV_READ	2
#define BLKDEV_WRITE	3

__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	"li8 %3, "__xstr__(BLKDEV_RESET)"*"__xstr__(__SIZEOF_POINTER__)"\n"
	"rli8 %sr, 0f\n"

	// Wait for controller ready.
	"jl %rp, %sr\n" // return with %1 == 0.

	"ldst %rp, %3\n" // %rp is non-null, initiating controller reset.
	// Wait for controller reset.
	"jl %rp, %sr\n" // return with %1 == 0.

	// Load block with index in %1.
	"li8 %2, "__xstr__(BLKDEV_READ)"*"__xstr__(__SIZEOF_POINTER__)"\n"
	"ldst %1, %2\n" // Initiate the block loading.
	// Wait for block load.
	"jl %rp, %sr\n" // return with %1 == 0.

	// Present the loaded block in the physical memory.
	"li8 %2, "__xstr__(BLKDEV_SWAP)"*"__xstr__(__SIZEOF_POINTER__)"\n"
	"ldst %2, %2\n"
	// Block device address is 0; hence `j %1` is encoded as `jz %1, %1`
	"jz %1, %1\n"

	// Function returning with %1 == 0 when device is ready.
	"0: li8 %1, 0\n" // Set null to prevent reset when reading status.
	"ldst %1, %3\n" // Read status.
	"inc8 %1, -1\n" // Will set null if status was 1(READY).
	"jnz %1, %sr\n"
	"jz %1, %rp\n"

	".size    _start, (. - _start)\n");
