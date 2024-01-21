// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#ifndef HWDRVCHAR_H
#define HWDRVCHAR_H

// Structure representing a UART device.
// Before initializing the device using
// init(), the field addr must be valid.
typedef struct {
	// Device address.
	void *addr;
	// Size in bytes of the transmit
	// and receive buffer.
	unsigned long bufsz;
	// Frequency of the device input clk.
	unsigned long clkfreq;
} hwdrvchar;

// Commands.
#define HWDRVCHAR_CMDDEVRDY         0
#define HWDRVCHAR_CMDGETBUFFERUSAGE 1
#define HWDRVCHAR_CMDSETINTERRUPT   2
#define HWDRVCHAR_CMDSETSPEED       3

// Initialize the UART device at the address given through
// the argument dev->addr using the baudrate given as argument.
// The field dev->bufsz get initialized by this function.
static void hwdrvchar_init (hwdrvchar *dev, unsigned long baudrate) {

	unsigned long data;
	void* addr = dev->addr;

	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the UART transmit buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		do {
			data = ((1<<2) | HWDRVCHAR_CMDGETBUFFERUSAGE);
			__asm__ __volatile__ (
				"ldst %0, %1"
				: "+r" (data)
				: "r" (addr+8)
				: "memory");
		} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
		data = HWDRVCHAR_CMDDEVRDY;
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((signed long)data >> 2); // Wait for the transmit buffer to be empty.

	// Command HWDRVCHAR_CMDSETSPEED to retrieve
	// the clock frequency used by the UART device.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = HWDRVCHAR_CMDSETSPEED;
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (data)
		: "r" (addr+8)
		: "memory");
	dev->clkfreq = ((signed long)data >> 2);

	// Command HWDRVCHAR_CMDSETSPEED to set
	// the speed to use when sending and receiving bytes.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = (((dev->clkfreq/baudrate)<<2) | HWDRVCHAR_CMDSETSPEED);
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"stv %0, %1"
		:: "r" (data),
		   "r" (addr+8)
		:  "memory");

	// Command HWDRVCHAR_CMDSETINTERRUPT to retrieve
	// the size in bytes of the UART transmit
	// and receive buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = HWDRVCHAR_CMDSETINTERRUPT;
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (data)
		: "r" (addr+8)
		: "memory");
	dev->bufsz = ((signed long)data >> 2);
}

// Return the count of bytes that can be read
// from the UART device without blocking.
static inline unsigned long hwdrvchar_readable (hwdrvchar *dev) {
	unsigned long data;
	void* addr = dev->addr;
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the UART receive buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = HWDRVCHAR_CMDGETBUFFERUSAGE;
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (data)
		: "r" (addr+8)
		: "memory");
	return ((signed long)data >> 2);
}

// Read from the UART device into the buffer given by the
// argument ptr, the byte amount given by the argument sz.
// Return the byte amount read.
static unsigned long hwdrvchar_read (hwdrvchar *dev, void *ptr, unsigned long sz) {
	void* addr = dev->addr;
	unsigned long cnt = 0;
	while (sz) {
		unsigned long n = hwdrvchar_readable(dev);
		if (!n)
			return cnt;
		if (sz >= n)
			sz -= n;
		else {
			n = sz;
			sz = 0;
		}
		cnt += n;
		do {
			*(unsigned char *)(ptr++) = *((volatile unsigned char *)addr);
		} while (--n);
	}
	return cnt;
}

// Return the count of bytes that can be written
// to the UART device without blocking.
static inline unsigned long hwdrvchar_writable (hwdrvchar *dev) {
	unsigned long data;
	void* addr = dev->addr;
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the UART transmit buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = ((1<<2) | HWDRVCHAR_CMDGETBUFFERUSAGE);
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (data)
		: "r" (addr+8)
		: "memory");
	return (dev->bufsz - ((signed long)data >> 2));
}

// Write to the UART device from the buffer given by the
// argument ptr, the byte amount given by the argument sz.
// Return the byte amount written.
static unsigned long hwdrvchar_write (hwdrvchar *dev, void *ptr, unsigned long sz) {
	void* addr = dev->addr;
	unsigned long cnt = 0;
	while (sz) {
		unsigned long n = hwdrvchar_writable(dev);
		if (!n)
			return cnt;
		if (sz >= n)
			sz -= n;
		else {
			n = sz;
			sz = 0;
		}
		cnt += n;
		do {
			*((volatile unsigned char *)addr) = *(unsigned char *)(ptr++);
		} while (--n);
	}
	return cnt;
}

// Configure the UART device interrupt.
// When the argument threshold is null, interrupt gets disabled.
// When the argument threshold is non-null, interrupt gets enabled,
// and its value is the receive buffer byte amount that will
// trigger an interrupt.
static inline void hwdrvchar_interrupt (hwdrvchar *dev, unsigned long threshold) {
	unsigned long data;
	void* addr = dev->addr;
	// Command HWDRVCHAR_CMDSETINTERRUPT to enable/disable interrupt.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		data = ((threshold<<2) | HWDRVCHAR_CMDSETINTERRUPT);
		__asm__ __volatile__ (
			"ldst %0, %1"
			: "+r" (data)
			: "r" (addr+8)
			: "memory");
	} while ((data & 0b11) != HWDRVCHAR_CMDDEVRDY);
	data = HWDRVCHAR_CMDDEVRDY;
	__asm__ __volatile__ (
		"stv %0, %1"
		:: "r" (data),
		   "r" (addr+8)
		:  "memory");
}

#endif /* HWDRVCHAR_H */
