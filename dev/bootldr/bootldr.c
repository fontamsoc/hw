// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

// Block device commands.
#define BLKDEV_RESET ((0*__SIZEOF_POINTER__)+512)
#define BLKDEV_SWAP  ((1*__SIZEOF_POINTER__)+512)
#define BLKDEV_READ  ((2*__SIZEOF_POINTER__)+512)
#define BLKDEV_WRITE ((3*__SIZEOF_POINTER__)+512)

__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	"li16 %3, "__xstr__(BLKDEV_RESET)"\n"
	"rli8 %sr, 0f\n"

	// Wait for controller ready.
	"jl %rp, %sr\n" // return with %1 == 0.

	"stv %3, %3\n" // Initiate controller reset.
	// Wait for controller reset.
	"jl %rp, %sr\n" // return with %1 == 0.

	// Load block with index in %1.
	"li16 %2, "__xstr__(BLKDEV_READ)"\n"
	"stv %1, %2\n" // Initiate block loading.
	// Wait for block load.
	"jl %rp, %sr\n" // return with %1 == 0.

	// Present loaded block in the physical memory.
	"li16 %2, "__xstr__(BLKDEV_SWAP)"\n"
	"ldst %2, %2\n"
	// jnz waits for ldst to complete before branching.
	"jnz %2, %1\n"

	// Function returning with %1 == 0 when device is ready.
	"0: ldv %1, %3\n" // Read status.
	"inc8 %1, -1\n" // Will set null if status was 1(READY).
	"jnz %1, %sr\n"
	"jz %1, %rp\n"

	".p2align 5\n" // 256bits alignment to insure proper hexdump.

	".size    _start, (. - _start)\n");
