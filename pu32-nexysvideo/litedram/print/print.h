// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#ifndef PRINT_H
#define PRINT_H

//int putchar (int);

static unsigned char gethex (unsigned char c) {
	c = (c+((c>=10)?('a'-10):'0'));
	return c;
}

static void printhex (unsigned long n) {
	for (unsigned i = 0; i < (2*sizeof(n)); ++i)
		putchar(gethex((n>>(((8*sizeof(n))-4)-(i*4)))&0xf));
}

static void printu8hex (unsigned char n) {
	for (unsigned i = 0; i < (2*sizeof(n)); ++i)
		putchar(gethex((n>>(((8*sizeof(n))-4)-(i*4)))&0xf));
}

// Take a string as argument, and pass each byte to putchar().
static void printstr (unsigned char *str) {
	unsigned char c;
	while (c = *str) {
		putchar(c);
		++str;
	}
}

#endif /* PRINT_H */
