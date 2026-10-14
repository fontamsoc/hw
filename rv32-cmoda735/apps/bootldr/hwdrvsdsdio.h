// SPDX-License-Identifier: GPL-2.0-only
// 20261003 (c) William Fonkou Tambe

#ifndef HWDRVSDSDIO_H
#define HWDRVSDSDIO_H

#include "hwdrvchar.h"

// Structure representing a sdsdio device.
// Before initializing the device using hwdrvsdsdio_init(),
// the field addr must be valid, and so must the field addr of addr[0].
typedef struct hwdrvsdsdio {
	// The serial interfaces of the device: addr[0] is its CMD interface, whose
	// field addr is the device address, and addr[1] its DAT interface, whose
	// field addr hwdrvsdsdio_init() sets, two words further.
	hwdrvchar_t* addr;
	// Capacity in block count.
	uintptr_t blkcnt;
	// Card CSD register, as received: csd[0] is CSD[127:120]; word aligned. It
	// is received again once the card is in the high speed mode, its TRAN_SPEED
	// csd[3] being then 0x5a.
	alignas(uintptr_t) uint8_t csd[16];
	// Bitrate in use, set by hwdrvsdsdio_init(), which both interfaces share. The
	// timeouts of the driver which are counts of clock cycles of the bus are
	// computed from it, ie: 500 ms is (bitrate/2) clock cycles, hence a caller
	// changing the device speed using hwdrvchar_init() must update it.
	uintptr_t bitrate;
	// Bitmap of HWDRVSDSDIO_FLAG_SDV2 and HWDRVSDSDIO_FLAG_BLKADDR.
	uintptr_t flags;
	// Relative card address, which the card published to hwdrvsdsdio_init().
	uintptr_t rca;
	// Function called while waiting for the card, on the DAT interface, as
	// described below; when null, the device gets polled instead.
	void (*wait) (struct hwdrvsdsdio *dev, uintptr_t cnt);
} hwdrvsdsdio_t;

#define HWDRVSDSDIO_FLAG_SDV2    1 // The card is SD version 2.00 or later.
#define HWDRVSDSDIO_FLAG_MMC     2 // Never set: an MMC fails hwdrvsdsdio_init(), as described below.
#define HWDRVSDSDIO_FLAG_BLKADDR 4 // The card is block addressed, ie: SDHC or SDXC.

// Block size in bytes; the SD spec fixes it.
#define HWDRVSDSDIO_BLKSZ 512

// Whether the CRC16 of the data blocks read is checked, 1 by default; the
// includer may define it before including this file. In SD mode, the card always
// checks the CRC7 of the commands and the CRC16 of the data blocks written, which
// the driver hence always computes, and the driver always checks the CRC7 of the
// responses. When null, the CRC16 of the data blocks read is not checked, which
// spares the CPU about 21 of its clock cycles per word read, the reads being
// bounded by the CPU at 50 MHz, a word taking the device 16 clock cycles of a
// CPU at 100 MHz to receive; an error in the transfer of a data block read then
// goes undetected. The CRC16 of the switch status of CMD6, which
// hwdrvsdsdio_init() receives once, is checked regardless.
#ifndef HWDRVSDSDIO_CRC
#define HWDRVSDSDIO_CRC 1
#endif

// Whether multiple block writes pre-erase their data blocks, 0 by default; the
// includer may define it before including this file. When non-null, a multiple
// block write, WRITE_MULTIPLE_BLOCK (CMD25), is preceded by SET_WR_BLK_ERASE_COUNT
// (ACMD23) giving its count of data blocks, which some cards write faster; but
// when the write stops before its last data block, ie: on a failure, the content
// of the data blocks not written is undefined, either erased or their previous
// content. A response R1 to CMD55 or ACMD23 reporting an error fails the write as
// recoverable, nothing being written.
#ifndef HWDRVSDSDIO_PREERASE
#define HWDRVSDSDIO_PREERASE 0
#endif

// The sdsdio device is an SD card in SD mode, attached to the SD host
// peripheral dev/sdio.sv, which is driven using hwdrvchar.h only, through its
// two serial interfaces: its CMD interface transfers the commands and their
// responses on the line CMD, and its DAT interface the data blocks, the CRC
// status tokens and the busy states on the lines DAT0 to DAT3, a bus 4 bits
// wide once initialized; as for hwdrvchar.h, <_os.h> must be included before
// this file, and so must the definition of HWDRVCHAR_DATATYPE to uintptr_t, as
// hwdrvchar_read() and hwdrvchar_write() access the data words of the device as
// a HWDRVCHAR_DATATYPE, and each access to them transfers a word.
//
// The accesses to the device must be serialized, ie: using a _mutex_t.
// Between calls, the driver leaves the device idle: the transmit buffer usage of
// both interfaces null, their receive buffers empty, and interrupt disabled.
// Other code may use the device between calls, as long as every command
// transaction it begins completes: every transaction of the driver begins with a
// close, which ends what may have been left open, aborted or not, and
// hwdrvsdsdio_init() recovers from any other state.
//
// The clock of the card runs only while a transmission of either interface is in
// progress, the lines being clocked together as dev/sdio.sv describes; it stops
// between transmissions, which the card allows, each transaction ending with the
// 8 clock cycles which the card needs before the clock stops.
// Each command to the card is a transmission of the CMD interface whose control
// word, 0xffffffef, chains it to the next one, as dev/sdio.sv describes, followed
// by 2 words, 16 bits 1 and the 48 bits of the command, its end bit ending the
// transmission, which releases the line CMD; the clock then remains stopped,
// while the 3 words received meanwhile are read, until the next transmission of
// the CMD interface begins, which receives the response: its control word,
// 0xfffffffa, waits for the start bit of the response, and keeps it, the
// response then landing in the first bytes received, followed by a word, or by
// 4 words for a response of 136 bits, its last bits giving the card the 8 clock
// cycles it needs. When no response begins within SYNCTIMEOUT, 2 ms by default,
// counted in real time, the device aborts that transmission, nothing being
// received; nothing is received either when the device gave up the chain, as
// described below, the clock having then remained stopped since the end bit of
// the command, while the card may still owe its response, and a part of it only
// when that transmission paused for PAUSETIMEOUT within the response: hence,
// when the response was not received whole, a transmission of the CMD interface
// whose control word, 0xfffffffb, keeps the line CMD released, of 4 words, or 7
// for a response of 136 bits, gives the card the clock cycles to send it, or its
// rest, its words received being ignored, so that the line CMD is never driven
// over a response.
// A command without response, ie: CMD0, is a single transmission, not chained,
// followed by a word of ones, giving the card its 8 clock cycles.
// Each data block is a transmission of the DAT interface. A data block read is
// received by a transmission whose control word, 0x0000ffff, waits on each line
// for its start bit, and discards it, so that its bytes land in whole words,
// followed by the 2 words of its CRC16, a CRC16 per line; that transmission is
// written while the chained command keeps the clock stopped, before the
// transmission which receives the response, both beginning on the same clock, so
// that a data block which begins while the response is received is not missed.
// A data block written is a transmission whose control word, 0xffffffff, is
// followed by a word ending with the start bit, the data block, its CRC16, and a
// word beginning with the end bit; the device sending the lines DAT 7 clock cycles
// late, the transmission ends with the end bit, releasing the lines: the card then
// sends on DAT0 the CRC status token, 2 clock cycles later, and its busy state,
// which a transmission of 4 words whose control word is 0xfff0ffff, not waiting
// for a start bit, receives as 32 samples of DAT0: the token is found from its
// start bit within the first 20 samples, hence also when it comes later than
// those 2 clock cycles, and at least 8 samples follow its end bit, the 8 clock
// cycles which the card needs after it; the busy state which follows is polled
// using transmissions of that control word, and so is the one which follows CMD7
// and CMD12.
// The device transfers words, which hwdrvchar_write() stores to the data word of
// an interface to be transmitted, and hwdrvchar_read() loads from it once
// received: a word maps byte for byte onto the bytes transferred, from its least
// significant byte, which comes first in memory, each most significant bit first;
// on the DAT interface, each byte is transferred 4 bits at a time, its bits (4+i)
// then i on the line DATi. Every transmission is a whole number of words, the
// first being its control word.
//
// The driver never disables preemption: a call may be preempted anywhere, its
// transmission pausing meanwhile, which is legal for the card. A pause lasting
// PAUSETIMEOUT, 100 ms by default, makes the device abort the transmission, and
// the call then fails as fatal, as described below, unless that transmission
// only polled the busy state or sent clock cycles, where an abort is harmless; so
// does a preemption lasting PAUSETIMEOUT between the end of a chained command and
// the transmission which receives its response, the device then giving up the
// chain. Hence a thread preempted within a call must run again within 100 ms,
// which underLineOS insures within SCHEDLRHZ, 50 ms, as long as the other contexts
// keep short their spans with preemption disabled, and their interrupt callbacks.
// Likewise, the device gives up waiting for the start bit of a data block after
// DATSYNCTIMEOUT, 250 ms by default, counted in real time from the beginning of
// the transmission, which precedes the response: it bounds the NAC (Data Read
// Access Time), 100 ms at most, leaving room for a preemption meanwhile. A
// debugger stopping the thread within a call fails that call.
//
// The function dev->wait, when non-null, is called only on the DAT interface,
// addr[1], while the card is busy beyond the first millisecond of clock cycles
// polling it, while clock cycles are sent, ie: the 250 ms after poweron, which
// include the realignment of the lanes, the 40 ms before each poll of the
// initialization, and the realignment of the lanes once a data block was not
// received whole, and while a read waits for the start bit of a data block, beyond
// the first 256 polls of the device, or for the words of a data block which a
// failure leaves to be received and ignored; never while a command, its response
// or the data words kept are transferred. It is called as follow:
// - With preemption enabled, every word of the transmission written, and the
//   transmission closed: it ends by itself.
// - Its argument cnt, a count of bytes, a multiple of sizeof(uintptr_t) from
//   sizeof(uintptr_t) to bufsz, is the receive buffer usage waited for, which is
//   reached without further action from the driver: within about 10 ms of clock
//   cycles while clock cycles are sent, 100 us while the busy state is polled, and
//   within the NAC of the card while a read waits for a data block, unless the
//   device gives up that wait, the transmission being then aborted.
// The function may return early, the driver checking again; it must return
// promptly once cnt is reached, as the polls of the initialization must be less
// than 50 ms apart, 40 ms of clock cycles separating them, and in any case within
// a bound above the longest wait for clock cycles, about 10 ms, ie: 20 ms; a wait
// for a data block, which may last longer, calls it again. Every transmission
// being closed meanwhile, none pauses, hence a dev->wait slow to return only
// lengthens the call in time.
// It may only use hwdrvchar_readable(), hwdrvchar_writable(), and
// hwdrvchar_interrupt() with a threshold from 1 to bufsz, on addr[1]: never 0,
// which would close the transmission in progress, and never the data word. Every
// close disabling the interrupt of its interface, the function is to enable it at
// every call; the device raises its interrupt when the threshold of either
// interface is reached, that of the CMD interface being never enabled. Its typical
// body is as follow, the interrupt callback only doing _thread_schedone(&sdwq), as
// _os_gdbstub.c does:
// 	hwdrvchar_t *c = &dev->addr[1];
// 	hwdrvchar_interrupt(c, cnt);
// 	_preempt_disable();
// 	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
// 		_thread_sleeponwquntil(&sdwq, (_clkcycles() + _MSECS(20)));
// 	_preempt_enable();
// where a null transmit buffer usage means that the transmission ended or was
// aborted, no more words coming. The interrupt is enabled before preemption
// gets disabled: an interrupt occurring in-between wakes up no thread, but its
// threshold is then reached, and the receive buffer usage, which nothing reads
// meanwhile, stays at least cnt, hence the check which follows does not sleep;
// an interrupt occurring once preemption is disabled pends until the sleep,
// which it ends, or until _preempt_enable().
//
// A failure is either recoverable, the card remaining usable, or fatal.
// Recoverable failures are a response R1 reporting an error, ie: OUT_OF_RANGE,
// ADDRESS_ERROR, BLOCK_LEN_ERROR, WP_VIOLATION, CARD_ECC_FAILED, CC_ERROR or
// ERROR, a CRC16 mismatch of the data read when HWDRVSDSDIO_CRC is non-null, a
// CRC status token rejecting the data written, and an error which the responses
// of CMD12 or CMD13 report after a transfer, but OUT_OF_RANGE after a multiple
// block read (SD 4.3.3); a multiple block read or write is then ended by CMD12,
// whose busy state is awaited. A single block read, and a write whose data were
// transmitted, end with SEND_STATUS (CMD13), whether the card accepted them or
// not: an error which the card detects while executing a command, ie:
// CARD_ECC_FAILED while sending a data block, which its CRC16 does not cover, or
// ERROR after a write error, is reported by the response of the next command,
// reading it clearing it; CMD13 hence reports it to the call which caused it, and
// keeps it from being taken for an error of the command of the next call, ie: a
// write command then left expecting its data block. A read whose command is
// rejected returns once the device has given up waiting for its data block,
// after DATSYNCTIMEOUT. COM_CRC_ERROR and ILLEGAL_COMMAND are never errors of the
// response which carries them: they concern the previous command, as the card
// does not respond to a command failing its CRC7, or illegal.
// Fatal failures set dev->blkcnt null: no valid response, ie: none within
// SYNCTIMEOUT, or a response whose transmission bit, index, CRC7 or end bit is
// wrong; no data block within DATSYNCTIMEOUT; no valid CRC status token; a busy
// state lasting more than 500 ms; and a transmission aborted by the device, other
// than a poll of the busy state or clock cycles. A multiple block read or write
// failing as fatal once its command was sent sends CMD12 again as a transmission
// of its own, whose outcome is ignored, so that the card does not remain sending
// or expecting data blocks. The busy states and the initialization are counted in
// clock cycles at dev->bitrate, hence pauses, and a dev->wait slow to return, only
// lengthen them in time, whereas SYNCTIMEOUT, DATSYNCTIMEOUT and PAUSETIMEOUT are
// real time.
// While dev->blkcnt is null, ie: the initialization failed, the card stopped
// answering, or a transmission was aborted, hwdrvsdsdio_read() and
// hwdrvsdsdio_write() fail without accessing the device, until hwdrvsdsdio_init()
// succeeds. After a fatal failure during a transfer, the card may still send or
// expect the rest of a data block, or be busy programming; hwdrvsdsdio_init()
// gives it clock cycles, the lines DAT released, which completes a data block
// written with bits 1 failing its CRC16, sends CMD12, then awaits its busy state,
// before its CMD0. An MMC, which SD mode does not support here, fails the
// initialization, as does a card left in SPI mode, ie: by hwdrvsdspi.h, which only
// a power cycle returns to SD mode.
// A line DAT which does not carry the start bit of a data block while the other
// lines do, ie: open, makes the lane of dev/sdio.sv receiving it give up waiting
// for it alone, the read failing as fatal; the other lanes then keep the words
// which they received beyond those of that lane, which no read reaches, ahead of
// the words which they receive next, as dev/sdio.sv describes. Hence, once a
// transmission which waits for the start bit of a data block is found aborted,
// and in hwdrvsdsdio_init() before its first command, the lanes are realigned, as
// dev/sdio.sv describes: a transmission of the DAT interface whose control word,
// 0xfff0ffff, keeps the lines released without receive flow control, of bufsz
// bytes, ie: as many words as the receive buffer of each lane holds, its control
// word included, closed, fills the receive buffer of every lane, which drops the
// words received while it is full; once it has ended, its words are read until
// the interface is idle and its receive buffer usage null, which empties every
// lane alike. Those (2*bufsz) clock cycles, every line released, ie: 0.33 ms
// at 50 MHz and 41 ms at 400 kHz for a bufsz of 8192 bytes, count among the 250
// ms of clock cycles which begin hwdrvsdsdio_init(). The other transmissions of
// the DAT interface, which do not wait for a start bit, cannot leave the lanes
// misaligned, every lane taking the same words, and ending or pausing with them.

// The words transferred, those of dev/sdio.sv on rv32, are of 4 bytes, which the
// layouts of the transmissions, their control words, and the CRC16 computed a
// word at a time assume; hwdrvchar_read() and hwdrvchar_write() transfer them as
// HWDRVCHAR_DATATYPE.
static_assert((sizeof(uintptr_t) == 4), "the transmissions are laid out in words of 4 bytes");
static_assert((sizeof(HWDRVCHAR_DATATYPE) == sizeof(uintptr_t)),
	"HWDRVCHAR_DATATYPE must be uintptr_t: each access to the data words of the device transfers a word");

// Bytes 0xff written to the device, word aligned; not const, since
// hwdrvchar_write() takes a pointer to non-const.
static alignas(uintptr_t) uint8_t __hwdrvsdsdio_ff[64] = {
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
};

// State of the transmissions of an interface: the count of bytes written to it,
// and the count of bytes read from it, both multiples of the word size, the last
// word read by __hwdrvsdsdio_drain(), and a scratch buffer of 64 bytes, an array
// of words, which receives the words read and stages the words written, its bytes
// being accessed through uint8_t. The functions which use both interfaces take an
// array of two, x[0] for the CMD interface and x[1] for the DAT interface, as
// dev->addr has them.
typedef struct __hwdrvsdsdio_xmit {
	uintptr_t w, r, v;
	uintptr_t bb[64/sizeof(uintptr_t)];
} __hwdrvsdsdio_xmit_t;

// Return the CRC7 of the n bytes at p, n being non-null, polynomial 0x09, most
// significant bit first, as the commands and the responses use it; a byte at a
// time, without table: v is the byte xored with the CRC7 shifted to its top 7
// bits, whose product by x^7 is reduced using x^7 = x^3 + 1, once into the 11
// bits of w, then once more for the 4 bits of w above its 7 bits.
static uintptr_t __hwdrvsdsdio_crc7 (uint8_t *p, uintptr_t n) {
	uintptr_t crc = 0;
	do {
		uintptr_t v = (((crc << 1) ^ *p++) & 0xff);
		uintptr_t w = (v ^ (v << 3));
		uintptr_t h = (w >> 7);
		crc = ((w ^ h ^ (h << 3)) & 0x7f);
	} while (--n);
	return crc;
}

// Return the word w with the 2 nibbles of each of its bytes swapped.
static inline uintptr_t __hwdrvsdsdio_nibswap (uintptr_t w) {
	return (((w & 0x0f0f0f0f) << 4) | ((w >> 4) & 0x0f0f0f0f));
}

// Update the CRC16 of the lines DAT held in crc[0] and crc[1] with the n bytes
// at p, word aligned, n being a non-null multiple of the word size; the words
// are read using __builtin_memcpy(), the buffer not being an array of words,
// which compiles to loads of words, p being aligned.
// The CRC16 of the 4 lines, polynomial 0x1021 each, are together a single CRC of
// the polynomial x^64+x^48+x^20+1, ie: 0x1021 in x^4, over the bytes in memory
// order, each most significant bit first: its remainder of 64 bits holds the bit k
// of the CRC16 of DATi as its bit (4*k+i), hence it is the nibbles of the 16 clock
// cycles of the CRC16 of the 4 lines, the most significant one first. The
// remainder is kept with its 16 nibbles in reverse order, crc[0] holding the
// nibbles 0 to 7 of the remainder, its least significant ones, the nibble 0 at the
// top, and crc[1] its nibbles 8 to 15, the nibble 8 at the top: a word w then only
// has the 2 nibbles of each of its bytes swapped to line up with the remainder, as
// the most significant nibble of a byte is transferred first, and the reduction of
// a word, using x^64 = x^48+x^20+1, is made of shifts by multiples of 4 bits, which
// the reversal turns from left shifts into right shifts.
static void __hwdrvsdsdio_crc16 (uintptr_t *crc, uint8_t *p, uintptr_t n) {
	uintptr_t h = crc[0], l = crc[1];
	uint8_t *e = (p + n);
	p = __builtin_assume_aligned(p, sizeof(uintptr_t));
	do {
		uintptr_t w, t, u;
		__builtin_memcpy(&w, p, sizeof(w));
		t = (l ^ __hwdrvsdsdio_nibswap(w));
		u = (t ^ (t << 16));
		l = (h ^ (u << 12) ^ (u >> 16));
		h = (u ^ (u >> 20));
	} while ((p += sizeof(uintptr_t)) != e);
	crc[0] = h;
	crc[1] = l;
}

// Compute into crc the 2 words which follow the data block of HWDRVSDSDIO_BLKSZ
// bytes at p, word aligned, in its transmission: its CRC16, the remainder of
// __hwdrvsdsdio_crc16() in memory order, its most significant byte first.
static void __hwdrvsdsdio_blkcrc (uint8_t *p, uintptr_t *crc) {
	uintptr_t c[2] = {0, 0};
	__hwdrvsdsdio_crc16(c, p, HWDRVSDSDIO_BLKSZ);
	crc[0] = __hwdrvsdsdio_nibswap(c[1]);
	crc[1] = __hwdrvsdsdio_nibswap(c[0]);
}

// Set the device to the highest bitrate of the form (clkfreq/(2*n)) which does
// not exceed the bitrate given as argument, and set dev->bitrate to it; the
// argument of CMDSETSPEED which hwdrvchar_init() computes as (clkfreq/bitrate)
// is then exactly (2*n), which the device does not round further. The bitrate
// set through the CMD interface is that of both interfaces.
// It is used only between transmissions.
static void __hwdrvsdsdio_speed (hwdrvsdsdio_t *dev, uintptr_t bitrate) {
	hwdrvchar_t *c = &dev->addr[0];
	uintptr_t n = ((c->clkfreq + (2*bitrate) - 1) / (2*bitrate));
	bitrate = (c->clkfreq / (2*n));
	hwdrvchar_init(c, bitrate);
	dev->bitrate = bitrate;
}

// Return non-null when the transmit buffer usage of the interface is null, ie:
// no transmission is in progress and no close is pending; it is valid before the
// field bufsz of the hwdrvchar_t is known, as hwdrvchar_writable() computes
// unsigned. It is checked before hwdrvchar_readable(), since every word received
// is readable once the transmit buffer usage is null.
static inline uintptr_t __hwdrvsdsdio_idle (hwdrvchar_t *c) {
	return (hwdrvchar_writable(c) == c->bufsz);
}

// Close the transmission in progress on the interface, which also disables its
// interrupt; nothing is written afterwards until __hwdrvsdsdio_idle() is true.
static inline void __hwdrvsdsdio_close (hwdrvchar_t *c) {
	hwdrvchar_interrupt(c, 0);
}

// Write the n bytes at p, word aligned, n being a multiple of the word size,
// as room is made for them; no more bytes than hwdrvchar_writable() returns
// being written at a time, the memory interface never stalls. It is the only
// user of hwdrvchar_write(), neither inlined nor cloned, so that the copy loop
// of hwdrvchar_write() exists once in the binary.
static __attribute__((noinline, noclone)) void __hwdrvsdsdio_put (
	hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uint8_t *p, uintptr_t n) {
	x->w += n;
	while (n) {
		uintptr_t k = hwdrvchar_write(c, p, n);
		p += k;
		n -= k;
	}
}

// Write n bytes 0xff, n being a multiple of the word size.
static void __hwdrvsdsdio_fill (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uintptr_t n) {
	while (n) {
		uintptr_t k = ((n < sizeof(__hwdrvsdsdio_ff)) ? n : sizeof(__hwdrvsdsdio_ff));
		__hwdrvsdsdio_put(c, x, __hwdrvsdsdio_ff, k);
		n -= k;
	}
}

// Read into p, word aligned, without waiting, up to n of the bytes of the
// transmissions received and not read yet, n being a multiple of the word size;
// return the count read. It is the only user of hwdrvchar_read(), neither
// inlined nor cloned, so that the copy loop of hwdrvchar_read() exists once in
// the binary.
static __attribute__((noinline, noclone)) uintptr_t __hwdrvsdsdio_take (
	hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uint8_t *p, uintptr_t n) {
	if (n > (x->w - x->r))
		n = (x->w - x->r);
	n = hwdrvchar_read(c, p, n);
	x->r += n;
	return n;
}

// Read into p, word aligned, the n bytes of the transmissions which follow those
// read, n being a multiple of the word size, waiting for them, every one having
// been written; return null if the transmission was aborted, ie: idle with bytes
// missing.
static uintptr_t __hwdrvsdsdio_get (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uint8_t *p, uintptr_t n) {
	while (n) {
		uintptr_t k = __hwdrvsdsdio_take(c, x, p, n);
		// Every word received is readable once the device is idle.
		if (!k && __hwdrvsdsdio_idle(c) && !hwdrvchar_readable(c))
			return 0;
		p += k;
		n -= k;
	}
	return 1;
}

// Read and ignore the bytes of the transmission until the byte e, a multiple of
// the word size, waiting for them, every one before it having been written;
// return null if the transmission was aborted, ie: idle with bytes missing.
static uintptr_t __hwdrvsdsdio_skip (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uintptr_t e) {
	uint8_t *bb = (uint8_t *)x->bb;
	while (x->r < e) {
		uintptr_t n = (e - x->r);
		if (!__hwdrvsdsdio_get(c, x, bb, ((n < sizeof(x->bb)) ? n : sizeof(x->bb))))
			return 0;
	}
	return 1;
}

// Close what may have been left open on the interface, read until it is idle,
// then read the words left in its receive buffer, as the first lines of the
// transmission recipe of dev/spi.sv do.
static void __hwdrvsdsdio_recover (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x) {
	uint8_t *bb = (uint8_t *)x->bb;
	__hwdrvsdsdio_close(c);
	x->w = (uintptr_t)-1; // The words read are not those of a transmission.
	x->r = 0;
	do __hwdrvsdsdio_take(c, x, bb, sizeof(x->bb));
	while (!__hwdrvsdsdio_idle(c));
	while (__hwdrvsdsdio_take(c, x, bb, sizeof(x->bb)));
}

// Prepare for a transmission of the interface, whose control word is written
// next: close what may have been left open, which also ends the discarding that
// follows a transmission aborted and not closed, the interface then reading idle;
// the interface is then expected idle with its receive buffer empty, the usage
// checked after the close insuring that the close is not pending anymore.
static void __hwdrvsdsdio_open (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x) {
	__hwdrvsdsdio_close(c);
	if (!__hwdrvsdsdio_idle(c) || hwdrvchar_readable(c))
		__hwdrvsdsdio_recover(c, x);
	x->w = x->r = 0;
}

// Read the words of the transmission closed, until it has ended, keeping the
// last word read in x->v; return non-null if every word written was received,
// otherwise the transmission was aborted.
static uintptr_t __hwdrvsdsdio_drain (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x) {
	uint8_t *bb = (uint8_t *)x->bb;
	for (;;) {
		uintptr_t e = __hwdrvsdsdio_idle(c), k;
		while ((k = __hwdrvsdsdio_take(c, x, bb, sizeof(x->bb))))
			x->v = x->bb[(k/sizeof(uintptr_t))-1];
		if (e)
			return (x->r == x->w);
	}
}

// Wait until cnt bytes, a multiple of the word size, can be read from the
// transmission closed of the interface c, every word written, and nothing read
// yet; return null if it ended before, ie: it was aborted. When slp is non-null,
// c being the DAT interface, dev->wait is called while waiting.
static uintptr_t __hwdrvsdsdio_rxwait (hwdrvsdsdio_t *dev, hwdrvchar_t *c, uintptr_t cnt, uintptr_t slp) {
	for (;;) {
		uintptr_t e = __hwdrvsdsdio_idle(c);
		if (hwdrvchar_readable(c) >= cnt)
			return 1;
		if (e)
			return 0;
		if (slp && dev->wait)
			dev->wait(dev, cnt);
	}
}

// Realign the lanes of the DAT interface, as described above: its transmission of
// bufsz bytes, whose control word, 0xfff0ffff, keeps the lines released without
// receive flow control, closed, is received whole before any of its words is
// read, every lane filling its receive buffer and dropping the words which do not
// fit, the receive buffer usage, that of the lane holding the fewest words,
// reaching bufsz with the last word received; dev->wait is called meanwhile, for
// about 10 ms of clock cycles at a time, ie: (bitrate/200) bytes more each time.
// Then the words are read until the interface is idle and its receive buffer
// usage null, which empties every lane alike. A transmission aborted before its
// end leaves the lanes as they are. Return the count of clock cycles given to the
// card, (2*bufsz). Interrupt is left disabled.
static uintptr_t __hwdrvsdsdio_realign (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x) {
	hwdrvchar_t *c = &dev->addr[1];
	uintptr_t w = 0xfff0ffff, k = (dev->bitrate/200), n = 0;
	x = &x[1];
	k -= (k % sizeof(uintptr_t));
	if (!k)
		k = sizeof(uintptr_t);
	__hwdrvsdsdio_open(c, x);
	__hwdrvsdsdio_put(c, x, (uint8_t *)&w, sizeof(w));
	__hwdrvsdsdio_fill(c, x, (c->bufsz - sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c);
	do {
		n = (((c->bufsz - n) > k) ? (n + k) : c->bufsz);
	} while (__hwdrvsdsdio_rxwait(dev, c, n, 1) && n != c->bufsz);
	__hwdrvsdsdio_drain(c, x);
	__hwdrvsdsdio_close(c); // Disable interrupt, which dev->wait may have enabled.
	return (2*c->bufsz);
}

// Read the words of the transmission of the DAT interface, closed, until it has
// ended, as __hwdrvsdsdio_drain() does, dev->wait being called while none is
// received, ie: while a read waits for a data block which may never come, the
// device giving up waiting for its start bit after DATSYNCTIMEOUT; return non-null
// if words were written and every one was received, ie: when a data block came;
// otherwise, words missing, the transmission was aborted, and the lanes get
// realigned, as __hwdrvsdsdio_realign() does. Interrupt is left disabled.
static uintptr_t __hwdrvsdsdio_datdrain (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x) {
	hwdrvchar_t *c = &dev->addr[1];
	uint8_t *bb = (uint8_t *)x[1].bb;
	for (;;) {
		uintptr_t e = __hwdrvsdsdio_idle(c);
		if (__hwdrvsdsdio_take(c, &x[1], bb, sizeof(x[1].bb)))
			continue;
		if (e)
			break;
		if (dev->wait)
			dev->wait(dev, sizeof(uintptr_t));
	}
	__hwdrvsdsdio_close(c); // Disable interrupt, which dev->wait may have enabled.
	if (x[1].r == x[1].w)
		return (x[1].w != 0);
	__hwdrvsdsdio_realign(dev, x);
	return 0;
}

// Write the transmission of the DAT interface which receives a data block, of n
// words received, and close it: its control word, 0x0000ffff, waits on each line
// for the start bit of the data block, and discards it, receive flow control
// being enabled, hence its first word received is the first word of the data
// block; then (n-1) words of ones. The previous transmission has ended, closed,
// and every word written to it was received, hence it is not opened again; its
// words may not be all read yet.
static void __hwdrvsdsdio_arm (hwdrvchar_t *c, __hwdrvsdsdio_xmit_t *x, uintptr_t n) {
	uintptr_t w = 0x0000ffff;
	__hwdrvsdsdio_put(c, x, (uint8_t *)&w, sizeof(w));
	__hwdrvsdsdio_fill(c, x, ((n - 1) * sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c);
}

// Stage in the scratch buffer the 4 words of the transmission of the command i
// with the argument a: the control word ctl, in place of which the device
// transmits 32 bits 1, then 2 bytes 0xff, the 6 bytes of the command, its CRC7
// and end bit last, and a word of ones, which only a command without response
// transmits.
static void __hwdrvsdsdio_stage (__hwdrvsdsdio_xmit_t *x, uintptr_t ctl, uintptr_t i, uintptr_t a) {
	uint8_t *bb = (uint8_t *)x->bb;
	x->bb[0] = ctl;
	bb[4] = bb[5] = 0xff;
	bb[6] = (0x40 | i);
	bb[7] = (a >> 24);
	bb[8] = (a >> 16);
	bb[9] = (a >> 8);
	bb[10] = a;
	bb[11] = ((__hwdrvsdsdio_crc7(&bb[6], 5) << 1) | 1);
	x->bb[3] = (uintptr_t)-1;
}

// Send the command i with the argument a, then receive its response of n words
// into the scratch buffer of x[0], n being 2 for a response of 48 bits, 5 for one
// of 136 bits, or null for none. With a response, the command is a transmission
// of 3 words chained to the next one, then, once it has ended, its words received
// read, the response is received by a transmission of n words, whose control word,
// 0xfffffffa, waits for its start bit, and keeps it, as described above; when arm
// is non-null, the transmission of the DAT interface which receives the data
// block of a read, of arm words, as __hwdrvsdsdio_arm() describes, is written
// in-between, the clock being stopped, so that it begins with the receive of the
// response, the DAT interface being opened before the command. Without response,
// the command is a transmission of 4 words, not chained, its last word giving the
// card 8 clock cycles. When the transmission which receives the response does not
// receive it whole, it is followed by a transmission of (n+2) words, whose control
// word, 0xfffffffb, keeps the line CMD released, and whose words received are
// ignored: its (32*(n+2)) clock cycles exceed the 64 of the NCR (Command Response
// Time), the response, and the 8 clock cycles which follow it, hence a card which
// still owes the response, the device having given up the chain, or the rest of
// it, that transmission having paused for PAUSETIMEOUT within it, gets to send it
// before the line CMD gets driven again.
// The response then begins the scratch buffer: its start bit, transmission bit
// and index are its byte 0, ie: the index for R1, R1b, R6 and R7, or 0x3f for R2
// and R3; the 32 bits which follow it for a response of 48 bits, ie: the card
// status of R1, are its bytes 1 to 4, most significant byte first, followed by its
// CRC7 and end bit; and its bytes 1 to 16 are the CID or CSD register of R2, its
// last byte holding its CRC7 and end bit.
// Return 1 when every word was received, and the response is valid: its byte 0
// as above, its CRC7, except for the response R3 of ACMD41, whose 7 bits are then
// 1, and its end bit; return 0 when the response is not valid, or was received in
// part, the transmission being aborted; return -1 when nothing was received, ie:
// the card did not respond within SYNCTIMEOUT, or the device gave up the chain,
// or when the transmission of the command was aborted.
static intptr_t __hwdrvsdsdio_cmd (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uintptr_t i, uintptr_t a, uintptr_t n, uintptr_t arm) {
	hwdrvchar_t *c = &dev->addr[0];
	uint8_t *bb = (uint8_t *)x->bb;
	__hwdrvsdsdio_open(c, x);
	if (arm)
		__hwdrvsdsdio_open(&dev->addr[1], &x[1]);
	__hwdrvsdsdio_stage(x, (n ? 0xffffffef : (uintptr_t)-1), i, a);
	__hwdrvsdsdio_put(c, x, bb, ((n ? 3 : 4) * sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c); // The transmission ends by itself after its last word.
	if (!__hwdrvsdsdio_drain(c, x))
		return -1;
	if (!n)
		return 1;
	// The chained transmission has ended, the clock stopped until the next one,
	// which is written at once, as nothing else may be waited for meanwhile; it
	// is not opened, the transmission which precedes it being closed and drained.
	if (arm)
		__hwdrvsdsdio_arm(&dev->addr[1], &x[1], arm);
	x->w = x->r = 0;
	x->bb[0] = 0xfffffffa;
	x->bb[1] = x->bb[2] = x->bb[3] = x->bb[4] = (uintptr_t)-1;
	__hwdrvsdsdio_put(c, x, bb, (n * sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c);
	if (!__hwdrvsdsdio_rxwait(dev, c, (n * sizeof(uintptr_t)), 0)) {
		__hwdrvsdsdio_drain(c, x);
		// Nothing, or a part of the response, received: the clock cycles of the
		// rest of a response the card may owe.
		a = x->r;
		__hwdrvsdsdio_open(c, x);
		x->bb[0] = 0xfffffffb;
		__hwdrvsdsdio_put(c, x, bb, sizeof(uintptr_t));
		__hwdrvsdsdio_fill(c, x, ((n + 1) * sizeof(uintptr_t)));
		__hwdrvsdsdio_close(c);
		__hwdrvsdsdio_drain(c, x);
		return (a ? 0 : -1);
	}
	__hwdrvsdsdio_take(c, x, bb, (n * sizeof(uintptr_t)));
	__hwdrvsdsdio_drain(c, x); // Every word is read; it reads none.
	if (n > 2)
		return (bb[0] == 0x3f && (bb[16] & 1) && __hwdrvsdsdio_crc7(&bb[1], 15) == (uintptr_t)(bb[16] >> 1));
	if (i == 41)
		return (bb[0] == 0x3f && bb[5] == 0xff);
	return (bb[0] == i && (bb[5] & 1) && __hwdrvsdsdio_crc7(bb, 5) == (uintptr_t)(bb[5] >> 1));
}

// Return non-null when the card status of the valid response R1 in the scratch
// buffer of x[0] reports an error, as described above; OUT_OF_RANGE is ignored
// when oor is null.
static inline uintptr_t __hwdrvsdsdio_r1err (__hwdrvsdsdio_xmit_t *x, uintptr_t oor) {
	uint8_t *bb = (uint8_t *)x->bb;
	return ((bb[1] & (oor ? 0xe4 : 0x64)) | (bb[2] & 0x38));
}

// Return non-null when the card status of the valid response R1 in the scratch
// buffer of x[0] has APP_CMD set, ie: the card takes the next command for an
// application specific command.
static inline uintptr_t __hwdrvsdsdio_appcmd (__hwdrvsdsdio_xmit_t *x) {
	return (((uint8_t *)x->bb)[4] & 0x20);
}

// Wait until the card is no longer busy, ie: until it releases DAT0, polling it
// using transmissions of the DAT interface of k bytes, whose control word,
// 0xfff0ffff, keeps the lines released, followed by words of ones, k
// doubling from a word up to 128 clock cycles, ie: 64 bytes, while the driver
// spins through the first millisecond of clock cycles polled, then up to about
// 100 us of clock cycles rounded down to words, dev->wait being then called for
// each transmission; the clock stops between them, which a busy card allows, each
// giving it the clock edges it needs to end its busy state. The card is no longer
// busy once the 8 samples of DAT0 of the last word received are 1, ie: the bits 4,
// 0, 12, 8, 20, 16, 28 and 24 of that word, in the order they were received.
// Return null if the card is still busy after 500 ms of clock cycles. Interrupt
// is left disabled.
static uintptr_t __hwdrvsdsdio_busy (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x) {
	hwdrvchar_t *c = &dev->addr[1];
	// Counts of bytes of the DAT interface, 2 clock cycles each: 500 ms, 1 ms,
	// and 100 us.
	uintptr_t budget = ((dev->bitrate/4) & ~(sizeof(uintptr_t) - 1)), ms = (dev->bitrate/2000);
	uintptr_t cap = (dev->bitrate/20000), k = sizeof(uintptr_t), n = 0, w = 0xfff0ffff;
	x = &x[1];
	if (cap > c->bufsz)
		cap = c->bufsz;
	cap -= (cap % sizeof(uintptr_t));
	if (!cap)
		cap = sizeof(uintptr_t);
	while (budget) {
		uintptr_t m = ((n < ms && cap > 64) ? 64 : cap);
		if (k > m)
			k = m;
		if (k > budget)
			k = budget;
		__hwdrvsdsdio_open(c, x);
		__hwdrvsdsdio_put(c, x, (uint8_t *)&w, sizeof(w));
		__hwdrvsdsdio_fill(c, x, (k - sizeof(uintptr_t)));
		__hwdrvsdsdio_close(c);
		__hwdrvsdsdio_rxwait(dev, c, k, (n >= ms));
		__hwdrvsdsdio_drain(c, x);
		budget -= k;
		n += k;
		// The card drives DAT0 low while busy, which the last word read shows;
		// a transmission aborted before its first word is repeated.
		if (x->r && (x->v & 0x11111111) == 0x11111111) {
			__hwdrvsdsdio_close(c); // Disable interrupt, which dev->wait may have enabled.
			return 1;
		}
		k *= 2;
	}
	__hwdrvsdsdio_close(c);
	return 0;
}

// Send the card n clock cycles, rounded up to whole words of 8 clock cycles,
// every line released, as transmissions of the DAT interface of 10 ms of clock
// cycles at most, whose control word is 0xfff0ffff, followed by words of ones;
// those transmissions being closed, dev->wait may be called. A transmission
// aborted before its end is harmless. Interrupt is left disabled.
static void __hwdrvsdsdio_clocks (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x, uintptr_t n) {
	hwdrvchar_t *c = &dev->addr[1];
	uintptr_t w = 0xfff0ffff;
	x = &x[1];
	// In bytes, 2 clock cycles each.
	n = (((n + (2*sizeof(uintptr_t)) - 1) / (2*sizeof(uintptr_t))) * sizeof(uintptr_t));
	while (n) {
		uintptr_t k = (dev->bitrate/200);
		if (k > c->bufsz)
			k = c->bufsz;
		k -= (k % sizeof(uintptr_t));
		if (!k)
			k = sizeof(uintptr_t);
		if (k > n)
			k = n;
		__hwdrvsdsdio_open(c, x);
		__hwdrvsdsdio_put(c, x, (uint8_t *)&w, sizeof(w));
		__hwdrvsdsdio_fill(c, x, (k - sizeof(uintptr_t)));
		__hwdrvsdsdio_close(c);
		__hwdrvsdsdio_rxwait(dev, c, k, 1);
		__hwdrvsdsdio_drain(c, x);
		n -= k;
	}
	__hwdrvsdsdio_close(c); // Disable interrupt, which dev->wait may have enabled.
}

// Receive into dst, word aligned, the data block of L bytes, a multiple of the
// word size, which the transmission of the DAT interface in progress receives,
// armed as __hwdrvsdsdio_arm() describes, none of its words read yet: the words
// of the data block are read straight into dst, by chunks of as many as were
// received, without sleeping, which would serialize receiving and reading them,
// the CRC16 being updated with each chunk, when chk is non-null, while the next
// ones are received; then its 2 words of CRC16, and the t words which follow
// them in the transmission, are read into the scratch buffer of x[1].
// While the first word of the data block is awaited, ie: the NAC (Data Read
// Access Time), the device is polled 256 times, about 200 us at 100 MHz, which
// covers the gaps between the data blocks of a READ_MULTIPLE_BLOCK (CMD18), then
// dev->wait is called; the device gives up waiting for the start bit after
// DATSYNCTIMEOUT.
// When nxt is non-null, the next data block of a CMD18 is armed, its transmission
// being of nxt words, once the transmission of this one has ended, every word of
// it received, the clock having stopped before its end bit, which is legal: when
// a chunk read holds every word of the data block left, ie: the CPU is behind the
// device, the transmission has likely ended, and the next data block is armed
// before that chunk gets checked, so that the card sends it meanwhile; otherwise,
// once the CRC16 is read. When nxt is null, the transmission is drained once read.
// Return 1 when every word through the CRC16 was received, the CRC16 matching
// when chk is non-null, 0 on a CRC16 mismatch, and -1 when the transmission was
// aborted, ie: idle with words missing. Interrupt is left disabled.
static intptr_t __hwdrvsdsdio_rdblk (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *dst, uintptr_t L, uintptr_t t, uintptr_t nxt, uintptr_t chk) {
	hwdrvchar_t *c = &dev->addr[1];
	uintptr_t crc[2] = {0, 0}, n = L, s = 0, a = 0, k, e = (L + ((2 + t) * sizeof(uintptr_t)));
	intptr_t ret = -1;
	x = &x[1];
	// The indexes are rebased at the first byte of the transmission of this data
	// block, the words of the previous transmissions being all read; it ends at e.
	x->w -= x->r;
	x->r = 0;
	dst = __builtin_assume_aligned(dst, sizeof(uintptr_t));
	while (n) {
		if (!(k = __hwdrvsdsdio_take(c, x, dst, n))) {
			// Every word received is readable once the device is idle, which
			// a preemption since the take may have made it: those words are
			// taken next, dev->wait being called only while it is not.
			if (__hwdrvsdsdio_idle(c)) {
				if (!hwdrvchar_readable(c))
					goto done;
			} else if (n == L && ++s > 256 && dev->wait)
				dev->wait(dev, sizeof(uintptr_t));
			continue;
		}
		if (k == n && nxt && !a && __hwdrvsdsdio_idle(c)) {
			// The transmission has ended: every word received is readable,
			// those missing were not received, ie: it was aborted.
			if ((x->r + hwdrvchar_readable(c)) < e)
				goto done;
			__hwdrvsdsdio_arm(c, x, nxt);
			a = 1;
		}
		if (chk)
			__hwdrvsdsdio_crc16(crc, dst, k);
		dst += k;
		n -= k;
	}
	if (!__hwdrvsdsdio_get(c, x, (uint8_t *)x->bb, ((2 + t) * sizeof(uintptr_t))))
		goto done;
	if (!nxt)
		__hwdrvsdsdio_drain(c, x); // Every word is read; it reads none.
	else if (!a) {
		// Every word received, the transmission ends at once.
		while (!__hwdrvsdsdio_idle(c));
		__hwdrvsdsdio_arm(c, x, nxt);
	}
	ret = 1;
	if (chk) {
		// The CRC16 updated with the 2 words of the CRC16 received is null when
		// they match.
		__hwdrvsdsdio_crc16(crc, (uint8_t *)x->bb, (2*sizeof(uintptr_t)));
		ret = !(crc[0] | crc[1]);
	}
	done:
	if (s > 256)
		__hwdrvsdsdio_close(c); // Disable interrupt, which dev->wait may have enabled.
	return ret;
}

// Decode the CRC status token which the 4 words at w received on DAT0, as 32
// samples, ie: in the bits 4 then 0 of their bytes, in the order of the bytes,
// the first sample being that of the clock cycle which follows the end bit of the
// data block: its start bit is the first null sample within the first 20, the
// token being found even when it comes later than the 2 clock cycles after the
// end bit which the SD spec gives, followed by its 3 status bits and its end bit,
// which must be 1; hence at least the 8 samples of the last word follow the end
// bit, which are the 8 clock cycles that the card needs after the CRC status
// token (4.4 of the SD Physical Layer Specification). Return the status bits,
// 0b010 when the data block was accepted, 0b101 when its CRC16 was wrong,
// otherwise a write error, or'ed with 8 when the card is busy, ie: when the 8
// samples of DAT0 of the last word are not all 1; return -1 when there is no
// valid token.
static intptr_t __hwdrvsdsdio_token (uintptr_t *w) {
	uint8_t *b = (uint8_t *)w;
	uintptr_t t = 0, q;
	// The samples, the first at the bit 31 of t.
	for (q = 0; q < 16; ++q)
		t = ((t << 2) | ((b[q] >> 3) & 2) | (b[q] & 1));
	for (q = 31; q >= 12 && ((t >> q) & 1); --q);
	if (q < 12 || !((t >> (q - 4)) & 1))
		return -1;
	return (intptr_t)(((t >> (q - 3)) & 7) | (((t & 0xff) != 0xff) ? 8 : 0));
}

// Transmit the data block at p, word aligned, which follows a write command, as
// a transmission of the DAT interface of 133 words, as dev/sdio.sv describes: the
// control word 0xffffffff, the word 0xf0ffffff, whose last nibble transmitted is
// the start bit, the HWDRVSDSDIO_BLKSZ bytes of the data block, its CRC16, the 2
// words at crc, then a word of ones, whose first nibble transmitted is the end
// bit; the device sending the lines DAT 7 clock cycles late, the transmission ends
// right after the end bit, which releases the lines. When now is non-null, the
// CRC16 is computed into crc once the data block is queued, while it is
// transmitted, the transmission pausing if the CPU is late, which is legal;
// otherwise crc holds it already. The 133 words received meanwhile are read and
// ignored; then the CRC status token is received by a transmission of 4 words,
// whose control word, 0xfff0ffff, keeps the lines released, and decoded.
// Return what __hwdrvsdsdio_token() returns, or -1 when a transmission was
// aborted, both being then drained.
static intptr_t __hwdrvsdsdio_putblk (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *p, uintptr_t *crc, uintptr_t now) {
	hwdrvchar_t *c = &dev->addr[1];
	uintptr_t w[4];
	x = &x[1];
	__hwdrvsdsdio_open(c, x);
	w[0] = (uintptr_t)-1;
	w[1] = 0xf0ffffff;
	__hwdrvsdsdio_put(c, x, (uint8_t *)w, (2*sizeof(uintptr_t)));
	__hwdrvsdsdio_put(c, x, p, HWDRVSDSDIO_BLKSZ);
	if (now)
		__hwdrvsdsdio_blkcrc(p, crc);
	w[0] = crc[0];
	w[1] = crc[1];
	w[2] = (uintptr_t)-1;
	__hwdrvsdsdio_put(c, x, (uint8_t *)w, (3*sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c);
	if (!__hwdrvsdsdio_skip(c, x, x->w)) {
		__hwdrvsdsdio_drain(c, x);
		return -1;
	}
	__hwdrvsdsdio_open(c, x);
	w[0] = 0xfff0ffff;
	w[1] = w[2] = w[3] = (uintptr_t)-1;
	__hwdrvsdsdio_put(c, x, (uint8_t *)w, (4*sizeof(uintptr_t)));
	__hwdrvsdsdio_close(c);
	if (!__hwdrvsdsdio_get(c, x, (uint8_t *)w, (4*sizeof(uintptr_t)))) {
		__hwdrvsdsdio_drain(c, x);
		return -1;
	}
	__hwdrvsdsdio_drain(c, x); // Every word is read; it reads none.
	return __hwdrvsdsdio_token(w);
}

// Fail as fatal: set dev->blkcnt null, which requires hwdrvsdsdio_init();
// return null. Both interfaces are idle.
static uintptr_t __hwdrvsdsdio_fatal (hwdrvsdsdio_t *dev) {
	dev->blkcnt = 0;
	return 0;
}

// Return the capacity in block count, computed from the CSD register:
// for CSD version 1.0, (C_SIZE+1)<<(C_SIZE_MULT+2+READ_BL_LEN-9),
// for CSD version 2.0, (C_SIZE+1)<<10 saturated, otherwise 1.
static uintptr_t __hwdrvsdsdio_capacity (hwdrvsdsdio_t *dev) {
	uint8_t *csd = dev->csd;
	uintptr_t s = (csd[0] >> 6), n; // CSD_STRUCTURE CSD[127:126].
	if (!s) {
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

// Receive the CSD register into dev->csd using SEND_CSD (CMD9), the card being in
// the stand-by state, then select the card using SELECT_CARD (CMD7), its busy
// state awaited, the card being then in the transfer state; return null on a
// failure.
static uintptr_t __hwdrvsdsdio_select (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x) {
	uint8_t *bb = (uint8_t *)x->bb;
	uintptr_t i;
	if (__hwdrvsdsdio_cmd(dev, x, 9, (dev->rca << 16), 5, 0) <= 0)
		return 0;
	for (i = 0; i < 16; ++i)
		dev->csd[i] = bb[i+1];
	return (__hwdrvsdsdio_cmd(dev, x, 7, (dev->rca << 16), 2, 0) > 0 &&
		!__hwdrvsdsdio_r1err(x, 1) && __hwdrvsdsdio_busy(dev, x));
}

// Initialize the sdsdio device at the address given through the field addr of
// dev->addr[0], dev->addr being an array of two hwdrvchar_t, the field dev->wait
// being valid or null; the fields dev->blkcnt, dev->csd, dev->bitrate,
// dev->flags and dev->rca, and the two hwdrvchar_t at dev->addr, get initialized
// by this function. It takes 290 ms at least, and fails if the buffers of the CMD
// interface are smaller than 64 bytes, or those of the DAT interface smaller
// than 1024 bytes, as a data block written keeps 133 words in flight, a data
// block read 130 words, and the next one armed as many, and a poll of the busy
// state at most bufsz.
// The bitrate set is the highest that the card supports, up to half the clock
// frequency of the device, ie: 50 MHz at 100 MHz; the caller may change the
// device speed only between calls, not below 400 kHz, using hwdrvchar_init() on
// dev->addr[0], which sets the bitrate of both interfaces, then must update
// dev->bitrate.
// On success returns 1 otherwise 0.
static uintptr_t hwdrvsdsdio_init (hwdrvsdsdio_t *dev) {
	hwdrvchar_t *c = dev->addr;
	__hwdrvsdsdio_xmit_t x[2];
	uint8_t *bb = (uint8_t *)x[0].bb;
	uintptr_t budget, n;
	intptr_t r;
	dev->blkcnt = 0;
	dev->flags = 0;
	dev->rca = 0;
	c[1].addr = (void *)((uint8_t *)c[0].addr + (2*sizeof(uintptr_t)));
	// The DAT interface first: a data block written left paused drives the lines
	// DAT, and DAT3 low at CMD0 would select SPI mode. A transmission left open
	// ends within (BUFSZ+2) word-times once closed, or PAUSETIMEOUT, while the
	// clock is stopped by a chained transmission left waiting, or DATSYNCTIMEOUT,
	// for a read left waiting for its data block.
	__hwdrvsdsdio_recover(&c[1], &x[1]);
	__hwdrvsdsdio_recover(&c[0], &x[0]);
	hwdrvchar_init(&c[0], 400000);
	hwdrvchar_init(&c[1], 400000);
	if (c[0].bufsz < 64 || c[1].bufsz < 1024)
		return 0;
	// 250 ms of clock cycles, every line released, which the pull-ups keep high,
	// covering the time for the card to power up, and the 74 clock cycles with
	// CMD high it needs before its first command; the first (2*bufsz) of them
	// realign the lanes of the DAT interface, which a failure or other code may
	// have left misaligned, as described above. They also give a card left
	// within a transaction by a failure, ie: still sending a data block or
	// expecting the rest of one, the clock cycles it needs: a partial data block
	// written gets completed with bits 1, failing its CRC16. Then CMD12, whose
	// outcome is ignored, ends a CMD18 or CMD25 left in progress, and is illegal
	// otherwise, which is harmless, and the busy state is awaited, since CMD0
	// would end a write in progress. A card just powered up ignores CMD12, and is
	// not busy.
	__hwdrvsdsdio_speed(dev, 400000);
	n = __hwdrvsdsdio_realign(dev, x);
	if (n < (dev->bitrate/4))
		__hwdrvsdsdio_clocks(dev, x, ((dev->bitrate/4) - n));
	__hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0);
	if (!__hwdrvsdsdio_busy(dev, x))
		return 0;
	// CMD0, software reset, DAT3 being released, which its pull-up keeps high,
	// hence the card remains in SD mode.
	if (__hwdrvsdsdio_cmd(dev, x, 0, 0, 0, 0) <= 0)
		return 0;
	// CMD8, check voltage range, to which an SDv1 card does not respond; the
	// response R7 must echo the voltage accepted and the check pattern.
	r = __hwdrvsdsdio_cmd(dev, x, 8, 0x1aa, 2, 0);
	if (!r)
		return 0;
	if (r > 0) {
		if ((bb[3] & 0x0f) != 0x01 || bb[4] != 0xaa)
			return 0;
		dev->flags = HWDRVSDSDIO_FLAG_SDV2;
	}
	// Poll the busy bit of the OCR register using ACMD41, with HCS if SDv2, and
	// the voltage window 3.2-3.4 V, until set, ie: the card is ready; an MMC, which
	// does not respond to CMD55, fails. Each poll is preceded by 40 ms of clock
	// cycles, as SD 4.4 requires polls less than 50 ms apart when the clock stops
	// between them; the polls last 1 s of clock cycles counted from the first one,
	// a command counting for 160, the last poll following that second, as SD 4.2.3
	// requires the host to poll for at least 1 s.
	for (budget = dev->bitrate, n = 0;; n = (dev->bitrate/25)) {
		// n is null up to the first poll, from which the second is counted.
		__hwdrvsdsdio_clocks(dev, x, (dev->bitrate/25));
		budget = ((budget > n) ? (budget - n) : 0);
		r = __hwdrvsdsdio_cmd(dev, x, 55, 0, 2, 0);
		budget = ((budget > 160) ? (budget - 160) : 0);
		if (r <= 0 || !__hwdrvsdsdio_appcmd(x))
			return 0;
		r = __hwdrvsdsdio_cmd(dev, x, 41,
			(((dev->flags & HWDRVSDSDIO_FLAG_SDV2) ? 0x40000000 : 0) | 0x00300000), 2, 0);
		budget = ((budget > 160) ? (budget - 160) : 0);
		if (r <= 0)
			return 0;
		if (bb[1] & 0x80)
			break;
		if (!budget)
			return 0;
	}
	// The bit 30 of the OCR register, CCS, is set if the card is block addressed.
	if ((dev->flags & HWDRVSDSDIO_FLAG_SDV2) && (bb[1] & 0x40))
		dev->flags |= HWDRVSDSDIO_FLAG_BLKADDR;
	// CMD2, the CID register, whose response R2 is only checked; then CMD3, the
	// relative card address, which the card publishes again if null.
	if (__hwdrvsdsdio_cmd(dev, x, 2, 0, 5, 0) <= 0)
		return 0;
	for (n = 0; n < 3 && !dev->rca; ++n) {
		if (__hwdrvsdsdio_cmd(dev, x, 3, 0, 2, 0) <= 0)
			return 0;
		dev->rca = (((uintptr_t)bb[1] << 8) | bb[2]);
	}
	if (!dev->rca)
		return 0;
	// CMD9 and CMD7, then ACMD6, which sets the bus 4 bits wide.
	if (!__hwdrvsdsdio_select(dev, x))
		return 0;
	r = __hwdrvsdsdio_cmd(dev, x, 55, (dev->rca << 16), 2, 0);
	if (r <= 0 || !__hwdrvsdsdio_appcmd(x))
		return 0;
	r = __hwdrvsdsdio_cmd(dev, x, 6, 2, 2, 0);
	if (r <= 0 || __hwdrvsdsdio_r1err(x, 1))
		return 0;
	// CMD6, switch to the high speed mode, if the card supports the command class
	// 10, CCC CSD[95:84]: its 64 bytes of switch status are received over the 4
	// lines DAT, into a local buffer, word aligned, and ignored, their CRC16
	// checked whatever HWDRVSDSDIO_CRC, as a mismatch requires a power cycle of
	// the card (SD 4.3.10), the switch taking effect within 8 clock cycles after
	// them.
	// A response R1 reporting an error skips the switch, its data never coming;
	// otherwise, the card is deselected using CMD7 with a null RCA, which has no
	// response, then its CSD register is received again, TRAN_SPEED being then
	// 0x5a if the switch took effect, and the card is selected again.
	if (dev->csd[4] & 0x40) {
		alignas(uintptr_t) uint8_t st[64];
		r = __hwdrvsdsdio_cmd(dev, x, 6, 0x80fffff1, 2, ((sizeof(st)/sizeof(uintptr_t)) + 4));
		if (r <= 0 || __hwdrvsdsdio_r1err(x, 1)) {
			__hwdrvsdsdio_datdrain(dev, x);
			if (r <= 0)
				return 0;
		} else if (__hwdrvsdsdio_rdblk(dev, x, st, sizeof(st), 2, 0, 1) <= 0) {
			__hwdrvsdsdio_datdrain(dev, x);
			return 0;
		} else if (__hwdrvsdsdio_cmd(dev, x, 7, 0, 0, 0) <= 0 || !__hwdrvsdsdio_select(dev, x))
			return 0;
	}
	// CMD16, block length of HWDRVSDSDIO_BLKSZ bytes.
	r = __hwdrvsdsdio_cmd(dev, x, 16, HWDRVSDSDIO_BLKSZ, 2, 0);
	if (r <= 0 || __hwdrvsdsdio_r1err(x, 1))
		return 0;
	// The speed is switched last, so that the caller can lower it before
	// any transfer; from TRAN_SPEED CSD[103:96]: 0x5a 50 MHz, 0x32 25 MHz,
	// 0x2a 20 MHz, otherwise 10 MHz.
	n = dev->csd[3];
	__hwdrvsdsdio_speed(dev, ((n == 0x5a) ? 50000000 : (n == 0x32) ? 25000000 :
		(n == 0x2a) ? 20000000 : 10000000));
	dev->blkcnt = __hwdrvsdsdio_capacity(dev);
	// A byte addressed card is addressed using (idx<<9), which fits in 32 bits
	// below 2^23 blocks, the capacity of the READ_BL_LEN values not reserved.
	if (!(dev->flags & HWDRVSDSDIO_FLAG_BLKADDR) && dev->blkcnt > ((uintptr_t)1 << 23))
		dev->blkcnt = ((uintptr_t)1 << 23);
	return 1;
}

// Read the data block at the address a into the buffer ptr, using
// READ_SINGLE_BLOCK (CMD17): its transmission of the DAT interface, armed with
// the command, receives 132 words: the data block, its CRC16, then 2 words
// giving the card the end bit and the 8 clock cycles it needs after it; then
// SEND_STATUS (CMD13) reports the errors which the card detected while sending
// the data block, ie: CARD_ECC_FAILED, and clears them.
// Return 1 if the block was read, otherwise 0.
static uintptr_t __hwdrvsdsdio_read1 (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *ptr, uintptr_t a) {
	intptr_t r = __hwdrvsdsdio_cmd(dev, x, 17, a, 2, ((HWDRVSDSDIO_BLKSZ/sizeof(uintptr_t)) + 4));
	if (r <= 0 || __hwdrvsdsdio_r1err(x, 1)) {
		// Rejected, or no valid response: no data block is expected, but one
		// may come, ie: when the response was corrupted; it is read and ignored,
		// otherwise the device gives up waiting for it after DATSYNCTIMEOUT.
		__hwdrvsdsdio_datdrain(dev, x);
		return ((r <= 0) ? __hwdrvsdsdio_fatal(dev) : 0);
	}
	r = __hwdrvsdsdio_rdblk(dev, x, ptr, HWDRVSDSDIO_BLKSZ, 2, 0, HWDRVSDSDIO_CRC);
	if (r < 0) {
		__hwdrvsdsdio_datdrain(dev, x);
		return __hwdrvsdsdio_fatal(dev);
	}
	if (__hwdrvsdsdio_cmd(dev, x, 13, (dev->rca << 16), 2, 0) <= 0)
		return __hwdrvsdsdio_fatal(dev);
	return (r && !__hwdrvsdsdio_r1err(x, 1));
}

// Read the cnt data blocks from the address a into the buffer ptr, cnt being at
// least 2, using READ_MULTIPLE_BLOCK (CMD18): a transmission of the DAT interface
// per data block, of 130 words, the data block and its CRC16, the first armed
// with the command, and each next one armed once the transmission of the previous
// one has ended, as __hwdrvsdsdio_rdblk() does; then STOP_TRANSMISSION (CMD12),
// the DAT interface being idle, hence ignoring the data blocks which the card
// sends with the clock cycles it gets meanwhile, and which it stops sending after
// the end bit of CMD12. The card status of the response R1b of CMD12 reports the
// errors which the card detected while sending the data blocks, ie:
// CARD_ECC_FAILED, which their CRC16 does not cover, but OUT_OF_RANGE, which may
// follow the last block of the card, and which the host is to ignore (SD 4.3.3);
// then its busy state is awaited. A data block with a CRC16 mismatch ends the
// read likewise, once the next data block armed, if any, is received and
// ignored.
// Return the count of data blocks read and checked, from the first, none when
// CMD12 reports an error, which may concern any of them; on a fatal failure once
// CMD18 was sent, CMD12 is sent again alone, whose outcome is ignored, and
// dev->blkcnt set null, the count remaining exact: cnt when the failure follows
// the last data block, ie: no valid response to CMD12, or its busy state lasting
// more than 500 ms.
static uintptr_t __hwdrvsdsdio_mbread (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *ptr, uintptr_t a, uintptr_t cnt) {
	uintptr_t m = ((HWDRVSDSDIO_BLKSZ/sizeof(uintptr_t)) + 2), b;
	intptr_t r = __hwdrvsdsdio_cmd(dev, x, 18, a, 2, m);
	if (r <= 0 || __hwdrvsdsdio_r1err(x, 1)) {
		// Rejected, or no valid response: no data block is expected, but some
		// may come, ie: when the response was corrupted, the card then sending
		// data blocks until CMD12, which is sent alone, its outcome ignored.
		if (__hwdrvsdsdio_datdrain(dev, x))
			__hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0);
		return ((r <= 0) ? __hwdrvsdsdio_fatal(dev) : 0);
	}
	for (b = 0; b < cnt; ++b, ptr += HWDRVSDSDIO_BLKSZ) {
		r = __hwdrvsdsdio_rdblk(dev, x, ptr, HWDRVSDSDIO_BLKSZ, 0, (((b + 1) < cnt) ? m : 0), HWDRVSDSDIO_CRC);
		if (r <= 0)
			break;
	}
	// The next data block armed before a CRC16 mismatch, or the words received
	// by a transmission aborted.
	if (r <= 0)
		__hwdrvsdsdio_datdrain(dev, x);
	if (r >= 0 && __hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0) > 0) {
		// An error of the data blocks sent, but OUT_OF_RANGE (SD 4.3.3).
		if (__hwdrvsdsdio_r1err(x, 0))
			b = 0;
		if (!__hwdrvsdsdio_busy(dev, x))
			__hwdrvsdsdio_fatal(dev);
		return b;
	}
	// Aborted, or no valid response to CMD12: the card may still be sending
	// data blocks.
	__hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0);
	__hwdrvsdsdio_fatal(dev);
	return b;
}

// Write the data block at the address a from the buffer ptr, using WRITE_BLOCK
// (CMD24): once its response R1 is received, the data block is transmitted as
// __hwdrvsdsdio_putblk() describes, its CRC16 computed once it is queued, then its
// busy state awaited, whether it was accepted or not, then SEND_STATUS (CMD13)
// reports the errors of its programming, also when the data block was rejected,
// its response clearing a write error which the card reports after its CRC
// status token. A response R1 reporting an error sends nothing more, the card
// having rejected the command.
// Return 1 if the block was written, otherwise 0.
static uintptr_t __hwdrvsdsdio_write1 (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *ptr, uintptr_t a) {
	uintptr_t crc[2], ok;
	intptr_t r = __hwdrvsdsdio_cmd(dev, x, 24, a, 2, 0);
	if (r <= 0)
		return __hwdrvsdsdio_fatal(dev);
	if (__hwdrvsdsdio_r1err(x, 1))
		return 0;
	r = __hwdrvsdsdio_putblk(dev, x, ptr, crc, 1);
	if (r < 0 || ((r & 8) && !__hwdrvsdsdio_busy(dev, x)))
		return __hwdrvsdsdio_fatal(dev);
	ok = ((r & 7) == 0b010);
	r = __hwdrvsdsdio_cmd(dev, x, 13, (dev->rca << 16), 2, 0);
	if (r <= 0)
		return __hwdrvsdsdio_fatal(dev);
	return (ok && !__hwdrvsdsdio_r1err(x, 1));
}

// Write the cnt data blocks at ptr, cnt being at least 2, from the address a,
// using WRITE_MULTIPLE_BLOCK (CMD25): once its response R1 is received, each data
// block is transmitted as __hwdrvsdsdio_putblk() describes, then its busy state
// awaited, whether it was accepted or not; then STOP_TRANSMISSION (CMD12), whose
// response R1b reports the errors of the write other than OUT_OF_RANGE, its busy
// state awaited, then SEND_STATUS (CMD13) reports the errors of the programming
// which followed. The CRC16 of the first data block is computed once it is queued,
// while it is transmitted, as for CMD24, and the CRC16 of each of the next ones
// before it is queued, while the card is busy with the previous one, or once it
// is queued when the card is not busy: a CRC16 computed during a busy state costs
// no time on the wire, whereas one computed while its data block is transmitted
// only delays the end of that transmission. A data block rejected by its CRC
// status token ends the write the same way, its busy state awaited.
// When HWDRVSDSDIO_PREERASE is non-null, CMD55 and ACMD23 (SET_WR_BLK_ERASE_COUNT)
// precede CMD25, each as a transmission of its own.
// Return the count of data blocks known written, from the first: cnt on success,
// the count of the data blocks before a data block rejected for its CRC16, none
// after a write error, which may concern an earlier one, and none after a fatal
// failure, CMD12 being then sent again alone, whose outcome is ignored, once CMD25
// was sent.
static uintptr_t __hwdrvsdsdio_mbwrite (hwdrvsdsdio_t *dev, __hwdrvsdsdio_xmit_t *x,
	uint8_t *ptr, uintptr_t a, uintptr_t cnt) {
	uintptr_t crc[2], ret = cnt, b, now = 1;
	intptr_t r;
	if (HWDRVSDSDIO_PREERASE) {
		// The count of data blocks to pre-erase, which ACMD23 holds in 23 bits;
		// ACMD23 is sent only if CMD55 succeeded.
		if (__hwdrvsdsdio_cmd(dev, x, 55, (dev->rca << 16), 2, 0) <= 0)
			return __hwdrvsdsdio_fatal(dev);
		if (__hwdrvsdsdio_r1err(x, 1) || !__hwdrvsdsdio_appcmd(x))
			return 0;
		if (__hwdrvsdsdio_cmd(dev, x, 23, ((cnt > 0x7fffff) ? 0x7fffff : cnt), 2, 0) <= 0)
			return __hwdrvsdsdio_fatal(dev);
		if (__hwdrvsdsdio_r1err(x, 1))
			return 0;
	}
	if (__hwdrvsdsdio_cmd(dev, x, 25, a, 2, 0) <= 0)
		goto fatal; // The card may have received CMD25, and expect data blocks.
	if (__hwdrvsdsdio_r1err(x, 1))
		return 0;
	for (b = 0; b < cnt; ++b, ptr += HWDRVSDSDIO_BLKSZ) {
		r = __hwdrvsdsdio_putblk(dev, x, ptr, crc, now);
		if (r < 0)
			goto fatal;
		// The CRC16 of the next data block, while the card is busy.
		now = !(r & 8);
		if ((r & 7) == 0b010 && (b + 1) < cnt && !now)
			__hwdrvsdsdio_blkcrc((ptr + HWDRVSDSDIO_BLKSZ), crc);
		if ((r & 8) && !__hwdrvsdsdio_busy(dev, x))
			goto fatal;
		if ((r & 7) != 0b010) {
			// Rejected: 101 for a CRC error, which concerns this data block;
			// otherwise a write error, which may concern an earlier one.
			ret = (((r & 7) == 0b101) ? b : 0);
			break;
		}
	}
	if (__hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0) <= 0)
		goto fatal;
	if (__hwdrvsdsdio_r1err(x, 0))
		ret = 0;
	if (!__hwdrvsdsdio_busy(dev, x))
		return __hwdrvsdsdio_fatal(dev);
	if (__hwdrvsdsdio_cmd(dev, x, 13, (dev->rca << 16), 2, 0) <= 0)
		return __hwdrvsdsdio_fatal(dev);
	if (__hwdrvsdsdio_r1err(x, 1))
		ret = 0;
	return ret;
	fatal:
	// The card may still expect data blocks.
	__hwdrvsdsdio_cmd(dev, x, 12, 0, 2, 0);
	return __hwdrvsdsdio_fatal(dev);
}

// Read cnt blocks from the sdsdio device into the buffer given by the argument
// ptr, which holds cnt*HWDRVSDSDIO_BLKSZ bytes, aligned on a word, ie: on
// sizeof(uintptr_t) bytes, as the words received are stored to it. The index of
// the first block to read is given by the argument idx, where a block is
// HWDRVSDSDIO_BLKSZ bytes.
// A count of 1 uses READ_SINGLE_BLOCK (CMD17) followed by SEND_STATUS (CMD13), a
// greater count READ_MULTIPLE_BLOCK (CMD18) ended by STOP_TRANSMISSION (CMD12),
// whose responses report the errors which the card detected while sending the
// blocks, ie: CARD_ECC_FAILED.
// Returns the count of blocks read, from the first, each at its place in ptr:
// cnt on success, fewer on a failure, none when the card reports such an error,
// the rest of ptr being then undefined; cnt also after a fatal failure which
// follows the last block, ie: of the CMD12 which ends a multiple block read,
// every block being read, dev->blkcnt being then null as after any fatal
// failure, which the next call finds; 0 without accessing the device when cnt
// is null, when ptr is not aligned on a word, when the blocks are beyond the
// card, or while dev->blkcnt is null.
static uintptr_t hwdrvsdsdio_read (hwdrvsdsdio_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	// Overflow-safe: (dev->blkcnt - cnt) does not wrap once cnt <= dev->blkcnt.
	if (!cnt || cnt > dev->blkcnt || idx > (dev->blkcnt - cnt) || ((uintptr_t)ptr % sizeof(uintptr_t)))
		return 0;
	__hwdrvsdsdio_xmit_t x[2];
	uintptr_t a = ((dev->flags & HWDRVSDSDIO_FLAG_BLKADDR) ? idx : (idx << 9));
	if (cnt == 1)
		return __hwdrvsdsdio_read1(dev, x, ptr, a);
	return __hwdrvsdsdio_mbread(dev, x, ptr, a, cnt);
}

// Write cnt blocks to the sdsdio device from the buffer given by the argument
// ptr, which holds cnt*HWDRVSDSDIO_BLKSZ bytes, aligned on a word as for a read,
// as the words transmitted are loaded from it. The index of the first block to
// write is given by the argument idx, where a block is HWDRVSDSDIO_BLKSZ bytes.
// A count of 1 uses WRITE_BLOCK (CMD24), a greater count WRITE_MULTIPLE_BLOCK
// (CMD25), preceded by SET_WR_BLK_ERASE_COUNT (ACMD23) when HWDRVSDSDIO_PREERASE
// is non-null, and ended by STOP_TRANSMISSION (CMD12); both are followed, once a
// data block was transmitted, accepted or not, by SEND_STATUS (CMD13), which
// reports the errors of the programming, and clears them.
// Returns the count of blocks written, from the first, which may understate
// them: cnt on success; after a failure, the blocks beyond the count may have
// been written or not, or erased when HWDRVSDSDIO_PREERASE is non-null, ie: a
// block rejected for its CRC16 counts the blocks before it, whereas a write
// error, which may concern an earlier block, and a fatal failure count none;
// 0 without accessing the device as for a read.
static uintptr_t hwdrvsdsdio_write (hwdrvsdsdio_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	if (!cnt || cnt > dev->blkcnt || idx > (dev->blkcnt - cnt) || ((uintptr_t)ptr % sizeof(uintptr_t)))
		return 0;
	__hwdrvsdsdio_xmit_t x[2];
	uintptr_t a = ((dev->flags & HWDRVSDSDIO_FLAG_BLKADDR) ? idx : (idx << 9));
	if (cnt == 1)
		return __hwdrvsdsdio_write1(dev, x, ptr, a);
	return __hwdrvsdsdio_mbwrite(dev, x, ptr, a, cnt);
}

#endif /* HWDRVSDSDIO_H */
