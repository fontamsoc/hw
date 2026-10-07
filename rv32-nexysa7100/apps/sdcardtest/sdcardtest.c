// SPDX-License-Identifier: GPL-2.0-only
// 20260927 (c) William Fonkou Tambe

// Benchmark of the SD card driven by hwdrvsdsdio.h in SD mode, or by
// hwdrvsdspi.h in SPI mode, as SDCARDTEST_MODE selects: the SDCARDTEST_BLKCNT
// blocks from SDCARDTEST_FIRSTBLK are read, SDCARDTEST_NBLK at a time, then each
// chunk of SDCARDTEST_NBLK blocks is read again and written back with its own
// content, only the writes being timed, hence the card is left as it was, barring
// a power loss during the writes; the last chunk may be shorter. Each pass ends
// with a status line giving the bytes copied, the seconds taken and the rate, the
// sizes being formatted as BusyBox dd does.
//
// When SDCARDTEST_VERIFY is non-null, the default, the CRC32 of the blocks,
// computed by a pass of its own reading them before the timed passes, is
// compared with that of a last pass reading them again after the writes, which
// were to leave them unchanged; a status line gives it. Both passes are untimed,
// and the timed passes are as without SDCARDTEST_VERIFY. The pass before being
// the reference, a block read wrong by it and by the read before its write gets
// written back wrong unnoticed; but it is the CRC32 of zlib, which python3
// computes using zlib.crc32() over the same blocks read on a PC, a reference
// which detects it.
//
// The drivers hwdrv*.h next to this file are copies of those of ftpu/sw, their
// canonical location.
//
// The defines SDCARDTEST_* which follow are set through the environment,
// ie: make clean && CFLAGS=-DSDCARDTEST_BITRATE=20000000 make
// as "make CFLAGS=..." replaces the flags of the makefile, and "make clean"
// is needed since the makefile does not rebuild when only the defines change.

#include <stdio.h>

#include <_os.h>

// HWDRVCHAR_DATATYPE is to be defined before including hwdrvchar.h: dev/sdio.sv
// and dev/spi.sv transfer a word per access of their data words, as hwdrvsdsdio.h
// and hwdrvsdspi.h require.
#define HWDRVCHAR_DATATYPE uintptr_t
#include "hwdrvchar.h"
#include "hwdrvirqctrl.h"

#ifndef SDCARDTEST_MODE
#define SDCARDTEST_MODE 1 // 1: SD mode, dev/sdio.sv driven by hwdrvsdsdio.h; 0: SPI mode, dev/spi.sv driven by hwdrvsdspi.h.
#endif
#ifndef SDCARDTEST_ADDR
#define SDCARDTEST_ADDR 0xe00
#endif
#ifndef SDCARDTEST_IRQ
#define SDCARDTEST_IRQ 2
#endif
#ifndef SDCARDTEST_FIRSTBLK
#define SDCARDTEST_FIRSTBLK 65536 // 32 MiB into the card.
#endif
#ifndef SDCARDTEST_BLKCNT
#define SDCARDTEST_BLKCNT 65536 // 32 MiB.
#endif
#ifndef SDCARDTEST_NBLK
#define SDCARDTEST_NBLK 128 // Blocks per call of the read and write of the driver; 1 uses CMD17/CMD24.
#endif
#ifndef SDCARDTEST_BITRATE
#define SDCARDTEST_BITRATE 0 // When non-null, bitrate not to exceed after initialization.
#endif
#ifndef SDCARDTEST_POLL
#define SDCARDTEST_POLL 0 // When non-null, poll instead of sleeping on the interrupt.
#endif
#ifndef SDCARDTEST_CRC
#define SDCARDTEST_CRC 1 // When null, the CRC checks which the driver makes optional are not used, as HWDRVSDSDIO_CRC and HWDRVSDSPI_CRC describe.
#endif
#ifndef SDCARDTEST_PREERASE
#define SDCARDTEST_PREERASE 0 // When non-null, writes pre-erase their blocks, as HWDRVSDSDIO_PREERASE and HWDRVSDSPI_PREERASE describe.
#endif
#ifndef SDCARDTEST_VERIFY
#define SDCARDTEST_VERIFY 1 // When non-null, the CRC32 of the blocks read after the writes is compared with that of a pass reading them before the timed passes.
#endif

// The defines HWDRVSDSDIO_* and HWDRVSDSPI_* are to be defined before including
// their driver; SDDRV() and SDDRVM() name the functions, type and macros of the
// driver in use, ie: SDDRV(read) is hwdrvsdsdio_read in SD mode.
#if SDCARDTEST_MODE
#define HWDRVSDSDIO_CRC SDCARDTEST_CRC
#define HWDRVSDSDIO_PREERASE SDCARDTEST_PREERASE
#include "hwdrvsdsdio.h"
#define SDDRV(N) hwdrvsdsdio_##N
#define SDDRVM(N) HWDRVSDSDIO_##N
#else
#define HWDRVSDSPI_CRC SDCARDTEST_CRC
#define HWDRVSDSPI_PREERASE SDCARDTEST_PREERASE
#include "hwdrvsdspi.h"
#define SDDRV(N) hwdrvsdspi_##N
#define SDDRVM(N) HWDRVSDSPI_##N
#endif

static_assert((SDCARDTEST_BLKCNT > 0 && SDCARDTEST_BLKCNT <= (0xffffffff/SDDRVM(BLKSZ))),
	"the byte count is printed with %u");
static_assert((!SDCARDTEST_BITRATE || SDCARDTEST_BITRATE >= 400000),
	"SDCARDTEST_BITRATE below the initialization bitrate");
static_assert((SDCARDTEST_NBLK > 0 && SDCARDTEST_NBLK <= 256),
	"SDCARDTEST_NBLK from 1 to 256 (128 KiB of buffer)");
static_assert((SDCARDTEST_MODE == 0 || SDCARDTEST_MODE == 1),
	"SDCARDTEST_MODE is 1 for SD mode or 0 for SPI mode");

// The serial interfaces of the device: in SPI mode, its only one; in SD mode, its
// CMD interface, then its DAT interface, whose address hwdrvsdsdio_init() sets.
static hwdrvchar_t sdc[1 + SDCARDTEST_MODE] = {{.addr = (void *)SDCARDTEST_ADDR}};

#if !SDCARDTEST_POLL
static _waitq_t sdwq; // Where main() sleeps until the interrupt.

// Interrupt callback; it only wakes up main(), the device
// being never accessed from a trap context.
static void sdirqcb (_irq_t *i) {
	(void)i;
	_thread_schedone(&sdwq);
}
static _IRQ_DEF(sdirq, SDCARDTEST_IRQ, sdirqcb);

// Callback of the field wait of the driver: sleep until cnt bytes can be read,
// from the only interface in SPI mode, from the DAT interface in SD mode.
// The interrupt is armed before preemption gets disabled: one occurring
// in-between wakes up no thread, but its threshold is then reached, hence
// the check, done with preemption disabled, does not sleep; one occurring
// once preemption is disabled pends until the sleep, which it ends. A null
// transmit buffer usage means the transmission ended or was aborted, no
// more bytes coming. The sleep is bounded, as the
// callback must return: 20 ms is above the longest wait of the driver for
// clock cycles, about 10 ms, a longer wait for a data block in SD mode
// calling it again, and a thread woken up may wait up to 50 ms (SCHEDLRHZ)
// before running, while the device aborts a transmission paused for 100 ms.
static void sdwait (SDDRV(t) *dev, uintptr_t cnt) {
	hwdrvchar_t *c = &dev->addr[SDCARDTEST_MODE];
	hwdrvchar_interrupt(c, cnt);
	_preempt_disable();
	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
		_thread_sleeponwquntil(&sdwq, (_clkcycles() + _MSECS(20)));
	_preempt_enable();
}
#endif

static SDDRV(t) sd = {
	.addr = sdc,
#if !SDCARDTEST_POLL
	.wait = sdwait,
#endif
};

// Word aligned, as the read and write of the driver require.
static alignas(uintptr_t) uint8_t buf[SDCARDTEST_NBLK * SDDRVM(BLKSZ)];

#if SDCARDTEST_VERIFY
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

// Read the blocks, untimed, SDCARDTEST_NBLK at a time as the timed passes do, and
// set *crc to their CRC32; return the block whose read failed, else the block
// after the last.
static uintptr_t crcpass (uint32_t *crc) {
	uintptr_t end = ((uintptr_t)SDCARDTEST_FIRSTBLK + SDCARDTEST_BLKCNT), i, n, r;
	*crc = 0;
	for (i = SDCARDTEST_FIRSTBLK; i < end; i += n) {
		n = (((end - i) < SDCARDTEST_NBLK) ? (end - i) : SDCARDTEST_NBLK);
		if ((r = SDDRV(read)(&sd, buf, i, n)) != n)
			return (i + r);
		*crc = crc32(*crc, buf, (n * SDDRVM(BLKSZ)));
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
	unsigned long long bytes = ((unsigned long long)SDCARDTEST_BLKCNT * SDDRVM(BLKSZ));
	unsigned long long us = ((cycles * 1000000) / _clkfreq());
	if (!us)
		us = 1;
	char s0[16], s1[16];
	printf("%s%u B (%sB) copied | ⏱️ %u.%06u s | 📊 %sB/s\n",
		label, (unsigned)bytes, hrstr(s0, bytes),
		(unsigned)(us / 1000000), (unsigned)(us % 1000000),
		hrstr(s1, ((bytes * 1000000) / us)));
}

static void failed (const char *op, uintptr_t idx) {
	printf("❌ ERROR: %s block %u failed%s\n", op, (unsigned)idx,
		(sd.blkcnt ? "" : "; the card must be initialized again"));
}

void main (void) {
	printf("🚀 Starting SD-card test ...\n");
#if !SDCARDTEST_POLL
	_irq_register(&sdirq);
	_preempt_disable(); // Insure the irqctrl transaction is not interrupted.
	hwdrvirqctrl_ena(SDCARDTEST_IRQ, 1);
	_preempt_enable();
#endif
	if (!SDDRV(init)(&sd)) {
		printf("❌ ERROR: initialization failed; is a card inserted?\n");
		goto done;
	}
	const char *lowered = "";
#if SDCARDTEST_BITRATE
	if (SDCARDTEST_BITRATE < sd.bitrate) {
		// Half-period in clock cycles rounded up, as the driver does; the
		// driver counts its timeouts at sd.bitrate. In SD mode, the bitrate
		// set through the CMD interface is that of both interfaces.
		uintptr_t n = ((sdc[0].clkfreq + (2*(uintptr_t)SDCARDTEST_BITRATE) - 1) / (2*(uintptr_t)SDCARDTEST_BITRATE));
		sd.bitrate = (sdc[0].clkfreq / (2*n));
		hwdrvchar_init(&sdc[0], sd.bitrate);
		lowered = " (SDCARDTEST_BITRATE)";
	}
#endif
	char s[16];
	printf("💾 %s card | 🔌 %s mode | 📦 %u blocks (%sB)\n"
		"⚡ TRAN_SPEED 0x%02x @ %u bps%s | 🛡️ CRC %s | 🧹 pre-erase %s\n",
		((sd.flags & SDDRVM(FLAG_MMC)) ? "MMC" : (sd.flags & SDDRVM(FLAG_BLKADDR)) ? "SDHC/SDXC" :
		 (sd.flags & SDDRVM(FLAG_SDV2)) ? "SDSC v2" : "SDSC v1"), (SDCARDTEST_MODE ? "SD" : "SPI"),
		(unsigned)sd.blkcnt, hrstr(s, ((unsigned long long)sd.blkcnt * SDDRVM(BLKSZ))),
		(unsigned)sd.csd[3], (unsigned)sd.bitrate, lowered, (SDDRVM(CRC) ? "on" : "off"),
		(SDDRVM(PREERASE) ? "on" : "off"));
	if (SDCARDTEST_BLKCNT > sd.blkcnt || SDCARDTEST_FIRSTBLK > (sd.blkcnt - SDCARDTEST_BLKCNT)) {
		printf("❌ ERROR: blocks %u to %u are beyond the card\n", (unsigned)SDCARDTEST_FIRSTBLK,
			((unsigned)SDCARDTEST_FIRSTBLK + SDCARDTEST_BLKCNT - 1));
		goto done;
	}
	// Chunks of n blocks from i, SDCARDTEST_NBLK but the last, which is fewer when
	// SDCARDTEST_BLKCNT is not a multiple of it; a call transferring r blocks of
	// them failed at the block (i+r).
	uintptr_t end = ((uintptr_t)SDCARDTEST_FIRSTBLK + SDCARDTEST_BLKCNT), i, n = 0, r = 0;
#if SDCARDTEST_VERIFY
	uint32_t crc[2]; // CRC32 of the blocks, before the timed passes, then after the writes.
	crc32init();
	if ((i = crcpass(&crc[0])) != end) {
		failed("reading", i);
		goto done;
	}
#endif
	_date_t t = _clkcycles();
	for (i = SDCARDTEST_FIRSTBLK; i < end; i += n) {
		n = (((end - i) < SDCARDTEST_NBLK) ? (end - i) : SDCARDTEST_NBLK);
		if ((r = SDDRV(read)(&sd, buf, i, n)) != n)
			break;
	}
	t = (_clkcycles() - t);
	if (i < end) {
		failed("reading", (i + r));
		goto done;
	}
	report("📥 Read:  ", t);
	for (t = 0, i = SDCARDTEST_FIRSTBLK; i < end; i += n) {
		n = (((end - i) < SDCARDTEST_NBLK) ? (end - i) : SDCARDTEST_NBLK);
		if ((r = SDDRV(read)(&sd, buf, i, n)) != n) {
			failed("reading", (i + r));
			goto done;
		}
		_date_t t0 = _clkcycles();
		r = SDDRV(write)(&sd, buf, i, n);
		t += (_clkcycles() - t0);
		if (r != n) {
			failed("writing", (i + r));
			goto done;
		}
	}
	report("📤 Write: ", t);
#if SDCARDTEST_VERIFY
	if ((i = crcpass(&crc[1])) != end) {
		failed("reading", i);
		goto done;
	}
	if (crc[1] != crc[0])
		printf("❌ ERROR: CRC32 0x%08x of the blocks read before the writes, 0x%08x after\n",
			(unsigned)crc[0], (unsigned)crc[1]);
	else
		printf("🔍 Verify: %u B (%sB) read back | 🔢 CRC32 0x%08x | ✅ unchanged\n",
			(unsigned)((unsigned long long)SDCARDTEST_BLKCNT * SDDRVM(BLKSZ)),
			hrstr(s, ((unsigned long long)SDCARDTEST_BLKCNT * SDDRVM(BLKSZ))), (unsigned)crc[0]);
#endif
	done: printf("----\n");
}
