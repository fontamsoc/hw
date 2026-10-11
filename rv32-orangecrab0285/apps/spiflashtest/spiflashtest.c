// SPDX-License-Identifier: GPL-2.0-only
// 20261008 (c) William Fonkou Tambe

// Benchmark of the SPI flash driven by hwdrvspiflash.h: the SPIFLASHTEST_WORDCNT
// words from SPIFLASHTEST_FIRSTWORD are read, SPIFLASHTEST_NWORD at a time, then
// each chunk of SPIFLASHTEST_NWORD words is read again and written back with its
// own content, only the writes being timed; a page program only clearing bits,
// the data of the flash is left as it was, barring a power loss during the
// writes, but on a Spansion S25FL-S, whose Automatic ECC protects each aligned
// unit of 16 bytes programmed once, programming a unit again disables its ECC
// until it is erased. The last chunk may be shorter. Each pass ends with a status line giving the bytes
// copied, the seconds taken and the rate, the sizes being formatted as BusyBox
// dd does.
//
// When SPIFLASHTEST_VERIFY is non-null, the default, a pass of its own reads the
// words before the timed passes, computing their CRC32, of which it keeps the
// value at the end of each chunk: the CRC32 of the words from the first through
// that chunk. The write pass then writes back a chunk only when the CRC32 of its
// words read again, continuing the one kept for the chunk before it, equals the
// one kept for it; otherwise, a word read differently by the two reads, the
// chunk is not written back, which would program the error into the flash, and
// the test stops. A last pass reads the words again after the writes, and
// compares their CRC32 with that of the first pass; a status line gives it.
// Those passes are untimed, and the timed passes are as without
// SPIFLASHTEST_VERIFY. The CRC32 kept costs 4 bytes per chunk. A word read
// wrong the same way by the first pass and the read before its write gets
// written back wrong unnoticed; but it is the CRC32 of zlib, which python3
// computes using zlib.crc32() over the same words read on a PC, a reference which
// detects it: ie: 0x7d5b6975 for 4 MiB erased, 0x956bac74 for 1 MiB erased.
//
// The drivers hwdrv*.h next to this file are copies of those of ftpu/sw, their
// canonical location.
//
// The defines SPIFLASHTEST_* which follow are set through the environment,
// ie: make clean && CFLAGS=-DSPIFLASHTEST_BITRATE=25000000 make
// as "make CFLAGS=..." replaces the flags of the makefile, and "make clean"
// is needed since the makefile does not rebuild when only the defines change.

#include <stdio.h>

#include <_os.h>

// HWDRVCHAR_DATATYPE is to be defined before including hwdrvchar.h: dev/spi.sv
// transfers a word per access of its data word, as hwdrvspiflash.h requires.
#define HWDRVCHAR_DATATYPE uintptr_t
#include "hwdrvchar.h"
#include "hwdrvirqctrl.h"

// The defaults of the board, the OrangeCrab r0.2 85F: its flash, a W25Q128JV of
// 16 MiB, holds the bootloader in its first 512 KiB, then the user bitstream;
// the region tested is the 4 MiB from 2 MiB.
#ifndef SPIFLASHTEST_IRQ
#define SPIFLASHTEST_IRQ 3
#endif
#ifndef SPIFLASHTEST_SIZE
#define SPIFLASHTEST_SIZE 16777216 // Capacity of the flash in bytes, as HWDRVSPIFLASH_SIZE describes.
#endif
#ifndef SPIFLASHTEST_FIRSTWORD
#define SPIFLASHTEST_FIRSTWORD 524288 // 2 MiB into the flash.
#endif
#ifndef SPIFLASHTEST_WORDCNT
#define SPIFLASHTEST_WORDCNT 1048576 // 4 MiB.
#endif

#ifndef SPIFLASHTEST_ADDR
#define SPIFLASHTEST_ADDR 0xe40
#endif
#ifndef SPIFLASHTEST_NWORD
#define SPIFLASHTEST_NWORD 16384 // Words per call of the read and write of the driver: 64 KiB.
#endif
#ifndef SPIFLASHTEST_BITRATE
#define SPIFLASHTEST_BITRATE 50000000 // Bitrate not to exceed, as HWDRVSPIFLASH_BITRATE describes.
#endif
#ifndef SPIFLASHTEST_BPCHECK
#define SPIFLASHTEST_BPCHECK 1 // When non-null, writes are refused while blocks are protected, as HWDRVSPIFLASH_BPCHECK describes.
#endif
#ifndef SPIFLASHTEST_POLL
#define SPIFLASHTEST_POLL 0 // When non-null, poll instead of sleeping on the interrupt.
#endif
#ifndef SPIFLASHTEST_VERIFY
#define SPIFLASHTEST_VERIFY 1 // When non-null, chunks are written back only when read alike twice, and the words read after the writes are checked.
#endif

// The defines HWDRVSPIFLASH_* are to be defined before including the driver.
#define HWDRVSPIFLASH_SIZE SPIFLASHTEST_SIZE
#define HWDRVSPIFLASH_BITRATE SPIFLASHTEST_BITRATE
#define HWDRVSPIFLASH_BPCHECK SPIFLASHTEST_BPCHECK
#include "hwdrvspiflash.h"

static_assert((SPIFLASHTEST_WORDCNT > 0 &&
	((unsigned long long)SPIFLASHTEST_FIRSTWORD + SPIFLASHTEST_WORDCNT) <= (SPIFLASHTEST_SIZE/sizeof(uintptr_t))),
	"the words tested must be within the flash");
static_assert((!(SPIFLASHTEST_FIRSTWORD % (HWDRVSPIFLASH_PAGESZ/sizeof(uintptr_t))) &&
	!(SPIFLASHTEST_NWORD % (HWDRVSPIFLASH_PAGESZ/sizeof(uintptr_t)))),
	"SPIFLASHTEST_FIRSTWORD and SPIFLASHTEST_NWORD must be multiples of a page, 64 words");
static_assert((SPIFLASHTEST_NWORD > 0 && SPIFLASHTEST_NWORD <= 32768),
	"SPIFLASHTEST_NWORD from 64 to 32768 (128 KiB of buffer)");

static hwdrvchar_t flashc = {.addr = (void *)SPIFLASHTEST_ADDR};

#if !SPIFLASHTEST_POLL
static _waitq_t flashwq; // Where main() sleeps until the interrupt.

// Interrupt callback; it only wakes up main(), the device
// being never accessed from a trap context.
static void flashirqcb (_irq_t *i) {
	(void)i;
	_thread_schedone(&flashwq);
}
static _IRQ_DEF(flashirq, SPIFLASHTEST_IRQ, flashirqcb);

// Callback of the field wait of the driver: sleep until cnt bytes can be read.
// The interrupt is armed before preemption gets disabled: one occurring
// in-between wakes up no thread, but its threshold is then reached, hence
// the check, done with preemption disabled, does not sleep; one occurring
// once preemption is disabled pends until the sleep, which it ends. A null
// transmit buffer usage means the transmission was aborted, no more bytes
// coming. The sleep is bounded, as the callback must return: 20 ms is above
// the longest wait of the driver, about 50 us of bytes, and a thread woken up
// may wait up to 50 ms (SCHEDLRHZ) before running, while the device aborts a
// transmission paused for 100 ms.
static void flashwait (hwdrvspiflash_t *dev, uintptr_t cnt) {
	hwdrvchar_t *c = dev->addr;
	hwdrvchar_interrupt(c, cnt);
	_preempt_disable();
	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
		_thread_sleeponwquntil(&flashwq, (_clkcycles() + _MSECS(20)));
	_preempt_enable();
}
#endif

static hwdrvspiflash_t flash = {
	.addr = &flashc,
#if !SPIFLASHTEST_POLL
	.wait = flashwait,
#endif
};

// Word aligned, as the read and write of the driver require.
static alignas(uintptr_t) uint8_t buf[SPIFLASHTEST_NWORD * sizeof(uintptr_t)];

#if SPIFLASHTEST_VERIFY
// Table of the CRC32 of zlib, filled by crc32init() rather than initialized,
// which spares the binary its 1 KB.
static uint32_t crc32tab[256];

static void crc32init (void) {
	for (unsigned i = 0; i < 256; ++i) {
		uint32_t c = i;
		for (unsigned k = 0; k < 8; ++k)
			c = ((c >> 1) ^ ((c & 1) ? 0xedb88320 : 0));
		crc32tab[i] = c;
	}
}

// CRC32 of zlib of the n bytes at p, continuing the CRC32 crc
// of the bytes before them, null when there are none.
static uint32_t crc32 (uint32_t crc, uint8_t *p, uintptr_t n) {
	crc = ~crc;
	while (n--)
		crc = (crc32tab[(crc ^ *p++) & 0xff] ^ (crc >> 8));
	return ~crc;
}

// The CRC32 of the words from the first through each chunk, as the first pass
// computes it.
static uint32_t crcs[(SPIFLASHTEST_WORDCNT + SPIFLASHTEST_NWORD - 1) / SPIFLASHTEST_NWORD];

// Read the words, untimed, SPIFLASHTEST_NWORD at a time as the timed passes do,
// and set *crc to their CRC32, storing to crcs[k], when keep is non-null, the
// CRC32 of the words from the first through the chunk k; return the word whose
// read failed, else the word after the last.
static uintptr_t crcpass (uint32_t *crc, uintptr_t keep) {
	uintptr_t end = ((uintptr_t)SPIFLASHTEST_FIRSTWORD + SPIFLASHTEST_WORDCNT), i, n, r, k;
	*crc = 0;
	for (k = 0, i = SPIFLASHTEST_FIRSTWORD; i < end; i += n, ++k) {
		n = (((end - i) < SPIFLASHTEST_NWORD) ? (end - i) : SPIFLASHTEST_NWORD);
		if ((r = hwdrvspiflash_read(&flash, buf, i, n)) != n)
			return (i + r);
		*crc = crc32(*crc, buf, (n * sizeof(uintptr_t)));
		if (keep)
			crcs[k] = *crc;
	}
	return end;
}
#endif

// Integer port of make_human_readable_str(val, 1, 0) of BusyBox,
// which dd uses; ie: 8388608 gives "8.0M", 1000 gives "1000".
static char *hrstr (char *s, unsigned long long val) {
	static const char units[] = {0, 'K', 'M', 'G', 'T', 'P', 'E'};
	unsigned u = 0, frac = 0;
	while (val >= 1024) {
		frac = ((((unsigned)val % 1024) * 10) + (1024/2)) / 1024;
		val /= 1024;
		++u;
	}
	if (frac >= 10) { // Round up.
		++val;
		frac = 0;
	}
	if (u)
		sprintf(s, "%u.%u%c", (unsigned)val, frac, units[u]);
	else
		sprintf(s, "%u", (unsigned)val);
	return s;
}

// Print the status line of a pass: the bytes of the region transferred in the
// clock cycle count given as argument, the seconds taken, and the rate.
static void report (const char *label, _date_t cycles) {
	unsigned long long bytes = ((unsigned long long)SPIFLASHTEST_WORDCNT * sizeof(uintptr_t));
	unsigned long long us = ((cycles * 1000000) / _clkfreq());
	if (!us)
		us = 1;
	char s0[16], s1[16];
	printf("%s%u B (%sB) copied | ⏱️ %u.%06u s | 📊 %sB/s\n",
		label, (unsigned)bytes, hrstr(s0, bytes),
		(unsigned)(us / 1000000), (unsigned)(us % 1000000),
		hrstr(s1, ((bytes * 1000000) / us)));
}

// A read failing is always fatal; a write failing as recoverable leaves in
// flash.sr the status register 1 which refused it.
static void failed (const char *op, uintptr_t idx) {
	printf("❌ ERROR: %s word %u failed", op, (unsigned)idx);
	if (!flash.wordcnt)
		printf("; the flash must be initialized again");
	else if (flash.sr & 0x1c)
		printf("; SR1 0x%02x: blocks protected", (unsigned)flash.sr);
	else
		printf("; SR1 0x%02x", (unsigned)flash.sr);
	printf("\n");
}

void main (void) {
	printf("🚀 Starting SPI-flash test ...\n");
#if !SPIFLASHTEST_POLL
	_irq_register(&flashirq);
	_preempt_disable(); // Insure the irqctrl transaction is not interrupted.
	hwdrvirqctrl_ena(SPIFLASHTEST_IRQ, 1);
	_preempt_enable();
#endif
	if (!hwdrvspiflash_init(&flash)) {
		printf("❌ ERROR: initialization failed; is the flash answering?\n");
		goto done;
	}
	char s0[16], s1[16];
	printf("💾 SPI flash | 📦 %u words (%sB) | 📄 %u B pages | 🔒 SR1 0x%02x\n"
		"⚡ %u bps | 📍 %u B (%sB) from byte %u\n",
		(unsigned)flash.wordcnt, hrstr(s0, ((unsigned long long)flash.wordcnt * sizeof(uintptr_t))),
		(unsigned)HWDRVSPIFLASH_PAGESZ, (unsigned)flash.sr, (unsigned)flash.bitrate,
		(unsigned)((unsigned long long)SPIFLASHTEST_WORDCNT * sizeof(uintptr_t)),
		hrstr(s1, ((unsigned long long)SPIFLASHTEST_WORDCNT * sizeof(uintptr_t))),
		(unsigned)((unsigned long long)SPIFLASHTEST_FIRSTWORD * sizeof(uintptr_t)));
	if (SPIFLASHTEST_WORDCNT > flash.wordcnt || SPIFLASHTEST_FIRSTWORD > (flash.wordcnt - SPIFLASHTEST_WORDCNT)) {
		printf("❌ ERROR: words %u to %u are beyond the flash\n", (unsigned)SPIFLASHTEST_FIRSTWORD,
			((unsigned)SPIFLASHTEST_FIRSTWORD + SPIFLASHTEST_WORDCNT - 1));
		goto done;
	}
	// Chunks of n words from i, SPIFLASHTEST_NWORD but the last, which is fewer when
	// SPIFLASHTEST_WORDCNT is not a multiple of it; a call transferring r words of
	// them failed at the word (i+r).
	uintptr_t end = ((uintptr_t)SPIFLASHTEST_FIRSTWORD + SPIFLASHTEST_WORDCNT), i, n = 0, r = 0;
#if SPIFLASHTEST_VERIFY
	uint32_t crc[2]; // CRC32 of the words, before the timed passes, then after the writes.
	crc32init();
	if ((i = crcpass(&crc[0], 1)) != end) {
		failed("reading", i);
		goto done;
	}
#endif
	_date_t t = _clkcycles();
	for (i = SPIFLASHTEST_FIRSTWORD; i < end; i += n) {
		n = (((end - i) < SPIFLASHTEST_NWORD) ? (end - i) : SPIFLASHTEST_NWORD);
		if ((r = hwdrvspiflash_read(&flash, buf, i, n)) != n)
			break;
	}
	t = (_clkcycles() - t);
	if (i < end) {
		failed("reading", (i + r));
		goto done;
	}
	report("📥 Read:  ", t);
	for (t = 0, i = SPIFLASHTEST_FIRSTWORD; i < end; i += n) {
		n = (((end - i) < SPIFLASHTEST_NWORD) ? (end - i) : SPIFLASHTEST_NWORD);
		if ((r = hwdrvspiflash_read(&flash, buf, i, n)) != n) {
			failed("reading", (i + r));
			goto done;
		}
#if SPIFLASHTEST_VERIFY
		// The chunk k must read as the first pass read it.
		uintptr_t k = ((i - SPIFLASHTEST_FIRSTWORD) / SPIFLASHTEST_NWORD);
		if (crc32((k ? crcs[k-1] : 0), buf, (n * sizeof(uintptr_t))) != crcs[k]) {
			printf("❌ ERROR: words %u to %u read differently than before the timed passes; not written back\n",
				(unsigned)i, (unsigned)(i + n - 1));
			goto done;
		}
#endif
		_date_t t0 = _clkcycles();
		r = hwdrvspiflash_write(&flash, buf, i, n);
		t += (_clkcycles() - t0);
		if (r != n) {
			failed("writing", (i + r));
			goto done;
		}
	}
	report("📤 Write: ", t);
#if SPIFLASHTEST_VERIFY
	if ((i = crcpass(&crc[1], 0)) != end) {
		failed("reading", i);
		goto done;
	}
	if (crc[1] != crc[0])
		printf("❌ ERROR: CRC32 0x%08x of the words read before the writes, 0x%08x after\n",
			(unsigned)crc[0], (unsigned)crc[1]);
	else
		printf("🔍 Verify: %u B (%sB) read back | 🔢 CRC32 0x%08x | ✅ unchanged\n",
			(unsigned)((unsigned long long)SPIFLASHTEST_WORDCNT * sizeof(uintptr_t)),
			hrstr(s0, ((unsigned long long)SPIFLASHTEST_WORDCNT * sizeof(uintptr_t))), (unsigned)crc[0]);
#endif
	done: printf("----\n");
}
