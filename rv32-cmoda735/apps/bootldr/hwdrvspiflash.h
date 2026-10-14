// SPDX-License-Identifier: GPL-2.0-only
// 20261008 (c) William Fonkou Tambe

#ifndef HWDRVSPIFLASH_H
#define HWDRVSPIFLASH_H

#include "hwdrvchar.h"

// Structure representing a spiflash device.
// Before initializing the device using hwdrvspiflash_init(),
// the field addr must be valid.
typedef struct hwdrvspiflash {
	// Device address.
	hwdrvchar_t* addr;
	// Capacity in word count, ie: (HWDRVSPIFLASH_SIZE/sizeof(uintptr_t)), set by
	// hwdrvspiflash_init(); null until it succeeds, and after a fatal failure.
	uintptr_t wordcnt;
	// Bitrate in use, set by hwdrvspiflash_init(). The timeouts of the driver
	// are counts of bytes computed from it, ie: 20 ms is (bitrate/400) bytes,
	// hence a caller changing the device speed using hwdrvchar_init() must
	// update it.
	uintptr_t bitrate;
	// Status register 1 of the flash, as the driver read it last.
	uintptr_t sr;
	// Function called while waiting for the flash, as described below;
	// when null, the device gets polled instead.
	void (*wait) (struct hwdrvspiflash *dev, uintptr_t cnt);
} hwdrvspiflash_t;

// Page size in bytes: a page program writes at most a page, within it,
// hence writes are split at its boundaries.
#define HWDRVSPIFLASH_PAGESZ 256

// Capacity in bytes of the flash, 16 MiB by default; the includer may define it
// before including this file. It must be a multiple of HWDRVSPIFLASH_PAGESZ, and
// at most 16 MiB, as the commands used take 3-byte addresses; a smaller value
// restricts the words accessed to the beginning of a larger flash.
#ifndef HWDRVSPIFLASH_SIZE
#define HWDRVSPIFLASH_SIZE 16777216
#endif

// Bitrate set by hwdrvspiflash_init(), 50 Mbps by default; the includer may
// define it before including this file. The highest bitrate of the form
// (clkfreq/(2*n)) which does not exceed it is used, ie: 50 Mbps at 100 MHz,
// 48 Mbps at 96 MHz, 24 Mbps at 48 MHz; it must be at least 400 kbps, the
// bitrate at which the device is initialized. Above about 25 Mbps, the flash
// output reaches the pin too late for "miso_i" to be sampled on the leading edge
// of the clock, hence the device must sample it on the trailing edge, its
// parameter LATESAMPLE being non-null.
#ifndef HWDRVSPIFLASH_BITRATE
#define HWDRVSPIFLASH_BITRATE 50000000
#endif

// Whether hwdrvspiflash_write() checks the block protection, 1 by default; the
// includer may define it before including this file. When non-null, a write
// is refused, nothing being programmed, while any of the bits BP2-BP0 of the
// status register 1 is set, whatever the range it protects; when null, the
// flash itself refuses the page programs within the range protected, which
// some flashes report only by failing every later command, as described below.
// Protections which BP2-BP0 do not show are not checked, and are reported only
// by the flash, ie: the sectors which the PPB or DYB bits of a Spansion S25FL-S
// protect, or the protection of a Winbond W25Q whose CMP or WPS bit is set.
#ifndef HWDRVSPIFLASH_BPCHECK
#define HWDRVSPIFLASH_BPCHECK 1
#endif

// The spiflash device is a SPI NOR flash, ie: the configuration flash of an
// FPGA, attached to the SPI peripheral dev/spi.sv whose parameters CTRLCSHIGH
// and LATESAMPLE are non-null, which is driven using hwdrvchar.h only; as for
// hwdrvchar.h, <_os.h> must be included before this file, and so must the
// definition of HWDRVCHAR_DATATYPE to uintptr_t, as hwdrvchar_read() and
// hwdrvchar_write() access the data word of the device as a HWDRVCHAR_DATATYPE,
// and each access to it transfers a word.
//
// The accesses to the device must be serialized, ie: using a _mutex_t.
// Between calls, the driver leaves the device idle: its transmit buffer usage
// null, its receive buffer empty, and interrupt disabled; and the flash not
// busy, unless a fatal failure happened. Other code may use the device between
// calls, as long as every command transaction it begins completes, and it
// leaves the flash not busy, as a read does not check the flash, which ignores
// it while busy: every transmission of the driver begins with a close, which
// ends what may have been left open, aborted or not, and hwdrvspiflash_init()
// recovers from any other state.
//
// Each command to the flash is a single transmission of the device, as
// described in dev/spi.sv: the control word, during which "cs" is high, as the
// parameter CTRLCSHIGH makes it, then the command, "cs" falling a half-period
// of the clock before it, then its data; a flash taking the first byte after
// the fall of its chip select for the instruction of a command, nothing is sent
// to it before. The device transfers words, each from its least significant byte,
// which comes first in memory: a word maps byte for byte onto the bytes
// transferred. The commands are sent a word at a time, the instruction first,
// followed by the 3 bytes of the address, most significant first, or by bytes
// 0xff; the data read or written begin a word, and are moved straight between
// the device and the buffer of the caller. The commands of a byte, WREN and
// WRDI, which some flashes execute only when their chip select rises right
// after its eighth bit, use the control word 0xffff01ff, whose second byte is
// the count of bytes during which "cs" is low, 1, followed by a word holding
// the instruction then 3 bytes 0xff, sent with "cs" high.
//
// The commands used, supported by the SPI flashes of the Spansion S25FL-S,
// Micron N25Q and Winbond W25Q families among others, are: READ (03h), PAGE
// PROGRAM (02h), WRITE ENABLE (06h), WRITE DISABLE (04h) and READ STATUS
// REGISTER 1 (05h); hence no erase command is ever sent, nor any command which
// changes the configuration of the flash, its protection included. A page
// program only clears bits, an erased byte being 0xff: a write leaves null
// the bits which were null, hence it is to be used on locations which were
// erased, using other means, or with data clearing bits only; writing back the
// data read leaves the flash unchanged. On a Spansion S25FL-S, whose Automatic
// ECC protects each aligned unit of 16 bytes programmed once, programming a unit
// again disables its ECC until it is erased.
// Of the status register 1, only the bits common to those families are used:
// WIP (bit 0), WEL (bit 1) and BP2-BP0 (bits 2 to 4); the bits 5 to 7 differ
// between families and are ignored. A page program is preceded by WREN, then
// a read of the status register 1 checking that WEL is set and WIP null, and when
// HWDRVSPIFLASH_BPCHECK is non-null, that BP2-BP0 are null; WIP is then polled
// until the program completes, and WEL checked null, as a program completed
// clears it. WEL remaining set means that the program was not executed, ie:
// a Micron N25Q refusing to program a sector protected or locked.
//
// The driver never disables preemption: a call may be preempted anywhere, its
// transmission pausing meanwhile, which is legal for the flash. A pause lasting
// PAUSETIMEOUT, 100 ms by default, makes the device abort the transmission, and
// the call then fails as fatal, as described below; an abort in a page program
// raises "cs" at the end of a word, hence the flash programs the bytes which it
// received, a prefix of the page with the data given. Hence a thread preempted
// within a call must run again within 100 ms, which underLineOS insures within
// SCHEDLRHZ, 50 ms, as long as the other contexts keep short their spans with
// preemption disabled, and their interrupt callbacks. A debugger stopping the
// thread within a call fails that call.
//
// The function dev->wait, when non-null, is called only while the flash is
// awaited not busy beyond the first millisecond of a WIP poll, after a page
// program, or by hwdrvspiflash_init() when the flash is busy, hence it must be
// usable before hwdrvspiflash_init(); never while a command or its data are
// transferred. It is called as follow:
// - With preemption enabled, every word waited for being written.
// - Its argument cnt, a count of bytes, a multiple of sizeof(uintptr_t) from
//   sizeof(uintptr_t) to bufsz, is the receive buffer usage waited for, which
//   is reached without further action from the driver, within about 50 us of
//   clocked bytes.
// - The transmission is open, and pauses once cnt is reached.
// The function may return early, the driver checking again; it must return
// promptly once cnt is reached, and in any case within a bound above the longest
// wait, such that the bound plus SCHEDLRHZ remains below PAUSETIMEOUT, ie: 20 ms.
// It may only use hwdrvchar_readable(), hwdrvchar_writable(), and
// hwdrvchar_interrupt() with a threshold from 1 to bufsz: never 0, which would
// close the transmission in progress, and never the data word. Every close
// disabling interrupt, the function is to enable it at every call; a threshold
// of bufsz+1 silences it without a close. Its typical body is as follow, the
// interrupt callback only doing _thread_schedone(&flashwq), as _os_gdbstub.c does:
// 	hwdrvchar_t *c = dev->addr;
// 	hwdrvchar_interrupt(c, cnt);
// 	_preempt_disable();
// 	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
// 		_thread_sleeponwquntil(&flashwq, (_clkcycles() + _MSECS(20)));
// 	_preempt_enable();
// where a null transmit buffer usage means that the transmission was aborted,
// no more bytes coming. The interrupt is enabled before preemption gets
// disabled: an interrupt occurring in-between wakes up no thread, but its
// threshold is then reached, and the receive buffer usage, which nothing reads
// meanwhile, stays at least cnt, hence the check which follows does not sleep;
// an interrupt occurring once preemption is disabled pends until the sleep,
// which it ends, or until _preempt_enable().
//
// A failure is either recoverable, the flash remaining usable, or fatal.
// Recoverable failures are a write refused, nothing being programmed for the
// page concerned, as WEL is null or WIP set after WREN, or BP2-BP0 are not null
// when HWDRVSPIFLASH_BPCHECK is non-null, WRDI being then sent in that last case;
// and a page program not executed, WEL remaining set after it, WRDI being then
// sent.
// Fatal failures set dev->wordcnt null: WIP remaining set 20 ms after a page
// program, and a transmission aborted by the device. While WIP is set, a flash
// ignores every command but the reads of its status registers, hence a page
// program failing on a Spansion S25FL-S, which reports it keeping WIP set
// until a CLEAR STATUS REGISTER (30h) that the driver does not send, fails every
// later call, hwdrvspiflash_init() included, until the flash is powered off.
// A Micron N25Q or a Winbond W25Q reports no such failure through the status
// register 1, the data read back showing it. Those timeouts are counted in bytes
// clocked at dev->bitrate, hence pauses, and a dev->wait slow to return, only
// lengthen them in time.
// While dev->wordcnt is null, ie: the initialization failed, or a fatal failure
// happened, hwdrvspiflash_read() and hwdrvspiflash_write() fail without
// accessing the device, until hwdrvspiflash_init() succeeds.

// The words transferred, those of dev/spi.sv on rv32, are of 4 bytes, which the
// layouts of the transmissions assume; hwdrvchar_read() and hwdrvchar_write()
// transfer them as HWDRVCHAR_DATATYPE.
static_assert((sizeof(uintptr_t) == 4), "the transmissions are laid out in words of 4 bytes");
static_assert((sizeof(HWDRVCHAR_DATATYPE) == sizeof(uintptr_t)),
	"HWDRVCHAR_DATATYPE must be uintptr_t: each access to the data word of the device transfers a word");
static_assert((HWDRVSPIFLASH_SIZE > 0 && HWDRVSPIFLASH_SIZE <= 16777216 && !(HWDRVSPIFLASH_SIZE % HWDRVSPIFLASH_PAGESZ)),
	"HWDRVSPIFLASH_SIZE must be a multiple of HWDRVSPIFLASH_PAGESZ, at most 16 MiB");
static_assert((HWDRVSPIFLASH_BITRATE >= 400000), "HWDRVSPIFLASH_BITRATE must be at least 400 kbps");

// The bits of the status register 1 used.
#define __HWDRVSPIFLASH_SR_WIP 0x01
#define __HWDRVSPIFLASH_SR_WEL 0x02
#define __HWDRVSPIFLASH_SR_BP  0x1c

// Bytes 0xff written to the device, word aligned; not const, since
// hwdrvchar_write() takes a pointer to non-const.
static alignas(uintptr_t) uint8_t __hwdrvspiflash_ff[64] = {
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
};

// State of a transmission: the count of bytes written to the device, and the
// count of bytes read from it, both multiples of the word size, the last byte
// read by __hwdrvspiflash_drain(), and a scratch buffer of 64 bytes, an array
// of words, which receives the words read and stages the words written, its
// bytes being accessed through uint8_t.
typedef struct __hwdrvspiflash_xmit {
	uintptr_t w, r, v;
	uintptr_t bb[64/sizeof(uintptr_t)];
} __hwdrvspiflash_xmit_t;

// Set the device to the highest bitrate of the form (clkfreq/(2*n)) which does
// not exceed the bitrate given as argument, and set dev->bitrate to it; the
// argument of CMDSETSPEED which hwdrvchar_init() computes as (clkfreq/bitrate)
// is then exactly (2*n), which the device does not round further.
// It is used only between transmissions.
static void __hwdrvspiflash_speed (hwdrvspiflash_t *dev, uintptr_t bitrate) {
	hwdrvchar_t *c = dev->addr;
	uintptr_t n = ((c->clkfreq + (2*bitrate) - 1) / (2*bitrate));
	bitrate = (c->clkfreq / (2*n));
	hwdrvchar_init(c, bitrate);
	dev->bitrate = bitrate;
}

// Return non-null when the transmit buffer usage is null, ie: no transmission
// is in progress and no close is pending; it is valid before the field bufsz of
// the hwdrvchar_t is known, as hwdrvchar_writable() computes unsigned.
// It is checked before hwdrvchar_readable(), since every word received is
// readable once the transmit buffer usage is null.
static inline uintptr_t __hwdrvspiflash_idle (hwdrvchar_t *c) {
	return (hwdrvchar_writable(c) == c->bufsz);
}

// Close the transmission in progress, which also disables interrupt;
// nothing is written afterwards until __hwdrvspiflash_idle() is true.
static inline void __hwdrvspiflash_close (hwdrvchar_t *c) {
	hwdrvchar_interrupt(c, 0);
}

// Write the n bytes at p, word aligned, n being a multiple of the word size,
// as room is made for them; no more bytes than hwdrvchar_writable() returns
// being written at a time, the memory interface never stalls. It is the only
// user of hwdrvchar_write(), neither inlined nor cloned, so that the copy loop
// of hwdrvchar_write() exists once in the binary.
static __attribute__((noinline, noclone)) void __hwdrvspiflash_put (
	hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x, uint8_t *p, uintptr_t n) {
	x->w += n;
	while (n) {
		uintptr_t k = hwdrvchar_write(c, p, n);
		p += k;
		n -= k;
	}
}

// Write n bytes 0xff, rounded up to whole words.
static void __hwdrvspiflash_fill (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x, uintptr_t n) {
	n = (((n + sizeof(uintptr_t) - 1) / sizeof(uintptr_t)) * sizeof(uintptr_t));
	while (n) {
		uintptr_t k = ((n < sizeof(__hwdrvspiflash_ff)) ? n : sizeof(__hwdrvspiflash_ff));
		__hwdrvspiflash_put(c, x, __hwdrvspiflash_ff, k);
		n -= k;
	}
}

// Read into p, word aligned, without waiting, up to n of the bytes of the
// transmission received and not read yet, n being a multiple of the word size;
// return the count read. It is the only user of hwdrvchar_read(), neither
// inlined nor cloned, so that the copy loop of hwdrvchar_read() exists once in
// the binary.
static __attribute__((noinline, noclone)) uintptr_t __hwdrvspiflash_take (
	hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x, uint8_t *p, uintptr_t n) {
	if (n > (x->w - x->r))
		n = (x->w - x->r);
	n = hwdrvchar_read(c, p, n);
	x->r += n;
	return n;
}

// Close what may have been left open, read until the device is idle, then read
// the words left in the receive buffer, as the first lines of the transmission
// recipe of dev/spi.sv do.
static void __hwdrvspiflash_recover (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x) {
	uint8_t *bb = (uint8_t *)x->bb;
	__hwdrvspiflash_close(c);
	x->w = (uintptr_t)-1; // The words read are not those of a transmission.
	x->r = 0;
	do __hwdrvspiflash_take(c, x, bb, sizeof(x->bb));
	while (!__hwdrvspiflash_idle(c));
	while (__hwdrvspiflash_take(c, x, bb, sizeof(x->bb)));
}

// Prepare for a transmission, whose control word is written next: close what
// may have been left open, which also ends the discarding that follows a
// transmission aborted and not closed, the device then reading idle; the device
// is then expected idle with its receive buffer empty, the usage checked after
// the close insuring that the close is not pending anymore.
static void __hwdrvspiflash_open (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x) {
	__hwdrvspiflash_close(c);
	if (!__hwdrvspiflash_idle(c) || hwdrvchar_readable(c))
		__hwdrvspiflash_recover(c, x);
	x->w = x->r = 0;
}

// Read the words of the transmission closed, until it has ended, keeping the
// last byte read in x->v; return non-null if every word written was received,
// otherwise the transmission was aborted.
static uintptr_t __hwdrvspiflash_drain (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x) {
	uint8_t *bb = (uint8_t *)x->bb;
	for (;;) {
		uintptr_t e = __hwdrvspiflash_idle(c), k;
		while ((k = __hwdrvspiflash_take(c, x, bb, sizeof(x->bb))))
			x->v = bb[k-1];
		if (e)
			return (x->r == x->w);
	}
}

// Fail as fatal: close the transmission, read until it has ended, and set
// dev->wordcnt null, which requires hwdrvspiflash_init(); return null.
static uintptr_t __hwdrvspiflash_fatal (hwdrvspiflash_t *dev, __hwdrvspiflash_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvspiflash_close(c);
	__hwdrvspiflash_drain(c, x);
	dev->wordcnt = 0;
	return 0;
}

// Open a transmission and write its first two words, staged in the scratch
// buffer: the control word ctl, then the instruction i followed by the 3 bytes
// of the address a, most significant first, for a command taking an address,
// or by 3 bytes 0xff, for a command taking none, a being then -1.
static void __hwdrvspiflash_cmd (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x,
	uintptr_t ctl, uintptr_t i, uintptr_t a) {
	uint8_t *bb = (uint8_t *)x->bb;
	__hwdrvspiflash_open(c, x);
	x->bb[0] = ctl;
	bb[4] = i;
	bb[5] = (a >> 16);
	bb[6] = (a >> 8);
	bb[7] = a;
	__hwdrvspiflash_put(c, x, bb, (2*sizeof(uintptr_t)));
}

// Send the command of a byte i, ie: WREN or WRDI, "cs" rising right after its
// eighth bit, as the count of bytes of the control word 0xffff01ff makes it, the
// 3 bytes 0xff which complete its word being sent with "cs" high. Return null
// if the transmission was aborted.
static uintptr_t __hwdrvspiflash_cmd1 (hwdrvchar_t *c, __hwdrvspiflash_xmit_t *x, uintptr_t i) {
	__hwdrvspiflash_cmd(c, x, 0xffff01ff, i, (uintptr_t)-1);
	__hwdrvspiflash_close(c);
	return __hwdrvspiflash_drain(c, x);
}

// Read the status register 1 using READ STATUS REGISTER (05h), which the flash
// sends in each of the 3 bytes which follow the instruction, the last one read
// being kept, and store it to dev->sr. Return null if the transmission was
// aborted.
static uintptr_t __hwdrvspiflash_rdsr (hwdrvspiflash_t *dev, __hwdrvspiflash_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvspiflash_cmd(c, x, (uintptr_t)-1, 0x05, (uintptr_t)-1);
	__hwdrvspiflash_close(c);
	if (!__hwdrvspiflash_drain(c, x))
		return 0;
	dev->sr = x->v;
	return 1;
}

// Wait until the flash is no longer busy, ie: WIP null, within a single
// transmission of READ STATUS REGISTER (05h), "cs" remaining low, the flash
// sending the status register 1 continuously, a fresh one in each byte: the
// instruction word, then windows of k bytes 0xff, each read whole, the last
// byte of each being the status register 1 to check, stored to dev->sr. A
// window overshooting the end of the program by up to its size, k doubles from
// 8 up to 64 bytes through the first millisecond of those bytes, while the
// driver spins, then up to about 50 us of bytes rounded down to words, dev->wait
// being called for each window, the transmission pausing at its end; at the
// lowest bitrates, where 50 us of bytes is less than 8 bytes, every window is a
// word.
// Return 1 once WIP is null, 0 if it is still set after 20 ms of clocked bytes,
// which the longest page program of the families supported, 5 ms, does not
// reach, and -1 if the transmission was aborted; the transmission is closed
// and has ended on return, and interrupt is disabled.
static intptr_t __hwdrvspiflash_wip (hwdrvspiflash_t *dev, __hwdrvspiflash_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	uint8_t *bb = (uint8_t *)x->bb;
	uintptr_t budget = (dev->bitrate/400), cap = (dev->bitrate/160000), k = 8, n = 0, v = 0xff;
	intptr_t ret = 0;
	if (cap > c->bufsz)
		cap = c->bufsz;
	cap -= (cap % sizeof(uintptr_t));
	if (!cap)
		cap = sizeof(uintptr_t);
	__hwdrvspiflash_cmd(c, x, (uintptr_t)-1, 0x05, (uintptr_t)-1);
	for (;;) {
		// The window written, whose last byte is the status register 1.
		while (x->r != x->w) {
			uintptr_t e = __hwdrvspiflash_idle(c), m;
			if ((m = __hwdrvspiflash_take(c, x, bb, sizeof(x->bb))))
				v = bb[m-1];
			else if (e) { // Idle while open: the transmission was aborted.
				ret = -1;
				goto end;
			}
		}
		if (!(v & __HWDRVSPIFLASH_SR_WIP)) {
			ret = 1;
			break;
		}
		if (!budget)
			break;
		if (k > cap)
			k = cap;
		if (n < (dev->bitrate/8000) && k > 64)
			k = 64;
		if (k > budget)
			k = budget;
		__hwdrvspiflash_fill(c, x, k);
		if (n >= (dev->bitrate/8000) && dev->wait)
			dev->wait(dev, (x->w - x->r));
		budget -= k;
		n += k;
		k *= 2;
	}
end:
	dev->sr = v;
	__hwdrvspiflash_close(c);
	if (!__hwdrvspiflash_drain(c, x))
		ret = -1;
	return ret;
}

// Program the n words at p, word aligned, from the byte address a, within a
// page, using PAGE PROGRAM (02h), once WREN was sent, and the status register 1
// checked, then await the program. Return 1 on success, 0 on a recoverable
// failure: WEL null after WREN, or BP2-BP0 not null when HWDRVSPIFLASH_BPCHECK
// is non-null, nothing being programmed, and WEL remaining set after the
// program, which was not executed; WRDI is then sent, but when WEL was null.
// Return -1 on a fatal failure: WIP still set 20 ms after the program, or a
// transmission aborted.
static intptr_t __hwdrvspiflash_pp (hwdrvspiflash_t *dev, __hwdrvspiflash_xmit_t *x,
	uint8_t *p, uintptr_t a, uintptr_t n) {
	hwdrvchar_t *c = dev->addr;
	if (!__hwdrvspiflash_cmd1(c, x, 0x06) || !__hwdrvspiflash_rdsr(dev, x))
		return -1;
	if ((dev->sr & (__HWDRVSPIFLASH_SR_WIP | __HWDRVSPIFLASH_SR_WEL)) != __HWDRVSPIFLASH_SR_WEL)
		return 0;
	if (HWDRVSPIFLASH_BPCHECK && (dev->sr & __HWDRVSPIFLASH_SR_BP))
		goto wrdi;
	__hwdrvspiflash_cmd(c, x, (uintptr_t)-1, 0x02, a);
	__hwdrvspiflash_put(c, x, p, (n * sizeof(uintptr_t)));
	__hwdrvspiflash_close(c);
	if (!__hwdrvspiflash_drain(c, x) || __hwdrvspiflash_wip(dev, x) <= 0)
		return -1;
	if (!(dev->sr & __HWDRVSPIFLASH_SR_WEL))
		return 1;
wrdi:
	if (!__hwdrvspiflash_cmd1(c, x, 0x04))
		return -1;
	return 0;
}

// Initialize the spiflash device at the address given through
// the argument dev->addr, a hwdrvchar_t whose field addr must be valid,
// the field dev->wait being valid or null; the fields dev->wordcnt,
// dev->bitrate and dev->sr, and the hwdrvchar_t at dev->addr, get
// initialized by this function. It fails if the buffers of the device are
// smaller than 512 bytes, as a page program keeps 264 bytes in flight.
// The bitrate set is HWDRVSPIFLASH_BITRATE, as described with it; the caller may
// change the device speed only between calls, using hwdrvchar_init(), then must
// update dev->bitrate.
// The flash is awaited not busy, then checked answering: WEL must be null after
// WRDI, set after WREN, then null after WRDI again, which fails a flash missing,
// one which ignores the commands, and an output stuck at either level; the
// flash is left with WEL null. Its capacity is not read from it, but given by
// HWDRVSPIFLASH_SIZE.
// On success returns 1 otherwise 0.
static uintptr_t hwdrvspiflash_init (hwdrvspiflash_t *dev) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvspiflash_xmit_t x;
	dev->wordcnt = 0;
	dev->sr = 0xff;
	// A transmission left open ends within (BUFSZ+2) word-times once closed.
	__hwdrvspiflash_recover(c, &x);
	hwdrvchar_init(c, 400000);
	if (c->bufsz < 512)
		return 0;
	__hwdrvspiflash_speed(dev, HWDRVSPIFLASH_BITRATE);
	// A program or erase in progress, ie: one which a reset interrupted, is
	// awaited, as the flash ignores the other commands meanwhile, for 20 ms of
	// clocked bytes at most, which an erase may exceed, the caller then calling
	// again; an output stuck high reads as WIP set.
	if (__hwdrvspiflash_wip(dev, &x) <= 0)
		return 0;
	if (!__hwdrvspiflash_cmd1(c, &x, 0x04) || !__hwdrvspiflash_rdsr(dev, &x) ||
		(dev->sr & (__HWDRVSPIFLASH_SR_WIP | __HWDRVSPIFLASH_SR_WEL)))
		return 0;
	// WRDI follows WREN whatever its outcome, so that WEL is left null.
	uintptr_t r = (__hwdrvspiflash_cmd1(c, &x, 0x06) && __hwdrvspiflash_rdsr(dev, &x) &&
		(dev->sr & (__HWDRVSPIFLASH_SR_WIP | __HWDRVSPIFLASH_SR_WEL)) == __HWDRVSPIFLASH_SR_WEL);
	if (!__hwdrvspiflash_cmd1(c, &x, 0x04) || !__hwdrvspiflash_rdsr(dev, &x) ||
		(dev->sr & (__HWDRVSPIFLASH_SR_WIP | __HWDRVSPIFLASH_SR_WEL)) || !r)
		return 0;
	dev->wordcnt = (HWDRVSPIFLASH_SIZE/sizeof(uintptr_t));
	return 1;
}

// Read cnt words from the spiflash device into the buffer given by the argument
// ptr, which holds cnt words, aligned on a word, ie: on sizeof(uintptr_t) bytes,
// as the words received are stored to it. The index of the first word to read
// is given by the argument idx, its byte address being (idx*sizeof(uintptr_t)).
// The words are read using a single READ (03h), which streams them at the
// bitrate, words 0xff being written to the device as the words received are
// read, at most (bufsz/2) bytes ahead.
// Returns the count of words read, from the first, each at its place in ptr:
// cnt on success, fewer on a fatal failure, the transmission having been
// aborted, the rest of ptr being then undefined; 0 without accessing the device
// when cnt is null, when ptr is not aligned on a word, when the words are beyond
// the flash, or while dev->wordcnt is null.
static uintptr_t hwdrvspiflash_read (hwdrvspiflash_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	// Overflow-safe: (dev->wordcnt - cnt) does not wrap once cnt <= dev->wordcnt.
	if (!cnt || cnt > dev->wordcnt || idx > (dev->wordcnt - cnt) || ((uintptr_t)ptr % sizeof(uintptr_t)))
		return 0;
	hwdrvchar_t *c = dev->addr;
	__hwdrvspiflash_xmit_t x;
	uint8_t *p = ptr;
	// The count of bytes of the transmission, the first byte of the data being
	// the byte (2*sizeof(uintptr_t)), and the bytes kept in flight.
	uintptr_t e = ((cnt + 2) * sizeof(uintptr_t)), ahead = (c->bufsz/2), k;
	__hwdrvspiflash_cmd(c, &x, (uintptr_t)-1, 0x03, (idx * sizeof(uintptr_t)));
	for (;;) {
		// Words 0xff are written once half of those in flight were read.
		if (x.w < e && (x.w - x.r) <= (ahead/2)) {
			k = (ahead - (x.w - x.r));
			if (k > (e - x.w))
				k = (e - x.w);
			__hwdrvspiflash_fill(c, &x, k);
			if (x.w == e)
				__hwdrvspiflash_close(c);
		}
		if (x.r < (2*sizeof(uintptr_t))) // The words of the control word and the command.
			k = __hwdrvspiflash_take(c, &x, (uint8_t *)x.bb, ((2*sizeof(uintptr_t)) - x.r));
		else
			k = __hwdrvspiflash_take(c, &x, (p + (x.r - (2*sizeof(uintptr_t)))), (e - x.r));
		// Every word received is readable once the device is idle: idle with
		// nothing to read, the transmission has ended, every word having been
		// received, or it was aborted.
		if (!k && __hwdrvspiflash_idle(c) && !hwdrvchar_readable(c)) {
			if (x.r == e)
				return cnt;
			k = ((x.r > (2*sizeof(uintptr_t))) ? ((x.r - (2*sizeof(uintptr_t))) / sizeof(uintptr_t)) : 0);
			__hwdrvspiflash_fatal(dev, &x);
			return k;
		}
	}
}

// Write cnt words to the spiflash device from the buffer given by the argument
// ptr, which holds cnt words, aligned on a word as for a read, as the words
// transmitted are loaded from it. The index of the first word to write is given
// by the argument idx, as for a read.
// The words are written using a PAGE PROGRAM (02h) per page which they span,
// each preceded by WREN and awaited, as described above; a page program only
// clears bits, the words being programmed over the content of the flash.
// Returns the count of words written, from the first: cnt on success; after a
// failure, the count of words of the pages programmed before it, the page which
// failed being programmed partly, or not at all, as described above; 0 without
// accessing the device as for a read.
static uintptr_t hwdrvspiflash_write (hwdrvspiflash_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	if (!cnt || cnt > dev->wordcnt || idx > (dev->wordcnt - cnt) || ((uintptr_t)ptr % sizeof(uintptr_t)))
		return 0;
	__hwdrvspiflash_xmit_t x;
	uint8_t *p = ptr;
	uintptr_t n = 0;
	while (n < cnt) {
		// The words up to the end of the page of the word idx.
		uintptr_t k = ((HWDRVSPIFLASH_PAGESZ/sizeof(uintptr_t)) - (idx % (HWDRVSPIFLASH_PAGESZ/sizeof(uintptr_t))));
		if (k > (cnt - n))
			k = (cnt - n);
		intptr_t r = __hwdrvspiflash_pp(dev, &x, p, (idx * sizeof(uintptr_t)), k);
		if (r < 0) {
			__hwdrvspiflash_fatal(dev, &x);
			return n;
		}
		if (!r)
			return n;
		n += k;
		idx += k;
		p += (k * sizeof(uintptr_t));
	}
	return n;
}

#endif /* HWDRVSPIFLASH_H */
