// SPDX-License-Identifier: GPL-2.0-only
// 20261012 (c) William Fonkou Tambe

// Bootloader: it loads the payload which tools/mkBootldrDat.py formats, ie: the
// .bin of an app linked at 0x1000, from the device at BOOTLDR_DEVADDR to 0x1000,
// then starts it by a system reset, as the load of gdb through the gdbstub starts
// the image which it loaded. The device is a SPI flash driven by hwdrvspiflash.h,
// or an SD card driven by hwdrvsdspi.h in SPI mode or by hwdrvsdsdio.h in SD mode,
// as BOOTLDR_DEVTYPE selects; it is polled, bootldr using no interrupt.
//
// The data at the word BOOTLDR_FIRSTU32 of the device is as follow, in words of
// 4 bytes, little-endian:
// - the signature 0x52444c42, ie: the bytes "BLDR";
// - n, the count of words of the payload, at least 1;
// - the n words of the payload, which get copied to 0x1000;
// - the CRC32 of the (4*n) bytes of the payload, that of zlib.
// The default of BOOTLDR_FIRSTU32, among the defaults of the board below, is a
// word of the flash past its bitstream. On an SD card, whose first partition
// typically begins at 1 MiB, BOOTLDR_FIRSTU32 is to be either a word within the
// gap before it, ie: 128, the block 1, or -1, -2 or -3, which select the entry
// 1, 2 or 3 of the partition table of the MBR of the card, the data being then
// at the beginning of that partition. The entries are indexed from 0, whereas
// fdisk and Linux number the partitions from 1: the entry 1 is the partition 2,
// ie: /dev/sdX2; the entry 0 cannot be selected.
//
// The units of the device which hold the data are read into a buffer, where the
// CRC32 of the payload is checked; then a routine copied right above the buffer,
// which uses no memory but the words it copies, copies the stack data described
// below and the payload to their place, and requests a system reset, which
// restarts every cpu, cache and device, the console included, save the serial_usb
// of the OrangeCrab, but not the memories: the cpu 0 then runs the payload from
// 0x1000, with register sp set to the end of memory, as at every reset, and
// register a1 set by bootldr, a reset writing no register but sp. Register a1
// holds the address below which the memory of the payload lies: that of the stack
// data when there is some, else the end of the memory to use, described below,
// when it is not the end of memory which the reset gives; otherwise a1 is null.
// Hence a payload honoring it begins with "if (a1) sp = a1;". Register a1 is
// meaningful only at the boot which bootldr starts: a later reset, ie: using the
// button, _sysreset() or the load of gdb through the gdbstub, runs the payload
// again, not bootldr, and leaves a1 as it was; hence a payload using the stack
// data, or memory beyond the end of memory which the reset gives, is to keep what
// it needs, ie: in its section .persistent. The crt0.S of underLineOS does not use
// register a1, which it overwrites, and its copy of .data, below the end of
// memory, overwrites the stack data stored there.
//
// The stack data, when BOOTLDR_STACKDATA is defined, is the content of that
// file, ie: a device tree blob, which #embed embeds in bootldr. Padded with null
// bytes to a multiple of 16 bytes, it is stored right below the end of the memory
// to use, rounded down to a multiple of 16; register a1 gives its address.
//
// __bootldr_init_array is an array of pointers to functions, ended by a null
// pointer, which main() calls in order once it printed its first line, before
// initializing the device, ie: to initialize or calibrate a DDR SDRAM. A function
// returns non-null on success; null stops the boot, an error being printed. This
// file defines the array weak, holding only the null pointer; a board defines its
// own in a source file which the makefile compiles as well, given through the
// variable SRCS, ie: make clean && SRCS=ddrinit.c make
// where ddrinit.c holds, for a DDR SDRAM of 128 MiB following 256 KiB of SRAM:
// 	#include <stdint.h>
// 	extern uintptr_t __bootldr_ram_end;
// 	static uintptr_t ddrinit (void) {
// 		... // Initialize and calibrate the DDR SDRAM at 0x41000.
// 		__bootldr_ram_end = 0x8041000; // The end of the DDR SDRAM.
// 		return 1;
// 	}
// 	uintptr_t (*const __bootldr_init_array[])(void) = {ddrinit, 0};
// The functions run once crt0.S has used the memory up to the end of memory
// which the reset gives, hence what they initialize must lie above it; and they
// must leave no thread, timer or interrupt source behind them, as nothing may
// disturb the copy which precedes the reset.
//
// __bootldr_ram_end is the end of the memory to use, set to the end of memory
// which the reset gives before the functions of __bootldr_init_array are called,
// which may change it: raise it, ie: to the end of the memory which they
// initialized, or lower it, ie: to keep memory from the payload. The stack data
// is stored right below it, and the routine and the buffer right below the stack
// data when there is room above the end of memory which the reset gives, else
// below the stack of bootldr. The memory from 0x1000 to __bootldr_ram_end must be
// a contiguous RAM, and the memory beyond the end of memory which the reset gives
// must keep its content across the system reset, ie: its controller must not be
// reset by the irqctrl, as the serial_usb of the OrangeCrab is not; otherwise the
// reset wipes what bootldr stored in it.
//
// The payload is at most the memory from the heap of bootldr to 4 KiB below its
// stack, or to the stack data when it lies lower, less the routine, 128 bytes,
// and the words which precede and follow the payload in the units read; the
// defaults of the board below give its value.
//
// A failure prints a line beginning with "❌ ERROR:" and stops bootldr, nothing
// at 0x1000 having been changed: a reset runs bootldr again.
//
// The drivers hwdrv*.h next to this file are copies of those of ftpu/sw, their
// canonical location.
//
// The defines BOOTLDR_* which follow are set through the environment, ie: for
// the SD card of the Nexys A7, in SD mode at 0xe00, its second MBR partition:
// make clean && CFLAGS='-DBOOTLDR_DEVTYPE=2 -DBOOTLDR_DEVADDR=0xe00 -DBOOTLDR_FIRSTU32=-1' make
// as "make CFLAGS=..." replaces the flags of the makefile, and "make clean"
// is needed since the makefile does not rebuild when only the defines change.

#include <stdio.h>
#include <unistd.h>

#include <_os.h>

// HWDRVCHAR_DATATYPE is to be defined before including hwdrvchar.h: dev/spi.sv
// and dev/sdio.sv transfer a word per access of their data words, as the
// drivers require.
#define HWDRVCHAR_DATATYPE uintptr_t
#include "hwdrvchar.h"
#include "hwdrvirqctrl.h"

// The defaults of the board, the OrangeCrab r0.2 85F: its flash, a W25Q128JV of
// 16 MiB, holds foboot, its DFU bootloader, in its first 512 KiB, then the user
// bitstream; the data is at 2 MiB, past it. Of the 256 KiB of SRAM, the payload
// gets at most about 212 KiB, or about 203 KiB from the SD card, in SPI mode,
// whose driver is larger.
#ifndef BOOTLDR_FIRSTU32
#define BOOTLDR_FIRSTU32 524288 // 2 MiB into the flash.
#endif
#ifndef BOOTLDR_SPIFLASHSIZE
#define BOOTLDR_SPIFLASHSIZE 16777216 // Capacity of the flash in bytes, as HWDRVSPIFLASH_SIZE describes.
#endif

#ifndef BOOTLDR_DEVADDR
#define BOOTLDR_DEVADDR 0xe40
#endif
#ifndef BOOTLDR_DEVTYPE
#define BOOTLDR_DEVTYPE 0 // 0: SPI flash, driven by hwdrvspiflash.h; 1: SD card in SPI mode, by hwdrvsdspi.h; 2: SD card in SD mode, by hwdrvsdsdio.h.
#endif
// BOOTLDR_STACKDATA, undefined by default, is the path of the file of the stack
// data, a string literal, searched from the directory of this file, ie:
// make clean && CFLAGS='-DBOOTLDR_STACKDATA=\"board.dtb\"' make

static_assert((BOOTLDR_DEVTYPE >= 0 && BOOTLDR_DEVTYPE <= 2),
	"BOOTLDR_DEVTYPE is 0 for hwdrvspiflash.h, 1 for hwdrvsdspi.h or 2 for hwdrvsdsdio.h");
static_assert(((long long)(BOOTLDR_FIRSTU32) >= -3 && (long long)(BOOTLDR_FIRSTU32) <= 0xffffffff),
	"BOOTLDR_FIRSTU32 is the index of a uint32_t, or -1, -2 or -3 for an entry of the MBR");

// The index of the first word of the data, and the entry of the MBR which
// BOOTLDR_FIRSTU32 selects, 1 to 3, else 0; a 2's complement negative number
// greater than -4 selects an entry, whether given negative or not, ie: -1 as
// 0xffffffff.
#define FIRSTU32 ((uint32_t)(BOOTLDR_FIRSTU32))
#if ((BOOTLDR_FIRSTU32) < 0 || (BOOTLDR_FIRSTU32) >= 0xfffffffd)
#define MBRENTRY ((uint32_t)-FIRSTU32)
#else
#define MBRENTRY 0
#endif

// The defines HWDRV* are to be defined before including the driver; DEVDRV()
// names the functions and type of the driver in use, ie: DEVDRV(read) is
// hwdrvspiflash_read for the flash. DEVUNIT is the unit of the indexes of the
// driver in words, DEVCAP the field which gives the capacity of the device in
// units, and which a fatal failure nulls.
#if BOOTLDR_DEVTYPE == 0
#define HWDRVSPIFLASH_SIZE BOOTLDR_SPIFLASHSIZE
#include "hwdrvspiflash.h"
#define DEVDRV(N) hwdrvspiflash_##N
#define DEVUNIT 1
#define DEVCAP wordcnt
#define DEVNAME "SPI flash"
#define DEVNOUN "flash"
#define DEVUNITNAME "word"
#define DEVHINT "is the flash answering?"
#elif BOOTLDR_DEVTYPE == 1
#include "hwdrvsdspi.h"
#define DEVDRV(N) hwdrvsdspi_##N
#define DEVUNIT (HWDRVSDSPI_BLKSZ/sizeof(uintptr_t))
#define DEVCAP blkcnt
#define DEVNAME "SD card in SPI mode"
#define DEVNOUN "card"
#define DEVUNITNAME "block"
#define DEVHINT "is a card inserted?"
#else
#include "hwdrvsdsdio.h"
#define DEVDRV(N) hwdrvsdsdio_##N
#define DEVUNIT (HWDRVSDSDIO_BLKSZ/sizeof(uintptr_t))
#define DEVCAP blkcnt
#define DEVNAME "SD card in SD mode"
#define DEVNOUN "card"
#define DEVUNITNAME "block"
#define DEVHINT "is a card inserted?"
#endif

// The serial interfaces of the device: its only one, or in SD mode, its CMD
// interface, then its DAT interface, whose address hwdrvsdsdio_init() sets.
static hwdrvchar_t devc[1 + (BOOTLDR_DEVTYPE == 2)] = {{.addr = (void *)BOOTLDR_DEVADDR}};

// The field wait being null, the driver polls the device.
static DEVDRV(t) dev = {.addr = devc};

#ifdef BOOTLDR_STACKDATA
#if __has_embed(BOOTLDR_STACKDATA) != __STDC_EMBED_FOUND__
#error "BOOTLDR_STACKDATA must be the path of a file which is not empty, searched from the directory of bootldr.c"
#endif
// The stack data, padded with null bytes to a multiple of 16 bytes;
// STACKDATASZ is the size of the file.
enum { STACKDATASZ = sizeof((const uint8_t[]){
#embed BOOTLDR_STACKDATA
}) };
static const alignas(16) uint8_t stackdata[(STACKDATASZ + 15) & ~15] = {
#embed BOOTLDR_STACKDATA
};
#else
enum { STACKDATASZ = 0 };
#endif

// The functions called before loading the data, as described above; a board
// defines its own array, which replaces this one.
__attribute__((weak)) uintptr_t (*const __bootldr_init_array[])(void) = {0};

// The end of the memory to use, as described above.
uintptr_t __bootldr_ram_end;

// The console, at the address where stdout writes, SERIAL0_ADDR of underLineOS.
#define CONADDR 0xf80

// The size in bytes of the routine __bootldr_handoff, defined below.
#define HANDOFFSZ 128
#define STR_(X) #X
#define STR(X) STR_(X)

// The units which hold the header of the data, or the MBR: 1 KiB,
// two blocks of a card, word aligned as the drivers require.
static uint32_t scr[256];

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

// Decimal of v, which the printf of newlib-nano does not print, lacking %ll;
// v is below 10^18.
static char *u64str (char *s, unsigned long long v) {
	if (v >> 32)
		sprintf(s, "%u%09u", (unsigned)(v / 1000000000), (unsigned)(v % 1000000000));
	else
		sprintf(s, "%u", (unsigned)v);
	return s;
}

// The read of the cnt units from the unit first failed, r units being read: at
// the unit (first+r), or after the last unit when r is cnt, the field DEVCAP of
// the device being then null, as hwdrvsdsdio_read() does when the CMD12 which
// follows the last block fails, the read being then fatal all the same.
static void failed (uintptr_t first, uintptr_t r, uintptr_t cnt) {
	if (r < cnt)
		printf("❌ ERROR: reading " DEVUNITNAME " %u failed", (unsigned)(first + r));
	else
		printf("❌ ERROR: ending the read of " DEVUNITNAME "s %u to %u failed",
			(unsigned)first, (unsigned)(first + cnt - 1));
	printf("%s\n", (dev.DEVCAP ? "" : "; the " DEVNOUN " must be initialized again"));
}

// Return the transmit buffer usage of the console in bytes, using the command
// HWDRVCHAR_CMDGETBUFFERUSAGE with the argument 1, as hwdrvchar_writable() does;
// that function needs the buffer size, which hwdrvchar_init() would get while
// setting the speed of the console.
static uintptr_t txusage (void) {
	uintptr_t *addrCmd = (uintptr_t *)(CONADDR + sizeof(uintptr_t));
	uintptr_t dat;
	do {
		dat = ((1<<2) | HWDRVCHAR_CMDGETBUFFERUSAGE);
		dat = _xchg(addrCmd, dat);
	} while ((dat & 0b11) != HWDRVCHAR_CMDDEVRDY);
	dat = HWDRVCHAR_CMDDEVRDY;
	dat = _xchg(addrCmd, dat);
	return ((intptr_t)dat >> 2);
}

// Wait until the console transmitted what stdout wrote to it, as the system
// reset would cut the last lines: until its transmit buffer usage is null, or
// has not decreased for 10 ms, ie: a serial_usb whose host reads nothing; then
// 2 ms more, for the last byte, which leaves the buffer before being transmitted.
static void drain (void) {
	uintptr_t u = txusage(), v;
	_date_t t = _clkcycles();
	while (u && (_clkcycles() - t) < _MSECS(10)) {
		if ((v = txusage()) < u)
			t = _clkcycles();
		u = v;
	}
	for (t = _clkcycles(); (_clkcycles() - t) < _MSECS(2););
}

// The routine which copies the stack data and the payload to their place, then
// requests the system reset; main() copies it right above the buffer, from which
// it is called, never returning, with a0 the address of the payload in the
// buffer, a1 where the stack data goes, which is also the value of register a1
// at reset, a2 the stack data, a3 its count of words, null without stack data,
// a4 n, and a5 IRQCTRLADDR. It is position independent: norelax and pc-relative
// branches only; an .org guards its size. It must access memory only using
// atomic accesses, which go straight to memory, as crt0.S copies .data: an atomic
// access reads the latest value of a word, whose dirty bytes the dcache writes
// back or merges, and allocates no entry of the dcache, neither does it evict
// one. An atomic access replacing a word wholly cached invalidates its entry,
// but one partly cached, its bytes from a byte or halfword store, ie: of the
// buffer of stdout, keeps a stale entry, possibly dirty; hence, from the first
// copy to the reset, which discards the dirty entries of the dcache, no access
// may write such an entry back over the payload: the routine makes none but
// atomic accesses, and there is no fence before the reset, as a fence which
// flushed the dcache would write them back. The .aqrl accesses, and wb_mux,
// which grants the irqctrl once the writes to the SRAM before are acknowledged,
// order the request of the reset after the copies.
extern const uintptr_t __bootldr_handoff[];
__asm__ (
	"	.pushsection .text.__bootldr_handoff,\"ax\",@progbits\n"
	"	.option push\n"
	"	.option norelax\n"
	"	.balign 4\n"
	"	.global __bootldr_handoff\n"
	"__bootldr_handoff:\n"
	"	csrw	mtvec, x0		# a trap would run overwritten code: halt instead\n"
	"	mv	t2, a1\n"
	"1:	beqz	a3, 2f			# the stack data first, its source lying where the payload goes\n"
	"	amoadd.w.aqrl	t0, x0, (a2)\n"
	"	amoswap.w.aqrl	x0, t0, (t2)\n"
	"	addi	a2, a2, 4\n"
	"	addi	t2, t2, 4\n"
	"	addi	a3, a3, -1\n"
	"	j	1b\n"
	"2:	li	t2, 0x1000		# the payload, upward: the destination never passes the source\n"
	"3:	amoadd.w.aqrl	t0, x0, (a0)\n"
	"	amoswap.w.aqrl	x0, t0, (t2)\n"
	"	addi	a0, a0, 4\n"
	"	addi	t2, t2, 4\n"
	"	addi	a4, a4, -1\n"
	"	bnez	a4, 3b\n"
	"	li	t0, -6			# CMDINTDST targeting the destination -1: a system reset\n"
	"4:	amoswap.w.aqrl	x0, zero, (a5)	# CMDDEVRDY closes any open transaction\n"
	"	amoswap.w.aqrl	t1, t0, (a5)\n"
	"	andi	t1, t1, 3		# accepted when the old word's cmd field is null\n"
	"	bnez	t1, 4b\n"
	"5:	wfi				# the reset follows; a1 is never written\n"
	"	j	5b\n"
	"	.org __bootldr_handoff + " STR(HANDOFFSZ) "	# the build fails when the routine exceeds HANDOFFSZ\n"
	"	.option pop\n"
	"	.popsection\n"
);

void main (void) {
	printf("🚀 Starting bootloader ...\n");
	// The end of memory which the reset gives, ie: the value of register sp at
	// reset, below which crt0.S carves, from tp up, the _thread_t of main(), its
	// .tdata, its .tbss, and the copy of .data, whose word of __rst_flg holds the
	// size of .data, crt0.S having set it before the copy.
	extern char __tdata_start[], __tdata_end[], __tbss_start[], __tbss_end[], __DATA_BEGIN__[], _edata[];
	extern uintptr_t __rst_flg;
	uintptr_t datasz = ((uintptr_t)_edata - (uintptr_t)__DATA_BEGIN__);
	uintptr_t memend = ((uintptr_t)_thread_cur + sizeof(_thread_t) +
		((uintptr_t)__tdata_end - (uintptr_t)__tdata_start) +
		((uintptr_t)__tbss_end - (uintptr_t)__tbss_start) + datasz);
	if (*(volatile uintptr_t *)((memend - datasz) + ((uintptr_t)&__rst_flg - (uintptr_t)__DATA_BEGIN__)) != datasz) {
		printf("❌ ERROR: the end of memory is not where crt0.S puts it\n");
		return;
	}
	__bootldr_ram_end = memend;
	// The array is walked through a pointer which GCC cannot trace back to it:
	// the weak definition has one entry, from which GCC would bound the loop.
	uintptr_t (*const *ia)(void) = __bootldr_init_array;
	__asm__ ("" : "+r"(ia));
	for (uintptr_t i = 0; ia[i]; ++i) {
		if (!ia[i]()) {
			printf("❌ ERROR: __bootldr_init_array[%u] failed\n", (unsigned)i);
			return;
		}
	}
	if (!DEVDRV(init)(&dev)) {
		printf("❌ ERROR: initialization failed; " DEVHINT "\n");
		return;
	}
	uintptr_t cap = dev.DEVCAP, r;
	char s0[16], s1[16];
	printf("💾 " DEVNAME " at 0x%x | 📦 %u " DEVUNITNAME "s (%sB) | ⚡ %u bps\n",
		(unsigned)BOOTLDR_DEVADDR, (unsigned)cap,
		hrstr(s0, ((unsigned long long)cap * DEVUNIT * sizeof(uintptr_t))), (unsigned)dev.bitrate);
	// The data begins at the word off of the unit first; the units before end
	// may hold it: those of the partition, else of the device. loc describes
	// where it is for the messages.
	uint64_t first, end;
	uintptr_t off;
	char loc[48];
	if (MBRENTRY) {
		// The MBR is the bytes 0 to 511 of the device: its partition table of 4
		// entries of 16 bytes at the byte 446, then the signature 0x55 0xaa; an
		// entry holds the type of the partition at its byte 4, null when it is
		// empty, then the address of its first block at its byte 8, and its count
		// of blocks at its byte 12, of 512 bytes, little-endian.
		uint8_t *m = (uint8_t *)scr;
		uintptr_t k = (128/DEVUNIT);
		if ((r = DEVDRV(read)(&dev, scr, 0, k)) != k || !dev.DEVCAP) {
			failed(0, r, k);
			return;
		}
		if (m[510] != 0x55 || m[511] != 0xaa) {
			printf("❌ ERROR: no MBR: bytes 510-511 hold 0x%02x 0x%02x\n", m[510], m[511]);
			return;
		}
		uint8_t *e = &m[446 + (16 * MBRENTRY)];
		if (!e[4]) {
			printf("❌ ERROR: MBR partition %u (fdisk's %u) is empty\n", (unsigned)MBRENTRY, (unsigned)(MBRENTRY + 1));
			return;
		}
		uint32_t lba = (e[8] | (e[9] << 8) | (e[10] << 16) | ((uint32_t)e[11] << 24));
		uint32_t cnt = (e[12] | (e[13] << 8) | (e[14] << 16) | ((uint32_t)e[15] << 24));
		first = ((uint64_t)lba * k);
		end = (((uint64_t)lba + cnt) * k);
		off = 0;
		sprintf(loc, "the start of MBR partition %u (fdisk's %u)", (unsigned)MBRENTRY, (unsigned)(MBRENTRY + 1));
		printf("📍 MBR partition %u (fdisk's %u): block %u (%sB)\n", (unsigned)MBRENTRY, (unsigned)(MBRENTRY + 1),
			(unsigned)lba, hrstr(s0, ((unsigned long long)lba * 512)));
	} else {
		first = (FIRSTU32 / DEVUNIT);
		off = (FIRSTU32 % DEVUNIT);
		end = cap;
		sprintf(loc, "word %u", (unsigned)FIRSTU32);
		printf("📍 %s (%sB)\n", loc, hrstr(s0, ((unsigned long long)FIRSTU32 * sizeof(uintptr_t))));
	}
	// The units which may hold the data end at lim, the end of the partition
	// or of the device, whichever comes first.
	uint64_t lim = ((end < cap) ? end : cap);
	const char *limname = ((end < cap) ? "partition" : DEVNOUN);
	// The h units which hold the header, the signature and n.
	uintptr_t h = ((off + 2 + DEVUNIT - 1) / DEVUNIT);
	if ((first + h) > lim) {
		printf("❌ ERROR: no payload at %s: beyond the %s\n", loc, limname);
		return;
	}
	if ((r = DEVDRV(read)(&dev, scr, (uintptr_t)first, h)) != h || !dev.DEVCAP) {
		failed((uintptr_t)first, r, h);
		return;
	}
	if (scr[off] != 0x52444c42) {
		printf("❌ ERROR: no payload at %s: signature 0x%08x, not 0x52444c42 (\"BLDR\")\n",
			loc, (unsigned)scr[off]);
		return;
	}
	uint32_t n = scr[off+1];
	if (!n) {
		printf("❌ ERROR: empty payload at %s\n", loc);
		return;
	}
	// The units which hold the data: the signature, n, the payload, its CRC32.
	uint64_t units = ((off + (uint64_t)n + 2 + 1 + DEVUNIT - 1) / DEVUNIT);
	if ((first + units) > lim) {
		printf("❌ ERROR: payload of %u words at %s goes beyond the %s\n", (unsigned)n, loc, limname);
		return;
	}
	// The stack data goes right below the end of the memory to use, rounded down to
	// a multiple of 16, at d, which the payload gets in register a1 when there is
	// stack data, or when the end of the memory to use was moved.
#ifdef BOOTLDR_STACKDATA
	const void *sdat = stackdata;
	uintptr_t sdsz = sizeof(stackdata);
#else
	const void *sdat = 0;
	uintptr_t sdsz = 0;
#endif
	uintptr_t brk = (uintptr_t)sbrk(0), sp;
	__asm__ __volatile__ ("mv %0, sp" : "=r"(sp));
	uintptr_t e = (__bootldr_ram_end & ~(uintptr_t)15);
	if (e < (brk + HANDOFFSZ + sdsz)) {
		if (sdsz)
			printf("❌ ERROR: stack data of %u B does not fit below 0x%08x\n", (unsigned)STACKDATASZ, (unsigned)e);
		else
			printf("❌ ERROR: __bootldr_ram_end 0x%08x is below bootldr's memory\n", (unsigned)__bootldr_ram_end);
		return;
	}
	uintptr_t d = (e - sdsz), a1 = ((sdsz || e != memend) ? d : 0);
	// The routine goes at l, the buffer of the units read right below it at b,
	// both aligned on 16 bytes: in the upper place, right below d, when d is
	// above the end of memory which the reset gives, ie: in memory which a
	// function of __bootldr_init_array added; else, or when there is no room
	// there, in the lower place, right below d or 4 KiB below the stack of
	// bootldr, whichever comes first, above the heap, the deepest calls of
	// main() using less than 4 KiB of stack. The space found for the buffer
	// is kept in max.
	uint64_t bufsz = (units * DEVUNIT * sizeof(uintptr_t));
	uintptr_t l = 0, b = 0, max = 0;
	if (d > memend) {
		uintptr_t l0 = ((d - HANDOFFSZ) & ~(uintptr_t)15), lo = ((memend + 15) & ~(uintptr_t)15);
		if (l0 >= lo) {
			max = (l0 - lo);
			if (bufsz <= max) {
				l = l0;
				b = ((l0 - (uintptr_t)bufsz) & ~(uintptr_t)15);
			}
		}
	}
	if (!l) {
		uintptr_t top = ((d < (sp - 4096)) ? d : (sp - 4096));
		uintptr_t l0 = ((top - HANDOFFSZ) & ~(uintptr_t)15), lo = ((brk + 15) & ~(uintptr_t)15);
		if (l0 >= lo) {
			if ((l0 - lo) > max)
				max = (l0 - lo);
			if (bufsz <= (l0 - lo)) {
				l = l0;
				b = ((l0 - (uintptr_t)bufsz) & ~(uintptr_t)15);
				// The heap is extended over the buffer and the routine, so that
				// nothing which allocates gets memory from them.
				sbrk((l + HANDOFFSZ) - brk);
			}
		}
	}
	if (!l) {
		// The largest payload, in bytes: the words of the units which fit in max,
		// less those of the header, of the CRC32, and before the header.
		uint64_t w = (((max / (DEVUNIT * sizeof(uintptr_t))) * DEVUNIT));
		w = ((w > (off + 3)) ? (w - (off + 3)) : 0);
		printf("❌ ERROR: payload of %s B does not fit; %u B at most\n",
			u64str(s0, ((unsigned long long)n * sizeof(uintptr_t))), (unsigned)(w * sizeof(uintptr_t)));
		return;
	}
	uintptr_t *buf = (uintptr_t *)b;
	_date_t c = _clkcycles();
	r = DEVDRV(read)(&dev, buf, (uintptr_t)first, (uintptr_t)units);
	c = (_clkcycles() - c);
	if (r != units || !dev.DEVCAP) {
		failed((uintptr_t)first, r, (uintptr_t)units);
		return;
	}
	uintptr_t *pl = &buf[off+2];
	crc32init();
	uint32_t crc = crc32(0, (uint8_t *)pl, (n * sizeof(uintptr_t)));
	if (crc != pl[n]) {
		printf("❌ ERROR: CRC32 0x%08x of the payload, 0x%08x expected\n", (unsigned)crc, (unsigned)pl[n]);
		return;
	}
	unsigned long long bytes = ((unsigned long long)n * sizeof(uintptr_t));
	unsigned long long us = ((c * 1000000) / _clkfreq());
	if (!us)
		us = 1;
	printf("📥 Loaded: %u B (%sB) | ⏱️ %u.%06u s | 📊 %sB/s | 🔢 CRC32 0x%08x ✅\n",
		(unsigned)bytes, hrstr(s0, bytes), (unsigned)(us / 1000000), (unsigned)(us % 1000000),
		hrstr(s1, ((bytes * 1000000) / us)), (unsigned)crc);
	const char *moved = ((e > memend) ? "raised" : "lowered");
	if (!a1)
		printf("🔄 Resetting into the payload at 0x1000 | 📎 a1 null\n");
	else if (!sdsz)
		printf("🔄 Resetting into the payload at 0x1000 | 📎 a1 0x%08x: end of memory %s\n", (unsigned)a1, moved);
	else if (e == memend)
		printf("🔄 Resetting into the payload at 0x1000 | 📎 a1 0x%08x: %u B of stack data\n",
			(unsigned)a1, (unsigned)STACKDATASZ);
	else
		printf("🔄 Resetting into the payload at 0x1000 | 📎 a1 0x%08x: %u B of stack data, end of memory %s to 0x%08x\n",
			(unsigned)a1, (unsigned)STACKDATASZ, moved, (unsigned)e);
	fflush(stdout);
	drain();
	// With interrupts disabled, the routine is copied to l, then each of its
	// words is pushed to memory, as gdbstub_memsync() of _os_gdbstub.c does,
	// from which the icache refills once fence.i invalidated it.
	__asm__ __volatile__ ("csrc mstatus, 0x8" ::: "memory");
	uintptr_t *hp = (uintptr_t *)l;
	for (uintptr_t i = 0; i < (HANDOFFSZ/sizeof(uintptr_t)); ++i)
		hp[i] = __bootldr_handoff[i];
	for (uintptr_t i = 0; i < (HANDOFFSZ/sizeof(uintptr_t)); ++i)
		(void)_xchg(&hp[i], *(volatile uintptr_t *)&hp[i]);
	__asm__ __volatile__ ("fence.i" ::: "memory");
	void (*handoff) (uintptr_t *, uintptr_t, const void *, uintptr_t, uintptr_t, uintptr_t *)
		__attribute__((noreturn)) = (void *)l;
	handoff(pl, a1, sdat, (sdsz / sizeof(uintptr_t)), n, IRQCTRLADDR);
}
