// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include <stdint.h>

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

#define STACKSZ 8 /* computed from -fstack-usage outputs and sizeof(savedkctx) */

static unsigned long stack[STACKSZ] __attribute__((used));

// Substitute for crt0.S since this is built using -nostdlib.
__asm__ (
	".section .text._start\n"
	".global  _start\n"
	".type    _start, @function\n"
	".p2align 1\n"
	"_start:\n"

	// Initialize %sp and %fp.
	"rli16 %sp, stack + "__xstr__(STACKSZ)"\n" // ### Manually encoding rli16 since linker-relaxation is not yet implemented.
	//"li8 %fp, 0\n" // ### Disabled, as it is unnecessary.
	"rli16 %sr, main\n" // ### Manually encoding rli16 since linker-relaxation is not yet implemented.
	"j %sr\n" // ### Note that %rp is expected to have been properly set.

	".size    _start, (. - _start)\n");

#define UARTADDR (0x0ff8 /* By convention, the first UART is located at 0x0ff8 */)
#define UARTBAUD 115200

#include <hwdrvchar/hwdrvchar.h>
hwdrvchar hwdrvchar_dev = {.addr = (void *)UARTADDR};

int putchar (int c) {
	while (!hwdrvchar_write_(&hwdrvchar_dev, &c, 1));
	return c;
}

#include <print/print.h>

void main (void) {
	hwdrvchar_init (&hwdrvchar_dev, UARTBAUD);
	printstr("ram initialized\n");
}
