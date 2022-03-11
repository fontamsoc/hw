// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Used to stringify.
#define __xstr__(s) __str__(s)
#define __str__(s) #s

#define __STACKSZ 16 /* computed from -fstack-usage outputs */

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
	"rli16 %sr, main\n"
	"j %sr\n" // ### %rp is expected to have been properly set.

	".size    _start, (. - _start)\n");

#define __SERIAL0_ADDR (0x0ff8 /* By convention, the first UART is located at 0x0ff8 */)
#define __SERIAL0_BAUD 115200

#include <hwdrvchar/hwdrvchar.h>
static hwdrvchar __hwdrvchar_dev = {.addr = (void *)__SERIAL0_ADDR};
static inline void serial0_init (void) {
	hwdrvchar_init (&__hwdrvchar_dev, __SERIAL0_BAUD);
}

static int putchar (int c) {
	while (!hwdrvchar_write(&__hwdrvchar_dev, &c, 1));
	return c;
}

static int puts (char *s) {
	char *_s = s;
	unsigned char c;
	while (c = *_s) {
		putchar(c);
		++_s;
	}
	return ((int)_s - (int)s);
}

void main (void) {
	serial0_init();
	puts("ram initialized\n");
}
