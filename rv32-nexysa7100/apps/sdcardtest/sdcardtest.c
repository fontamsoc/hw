// SPDX-License-Identifier: GPL-2.0-only
// 20260927 (c) William Fonkou Tambe

// Benchmark of the SD card driven by hwdrvsdspi.h: the SDCARDTEST_BLKCNT blocks
// from SDCARDTEST_FIRSTBLK are read, SDCARDTEST_NBLK at a time, then each chunk
// of SDCARDTEST_NBLK blocks is read again and written back with its own content,
// only the writes being timed, hence the card is left as it was, barring a power
// loss during the writes; the last chunk may be shorter. Each pass ends with a
// status line giving the bytes copied, the seconds taken and the rate, the sizes
// being formatted as BusyBox dd does.
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

#include "hwdrvchar.h"
#include "hwdrvirqctrl.h"

#ifndef SDCARDTEST_ADDR
#define SDCARDTEST_ADDR 0xe00
#endif
#ifndef SDCARDTEST_IRQ
#define SDCARDTEST_IRQ 2
#endif
#ifndef SDCARDTEST_FIRSTBLK
#define SDCARDTEST_FIRSTBLK 0
#endif
#ifndef SDCARDTEST_BLKCNT
#define SDCARDTEST_BLKCNT 16384 // 8 MiB.
#endif
#ifndef SDCARDTEST_NBLK
#define SDCARDTEST_NBLK 128 // Blocks per call of hwdrvsdspi_read() and hwdrvsdspi_write(); 1 uses CMD17/CMD24.
#endif
#ifndef SDCARDTEST_BITRATE
#define SDCARDTEST_BITRATE 0 // When non-null, bitrate not to exceed after initialization.
#endif
#ifndef SDCARDTEST_POLL
#define SDCARDTEST_POLL 0 // When non-null, poll instead of sleeping on the interrupt.
#endif
#ifndef SDCARDTEST_CRC
#define SDCARDTEST_CRC 1 // When null, CRC checks are not used, as HWDRVSDSPI_CRC describes.
#endif
#ifndef SDCARDTEST_PREERASE
#define SDCARDTEST_PREERASE 0 // When non-null, writes pre-erase their blocks, as HWDRVSDSPI_PREERASE describes.
#endif

// HWDRVSDSPI_CRC and HWDRVSDSPI_PREERASE are to be defined before including hwdrvsdspi.h.
#define HWDRVSDSPI_CRC SDCARDTEST_CRC
#define HWDRVSDSPI_PREERASE SDCARDTEST_PREERASE
#include "hwdrvsdspi.h"

static_assert((SDCARDTEST_BLKCNT > 0 && SDCARDTEST_BLKCNT <= (0xffffffff/HWDRVSDSPI_BLKSZ)),
	"the byte count is printed with %u");
static_assert((!SDCARDTEST_BITRATE || SDCARDTEST_BITRATE >= 400000),
	"SDCARDTEST_BITRATE below the initialization bitrate");
static_assert((SDCARDTEST_NBLK > 0 && SDCARDTEST_NBLK <= 256),
	"SDCARDTEST_NBLK from 1 to 256 (128 KiB of buffer)");

static hwdrvchar_t spi = {.addr = (void *)SDCARDTEST_ADDR};

#if !SDCARDTEST_POLL
static _waitq_t sdwq; // Where main() sleeps until the interrupt.

// Interrupt callback; it only wakes up main(), the device
// being never accessed from a trap context.
static void sdirqcb (_irq_t *i) {
	(void)i;
	_thread_schedone(&sdwq);
}
static _IRQ_DEF(sdirq, SDCARDTEST_IRQ, sdirqcb);

// Callback of hwdrvsdspi_t.wait: sleep until cnt bytes can be read.
// The interrupt is armed before preemption gets disabled: one occurring
// in-between wakes up no thread, but its threshold is then reached, hence
// the check, done with preemption disabled, does not sleep; one occurring
// once preemption is disabled pends until the sleep, which it ends. A null
// transmit buffer usage means the transmission ended or was aborted, no
// more bytes coming. The sleep is bounded, as the
// callback must return: 20 ms is above the longest wait of the driver,
// about 10 ms, and a thread woken up may wait up to 50 ms (SCHEDLRHZ) before
// running, while the device aborts a transmission paused for 100 ms.
static void sdwait (hwdrvsdspi_t *dev, uintptr_t cnt) {
	hwdrvchar_t *c = dev->addr;
	hwdrvchar_interrupt(c, cnt);
	_preempt_disable();
	if (hwdrvchar_readable(c) < cnt && hwdrvchar_writable(c) != c->bufsz)
		_thread_sleeponwquntil(&sdwq, (_clkcycles() + _MSECS(20)));
	_preempt_enable();
}
#endif

static hwdrvsdspi_t sd = {
	.addr = &spi,
#if !SDCARDTEST_POLL
	.wait = sdwait,
#endif
};

static unsigned char buf[SDCARDTEST_NBLK * HWDRVSDSPI_BLKSZ];

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
	unsigned long long bytes = ((unsigned long long)SDCARDTEST_BLKCNT * HWDRVSDSPI_BLKSZ);
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
	printf("🚀 Starting SDCard test ...\n");
#if !SDCARDTEST_POLL
	_irq_register(&sdirq);
	_preempt_disable(); // Insure the irqctrl transaction is not interrupted.
	hwdrvirqctrl_ena(SDCARDTEST_IRQ, 1);
	_preempt_enable();
#endif
	if (!hwdrvsdspi_init(&sd)) {
		printf("❌ ERROR: initialization failed; is a card inserted?\n");
		goto done;
	}
	const char *lowered = "";
#if SDCARDTEST_BITRATE
	if (SDCARDTEST_BITRATE < sd.bitrate) {
		// Half-period in clock cycles rounded up, as the driver does;
		// the driver counts its timeouts in bytes at sd.bitrate.
		uintptr_t n = ((spi.clkfreq + (2*(uintptr_t)SDCARDTEST_BITRATE) - 1) / (2*(uintptr_t)SDCARDTEST_BITRATE));
		sd.bitrate = (spi.clkfreq / (2*n));
		hwdrvchar_init(&spi, sd.bitrate);
		lowered = " (SDCARDTEST_BITRATE)";
	}
#endif
	char s[16];
	printf("💾 %s card | 📦 %u blocks (%sB) | ⚡ TRAN_SPEED 0x%02x @ %u bps%s | 🛡️ CRC %s | 🧹 pre-erase %s\n",
		((sd.flags & HWDRVSDSPI_FLAG_MMC) ? "MMC" : (sd.flags & HWDRVSDSPI_FLAG_BLKADDR) ? "SDHC/SDXC" :
		 (sd.flags & HWDRVSDSPI_FLAG_SDV2) ? "SDSC v2" : "SDSC v1"),
		(unsigned)sd.blkcnt, hrstr(s, ((unsigned long long)sd.blkcnt * HWDRVSDSPI_BLKSZ)),
		(unsigned)sd.csd[3], (unsigned)sd.bitrate, lowered, (HWDRVSDSPI_CRC ? "on" : "off"),
		(HWDRVSDSPI_PREERASE ? "on" : "off"));
	if (SDCARDTEST_BLKCNT > sd.blkcnt || SDCARDTEST_FIRSTBLK > (sd.blkcnt - SDCARDTEST_BLKCNT)) {
		printf("❌ ERROR: blocks %u to %u are beyond the card\n", (unsigned)SDCARDTEST_FIRSTBLK,
			((unsigned)SDCARDTEST_FIRSTBLK + SDCARDTEST_BLKCNT - 1));
		goto done;
	}
	// Chunks of n blocks from i, SDCARDTEST_NBLK but the last, which is fewer when
	// SDCARDTEST_BLKCNT is not a multiple of it; a call transferring r blocks of
	// them failed at the block (i+r).
	uintptr_t end = ((uintptr_t)SDCARDTEST_FIRSTBLK + SDCARDTEST_BLKCNT), i, n = 0, r = 0;
	_date_t t = _clkcycles();
	for (i = SDCARDTEST_FIRSTBLK; i < end; i += n) {
		n = (((end - i) < SDCARDTEST_NBLK) ? (end - i) : SDCARDTEST_NBLK);
		if ((r = hwdrvsdspi_read(&sd, buf, i, n)) != n)
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
		if ((r = hwdrvsdspi_read(&sd, buf, i, n)) != n) {
			failed("reading", (i + r));
			goto done;
		}
		_date_t t0 = _clkcycles();
		r = hwdrvsdspi_write(&sd, buf, i, n);
		t += (_clkcycles() - t0);
		if (r != n) {
			failed("writing", (i + r));
			goto done;
		}
	}
	report("📤 Write: ", t);
	done: printf("----\n");
}
