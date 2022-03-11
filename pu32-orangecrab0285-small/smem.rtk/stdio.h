// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#ifndef STDIO_H
#define STDIO_H

static int puts (char *s) {
	char *_s = s;
	unsigned char c;
	while (c = *_s) {
		putchar(c);
		++_s;
	}
	return ((int)_s - (int)s);
}

#endif /* STDIO_H */
