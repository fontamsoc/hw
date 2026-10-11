// SPDX-License-Identifier: GPL-2.0-only
// 20260606 (c) William Fonkou Tambe

#ifndef HWDRVCHAR_H
#define HWDRVCHAR_H

// HWDRVCHAR_DATATYPE is the type of the data which an access to the data word
// of the device transfers, which hwdrvchar_read() and hwdrvchar_write() use
// when copying data; it must be defined before including this file, ie:
// uint8_t for a device transferring a byte at a time, as a UART does, or
// uintptr_t for one transferring a word at a time, as dev/spi.sv does.
#ifndef HWDRVCHAR_DATATYPE
#error "HWDRVCHAR_DATATYPE must be defined!"
#endif

// Structure representing a serial device.
// Before initializing the device using hwdrvchar_init(),
// the fields addr must be valid.
typedef struct {
	// Device address.
	void *addr;
	// Size in bytes of the transmit and receive buffer.
	uintptr_t bufsz;
	// Clock frequency in Hz used by the device.
	uintptr_t clkfreq;
} hwdrvchar_t;

// Commands.
#define HWDRVCHAR_CMDDEVRDY         0
#define HWDRVCHAR_CMDGETBUFFERUSAGE 1
#define HWDRVCHAR_CMDSETINTERRUPT   2
#define HWDRVCHAR_CMDSETSPEED       3

// Initialize the serial device at the address given through
// the argument dev->addr using the baudrate given as argument.
// The field dev->bufsz get initialized by this function.
static void hwdrvchar_init (hwdrvchar_t *dev, uintptr_t baudrate) {

	void *addrDat = dev->addr;
	void *addrCmd = (addrDat + sizeof(uintptr_t));

	uintptr_t dat;

	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the serial transmit buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		do {
			dat = ((1<<2) | HWDRVCHAR_CMDGETBUFFERUSAGE);
			dat = _xchg((uintptr_t *)addrCmd, dat);
		} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
		dat = HWDRVCHAR_CMDDEVRDY;
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((intptr_t)dat >> 2); // Wait for the transmit buffer to be empty.

	// Command HWDRVCHAR_CMDSETSPEED to retrieve
	// the clock frequency used by the serial device.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = HWDRVCHAR_CMDSETSPEED;
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	dat = _xchg((uintptr_t *)addrCmd, dat);
	dev->clkfreq = ((intptr_t)dat >> 2);

	// Command HWDRVCHAR_CMDSETSPEED to set
	// the speed to use when sending and receiving bytes.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = (((dev->clkfreq/baudrate)<<2) | HWDRVCHAR_CMDSETSPEED);
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	(void)_xchg((uintptr_t *)addrCmd, dat);

	// Command HWDRVCHAR_CMDSETINTERRUPT to retrieve
	// the size in bytes of the serial transmit
	// and receive buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = HWDRVCHAR_CMDSETINTERRUPT;
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	dat = _xchg((uintptr_t *)addrCmd, dat);
	dev->bufsz = ((intptr_t)dat >> 2);
}

// Return the count of bytes that can be read
// from the serial device without blocking.
static inline uintptr_t hwdrvchar_readable (hwdrvchar_t *dev) {
	void *addrDat = dev->addr;
	void *addrCmd = (addrDat + sizeof(uintptr_t));
	uintptr_t dat;
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the serial receive buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = HWDRVCHAR_CMDGETBUFFERUSAGE;
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	dat = _xchg((uintptr_t *)addrCmd, dat);
	return ((intptr_t)dat >> 2);
}

// Read from the serial device into the buffer given by the
// argument ptr, the byte amount given by the argument sz,
// a HWDRVCHAR_DATATYPE at a time: sz is a multiple of the size
// of HWDRVCHAR_DATATYPE, on which ptr is aligned.
// Return the byte amount read.
static inline uintptr_t hwdrvchar_read (hwdrvchar_t *dev, void *ptr, uintptr_t sz) {
	void *addrDat = dev->addr;
	uintptr_t cnt = 0;
	ptr = __builtin_assume_aligned(ptr, sizeof(HWDRVCHAR_DATATYPE));
	while (sz) {
		uintptr_t n = hwdrvchar_readable(dev);
		if (!n)
			return cnt;
		if (sz >= n)
			sz -= n;
		else {
			n = sz;
			sz = 0;
		}
		cnt += n;
		// The data is stored using __builtin_memcpy(), the buffer
		// being possibly declared of another type than its data.
		do {
			HWDRVCHAR_DATATYPE dat = *((volatile HWDRVCHAR_DATATYPE *)addrDat);
			__builtin_memcpy(ptr, &dat, sizeof(dat));
			ptr += sizeof(dat);
		} while (n -= sizeof(HWDRVCHAR_DATATYPE));
	}
	return cnt;
}

// Return the count of bytes that can be written
// to the serial device without blocking.
static inline uintptr_t hwdrvchar_writable (hwdrvchar_t *dev) {
	void *addrDat = dev->addr;
	void *addrCmd = (addrDat + sizeof(uintptr_t));
	uintptr_t dat;
	// Command HWDRVCHAR_CMDGETBUFFERUSAGE to retrieve
	// the number of bytes in the serial transmit buffer.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = ((1<<2) | HWDRVCHAR_CMDGETBUFFERUSAGE);
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	dat = _xchg((uintptr_t *)addrCmd, dat);
	return (dev->bufsz - ((intptr_t)dat >> 2));
}

// Write to the serial device from the buffer given by the
// argument ptr, the byte amount given by the argument sz,
// a HWDRVCHAR_DATATYPE at a time: sz is a multiple of the size
// of HWDRVCHAR_DATATYPE, on which ptr is aligned.
// Return the byte amount written.
static inline uintptr_t hwdrvchar_write (hwdrvchar_t *dev, void *ptr, uintptr_t sz) {
	void *addrDat = dev->addr;
	uintptr_t cnt = 0;
	ptr = __builtin_assume_aligned(ptr, sizeof(HWDRVCHAR_DATATYPE));
	while (sz) {
		uintptr_t n = hwdrvchar_writable(dev);
		if (!n)
			return cnt;
		if (sz >= n)
			sz -= n;
		else {
			n = sz;
			sz = 0;
		}
		cnt += n;
		// The data is loaded using __builtin_memcpy(), the buffer
		// being possibly declared of another type than its data.
		do {
			HWDRVCHAR_DATATYPE dat;
			__builtin_memcpy(&dat, ptr, sizeof(dat));
			*((volatile HWDRVCHAR_DATATYPE *)addrDat) = dat;
			ptr += sizeof(dat);
		} while (n -= sizeof(HWDRVCHAR_DATATYPE));
	}
	return cnt;
}

// Configure the serial device interrupt.
// When the argument threshold is null, interrupt gets disabled.
// When the argument threshold is non-null, interrupt gets enabled,
// and its value is the receive buffer byte amount that will
// trigger an interrupt.
static inline void hwdrvchar_interrupt (hwdrvchar_t *dev, uintptr_t threshold) {
	void *addrDat = dev->addr;
	void *addrCmd = (addrDat + sizeof(uintptr_t));
	uintptr_t dat;
	// Command HWDRVCHAR_CMDSETINTERRUPT to enable/disable interrupt.
	// The encoding of a command and its argument
	// is as follow: | arg: (ARCHBITSZ-2) bits | cmd: 2 bits |
	do {
		dat = ((threshold<<2) | HWDRVCHAR_CMDSETINTERRUPT);
		dat = _xchg((uintptr_t *)addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	(void)_xchg((uintptr_t *)addrCmd, dat);
}

#endif /* HWDRVCHAR_H */
