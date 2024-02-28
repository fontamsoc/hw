// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#ifndef CRT0_H
#define CRT0_H

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

#define __initcall(fn) __asm__ ( \
	".section .initcalls, \"a\"\n" \
	".long "__str__(fn)"\n" \
	".previous\n");	\

#define __STACKSZ 128 /* computed from -fstack-usage outputs */

static unsigned long __stack[__STACKSZ] __attribute__((used));

// Substitute for crt0.S since this is built using -nostdlib.
__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	// Initialize %sp and %fp.
	"rli16 %sp, __stack + "__xstr__(__STACKSZ)"\n"
	//"li8 %fp, 0\n" // ### Disabled, as it is unnecessary.

	"rli16 %1, __initcalls_start\n"
	"rli16 %2, __initcalls_end\n"
	"rli16 %sr, __initcalls_hdlr\n"
	"jl %rp, %sr\n"

	"rli16 %sr, main\n"
	"jl %rp, %sr; j %rp\n"

	".size    _start, (. - _start)\n");

// NOTE: Use absolute adresses from .initcalls{}.
void __initcalls_hdlr (void *start, void *end) {
	while (start < end) {
		(*(void(**)())start)();
		start += sizeof(long);
	}
}

#endif /* CRT0_H */
