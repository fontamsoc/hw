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

// Whether CRC checks are used, 1 by default; the includer may define it before
// including this file. When non-null, the CMD59 of hwdrvsdspi_init() turns on
// the checks of the card, of the CRC7 of the commands and of the CRC16 of the
// data blocks written, whereas the driver checks the CRC16 of the data blocks
// read. When null, the CMD59 turns them off, and the CRC16 of the data blocks
// is neither computed nor checked, which saves its computation for every block
// transferred: an error in the transfer of a data block then goes undetected,
// and a data block whose write a fatal failure interrupts gets written by the
// card, completed with the bytes 0xff which the next hwdrvsdspi_init() gives
// it, instead of being rejected. The CRC7 of the commands is computed
// regardless, the card always checking those of CMD0 and CMD8.
#ifndef HWDRVSDSPI_CRC
#define HWDRVSDSPI_CRC 1
#endif

// Whether multiple block writes pre-erase their data blocks, 0 by default; the
// includer may define it before including this file. When non-null, a multiple
// block write to an SD card, WRITE_MULTIPLE_BLOCK (CMD25), is preceded by
// SET_WR_BLK_ERASE_COUNT (ACMD23) giving its count of data blocks, which some
// cards write faster; but when the write stops before its last data block, ie:
// on a failure, the content of the data blocks not written is undefined, either
// erased or their previous content. A response R1 to CMD55 or ACMD23 reporting
// an error fails the write as recoverable, nothing being written. It does not
// apply to MMC, which is written a block at a time.
#ifndef HWDRVSDSPI_PREERASE
#define HWDRVSDSPI_PREERASE 0
#endif

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
// follow it included; but CMD12 (STOP_TRANSMISSION), which ends a CMD18
// (READ_MULTIPLE_BLOCK) within the transmission of the CMD18, after its data
// blocks. A CMD25 (WRITE_MULTIPLE_BLOCK) transmission holds its data blocks, the
// busy state which follows each, and the Stop Tran token which ends it. The
// driver closes every transmission, and writes the next one only once the
// transmit buffer usage is null. The busy state which follows a write, CMD24 or
// the Stop Tran token, and a CMD12, is polled using short transmissions, "cs"
// rising between them; delays send clock cycles with "cs" high.
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
// after poweron and the 40 ms before each poll of the initialization, while
// a read waits for a data token beyond its first millisecond, and while a
// multiple block write waits for the end of the busy state of a data block
// beyond its first millisecond; never while a command, its response or data
// bytes are transferred. It is called as follow:
// - With preemption enabled, every byte waited for being written.
// - Its argument cnt, from 1 to bufsz, is the receive buffer usage waited for,
//   which is reached without further action from the driver, within about 10 ms
//   of clocked bytes: transmissions with "cs" high last 10 ms at most, polls of
//   the busy state 100 us at most, and windows waiting for a data token 516
//   bytes at most.
// - The transmission is closed, and ends by itself, except while a read waits
//   for a data token, or a multiple block write for the end of the busy state
//   of a data block, where the transmission is open, and pauses once cnt is
//   reached.
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
// a CRC16 mismatch of the data read when HWDRVSDSPI_CRC is non-null, and a data
// response rejecting the data written, the busy state which follows it being
// awaited; a multiple block read is then ended by CMD12, a multiple block write
// by the Stop Tran token.
// Fatal failures set dev->blkcnt null: no response R1 within the NCR (Command
// Response Time), 8 bytes at most, a response R1 reporting the idle state to a
// read or a write (the card was reset), no data token within the NAC (Data Read
// Access Time), 100 ms at most for each data block, no response to the CMD12
// ending a multiple block read, no valid data response, a busy state lasting
// more than 500 ms, and a transmission aborted by the device, other than a poll
// of the busy state or clock cycles sent with "cs" high. A multiple block read
// failing as fatal once its CMD18 was sent sends CMD12 again as a transmission
// of its own, whose outcome is ignored, so that the card does not remain sending
// data blocks. Those timeouts are counted in bytes clocked at dev->bitrate, hence
// pauses, and a dev->wait slow to return, only lengthen them in time.
// While dev->blkcnt is null, ie: the initialization failed, the card stopped
// answering, or a transmission was aborted, hwdrvsdspi_read() and
// hwdrvsdspi_write() fail without accessing the device, until hwdrvsdspi_init()
// succeeds. After a fatal failure during a transfer, the card may still expect
// or send the rest of a data block, or be busy programming; hwdrvsdspi_init()
// gives it the bytes it needs, then awaits its busy state, before its CMD0.

// Tables of the CRC16 of data blocks, polynomial 0x1021, sliced by 4:
// __hwdrvsdspi_crc16tab[k][i] is the CRC16 of the byte i followed by k null
// bytes, its two bytes swapped, as __hwdrvsdspi_crc16() keeps the CRC16.
static const unsigned short __hwdrvsdspi_crc16tab[4][256] = {
	{
		0x0000, 0x2110, 0x4220, 0x6330, 0x8440, 0xa550, 0xc660, 0xe770,
		0x0881, 0x2991, 0x4aa1, 0x6bb1, 0x8cc1, 0xadd1, 0xcee1, 0xeff1,
		0x3112, 0x1002, 0x7332, 0x5222, 0xb552, 0x9442, 0xf772, 0xd662,
		0x3993, 0x1883, 0x7bb3, 0x5aa3, 0xbdd3, 0x9cc3, 0xfff3, 0xdee3,
		0x6224, 0x4334, 0x2004, 0x0114, 0xe664, 0xc774, 0xa444, 0x8554,
		0x6aa5, 0x4bb5, 0x2885, 0x0995, 0xeee5, 0xcff5, 0xacc5, 0x8dd5,
		0x5336, 0x7226, 0x1116, 0x3006, 0xd776, 0xf666, 0x9556, 0xb446,
		0x5bb7, 0x7aa7, 0x1997, 0x3887, 0xdff7, 0xfee7, 0x9dd7, 0xbcc7,
		0xc448, 0xe558, 0x8668, 0xa778, 0x4008, 0x6118, 0x0228, 0x2338,
		0xccc9, 0xedd9, 0x8ee9, 0xaff9, 0x4889, 0x6999, 0x0aa9, 0x2bb9,
		0xf55a, 0xd44a, 0xb77a, 0x966a, 0x711a, 0x500a, 0x333a, 0x122a,
		0xfddb, 0xdccb, 0xbffb, 0x9eeb, 0x799b, 0x588b, 0x3bbb, 0x1aab,
		0xa66c, 0x877c, 0xe44c, 0xc55c, 0x222c, 0x033c, 0x600c, 0x411c,
		0xaeed, 0x8ffd, 0xeccd, 0xcddd, 0x2aad, 0x0bbd, 0x688d, 0x499d,
		0x977e, 0xb66e, 0xd55e, 0xf44e, 0x133e, 0x322e, 0x511e, 0x700e,
		0x9fff, 0xbeef, 0xdddf, 0xfccf, 0x1bbf, 0x3aaf, 0x599f, 0x788f,
		0x8891, 0xa981, 0xcab1, 0xeba1, 0x0cd1, 0x2dc1, 0x4ef1, 0x6fe1,
		0x8010, 0xa100, 0xc230, 0xe320, 0x0450, 0x2540, 0x4670, 0x6760,
		0xb983, 0x9893, 0xfba3, 0xdab3, 0x3dc3, 0x1cd3, 0x7fe3, 0x5ef3,
		0xb102, 0x9012, 0xf322, 0xd232, 0x3542, 0x1452, 0x7762, 0x5672,
		0xeab5, 0xcba5, 0xa895, 0x8985, 0x6ef5, 0x4fe5, 0x2cd5, 0x0dc5,
		0xe234, 0xc324, 0xa014, 0x8104, 0x6674, 0x4764, 0x2454, 0x0544,
		0xdba7, 0xfab7, 0x9987, 0xb897, 0x5fe7, 0x7ef7, 0x1dc7, 0x3cd7,
		0xd326, 0xf236, 0x9106, 0xb016, 0x5766, 0x7676, 0x1546, 0x3456,
		0x4cd9, 0x6dc9, 0x0ef9, 0x2fe9, 0xc899, 0xe989, 0x8ab9, 0xaba9,
		0x4458, 0x6548, 0x0678, 0x2768, 0xc018, 0xe108, 0x8238, 0xa328,
		0x7dcb, 0x5cdb, 0x3feb, 0x1efb, 0xf98b, 0xd89b, 0xbbab, 0x9abb,
		0x754a, 0x545a, 0x376a, 0x167a, 0xf10a, 0xd01a, 0xb32a, 0x923a,
		0x2efd, 0x0fed, 0x6cdd, 0x4dcd, 0xaabd, 0x8bad, 0xe89d, 0xc98d,
		0x267c, 0x076c, 0x645c, 0x454c, 0xa23c, 0x832c, 0xe01c, 0xc10c,
		0x1fef, 0x3eff, 0x5dcf, 0x7cdf, 0x9baf, 0xbabf, 0xd98f, 0xf89f,
		0x176e, 0x367e, 0x554e, 0x745e, 0x932e, 0xb23e, 0xd10e, 0xf01e,
	},
	{
		0x0000, 0x3133, 0x6266, 0x5355, 0xc4cc, 0xf5ff, 0xa6aa, 0x9799,
		0xa989, 0x98ba, 0xcbef, 0xfadc, 0x6d45, 0x5c76, 0x0f23, 0x3e10,
		0x7303, 0x4230, 0x1165, 0x2056, 0xb7cf, 0x86fc, 0xd5a9, 0xe49a,
		0xda8a, 0xebb9, 0xb8ec, 0x89df, 0x1e46, 0x2f75, 0x7c20, 0x4d13,
		0xe606, 0xd735, 0x8460, 0xb553, 0x22ca, 0x13f9, 0x40ac, 0x719f,
		0x4f8f, 0x7ebc, 0x2de9, 0x1cda, 0x8b43, 0xba70, 0xe925, 0xd816,
		0x9505, 0xa436, 0xf763, 0xc650, 0x51c9, 0x60fa, 0x33af, 0x029c,
		0x3c8c, 0x0dbf, 0x5eea, 0x6fd9, 0xf840, 0xc973, 0x9a26, 0xab15,
		0xcc0d, 0xfd3e, 0xae6b, 0x9f58, 0x08c1, 0x39f2, 0x6aa7, 0x5b94,
		0x6584, 0x54b7, 0x07e2, 0x36d1, 0xa148, 0x907b, 0xc32e, 0xf21d,
		0xbf0e, 0x8e3d, 0xdd68, 0xec5b, 0x7bc2, 0x4af1, 0x19a4, 0x2897,
		0x1687, 0x27b4, 0x74e1, 0x45d2, 0xd24b, 0xe378, 0xb02d, 0x811e,
		0x2a0b, 0x1b38, 0x486d, 0x795e, 0xeec7, 0xdff4, 0x8ca1, 0xbd92,
		0x8382, 0xb2b1, 0xe1e4, 0xd0d7, 0x474e, 0x767d, 0x2528, 0x141b,
		0x5908, 0x683b, 0x3b6e, 0x0a5d, 0x9dc4, 0xacf7, 0xffa2, 0xce91,
		0xf081, 0xc1b2, 0x92e7, 0xa3d4, 0x344d, 0x057e, 0x562b, 0x6718,
		0x981b, 0xa928, 0xfa7d, 0xcb4e, 0x5cd7, 0x6de4, 0x3eb1, 0x0f82,
		0x3192, 0x00a1, 0x53f4, 0x62c7, 0xf55e, 0xc46d, 0x9738, 0xa60b,
		0xeb18, 0xda2b, 0x897e, 0xb84d, 0x2fd4, 0x1ee7, 0x4db2, 0x7c81,
		0x4291, 0x73a2, 0x20f7, 0x11c4, 0x865d, 0xb76e, 0xe43b, 0xd508,
		0x7e1d, 0x4f2e, 0x1c7b, 0x2d48, 0xbad1, 0x8be2, 0xd8b7, 0xe984,
		0xd794, 0xe6a7, 0xb5f2, 0x84c1, 0x1358, 0x226b, 0x713e, 0x400d,
		0x0d1e, 0x3c2d, 0x6f78, 0x5e4b, 0xc9d2, 0xf8e1, 0xabb4, 0x9a87,
		0xa497, 0x95a4, 0xc6f1, 0xf7c2, 0x605b, 0x5168, 0x023d, 0x330e,
		0x5416, 0x6525, 0x3670, 0x0743, 0x90da, 0xa1e9, 0xf2bc, 0xc38f,
		0xfd9f, 0xccac, 0x9ff9, 0xaeca, 0x3953, 0x0860, 0x5b35, 0x6a06,
		0x2715, 0x1626, 0x4573, 0x7440, 0xe3d9, 0xd2ea, 0x81bf, 0xb08c,
		0x8e9c, 0xbfaf, 0xecfa, 0xddc9, 0x4a50, 0x7b63, 0x2836, 0x1905,
		0xb210, 0x8323, 0xd076, 0xe145, 0x76dc, 0x47ef, 0x14ba, 0x2589,
		0x1b99, 0x2aaa, 0x79ff, 0x48cc, 0xdf55, 0xee66, 0xbd33, 0x8c00,
		0xc113, 0xf020, 0xa375, 0x9246, 0x05df, 0x34ec, 0x67b9, 0x568a,
		0x689a, 0x59a9, 0x0afc, 0x3bcf, 0xac56, 0x9d65, 0xce30, 0xff03,
	},
	{
		0x0000, 0x3037, 0x606e, 0x5059, 0xc0dc, 0xf0eb, 0xa0b2, 0x9085,
		0xa1a9, 0x919e, 0xc1c7, 0xf1f0, 0x6175, 0x5142, 0x011b, 0x312c,
		0x6343, 0x5374, 0x032d, 0x331a, 0xa39f, 0x93a8, 0xc3f1, 0xf3c6,
		0xc2ea, 0xf2dd, 0xa284, 0x92b3, 0x0236, 0x3201, 0x6258, 0x526f,
		0xc686, 0xf6b1, 0xa6e8, 0x96df, 0x065a, 0x366d, 0x6634, 0x5603,
		0x672f, 0x5718, 0x0741, 0x3776, 0xa7f3, 0x97c4, 0xc79d, 0xf7aa,
		0xa5c5, 0x95f2, 0xc5ab, 0xf59c, 0x6519, 0x552e, 0x0577, 0x3540,
		0x046c, 0x345b, 0x6402, 0x5435, 0xc4b0, 0xf487, 0xa4de, 0x94e9,
		0xad1d, 0x9d2a, 0xcd73, 0xfd44, 0x6dc1, 0x5df6, 0x0daf, 0x3d98,
		0x0cb4, 0x3c83, 0x6cda, 0x5ced, 0xcc68, 0xfc5f, 0xac06, 0x9c31,
		0xce5e, 0xfe69, 0xae30, 0x9e07, 0x0e82, 0x3eb5, 0x6eec, 0x5edb,
		0x6ff7, 0x5fc0, 0x0f99, 0x3fae, 0xaf2b, 0x9f1c, 0xcf45, 0xff72,
		0x6b9b, 0x5bac, 0x0bf5, 0x3bc2, 0xab47, 0x9b70, 0xcb29, 0xfb1e,
		0xca32, 0xfa05, 0xaa5c, 0x9a6b, 0x0aee, 0x3ad9, 0x6a80, 0x5ab7,
		0x08d8, 0x38ef, 0x68b6, 0x5881, 0xc804, 0xf833, 0xa86a, 0x985d,
		0xa971, 0x9946, 0xc91f, 0xf928, 0x69ad, 0x599a, 0x09c3, 0x39f4,
		0x5a3b, 0x6a0c, 0x3a55, 0x0a62, 0x9ae7, 0xaad0, 0xfa89, 0xcabe,
		0xfb92, 0xcba5, 0x9bfc, 0xabcb, 0x3b4e, 0x0b79, 0x5b20, 0x6b17,
		0x3978, 0x094f, 0x5916, 0x6921, 0xf9a4, 0xc993, 0x99ca, 0xa9fd,
		0x98d1, 0xa8e6, 0xf8bf, 0xc888, 0x580d, 0x683a, 0x3863, 0x0854,
		0x9cbd, 0xac8a, 0xfcd3, 0xcce4, 0x5c61, 0x6c56, 0x3c0f, 0x0c38,
		0x3d14, 0x0d23, 0x5d7a, 0x6d4d, 0xfdc8, 0xcdff, 0x9da6, 0xad91,
		0xfffe, 0xcfc9, 0x9f90, 0xafa7, 0x3f22, 0x0f15, 0x5f4c, 0x6f7b,
		0x5e57, 0x6e60, 0x3e39, 0x0e0e, 0x9e8b, 0xaebc, 0xfee5, 0xced2,
		0xf726, 0xc711, 0x9748, 0xa77f, 0x37fa, 0x07cd, 0x5794, 0x67a3,
		0x568f, 0x66b8, 0x36e1, 0x06d6, 0x9653, 0xa664, 0xf63d, 0xc60a,
		0x9465, 0xa452, 0xf40b, 0xc43c, 0x54b9, 0x648e, 0x34d7, 0x04e0,
		0x35cc, 0x05fb, 0x55a2, 0x6595, 0xf510, 0xc527, 0x957e, 0xa549,
		0x31a0, 0x0197, 0x51ce, 0x61f9, 0xf17c, 0xc14b, 0x9112, 0xa125,
		0x9009, 0xa03e, 0xf067, 0xc050, 0x50d5, 0x60e2, 0x30bb, 0x008c,
		0x52e3, 0x62d4, 0x328d, 0x02ba, 0x923f, 0xa208, 0xf251, 0xc266,
		0xf34a, 0xc37d, 0x9324, 0xa313, 0x3396, 0x03a1, 0x53f8, 0x63cf,
	},
	{
		0x0000, 0xb476, 0x68ed, 0xdc9b, 0xf1ca, 0x45bc, 0x9927, 0x2d51,
		0xc385, 0x77f3, 0xab68, 0x1f1e, 0x324f, 0x8639, 0x5aa2, 0xeed4,
		0xa71b, 0x136d, 0xcff6, 0x7b80, 0x56d1, 0xe2a7, 0x3e3c, 0x8a4a,
		0x649e, 0xd0e8, 0x0c73, 0xb805, 0x9554, 0x2122, 0xfdb9, 0x49cf,
		0x4e37, 0xfa41, 0x26da, 0x92ac, 0xbffd, 0x0b8b, 0xd710, 0x6366,
		0x8db2, 0x39c4, 0xe55f, 0x5129, 0x7c78, 0xc80e, 0x1495, 0xa0e3,
		0xe92c, 0x5d5a, 0x81c1, 0x35b7, 0x18e6, 0xac90, 0x700b, 0xc47d,
		0x2aa9, 0x9edf, 0x4244, 0xf632, 0xdb63, 0x6f15, 0xb38e, 0x07f8,
		0x9c6e, 0x2818, 0xf483, 0x40f5, 0x6da4, 0xd9d2, 0x0549, 0xb13f,
		0x5feb, 0xeb9d, 0x3706, 0x8370, 0xae21, 0x1a57, 0xc6cc, 0x72ba,
		0x3b75, 0x8f03, 0x5398, 0xe7ee, 0xcabf, 0x7ec9, 0xa252, 0x1624,
		0xf8f0, 0x4c86, 0x901d, 0x246b, 0x093a, 0xbd4c, 0x61d7, 0xd5a1,
		0xd259, 0x662f, 0xbab4, 0x0ec2, 0x2393, 0x97e5, 0x4b7e, 0xff08,
		0x11dc, 0xa5aa, 0x7931, 0xcd47, 0xe016, 0x5460, 0x88fb, 0x3c8d,
		0x7542, 0xc134, 0x1daf, 0xa9d9, 0x8488, 0x30fe, 0xec65, 0x5813,
		0xb6c7, 0x02b1, 0xde2a, 0x6a5c, 0x470d, 0xf37b, 0x2fe0, 0x9b96,
		0x38dd, 0x8cab, 0x5030, 0xe446, 0xc917, 0x7d61, 0xa1fa, 0x158c,
		0xfb58, 0x4f2e, 0x93b5, 0x27c3, 0x0a92, 0xbee4, 0x627f, 0xd609,
		0x9fc6, 0x2bb0, 0xf72b, 0x435d, 0x6e0c, 0xda7a, 0x06e1, 0xb297,
		0x5c43, 0xe835, 0x34ae, 0x80d8, 0xad89, 0x19ff, 0xc564, 0x7112,
		0x76ea, 0xc29c, 0x1e07, 0xaa71, 0x8720, 0x3356, 0xefcd, 0x5bbb,
		0xb56f, 0x0119, 0xdd82, 0x69f4, 0x44a5, 0xf0d3, 0x2c48, 0x983e,
		0xd1f1, 0x6587, 0xb91c, 0x0d6a, 0x203b, 0x944d, 0x48d6, 0xfca0,
		0x1274, 0xa602, 0x7a99, 0xceef, 0xe3be, 0x57c8, 0x8b53, 0x3f25,
		0xa4b3, 0x10c5, 0xcc5e, 0x7828, 0x5579, 0xe10f, 0x3d94, 0x89e2,
		0x6736, 0xd340, 0x0fdb, 0xbbad, 0x96fc, 0x228a, 0xfe11, 0x4a67,
		0x03a8, 0xb7de, 0x6b45, 0xdf33, 0xf262, 0x4614, 0x9a8f, 0x2ef9,
		0xc02d, 0x745b, 0xa8c0, 0x1cb6, 0x31e7, 0x8591, 0x590a, 0xed7c,
		0xea84, 0x5ef2, 0x8269, 0x361f, 0x1b4e, 0xaf38, 0x73a3, 0xc7d5,
		0x2901, 0x9d77, 0x41ec, 0xf59a, 0xd8cb, 0x6cbd, 0xb026, 0x0450,
		0x4d9f, 0xf9e9, 0x2572, 0x9104, 0xbc55, 0x0823, 0xd4b8, 0x60ce,
		0x8e1a, 0x3a6c, 0xe6f7, 0x5281, 0x7fd0, 0xcba6, 0x173d, 0xa34b,
	},
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
// The CRC16 is kept with its two bytes swapped, so that its high byte lines up
// with the byte at p in a little-endian word: the bytes are consumed a word at a
// time, the word xored with the CRC16 being looked up a byte at a time in the four
// tables, the byte at p in the last one; the bytes before the first aligned word,
// and those after the last one, are consumed a byte at a time using the first.
// The words are read using __builtin_memcpy(), the buffer not being an array of
// words, which compiles to loads of words, p being aligned.
static uintptr_t __hwdrvsdspi_crc16 (uintptr_t crc, unsigned char *p, uintptr_t n) {
	const unsigned short (*t)[256] = __hwdrvsdspi_crc16tab;
	crc = (((crc & 0xff) << 8) | ((crc >> 8) & 0xff));
	for (; n && ((uintptr_t)p % sizeof(uint32_t)); --n)
		crc = ((crc >> 8) ^ t[0][(crc ^ *p++) & 0xff]);
	for (; n >= (2*sizeof(uint32_t)); n -= (2*sizeof(uint32_t)), p += (2*sizeof(uint32_t))) {
		uint32_t w[2];
		__builtin_memcpy(w, __builtin_assume_aligned(p, sizeof(uint32_t)), sizeof(w));
		w[0] ^= crc;
		crc = (t[3][w[0] & 0xff] ^ t[2][(w[0] >> 8) & 0xff] ^ t[1][(w[0] >> 16) & 0xff] ^ t[0][w[0] >> 24]);
		w[1] ^= crc;
		crc = (t[3][w[1] & 0xff] ^ t[2][(w[1] >> 8) & 0xff] ^ t[1][(w[1] >> 16) & 0xff] ^ t[0][w[1] >> 24]);
	}
	for (; n; --n)
		crc = ((crc >> 8) ^ t[0][(crc ^ *p++) & 0xff]);
	return (((crc & 0xff) << 8) | (crc >> 8));
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

// Write CMD12 (STOP_TRANSMISSION), which ends the CMD18 in progress, then 12
// bytes 0xff: its stuff byte, the 9 bytes of the window of its response R1b,
// NCR being 0 to 8 bytes after the stuff byte, a byte, and a byte checking the
// busy state. Return the index of its first byte.
static uintptr_t __hwdrvsdspi_putstop12 (hwdrvchar_t *c, __hwdrvsdspi_xmit_t *x) {
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t s = x->w;
	__hwdrvsdspi_stage(x, 12, 0, 22);
	__hwdrvsdspi_put(c, x, &bb[4], 18);
	return s;
}

// Send CMD12 (STOP_TRANSMISSION) alone, as a transmission of 22 bytes, whose
// outcome is ignored: it stops a card which a fatal failure left sending the
// data blocks of a CMD18, and is illegal otherwise, which is harmless; its busy
// state is left to the next hwdrvsdspi_init(). Interrupt is left disabled.
static void __hwdrvsdspi_stopread (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, 12, 0, 22);
	__hwdrvsdspi_put(c, x, bb, 22);
	__hwdrvsdspi_close(c);
	__hwdrvsdspi_drain(c, x);
}

// Send the command i with the argument a, and receive the cnt data blocks of L
// bytes which follow, as a single transmission: the command as for
// __hwdrvsdspi_cmd(), R1 from the byte 10 to 18, then per data block, the data
// token after the NAC (Data Read Access Time), up to 100 ms of bytes 0xff, the
// data block and its CRC16. A count of 1 ends with a byte giving the card 8
// clock cycles. A greater count, only used with CMD18, ends with CMD12 right
// after the CRC16 of the last data block, as __hwdrvsdspi_putstop12() writes it:
// the data blocks which the card may begin meanwhile are ignored, and so is its
// stuff byte; its response is awaited, not decoded, since a response shifted by
// a few bits could not be told from an error, which anyway does not concern the
// data blocks received; its busy state is awaited, the transmission closed.
// Until each data token, (L+4) bytes 0xff at most are written ahead of the bytes
// read, refilled once half of them are read, or, beyond the first millisecond
// waiting for that data token, once all of them are read, then waited for using
// dev->wait; then, the remainder of the data block through its CRC16 is written,
// the rest of the transmission after the last one, and it is closed. The bytes
// 0xff which await the data token of the next data block are written once the
// data block is read and its CRC16 checked, the transmission pausing meanwhile,
// which is legal: the card's delay between two data blocks elapses during the
// CRC16 instead of being clocked. The indexes of the bytes are rebased at each
// data block, so that none grows with the count of data blocks.
// The data blocks are copied one after the other from dst when non-null; their
// CRC16 is checked when chk is non-null, which requires dst non-null. R1 is
// stored at r1, 0xff meaning none, and the count of data blocks received, and
// checked when chk is non-null, from the first, at got.
// Return 1 on success; 0 on a recoverable failure: R1 reporting an error, a data
// error token, or a CRC16 mismatch; -1 on a fatal failure: no R1, R1 reporting
// the idle state, no data token within 100 ms, no response to CMD12, its busy
// state lasting more than 500 ms, or the transmission aborted, CMD12 being then
// sent again as a transmission of its own, as __hwdrvsdspi_stopread() does, when
// the count is greater than 1.
static intptr_t __hwdrvsdspi_datain (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x, uintptr_t i,
	uintptr_t a, unsigned char *dst, uintptr_t L, uintptr_t cnt, uintptr_t chk,
	uintptr_t *r1, uintptr_t *got) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t win = (L + 4);
	// Once R1 is received, rok is non-null, and nac is the index of the first
	// byte of the NAC (Data Read Access Time) of the data block awaited, the
	// bytes 0xff which precede its data token.
	uintptr_t rok = 0, nac = 0;
	uintptr_t k0, m, q, p, s = 0;
	intptr_t ret = -1;
	*r1 = 0xff;
	*got = 0;
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, i, a, 10);
	__hwdrvsdspi_put(c, x, bb, 10);
	__hwdrvsdspi_fill(c, x, win);
await:
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x->r; // Index of the first byte read below.
		if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
			if (e) // Idle while open: the transmission was aborted.
				goto aborted;
			if (rok && (x->r - nac) >= (dev->bitrate/8000) && dev->wait) {
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
		if (!rok) {
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
					rok = 1;
					nac = ++k;
					++q;
					break;
				}
				if (k == 18) // No R1.
					goto end;
			}
		}
		if (rok) {
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
				goto stop;
			}
			if ((x->r - nac) > (dev->bitrate/80)) // No data token within 100 ms.
				goto stop;
		}
		// Beyond the first millisecond waiting for the data token, the window
		// is not refilled at its half: it is read whole, then refilled whole
		// above, where dev->wait is called; otherwise, at the highest bitrates,
		// a byte being received during every iteration, the receive buffer
		// would never be found empty, and dev->wait never called.
		if ((x->w - x->r) <= (win/2) && !(rok && dev->wait && (x->r - nac) >= (dev->bitrate/8000)))
			__hwdrvsdspi_fill(c, x, (win - (x->w - x->r)));
	}
token:
	if (cnt == 1) {
		// The remainder is never negative: the count of bytes written is at most
		// (10+win), or the count of bytes read before a refill plus win, hence at
		// most the greatest of (10+win) and (k0+win), whereas p is at least 11 and k0.
		__hwdrvsdspi_fill(c, x, ((p + L + 4) - x->w));
		__hwdrvsdspi_close(c);
	} else {
		// The data block through its CRC16; as above, at most (p+L+4) bytes are
		// written, hence a byte beyond the CRC16 may be written already, which
		// belongs to the NAC of the next data block.
		if (x->w < (p + L + 3))
			__hwdrvsdspi_fill(c, x, ((p + L + 3) - x->w));
	}
	{
		// Bytes are taken as they are received, without sleeping, which
		// would serialize receiving and reading them; a data block of a count
		// greater than 1 is taken through its CRC16, the chunk taken above
		// never going beyond it since it holds 64 bytes at most, less than
		// (L+3) for CMD18.
		uintptr_t o = 0; // Count of bytes of the data block received.
		uintptr_t t = 0; // Count of bytes received after the data block.
		uintptr_t n = ((cnt == 1) ? 3 : 2); // Count of bytes taken after the data block.
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
		if (cnt > 1 && (*got + 1) == cnt) {
			// The last data block: CMD12 follows its CRC16, the bytes beyond it
			// being at most (p+L+4), then the transmission is closed.
			s = __hwdrvsdspi_putstop12(c, x);
			__hwdrvsdspi_close(c);
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
			} else if (t < n) {
				// The CRC16, then, for a count of 1, the byte which follows it.
				if ((k = __hwdrvsdspi_take(c, x, bb, (n - t)))) {
					for (q = 0; q < k; ++q, ++t)
						cb = ((cb << 8) | bb[q]);
					continue;
				}
			} else
				break;
			if (e) // Idle with bytes missing: the transmission was aborted.
				break;
		}
		if (cnt == 1) {
			if (!__hwdrvsdspi_drain(c, x))
				return -1;
			return (!chk || crc == ((cb >> 8) & 0xffff));
		}
		if (o < L || t < n)
			goto aborted;
		if (chk && crc != (cb & 0xffff)) {
			// A CRC16 mismatch: the data blocks before it are counted,
			// and CMD12 follows, written already after the last data block.
			ret = 0;
			if ((*got + 1) == cnt)
				goto tail;
			goto stop;
		}
		if (++*got == cnt) {
			ret = 1;
			goto tail;
		}
		// The next data block: every byte through the CRC16 was read, from
		// which the indexes are rebased, the NAC beginning at 0 with the byte
		// which may have been written beyond the CRC16; the late window.
		dst += L;
		x->w -= x->r;
		x->r = 0;
		nac = 0;
		if (x->w < win)
			__hwdrvsdspi_fill(c, x, (win - x->w));
		goto await;
	}
stop:
	// A data error token, a CRC16 mismatch of a data block before the last,
	// or no data token within 100 ms (ret -1); with a count of 1, the
	// transmission ends after the bytes 0xff written ahead, otherwise CMD12
	// follows them.
	if (cnt == 1)
		goto end;
	s = __hwdrvsdspi_putstop12(c, x);
	__hwdrvsdspi_close(c);
tail:
	{
		// The transmission of a count greater than 1, closed, with CMD12 at s:
		// its response is the first byte other than 0xff from s+7 to s+15, the
		// byte s+6 being its stuff byte, and the byte s+17 is busy while the
		// card is. Every byte written before s is read and ignored.
		uintptr_t ans = 0, v = 0xff;
		for (;;) {
			uintptr_t e = __hwdrvsdspi_idle(c);
			k0 = x->r;
			if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
				if (e)
					break;
				continue;
			}
			for (q = 0; q < m; ++q) {
				uintptr_t k = (k0 + q);
				if (k >= (s + 7) && k <= (s + 15) && bb[q] != 0xff)
					ans = 1;
				else if (k == (s + 17))
					v = bb[q];
			}
		}
		if (x->r != x->w || !ans) {
			// Aborted, or no response to CMD12: the card may still be
			// sending data blocks.
			__hwdrvsdspi_stopread(dev, x);
			return -1;
		}
		// The busy state of the response R1b, if any.
		if (v != 0xff && !__hwdrvsdspi_busy(dev, x))
			return -1;
		return ret;
	}
aborted:
	// The transmission was aborted: idle while open, or with bytes missing.
	// With a count greater than 1, the card may still be sending data blocks,
	// once the command reached it.
	if (cnt == 1)
		goto end;
	__hwdrvsdspi_close(c);
	__hwdrvsdspi_drain(c, x);
	__hwdrvsdspi_stopread(dev, x);
	return -1;
end:
	// Once closed, the transmission ends after the bytes 0xff written ahead. With
	// a count greater than 1, a fatal failure, ie: no R1 or R1 reporting the idle
	// state, also sends CMD12 alone, in case the card began sending data blocks.
	__hwdrvsdspi_close(c);
	if (!__hwdrvsdspi_drain(c, x))
		ret = -1;
	if (cnt > 1 && ret < 0)
		__hwdrvsdspi_stopread(dev, x);
	return ret;
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
	// CRC16, CRC checks being on since the CMD59 of the previous initialization,
	// unless HWDRVSDSPI_CRC is null, the card then writing it as completed.
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
	// CMD59, turn CRC checks on, or off when HWDRVSDSPI_CRC is null.
	r = __hwdrvsdspi_cmd(dev, &x, 59, (HWDRVSDSPI_CRC ? 1 : 0), 0);
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
		r = __hwdrvsdspi_datain(dev, &x, 6, 0x80fffff1, 0, 64, 1, 0, &r1, &n);
		if (r < 0 || (!r && !(r1 & 0x7e)))
			return 0;
	}
	// CMD9, the CSD register, its CRC16 checked when HWDRVSDSPI_CRC is non-null.
	if (__hwdrvsdspi_datain(dev, &x, 9, 0, dev->csd, 16, 1, HWDRVSDSPI_CRC, &r1, &n) != 1)
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

// Read the block of index idx into the buffer ptr, using READ_SINGLE_BLOCK
// (CMD17); return 1 if the block was read, otherwise 0.
static uintptr_t __hwdrvsdspi_read1 (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x,
	unsigned char *ptr, uintptr_t idx) {
	uintptr_t r1, got;
	intptr_t r = __hwdrvsdspi_datain(dev, x, 17,
		((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)), ptr, HWDRVSDSPI_BLKSZ, 1, HWDRVSDSPI_CRC, &r1, &got);
	if (r < 0) { // Fatal; the transmission is closed and has ended.
		dev->blkcnt = 0;
		return 0;
	}
	return r;
}

// Write the block of index idx from the buffer ptr, using WRITE_BLOCK (CMD24);
// return 1 if the block was written, otherwise 0.
static uintptr_t __hwdrvsdspi_write1 (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x,
	unsigned char *ptr, uintptr_t idx) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	// The CRC16 is computed before the transmission, bringing ptr in the data cache;
	// when HWDRVSDSPI_CRC is null, bytes 0xff are sent in its place, which the card
	// ignores.
	uintptr_t crc = (HWDRVSDSPI_CRC ? __hwdrvsdspi_crc16(0, ptr, HWDRVSDSPI_BLKSZ) : 0xffff);
	uintptr_t r1 = 0x100, dr = 0x100, v = 0, k0, m, q; // 0x100 meaning none yet.
	// The command and the window of its response R1, the NCR (Command Response
	// Time), the transmission left open, pausing while R1 gets checked.
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, 24, ((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)), 19);
	__hwdrvsdspi_put(c, x, bb, 19);
	while (r1 > 0xff) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x->r;
		if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
			if (e) // Idle while open: the transmission was aborted.
				return __hwdrvsdspi_fatal(dev, x);
			continue;
		}
		for (q = 0; q < m; ++q) {
			if ((k0 + q) >= 10 && !(bb[q] & 0x80)) {
				r1 = bb[q];
				break;
			}
		}
		if (r1 > 0xff && x->r == x->w) // No R1.
			return __hwdrvsdspi_fatal(dev, x);
	}
	if (r1) {
		// Rejected, the data block is not sent; a byte gives the card
		// 8 clock cycles after R1. A card reporting the idle state was reset.
		__hwdrvsdspi_put(c, x, __hwdrvsdspi_ff, 1);
		if (r1 & 0x01)
			return __hwdrvsdspi_fatal(dev, x);
		__hwdrvsdspi_close(c);
		if (!__hwdrvsdspi_drain(c, x))
			dev->blkcnt = 0;
		return 0;
	}
	// A byte 0xff, the data token, the data block and its CRC16, the 8 bytes 0xff
	// within which the data response is expected (bytes 535 to 542), then 2 bytes
	// 0xff: the internal write begins a byte after the data response, hence the
	// last byte (544) is busy if the card is.
	bb[0] = 0xff;
	bb[1] = 0xfe;
	__hwdrvsdspi_put(c, x, bb, 2);
	__hwdrvsdspi_put(c, x, ptr, HWDRVSDSPI_BLKSZ);
	bb[0] = (crc >> 8);
	bb[1] = crc;
	for (q = 2; q < 12; ++q)
		bb[q] = 0xff;
	__hwdrvsdspi_put(c, x, bb, 12);
	__hwdrvsdspi_close(c);
	for (;;) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x->r;
		if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
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
	if (!__hwdrvsdspi_drain(c, x))
		return __hwdrvsdspi_fatal(dev, x);
	// The busy state is awaited whether the data was accepted or not, and even
	// without a valid data response, since the initialization which a fatal
	// failure requires begins with CMD0, which would end a write in progress.
	if (v != 0xff && !__hwdrvsdspi_busy(dev, x))
		return __hwdrvsdspi_fatal(dev, x);
	// A data response is xxx0sss1: none, or a byte not of that form, ie: a busy
	// state instead, is fatal; sss is 010 when the data was accepted.
	if (dr > 0xff || (dr & 0x11) != 0x01)
		return __hwdrvsdspi_fatal(dev, x);
	return ((dr & 0x0e) == 0x04);
}

// Wait until the card is no longer busy after a data block of a multiple block
// write, within its transmission, "cs" remaining low: windows of k bytes 0xff,
// each read whole, until one ends with a byte 0xff, the card driving its output
// low while busy. A window overshooting the end of the busy state by up to its
// size, k doubles from 8 up to 64 bytes through the first millisecond of those
// bytes, while the driver spins, then up to about 100 us of bytes, dev->wait
// being called for each window, the transmission pausing at its end. Return
// null if the card is still busy after 500 ms of clocked bytes, or if the
// transmission was aborted.
static uintptr_t __hwdrvsdspi_inbusy (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t budget = (dev->bitrate/16), cap = (dev->bitrate/80000), k = 8, n = 0, v = 0;
	if (cap > c->bufsz)
		cap = c->bufsz;
	if (!cap)
		cap = 1;
	while (budget) {
		if (k > cap)
			k = cap;
		if (n < (dev->bitrate/8000) && k > 64)
			k = 64;
		if (k > budget)
			k = budget;
		__hwdrvsdspi_fill(c, x, k);
		if (n >= (dev->bitrate/8000) && dev->wait)
			dev->wait(dev, (x->w - x->r));
		while (x->r != x->w) {
			uintptr_t e = __hwdrvsdspi_idle(c), m;
			if ((m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb))))
				v = bb[m-1];
			else if (e) // Idle with bytes missing: the transmission was aborted.
				return 0;
		}
		budget -= k;
		n += k;
		if (v == 0xff)
			return 1;
		k *= 2;
	}
	return 0;
}

// Write the cnt data blocks at ptr, cnt being at least 2, from the address a,
// using WRITE_MULTIPLE_BLOCK (CMD25), as a single transmission: the command and
// the window of its response R1, as for CMD24, the transmission pausing while
// R1 gets checked, then per data block, a byte 0xff, the data token 0xfc, the
// data block and its CRC16, the 8 bytes 0xff within which the data response is
// expected, then 2 bytes 0xff, the last being busy if the card is, its busy
// state being then awaited within the transmission by __hwdrvsdspi_inbusy(); the
// CRC16 of the next data block is computed before, while the card is busy.
// Last, a byte 0xff, the Stop Tran token 0xfd, and 2 bytes 0xff, the last being
// busy if the card is: the busy state of the Stop Tran token is awaited by
// __hwdrvsdspi_busy(), the transmission closed.
// The indexes of the bytes are rebased at each data block. A data block rejected
// by its data response ends the write the same way, its busy state awaited.
// When HWDRVSDSPI_PREERASE is non-null, CMD55 and ACMD23 (SET_WR_BLK_ERASE_COUNT)
// precede CMD25, each as a transmission of its own.
// Return the count of data blocks known written, from the first: cnt on success,
// the count of the data blocks before a data block rejected for its CRC16, none
// after a write error, which may concern an earlier data block, and none after a
// fatal failure, which sets dev->blkcnt null: no response R1, R1 reporting the
// idle state, no valid data response, a busy state lasting more than 500 ms, or
// the transmission aborted.
static uintptr_t __hwdrvsdspi_mbwrite (hwdrvsdspi_t *dev, __hwdrvsdspi_xmit_t *x,
	unsigned char *ptr, uintptr_t a, uintptr_t cnt) {
	hwdrvchar_t *c = dev->addr;
	unsigned char *bb = (unsigned char *)x->bb;
	uintptr_t crc = (HWDRVSDSPI_CRC ? __hwdrvsdspi_crc16(0, ptr, HWDRVSDSPI_BLKSZ) : 0xffff);
	uintptr_t r1 = 0x100, ret = cnt, k0, m, q, b; // 0x100 meaning none yet.
	if (HWDRVSDSPI_PREERASE) {
		// The count of data blocks to pre-erase, which ACMD23 holds in 23 bits;
		// ACMD23 is sent only if CMD55 succeeded.
		intptr_t r = __hwdrvsdspi_cmd(dev, x, 55, 0, 0);
		if (!r)
			r = __hwdrvsdspi_cmd(dev, x, 23, ((cnt > 0x7fffff) ? 0x7fffff : cnt), 0);
		if (r < 0 || (r & 0x01)) { // No response R1, or the card was reset.
			dev->blkcnt = 0;
			return 0;
		}
		if (r) // A response R1 reporting an error: nothing is written.
			return 0;
	}
	// The command and the window of its response R1, as for CMD24.
	__hwdrvsdspi_open(c, x);
	__hwdrvsdspi_stage(x, 25, a, 19);
	__hwdrvsdspi_put(c, x, bb, 19);
	while (r1 > 0xff) {
		uintptr_t e = __hwdrvsdspi_idle(c);
		k0 = x->r;
		if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
			if (e) // Idle while open: the transmission was aborted.
				return __hwdrvsdspi_fatal(dev, x);
			continue;
		}
		for (q = 0; q < m; ++q) {
			if ((k0 + q) >= 10 && !(bb[q] & 0x80)) {
				r1 = bb[q];
				break;
			}
		}
		if (r1 > 0xff && x->r == x->w) // No R1.
			return __hwdrvsdspi_fatal(dev, x);
	}
	if (r1) {
		// Rejected, no data block is sent, as for CMD24.
		__hwdrvsdspi_put(c, x, __hwdrvsdspi_ff, 1);
		if (r1 & 0x01)
			return __hwdrvsdspi_fatal(dev, x);
		__hwdrvsdspi_close(c);
		if (!__hwdrvsdspi_drain(c, x))
			dev->blkcnt = 0;
		return 0;
	}
	for (b = 0; b < cnt; ++b, ptr += HWDRVSDSPI_BLKSZ) {
		// The indexes are rebased at the first byte not read: j is then the
		// index of the byte 0xff before the data token, 19 less the bytes of
		// the window of R1 read for the first data block, 0 for the others,
		// every byte of the busy state of the previous data block being read.
		uintptr_t j, dr = 0x100, v = 0, valid, acc;
		x->w -= x->r;
		x->r = 0;
		j = x->w;
		bb[0] = 0xff;
		bb[1] = 0xfc;
		__hwdrvsdspi_put(c, x, bb, 2);
		__hwdrvsdspi_put(c, x, ptr, HWDRVSDSPI_BLKSZ);
		bb[0] = (crc >> 8);
		bb[1] = crc;
		for (q = 2; q < 12; ++q)
			bb[q] = 0xff;
		__hwdrvsdspi_put(c, x, bb, 12);
		// The data response is the first byte other than 0xff from (j+516) to
		// (j+523), and the byte (j+525) is busy if the card is; every byte is
		// taken, spinning.
		while (x->r != x->w) {
			uintptr_t e = __hwdrvsdspi_idle(c);
			k0 = x->r;
			if (!(m = __hwdrvsdspi_take(c, x, bb, sizeof(x->bb)))) {
				if (e) // Idle while open: the transmission was aborted.
					return __hwdrvsdspi_fatal(dev, x);
				continue;
			}
			for (q = 0; q < m; ++q) {
				uintptr_t k = (k0 + q);
				if (k >= (j + 516) && k <= (j + 523) && dr > 0xff && bb[q] != 0xff)
					dr = bb[q];
				else if (k == (j + 525))
					v = bb[q];
			}
		}
		// A data response is xxx0sss1, sss being 010 when the data was accepted.
		valid = (dr <= 0xff && (dr & 0x11) == 0x01);
		acc = (valid && (dr & 0x0e) == 0x04);
		// The CRC16 of the next data block, while the card is busy, the
		// transmission pausing meanwhile.
		if (acc && (b + 1) < cnt)
			crc = (HWDRVSDSPI_CRC ? __hwdrvsdspi_crc16(0, (ptr + HWDRVSDSPI_BLKSZ), HWDRVSDSPI_BLKSZ) : 0xffff);
		// The busy state is awaited whether the data was accepted or not, and
		// even without a valid data response, as for CMD24.
		if (v != 0xff && !__hwdrvsdspi_inbusy(dev, x))
			return __hwdrvsdspi_fatal(dev, x);
		if (!valid)
			return __hwdrvsdspi_fatal(dev, x);
		if (!acc) {
			// Rejected: 101 for a CRC error, which concerns this data block;
			// otherwise a write error, which may concern an earlier one.
			ret = (((dr & 0x0e) == 0x0a) ? b : 0);
			break;
		}
	}
	// A byte 0xff, the Stop Tran token, a byte 0xff (NBR), then a byte 0xff
	// which is busy if the card is: the busy state begins a byte after the
	// Stop Tran token, as after a data response.
	bb[0] = 0xff;
	bb[1] = 0xfd;
	bb[2] = 0xff;
	bb[3] = 0xff;
	__hwdrvsdspi_put(c, x, bb, 4);
	__hwdrvsdspi_close(c);
	if (!__hwdrvsdspi_drain(c, x))
		return __hwdrvsdspi_fatal(dev, x);
	if (x->v != 0xff && !__hwdrvsdspi_busy(dev, x))
		return __hwdrvsdspi_fatal(dev, x);
	return ret;
}

// Read cnt blocks from the sdspi device into the buffer given by the argument
// ptr, which holds cnt*HWDRVSDSPI_BLKSZ bytes. The index of the first block to
// read is given by the argument idx, where a block is HWDRVSDSPI_BLKSZ bytes.
// A count of 1 uses READ_SINGLE_BLOCK (CMD17), a greater count
// READ_MULTIPLE_BLOCK (CMD18) ended by STOP_TRANSMISSION (CMD12), unless the
// card is MMC, which is read a block at a time.
// Returns the count of blocks read, from the first, each at its place in ptr:
// cnt on success, fewer on a failure, the rest of ptr being then undefined; 0
// without accessing the device when cnt is null, when the blocks are beyond
// the card, or while dev->blkcnt is null.
static uintptr_t hwdrvsdspi_read (hwdrvsdspi_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	// Overflow-safe: (dev->blkcnt - cnt) does not wrap once cnt <= dev->blkcnt.
	if (!cnt || cnt > dev->blkcnt || idx > (dev->blkcnt - cnt))
		return 0;
	__hwdrvsdspi_xmit_t x;
	unsigned char *p = ptr;
	uintptr_t r1, n;
	if (cnt == 1 || (dev->flags & HWDRVSDSPI_FLAG_MMC)) {
		for (n = 0; n < cnt && __hwdrvsdspi_read1(dev, &x, p, idx); ++n, ++idx, p += HWDRVSDSPI_BLKSZ);
		return n;
	}
	if (__hwdrvsdspi_datain(dev, &x, 18, ((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)),
		p, HWDRVSDSPI_BLKSZ, cnt, HWDRVSDSPI_CRC, &r1, &n) < 0)
		dev->blkcnt = 0; // Fatal; the transmission is closed and has ended.
	return n;
}

// Write cnt blocks to the sdspi device from the buffer given by the argument
// ptr, which holds cnt*HWDRVSDSPI_BLKSZ bytes. The index of the first block to
// write is given by the argument idx, where a block is HWDRVSDSPI_BLKSZ bytes.
// A count of 1 uses WRITE_BLOCK (CMD24), a greater count WRITE_MULTIPLE_BLOCK
// (CMD25), preceded by SET_WR_BLK_ERASE_COUNT (ACMD23) when HWDRVSDSPI_PREERASE
// is non-null, and ended by the Stop Tran token, unless the card is MMC, which
// is written a block at a time.
// Returns the count of blocks written, from the first, which may understate
// them: cnt on success; after a failure, the blocks beyond the count may have
// been written or not, or erased when HWDRVSDSPI_PREERASE is non-null, ie: a
// block rejected for its CRC16 counts the blocks before it, whereas a write
// error, which may concern an earlier block, and a fatal failure count none; 0
// without accessing the device as for a read.
static uintptr_t hwdrvsdspi_write (hwdrvsdspi_t *dev, void* ptr, uintptr_t idx, uintptr_t cnt) {
	if (!cnt || cnt > dev->blkcnt || idx > (dev->blkcnt - cnt))
		return 0;
	__hwdrvsdspi_xmit_t x;
	unsigned char *p = ptr;
	uintptr_t n;
	if (cnt == 1 || (dev->flags & HWDRVSDSPI_FLAG_MMC)) {
		for (n = 0; n < cnt && __hwdrvsdspi_write1(dev, &x, p, idx); ++n, ++idx, p += HWDRVSDSPI_BLKSZ);
		return n;
	}
	return __hwdrvsdspi_mbwrite(dev, &x, p, ((dev->flags & HWDRVSDSPI_FLAG_BLKADDR) ? idx : (idx << 9)), cnt);
}

#endif /* HWDRVSDSPI_H */
