// SPDX-License-Identifier: GPL-2.0-only
// 20260927 (c) William Fonkou Tambe

#ifndef HWDRVSDSPI_H
#define HWDRVSDSPI_H

#include "hwdrvchar.h"

// Structure representing a sdspi device.
// Before initializing the device using hwdrvsdspi_init(),
// the field addr must be valid.
typedef struct hwdrvsdspi {
	// Device address.
	hwdrvchar_t* addr;
	// Capacity in block count.
	uintptr_t blkcnt;
	// Card CSD register, as received: csd[0] is CSD[127:120].
	unsigned char csd[16];
	// Bitrate in use, set by hwdrvsdspi_init(). The timeouts of the driver are
	// counts of bytes computed from it, ie: 100 ms is (bitrate/80) bytes, hence
	// a caller changing the device speed using hwdrvchar_init() must update it.
	uintptr_t bitrate;
	// Bitmap of HWDRVSDSPI_FLAG_SDV2, HWDRVSDSPI_FLAG_MMC
	// and HWDRVSDSPI_FLAG_BLKADDR.
	uintptr_t flags;
	// Function called while waiting for the card, as described below;
	// when null, the device gets polled instead.
	void (*wait) (struct hwdrvsdspi *dev, uintptr_t cnt);
} hwdrvsdspi_t;

#define HWDRVSDSPI_FLAG_SDV2    1 // The card is SD version 2.00 or later.
#define HWDRVSDSPI_FLAG_MMC     2 // The card is MMC.
#define HWDRVSDSPI_FLAG_BLKADDR 4 // The card is block addressed, ie: SDHC or SDXC.

// Block size in bytes.
#define HWDRVSDSPI_BLKSZ 512

// The sdspi device is an SD or MMC card in SPI mode, attached to the SPI
// peripheral dev/spi.sv, which is driven using hwdrvchar.h only; as for
// hwdrvchar.h, <_os.h> must be included before this file.
//
// The accesses to the device must be serialized, ie: using a _mutex_t.
// Between calls, the driver leaves the device idle: its transmit buffer usage
// null, its receive buffer empty, and interrupt disabled. Other code may use
// the device between calls, as long as every command transaction it begins
// completes: every transmission of the driver begins with a close, which ends
// what may have been left open, aborted or not, and hwdrvsdspi_init() recovers
// from any other state.
//
// Each command to the card is a single transmission of the device, as
// described in dev/spi.sv: "cs" remains low from the command through its
// response and data, the data response of a write and the clock cycles which
// follow it included. The driver closes every transmission, and writes the
// next one only once the transmit buffer usage is null. The busy state which
// follows a write is polled using short transmissions, "cs" rising between
// them; delays send clock cycles with "cs" high.
//
// The driver never disables preemption: a call may be preempted anywhere, its
// transmission pausing meanwhile, which is legal for the card. A pause lasting
// PAUSETIMEOUT, 100 ms by default, makes the device abort the transmission, and
// the call then fails as fatal, as described below, unless that transmission
// only polled the busy state or sent clock cycles with "cs" high, where an abort
// is harmless. Hence a thread preempted within a call must run again within
// 100 ms, which underLineOS insures within SCHEDLRHZ, 50 ms, as long as the
// other contexts keep short their spans with preemption disabled, and their
// interrupt callbacks. A debugger stopping the thread within a call fails that
// call.
//
// The function dev->wait, when non-null, is called only while the card is busy
// after a write, while clock cycles are sent with "cs" high, ie: the 250 ms
// after poweron and the 40 ms before each poll of the initialization, and while
// a read waits for its data token beyond its first millisecond; never while a
// command, its response or data bytes are transferred. It is called as follow:
// - With preemption enabled, every byte waited for being written.
// - Its argument cnt, from 1 to bufsz, is the receive buffer usage waited for,
//   which is reached without further action from the driver, within about 10 ms
//   of clocked bytes: transmissions with "cs" high last 10 ms at most, polls of
//   the busy state 100 us at most, and windows waiting for a data token 516
//   bytes at most.
// - The transmission is closed, and ends by itself, except while a read waits
//   for its data token, where the transmission is open, and pauses once cnt
//   is reached.
// The function may return early, the driver checking again; it must return
// promptly once cnt is reached, and in any case within a bound above the longest
// wait, such that the bound plus SCHEDLRHZ remains below PAUSETIMEOUT, ie: 20 ms.
// It may only use hwdrvchar_readable(), hwdrvchar_writable(), and
// hwdrvchar_interrupt() with a threshold from 1 to bufsz: never 0, which would
// close the transmission in progress, and never the data word. Every close
// disabling interrupt, the function is to enable it at every call; a threshold
// of bufsz+1 silences it without a close. Its typical body is as follow, the
// interrupt callback only doing _thread_schedone(&sdwq), as _os_gdbstub.c does:
// 	hwdrvchar_t *c = dev->addr;
// 	hwdrvchar_interrupt(c, cnt);
// 	_preempt_disable();
// 	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
// 		_thread_sleeponwquntil(&sdwq, (_clkcycles() + _MSECS(20)));
// 	_preempt_enable();
// where a null transmit buffer usage means that the transmission ended or was
// aborted, no more bytes coming. The interrupt is enabled before preemption
// gets disabled: an interrupt occurring in-between wakes up no thread, but its
// threshold is then reached, and the receive buffer usage, which nothing reads
// meanwhile, stays at least cnt, hence the check which follows does not sleep;
// an interrupt occurring once preemption is disabled pends until the sleep,
// which it ends, or until _preempt_enable().
//
// A failure is either recoverable, the card remaining usable, or fatal.
// Recoverable failures are a response R1 reporting an error, a data error token,
// a CRC16 mismatch of the data read, and a data response rejecting the data
// written, the busy state which follows it being awaited.
// Fatal failures set dev->blkcnt null: no response R1 within the NCR (Command
// Response Time), 8 bytes at most, a response R1 reporting the idle state to a
// read or a write (the card was reset), no data token within the NAC (Data Read
// Access Time), 100 ms at most, no valid data response, a busy state lasting
// more than 500 ms, and a transmission aborted by the device, other than a poll
// of the busy state or clock cycles sent with "cs" high. Those timeouts are
// counted in bytes clocked at dev->bitrate, hence pauses, and a dev->wait slow
// to return, only lengthen them in time.
// While dev->blkcnt is null, ie: the initialization failed, the card stopped
// answering, or a transmission was aborted, hwdrvsdspi_read() and
// hwdrvsdspi_write() fail without accessing the device, until hwdrvsdspi_init()
// succeeds. After a fatal failure during a transfer, the card may still expect
// or send the rest of a data block, or be busy programming; hwdrvsdspi_init()
// gives it the bytes it needs, then awaits its busy state, before its CMD0.

// Table of the CRC16 of data blocks, polynomial 0x1021.
static const unsigned short __hwdrvsdspi_crc16tab[256] = {
	0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
	0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
	0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
	0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
	0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
	0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
	0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
	0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
	0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
	0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
	0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
	0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
	0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
	0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
	0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
	0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
	0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
	0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
	0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
	0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
	0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
	0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
	0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
	0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
	0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
	0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
	0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
	0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
	0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
	0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
	0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
	0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
};

// Bytes 0xff written to the device; not const, since
// hwdrvchar_write() takes a pointer to non-const.
static unsigned char __hwdrvsdspi_ff[64] = {
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
};

// State of a transmission: the count of bytes written to the device,
// the count of bytes read from it, the last byte read by __hwdrvsdspi_drain(),
// and a scratch buffer of 64 bytes, accessed through unsigned char, and
// declared as an array of words so that its bytes can also be checked
// a word at a time, the words being read through their own type.
typedef struct __hwdrvsdspi_xmit {
	uintptr_t w, r, v;
	uintptr_t bb[64/sizeof(uintptr_t)];
} __hwdrvsdspi_xmit_t;

// Return the CRC7 of the n bytes at p, polynomial 0x09,
// most significant bit first, as a command uses it.
static inline uintptr_t __hwdrvsdspi_crc7 (unsigned char *p, uintptr_t n) {
	uintptr_t crc = 0;
	while (n--) {
		uintptr_t b = *p++;
		for (uintptr_t i = 0; i < 8; ++i, b <<= 1) {
			crc <<= 1;
			if ((b ^ crc) & 0x80)
				crc ^= 0x09;
		}
	}
	return (crc & 0x7f);
}

// Return the CRC16 given as argument updated with the n bytes at p.
static uintptr_t __hwdrvsdspi_crc16 (uintptr_t crc, unsigned char *p, uintptr_t n) {
	while (n--)
		crc = (((crc << 8) ^ __hwdrvsdspi_crc16tab[((crc >> 8) ^ *p++) & 0xff]) & 0xffff);
	return crc;
}

// Set the device to the highest bitrate of the form (clkfreq/(2*n)) which does
// not exceed the bitrate given as argument, and set dev->bitrate to it; the
// argument of CMDSETSPEED which hwdrvchar_init() computes as (clkfreq/bitrate)
// is then exactly (2*n), which the device does not round further.
// It is used only between transmissions.
static void __hwdrvsdspi_speed (hwdrvsdspi_t *dev, uintptr_t bitrate) {
	hwdrvchar_t *c = dev->addr;
	uintptr_t n = ((c->clkfreq + (2*bitrate) - 1) / (2*bitrate));
	bitrate = (c->clkfreq / (2*n));
	hwdrvchar_init(c, bitrate);
	dev->bitrate = bitrate;
}

// Return non-null when the transmit buffer usage is null, ie: no transmission
// is in progress and no close is pending; it is valid before the field bufsz of
// the hwdrvchar_t is known, as hwdrvchar_writable() computes unsigned.
// It is checked before hwdrvchar_readable(), since every byte received is
// readable once the transmit buffer usage is null.
static inline uintptr_t __hwdrvsdspi_idle (hwdrvchar_t *c) {
	return (hwdrvchar_writable(c) == c->bufsz);
}

// Close the transmission in progress, which also disables interrupt;
// nothing is written afterwards until __hwdrvsdspi_idle() is true.
static inline void __hwdrvsdspi_close (hwdrvchar_t *c) {
	hwdrvchar_interrupt(c, 0);
}

// Write the n bytes at p, as room is made for them; no more bytes than
// hwdrvchar_writable() returns being written at a time, the memory interface
// never stalls. It is the only user of hwdrvchar_write(), neither inlined nor
// cloned, so that the byte loop of hwdrvchar_write() exists once in the binary.
static __attribute__((noinline, noclone)) void __hwdrvsdspi_put (
	hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x, unsigned char *p, uintptr_t n) {
	x->w += n;
	while (n) {
		uintptr_t k = hwdrvchar_write(c, p, n);
		p += k;
		n -= k;
	}
}

// Write n bytes 0xff.
static void __hwdrvsdspi_fill (hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x, uintptr_t n) {
	while (n) {
		uintptr_t k = ((n < sizeof(__hwdrvsdspi_ff)) ? n : sizeof(__hwdrvsdspi_ff));
		__hwdrvsdspi_put(c, x, __hwdrvsdspi_ff, k);
		n -= k;
	}
}

// Read into p, without waiting, up to n of the bytes of the transmission
// received and not read yet; return the count read. It is the only user of
// hwdrvchar_read(), neither inlined nor cloned, so that the byte loop of
// hwdrvchar_read() exists once in the binary.
static __attribute__((noinline, noclone)) uintptr_t __hwdrvsdspi_take (
	hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x, unsigned char *p, uintptr_t n) {
	if (n > (x->w - x->r))
		n = (x->w - x->r);
	n = hwdrvchar_read(c, p, n);
	x->r += n;
	return n;
}

// Close what may have been left open, read until the device is idle, then read
// the bytes left in the receive buffer, as the first lines of the transmission
// recipe of dev/spi.sv do.
static void __hwdrvsdspi_recover (hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x) {
	unsigned char *bb = (unsigned char *)x->bb;
	__hwdrvsdspi_close(c);
	x->w = (uintptr_t)-1; // The bytes read are not those of a transmission.
	x->r = 0;
	do __hwdrvsdspi_take(c, x, bb, sizeof(x->bb));
	while (!__hwdrvsdspi_idle(c));
	while (__hwdrvsdspi_take(c, x, bb, sizeof(x->bb)));
}

// Prepare for a transmission, whose control byte is written next: close what
// may have been left open, which also ends the discarding that follows a
// transmission aborted and not closed, the device then reading idle; the device
// is then expected idle with its receive buffer empty, the usage checked after
// the close insuring that the close is not pending anymore.
static void __hwdrvsdspi_open (hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x) {
	__hwdrvsdspi_close(c);
	if (!__hwdrvsdspi_idle(c) || hwdrvchar_readable(c))
		__hwdrvsdspi_recover(c, x);
	x->w = x->r = 0;
}

// Read the bytes of the transmission closed, until it has ended, keeping the
// last byte read in x->v; return non-null if every byte written was received,
// otherwise the transmission was aborted.
static uintptr_t __hwdrvsdspi_drain (hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x) {
	unsigned char *bb = (unsigned char *)x->bb;
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c), k;
		while ((k = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb))))
			x->v = bb[k-1];
		if (e)
			return (x->r == x->w);
	}
}

// Wait until cnt bytes can be read from the transmission closed, every byte
// written, and nothing read yet; return null if it ended before, ie: it was
// aborted. When slp is non-null, dev->wait is called while waiting.
static uintptr_t __hwdrvsdspi_rxwait (hwdrvsdspi_t *dev, uintptr_t cnt, uintptr_t slp) {
	hwdrvchar_t *c = dev->addr;
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		if (hwdrvchar_readable(c) >= cnt)
			return 1;
		if (e)
			return 0;
		if (slp && dev->wait)
			dev->wait(dev, cnt);
	}
}

// Fail as fatal: close the transmission, read until it has ended, and set
// dev->blkcnt null, which requires hwdrvsdspi_init(); return null.
static uintptr_t __hwdrvsdspi_fatal (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvsdspi_close(c);
	__hwdrvsdspi_drain(c, x);
	dev->blkcnt = 0;
	return 0;
}

// Stage in the scratch buffer the n first bytes of the transmission of the
// command i with the argument a: the control byte 0xff and three bytes 0xff,
// which give the card 32 clock cycles with "cs" low, the 6 bytes of the
// command, then bytes 0xff.
static void __hwdrvsdspi_stage (__hwdrvsdspi_xmit_t *x, uintptr_t i, uintptr_t a, uintptr_t n) {
	unsigned char *bb = (unsigned char *)x->bb;
	bb[0] = bb[1] = bb[2] = bb[3] = 0xff;
	bb[4] = (0x40 | i);
	bb[5] = (a >> 24);
	bb[6] = (a >> 16);
	bb[7] = (a >> 8);
	bb[8] = a;
	bb[9] = ((__hwdrvsdspi_crc7(&bb[4], 5) << 1) | 1);
	for (i = 10; i < n; ++i)
		bb[i] = 0xff;
}

// Send the command i with the argument a, as a transmission of 20 bytes, or
// 24 bytes when r4 is non-null, for a response R3 or R7 whose 4 bytes which
// follow R1 get copied to r4. The response R1 is the first byte whose most
// significant bit is null from the byte 10 to 18, the NCR (Command Response
// Time) being 0 to 8 bytes (1 to 8 for MMC), and at least a byte follows the
// response, giving the card the 8 clock cycles it needs. Return R1, or -1 when
// there is none, or when the transmission was aborted.
static intptr_t __hwdrvsdspi_cmd (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x,
	uintptr_t i, uintptr_t a, unsigned char *r4) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t n = (r4 ? 24 : 20);
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, i, a, n);
	__hwdrvsdspi_put(c, x, bb, n);
	__hwdrvsdspi_close(c); // The transmission ends by itself after its last byte.
	if (!__hwdrvsdspi_rxwait(dev, n, 0)) {
		__hwdrvsdspi_drain(c, x);
		return -1;
	}
	__hwdrvsdspi_take(c, x, bb, n);
	__hwdrvsdspi_drain(c, x); // Every byte is read; it reads none.
	for (i = 10; i <= 18; ++i) {
		if (!(bb[i] & 0x80)) {
			if (r4) {
				r4[0] = bb[i+1];
				r4[1] = bb[i+2];
				r4[2] = bb[i+3];
				r4[3] = bb[i+4];
			}
			return bb[i];
		}
	}
	return -1;
}

// Send the command i with the argument a, and receive the data block of L bytes
// which follows, as a single transmission: the command as for __hwdrvsdspi_cmd(),
// R1 from the byte 10 to 18, the data token after the NAC (Data Read Access
// Time), up to 100 ms of bytes 0xff, the data block, its CRC16, and a byte
// giving the card 8 clock cycles.
// Until the data token, (L+4) bytes 0xff at most are written ahead of the bytes
// read, refilled once half of them are read, or, beyond the first millisecond
// waiting for the data token, once all of them are read, then waited for using
// dev->wait; then, the exact remainder of the transmission is written, and it
// is closed. The data block is copied to dst when non-null; its CRC16 is
// checked when chk is non-null, which requires dst non-null. R1 is stored at
// r1, 0xff meaning none.
// Return 1 on success; 0 on a recoverable failure: R1 reporting an error, a data
// error token, or a CRC16 mismatch; -1 on a fatal failure: no R1, R1 reporting
// the idle state, no data token within 100 ms, or the transmission aborted.
static intptr_t __hwdrvsdspi_datain (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x, uintptr_t i,
	uintptr_t a, unsigned char *dst, uintptr_t L, uintptr_t chk, uintptr_t *r1) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t win = (L + 4);
	// Once R1 is received, the index of the byte which follows it, the first of
	// the NAC (Data Read Access Time), the bytes 0xff which precede the data token.
	uintptr_t nac = 0;
	uintptr_t k0, m, q, p;
	intptr_t ret = -1;
	*r1 = 0xff;
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, i, a, 10);
	__hwdrvsdspi_put(c, x, bb, 10);
	__hwdrvsdspi_fill(c, x, win);
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x->r; // Index of the first byte read below.
		if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
			if (e) // Idle while open: the transmission was aborted.
				goto end;
			if (nac && (x->r - nac) >= (dev->bitrate/8000) && dev->wait) {
				// Beyond the first millisecond waiting for the data token,
				// wait for a window of bytes at a time, the transmission
				// pausing at its end; a pause is legal, as is a preemption
				// while spinning otherwise.
				__hwdrvsdspi_fill(c, x, (win - (x->w - x->r)));
				dev->wait(dev, (x->w - x->r));
			}
			continue;
		}
		q = 0;
		if (!nac) {
			// R1 is the first byte whose most significant bit is null
			// from the byte 10 to 18; a card reporting the idle state
			// was reset.
			for (; q < m; ++q) {
				uintptr_t k = (k0 + q);
				if (k < 10)
					continue;
				uintptr_t b = bb[q];
				if (!(b & 0x80)) {
					*r1 = b;
					if (b & 0x01)
						goto end;
					if (b & 0x7e) {
						ret = 0;
						goto end;
					}
					nac = ++k;
					++q;
					break;
				}
				if (k == 18) // No R1.
					goto end;
			}
		}
		if (nac) {
			// Bytes 0xff are skipped, a word at a time when every byte of
			// an aligned word is 0xff; 0xfe is the data token, and any other
			// byte is a data error token.
			for (; q < m; ++q) {
				if (!(q % sizeof(uintptr_t)) && (q + sizeof(uintptr_t)) <= m &&
					x->bb[q/sizeof(uintptr_t)] == (uintptr_t)-1) {
					q += (sizeof(uintptr_t) - 1);
					continue;
				}
				uintptr_t b = bb[q];
				if (b == 0xff)
					continue;
				if (b == 0xfe) {
					p = (k0 + q);
					goto token;
				}
				// A data error token; the bytes written ahead may all have
				// been read, hence a byte is added if needed, giving the card
				// 8 clock cycles after the data error token.
				if (x->w < (k0 + q + 2))
					__hwdrvsdspi_fill(c, x, ((k0 + q + 2) - x->w));
				ret = 0;
				goto end;
			}
			if ((x->r - nac) > (dev->bitrate/80)) // No data token within 100 ms.
				goto end;
		}
		// Beyond the first millisecond waiting for the data token, the window
		// is not refilled at its half: it is read whole, then refilled whole
		// above, where dev->wait is called; otherwise, at the highest bitrates,
		// a byte being received during every iteration, the receive buffer
		// would never be found empty, and dev->wait never called.
		if ((x->w - x->r) <= (win/2) && !(nac && dev->wait && (x->r - nac) >= (dev->bitrate/8000)))
			__hwdrvsdspi_fill(c, x, (win - (x->w - x->r)));
	}
token:
	// The remainder is never negative: the count of bytes written is at most
	// (10+win), or the count of bytes read before a refill plus win, hence at
	// most the greatest of (10+win) and (k0+win), whereas p is at least 11 and k0.
	__hwdrvsdspi_fill(c, x, ((p + L + 4) - x->w));
	__hwdrvsdspi_close(c);
	{
		// Bytes are taken as they are received, without sleeping, which
		// would serialize receiving and reading them.
		uintptr_t o = 0; // Count of bytes of the data block received.
		uintptr_t t = 0; // Count of bytes received after the data block.
		uintptr_t crc = 0, cb = 0;
		for (++q; q < m; ++q) {
			if (o < L) {
				if (dst)
					dst[o] = bb[q];
				++o;
			} else {
				cb = ((cb << 8) | bb[q]);
				++t;
			}
		}
		if (chk)
			crc = __hwdrvsdspi_crc16(0, dst, o);
		for (;;) {
			uintptr_t e = __hwdrvsdspi_idle(c), k;
			if (o < L) {
				unsigned char *d = (dst ? &dst[o] : bb);
				k = (L - o);
				if (!dst && k > sizeof(x->bb))
					k = sizeof(x->bb);
				if ((k = __hwdrvsdspi_take(c, x, d, k))) {
					if (chk)
						crc = __hwdrvsdspi_crc16(crc, d, k);
					o += k;
					continue;
				}
			} else if (t < 3) {
				// The CRC16, then the byte which follows it.
				if ((k = __hwdrvsdspi_take(c, x, bb, (3 - t)))) {
					for (q = 0; q < k; ++q, ++t)
						cb = ((cb << 8) | bb[q]);
					continue;
				}
			} else
				break;
			if (e) // Idle with bytes missing: the transmission was aborted.
				break;
		}
		if (!__hwdrvsdspi_drain(c, x))
			return -1;
		return (!chk || crc == ((cb >> 8) & 0xffff));
	}
end:
	// Once closed, the transmission ends after the bytes 0xff written ahead.
	__hwdrvsdspi_close(c);
	if (!__hwdrvsdspi_drain(c, x))
		ret = -1;
	return ret;
}

// Wait until the card is no longer busy, polling it using transmissions of
// k bytes 0xff, the first being the control byte, k doubling from 1 up to about
// 100 us of bytes; those transmissions being closed, "cs" rising between them,
// dev->wait may be called. Return null if the card is still busy after 500 ms
// of clocked bytes. Interrupt is left disabled.
static uintptr_t __hwdrvsdspi_busy (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	uintptr_t budget = (dev->bitrate/16), cap = (dev->bitrate/80000), k = 1;
	if (cap > c->bufsz)
		cap = c->bufsz;
	if (!cap)
		cap = 1;
	while (budget) {
		if (k > budget)
			k = budget;
		__hwdrvsdspi_open(c, x);
		__hwdrvsdspi_fill(c, x, k);
		__hwdrvsdspi_close(c);
		__hwdrvsdspi_rxwait(dev, k, 1);
		__hwdrvsdspi_drain(c, x);
		budget -= k;
		// The card drives its output low while busy, which the last byte
		// read shows; a transmission aborted before its first byte is repeated.
		if (x->r && x->v == 0xff) {
			__hwdrvsdspi_close(c); // Disable interrupt, which dev->wait may have enabled.
			return 1;
		}
		if ((k *= 2) > cap)
			k = cap;
	}
	__hwdrvsdspi_close(c);
	return 0;
}

// Send the card n bytes 0xff with "cs" high, as transmissions of 10 ms of bytes
// at most, whose control byte is 0xfb; those transmissions being closed,
// dev->wait may be called. A transmission aborted before its end is harmless.
// Interrupt is left disabled.
static void __hwdrvsdspi_clocks (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x, uintptr_t n) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	while (n) {
		uintptr_t k = (dev->bitrate/800);
		if (k > c->bufsz)
			k = c->bufsz;
		if (!k)
			k = 1;
		if (k > n)
			k = n;
		__hwdrvsdspi_open(c, x);
		bb[0] = 0xfb;
		__hwdrvsdspi_put(c, x, bb, 1);
		__hwdrvsdspi_fill(c, x, (k - 1));
		__hwdrvsdspi_close(c);
		__hwdrvsdspi_rxwait(dev, k, 1);
		__hwdrvsdspi_drain(c, x);
		n -= k;
	}
	__hwdrvsdspi_close(c); // Disable interrupt, which dev->wait may have enabled.
}

// Return the capacity in block count, computed from the CSD register:
// for an MMC, or CSD version 1.0, (C_SIZE+1)<<(C_SIZE_MULT+2+READ_BL_LEN-9),
// for CSD version 2.0, (C_SIZE+1)<<10 saturated, otherwise 1.
static uintptr_t __hwdrvsdspi_capacity (hwdrvsdspi_t *dev) {
	unsigned char *csd = dev->csd;
	uintptr_t s = (csd[0] >> 6), n; // CSD_STRUCTURE CSD[127:126].
	if ((dev->flags & HWDRVSDSPI_FLAG_MMC) || !s) {
		// C_SIZE CSD[73:62], C_SIZE_MULT CSD[49:47], READ_BL_LEN CSD[83:80].
		n = ((((csd[6] & 0x03) << 10) | (csd[7] << 2) | (csd[8] >> 6)) + 1);
		s = ((((csd[9] & 0x03) << 1) | (csd[10] >> 7)) + 2 + (csd[5] & 0x0f));
		return ((s < 9) ? (n >> (9 - s)) : (n << (s - 9)));
	} else if (s == 1) {
		// C_SIZE CSD[69:48]; the largest value gives 2^32 blocks.
		n = ((((csd[7] & 0x3f) << 16) | (csd[8] << 8) | csd[9]) + 1);
		return ((n > ((uintptr_t)-1 >> 10)) ? (uintptr_t)-1 : (n << 10));
	}
	return 1;
}

// Initialize the sdspi device at the address given through
// the argument dev->addr, a hwdrvchar_t whose field addr must be valid,
// the field dev->wait being valid or null; the fields dev->blkcnt,
// dev->csd, dev->bitrate and dev->flags, and the hwdrvchar_t at dev->addr,
// get initialized by this function. It takes 260 ms at least, and fails
// if the buffers of the device are smaller than 1024 bytes, as a write keeps
// up to 534 bytes in flight. The bitrate set is the highest that the card
// supports, up to half the clock frequency of the device, ie: 50 Mbps at
// 100 MHz; the caller may change the device speed only between calls, not
// below 400 kbps, using hwdrvchar_init(), then must update dev->bitrate.
// On success returns 1 otherwise 0.
static uintptr_t hwdrvsdspi_init (hwdrvsdspi_t *dev) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvsdspi_xmit_t x;
	unsigned char r4[4];
	uintptr_t r1, budget, n;
	intptr_t r;
	dev->blkcnt = 0;
	dev->flags = 0;
	// A transmission left open ends within (BUFSZ+2) byte-times once closed.
	__hwdrvsdspi_recover(c, &x);
	hwdrvchar_init(c, 400000);
	if (c->bufsz < 1024)
		return 0;
	// 250 ms of clock cycles with "cs" high, covering the time for the card
	// to power up, and the 74 clock cycles it needs before its first command.
	__hwdrvsdspi_speed(dev, 400000);
	__hwdrvsdspi_clocks(dev, &x, (dev->bitrate/32));
	// A card left within a transaction by a failure, whose "cs" rose meanwhile,
	// ie: still sending a data block or expecting the rest of one, is given the
	// bytes it needs with "cs" low: more than a data token, a data block, its
	// CRC16, a data response and 8 bytes; a partial data block written fails its
	// CRC16, CRC checking being on since the CMD59 of the previous initialization.
	// Then the busy state is awaited, since CMD0 would end a write in progress.
	// A card just powered up ignores those bytes, and is not busy.
	__hwdrvsdspi_open(c, &x);
	__hwdrvsdspi_fill(c, &x, (HWDRVSDSPI_BLKSZ + 18));
	__hwdrvsdspi_close(c);
	__hwdrvsdspi_drain(c, &x);
	if (!__hwdrvsdspi_busy(dev, &x))
		return 0;
	// CMD0, software reset, which enters SPI mode, "cs" being low.
	r = __hwdrvsdspi_cmd(dev, &x, 0, 0, 0);
	if (r < 0 || (r & 0x7e))
		return 0;
	// CMD59, turn-on CRC.
	r = __hwdrvsdspi_cmd(dev, &x, 59, 1, 0);
	if (r < 0 || (r & 0x7a))
		return 0;
	// CMD8, check voltage range, illegal for SDv1 and MMC; the response R7
	// must echo the voltage accepted and the check pattern.
	r = __hwdrvsdspi_cmd(dev, &x, 8, 0x1aa, r4);
	if (r < 0)
		return 0;
	if (!(r & 0x04)) {
		if (!(r4[2] & 0x01) || r4[3] != 0xaa)
			return 0;
		dev->flags = HWDRVSDSPI_FLAG_SDV2;
	}
	// Poll the idle state using ACMD41, with HCS if SDv2, or using CMD1 once
	// the card is found to be MMC by CMD55 or ACMD41 being illegal, which for
	// an SDv2 card fails, until the idle state is cleared. Each poll is preceded
	// by 40 ms of clock cycles with "cs" high, as SD 4.4 requires polls less than
	// 50 ms apart when the clock stops between them; the polls last 1 s of
	// clocked bytes counted from the first one, the last poll following that
	// second, as SD 4.2.3 requires the host to poll for at least 1 s.
	for (budget = (dev->bitrate/8), n = 0;; n = (dev->bitrate/200)) {
		// n is null up to the first poll, from which the second is counted.
		__hwdrvsdspi_clocks(dev, &x, (dev->bitrate/200));
		budget = ((budget > n) ? (budget - n) : 0);
		if (!(dev->flags & HWDRVSDSPI_FLAG_MMC)) {
			r = __hwdrvsdspi_cmd(dev, &x, 55, 0, 0);
			budget = ((budget > 20) ? (budget - 20) : 0);
			if (r < 0 || (r & 0x7a))
				return 0;
			if (r & 0x04) {
				if (dev->flags & HWDRVSDSPI_FLAG_SDV2)
					return 0;
				dev->flags |= HWDRVSDSPI_FLAG_MMC;
				// The second is counted from the first CMD1, the delay
				// before it compensated.
				budget = ((dev->bitrate/8) + (dev->bitrate/200));
				continue;
			}
			r = __hwdrvsdspi_cmd(dev, &x, 41, ((dev->flags & HWDRVSDSPI_FLAG_SDV2) ? 0x40000000 : 0), 0);
			budget = ((budget > 20) ? (budget - 20) : 0);
			if (r >= 0 && (r & 0x04) && !(dev->flags & HWDRVSDSPI_FLAG_SDV2)) {
				dev->flags |= HWDRVSDSPI_FLAG_MMC;
				budget = ((dev->bitrate/8) + (dev->bitrate/200)); // As above.
				continue;
			}
		} else {
			r = __hwdrvsdspi_cmd(dev, &x, 1, 0, 0);
			budget = ((budget > 20) ? (budget - 20) : 0);
		}
		if (r < 0 || (r & 0x7e))
			return 0;
		if (!(r & 0x01))
			break;
		if (!budget)
			return 0;
	}
	// CMD6, switch to the high speed mode, unless MMC; a response R1 reporting
	// an error, ie: illegal before SD 1.10, skips it, whereas a data error token
	// fails. The 64 bytes of the switch status are ignored.
	if (!(dev->flags & HWDRVSDSPI_FLAG_MMC)) {
		r = __hwdrvsdspi_datain(dev, &x, 6, 0x80fffff1, 0, 64, 0, &r1);
		if (r < 0 || (!r && !(r1 & 0x7e)))
			return 0;
	}
	// CMD9, the CSD register, its CRC16 checked.
	if (__hwdrvsdspi_datain(dev, &x, 9, 0, dev->csd, 16, 1, &r1) != 1)
		return 0;
	// CMD58, the OCR register, whose bit 30 is set if the card is block addressed.
	r = __hwdrvsdspi_cmd(dev, &x, 58, 0, r4);
	if (r < 0 || (r & 0x7e))
		return 0;
	if (r4[0] & 0x40)
		dev->flags |= HWDRVSDSPI_FLAG_BLKADDR;
	// CMD16, block length of HWDRVSDSPI_BLKSZ bytes.
	r = __hwdrvsdspi_cmd(dev, &x, 16, HWDRVSDSPI_BLKSZ, 0);
	if (r < 0 || (r & 0x7e))
		return 0;
	// The speed is switched last, so that the caller can lower it before
	// any transfer; from TRAN_SPEED CSD[103:96]: 0x5a 50 Mbps, 0x32 25 Mbps,
	// 0x2a 20 Mbps, otherwise 10 Mbps.
	n = dev->csd[3];
	__hwdrvsdspi_speed(dev, ((n == 0x5a) ? 50000000 : (n == 0x32) ? 25000000 :
		(n == 0x2a) ? 20000000 : 10000000));
	dev->blkcnt = __hwdrvsdspi_capacity(dev);
	// A byte addressed card is addressed using (idx<<9), which fits in 32 bits
	// below 2^23 blocks, the capacity of the READ_BL_LEN values not reserved.
	if (!(dev->flags & HWDRVSDSPI_FLAG_BLKADDR) && dev->blkcnt > ((uintptr_t)1 << 23))
		dev->blkcnt = ((uintptr_t)1 << 23);
	return 1;
}

// Read a block from the sdspi device into the buffer given by the argument ptr.
// The index of the block to read is given by the argument idx,
// where a block is HWDRVSDSPI_BLKSZ bytes.
// Returns 1 if block was read, otherwise 0.
static uintptr_t hwdrvsdspi_read (hwdrvsdspi_t *dev, void* ptr, uintptr_t idx) {
	if (idx >= dev->blkcnt)
		return 0;
	__hwdrvsdspi_xmit_t x;
	uintptr_t r1;
	intptr_t r = __hwdrvsdspi_datain(dev, &x, 17,
		((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)), ptr, HWDRVSDSPI_BLKSZ, 1, &r1);
	if (r < 0) { // Fatal; the transmission is closed and has ended.
		dev->blkcnt = 0;
		return 0;
	}
	return r;
}

// Write a block to the sdspi device from the buffer given by the argument ptr.
// The index of the block to write is given by the argument idx,
// where a block is HWDRVSDSPI_BLKSZ bytes.
// Returns 1 if block was written, otherwise 0.
static uintptr_t hwdrvsdspi_write (hwdrvsdspi_t *dev, void* ptr, uintptr_t idx) {
	if (idx >= dev->blkcnt)
		return 0;
	hwdrvchar_t *c = dev->addr;
	__hwdrvsdspi_xmit_t x;
	unsigned char *bb = (unsigned char *)x.bb;
	// The CRC16 is computed before the transmission, bringing ptr in the data cache.
	uintptr_t crc = __hwdrvsdspi_crc16(0, ptr, HWDRVSDSPI_BLKSZ);
	uintptr_t r1 = 0x100, dr = 0x100, v = 0, k0, m, q; // 0x100 meaning none yet.
	// The command and the window of its response R1, the NCR (Command Response
	// Time), the transmission left open, pausing while R1 gets checked.
	__hwdrvsdspi_open(c, &x);
	__hwdrvsdspi_stage(&x, 24, ((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)), 19);
	__hwdrvsdspi_put(c, &x, bb, 19);
	while (r1 > 0xff) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x.r;
		if (!(m = __hwdrvsdspi_take(c, &x, bb, sizeof(x.bb)))) {
			if (e) // Idle while open: the transmission was aborted.
				return __hwdrvsdspi_fatal(dev, &x);
			continue;
		}
		for (q = 0; q < m; ++q) {
			if ((k0 + q) >= 10 && !(bb[q] & 0x80)) {
				r1 = bb[q];
				break;
			}
		}
		if (r1 > 0xff && x.r == x.w) // No R1.
			return __hwdrvsdspi_fatal(dev, &x);
	}
	if (r1) {
		// Rejected, the data block is not sent; a byte gives the card
		// 8 clock cycles after R1. A card reporting the idle state was reset.
		__hwdrvsdspi_put(c, &x, __hwdrvsdspi_ff, 1);
		if (r1 & 0x01)
			return __hwdrvsdspi_fatal(dev, &x);
		__hwdrvsdspi_close(c);
		if (!__hwdrvsdspi_drain(c, &x))
			dev->blkcnt = 0;
		return 0;
	}
	// A byte 0xff, the data token, the data block and its CRC16, the 8 bytes 0xff
	// within which the data response is expected (bytes 535 to 542), then 2 bytes
	// 0xff: the internal write begins a byte after the data response, hence the
	// last byte (544) is busy if the card is.
	bb[0] = 0xff;
	bb[1] = 0xfe;
	__hwdrvsdspi_put(c, &x, bb, 2);
	__hwdrvsdspi_put(c, &x, ptr, HWDRVSDSPI_BLKSZ);
	bb[0] = (crc >> 8);
	bb[1] = crc;
	for (q = 2; q < 12; ++q)
		bb[q] = 0xff;
	__hwdrvsdspi_put(c, &x, bb, 12);
	__hwdrvsdspi_close(c);
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x.r;
		if (!(m = __hwdrvsdspi_take(c, &x, bb, sizeof(x.bb)))) {
			if (e)
				break;
			continue;
		}
		for (q = 0; q < m; ++q) {
			uintptr_t k = (k0 + q);
			if (k >= 535 && k <= 542 && dr > 0xff && bb[q] != 0xff)
				dr = bb[q]; // The data response: the first byte other than 0xff.
			else if (k == 544)
				v = bb[q];
		}
	}
	if (!__hwdrvsdspi_drain(c, &x))
		return __hwdrvsdspi_fatal(dev, &x);
	// The busy state is awaited whether the data was accepted or not, and even
	// without a valid data response, since the initialization which a fatal
	// failure requires begins with CMD0, which would end a write in progress.
	if (v != 0xff && !__hwdrvsdspi_busy(dev, &x))
		return __hwdrvsdspi_fatal(dev, &x);
	// A data response is xxx0sss1: none, or a byte not of that form, ie: a busy
	// state instead, is fatal; sss is 010 when the data was accepted.
	if (dr > 0xff || (dr & 0x11) != 0x01)
		return __hwdrvsdspi_fatal(dev, &x);
	return ((dr & 0x0e) == 0x04);
}

#endif /* HWDRVSDSPI_H */
