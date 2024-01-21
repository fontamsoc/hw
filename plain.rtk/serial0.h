// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#ifndef SERIAL0_H
#define SERIAL0_H

#define __SERIAL0_ADDR (0x0ff0 /* By convention, the first UART is located at 0x0ff0 */)
#define __SERIAL0_BAUD 115200

#include <hwdrvchar/hwdrvchar.h>
static hwdrvchar serial0_hwdrvchar = {.addr = (void *)__SERIAL0_ADDR};
void serial0_init (void) {
	hwdrvchar_init (&serial0_hwdrvchar, __SERIAL0_BAUD);
}
__initcall(serial0_init);

static int putchar (int c) {
	while (!hwdrvchar_write(&serial0_hwdrvchar, &c, 1));
	return c;
}

#endif /* SERIAL0_H */
