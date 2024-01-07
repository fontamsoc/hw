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
#define HWDRVCHAR_CMDGETBUFFERUSAGE 0
#define HWDRVCHAR_CMDSETINTERRUPT   1
#define HWDRVCHAR_CMDSETSPEED       2

// Initialize the UART device at the address given through
// the argument dev->addr using the baudrate given as argument.
// The field dev->bufsz get initialized by this function.
static void hwdrvchar_init (hwdrvchar *dev, unsigned long baudrate) {
	void* addr = dev->addr;
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE == 0 to retrieve
	// the number of bytes in the UART transmit buffer.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	unsigned long bufferusage = ((HWDRVCHAR_CMDGETBUFFERUSAGE<<((sizeof(unsigned long)*8)-2)) | 1);
	do __asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (bufferusage)
		: "r" (addr)
		: "memory");
		while (bufferusage); // Wait for the transmit buffer to be empty.
	// Command HWDRVCHAR_CMDSETSPEED == 2 to retrieve
	// the clock frequency used by the UART device.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	dev->clkfreq = (HWDRVCHAR_CMDSETSPEED<<((sizeof(unsigned long)*8)-2));
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (dev->clkfreq)
		: "r" (addr)
		: "memory");
	// Command HWDRVCHAR_CMDSETSPEED == 2 to set
	// the speed to use when sending and receiving bytes.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	baudrate = ((HWDRVCHAR_CMDSETSPEED<<((sizeof(unsigned long)*8)-2)) + (dev->clkfreq/baudrate));
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (baudrate)
		: "r" (addr)
		: "memory");
	// Command HWDRVCHAR_CMDSETINTERRUPT == 1 to retrieve
	// the size in bytes of the UART transmit
	// and receive buffer.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	dev->bufsz = (HWDRVCHAR_CMDSETINTERRUPT<<((sizeof(unsigned long)*8)-2));
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (dev->bufsz)
		: "r" (addr)
		: "memory");
}

// Return the count of bytes that can be read
// from the UART device without blocking.
static inline unsigned long hwdrvchar_readable (hwdrvchar *dev) {
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE == 0 to retrieve
	// the number of bytes in the UART receive buffer.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	unsigned long bufferusage = (HWDRVCHAR_CMDGETBUFFERUSAGE<<((sizeof(unsigned long)*8)-2));
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (bufferusage)
		: "r" (dev->addr)
		: "memory");
	return bufferusage;
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
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE == 0 to retrieve
	// the number of bytes in the UART transmit buffer.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	unsigned long bufferusage = ((HWDRVCHAR_CMDGETBUFFERUSAGE<<((sizeof(unsigned long)*8)-2)) | 1);
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (bufferusage)
		: "r" (dev->addr)
		: "memory");
	return (dev->bufsz - bufferusage);
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
	// Command HWDRVCHAR_CMDSETINTERRUPT == 1 to enable/disable interrupt.
	// The encoding of a command and its argument
	// is as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
	unsigned long bufferusage = ((HWDRVCHAR_CMDSETINTERRUPT<<((sizeof(unsigned long)*8)-2)) | threshold);
	__asm__ __volatile__ (
		"ldst %0, %1"
		: "+r" (bufferusage)
		: "r" (dev->addr)
		: "memory");
}

#endif /* HWDRVCHAR_H */
