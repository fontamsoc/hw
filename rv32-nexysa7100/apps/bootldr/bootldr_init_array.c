// SPDX-License-Identifier: GPL-2.0-only
// 20261020 (c) William Fonkou Tambe

// The functions which bootldr calls before loading the data, as bootldr.c
// describes: litedram_init(), of ../../litedram/litedram.c, initializes and
// calibrates the DDR2 SDRAM of the Nexys A7, which follows its SRAM, and
// raises the end of memory to the end of the DDR2 SDRAM; then, with stack
// data, dtbharts() enables in it, when it is a device tree blob, ie: that of
// a Linux kernel, the harts which the bitstream has.

#include <stdint.h>

uintptr_t litedram_init (void);

#ifdef BOOTLDR_STACKDATA

#include <stdio.h>
#include <string.h>

#include <_os.h>

// The stack data, as bootldr.c defines it.
extern uint8_t __bootldr_stackdata[];
extern const uintptr_t __bootldr_stackdatasz;

// The tokens of the structure block of a device tree blob.
enum { FDT_BEGIN_NODE = 1, FDT_END_NODE = 2, FDT_PROP = 3, FDT_NOP = 4, FDT_END = 9 };

// The word at p, big-endian as every word of a device tree blob.
static uint32_t be32 (const uint8_t *p) {
	return (((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3]);
}

// Store the word v at p, big-endian.
static void setbe32 (uint8_t *p, uint32_t v) {
	p[0] = (v >> 24);
	p[1] = (v >> 16);
	p[2] = (v >> 8);
	p[3] = v;
}

// Walk the structure block of the device tree blob b of sz bytes, whose
// header is of version 17 or later, and return whether the blob is well
// formed; *cpus gets the count of the nodes of harts, ie: the children of
// /cpus named "cpu" or "cpu@...", and *en that of those enabled, ie: whose
// property status is absent, "okay" or "ok". The node of a hart which ncpu
// covers, ie: whose property reg, the hart, is below ncpu, and whose
// property status is "disabled", counts as enabled, and when edit is set,
// gets enabled, in place: its status becomes "okay", padded with null bytes
// to 8 bytes, and the 4 bytes which that frees become the token FDT_NOP.
static bool dtbwalk (uint8_t *b, uintptr_t sz, uintptr_t ncpu, bool edit, uintptr_t *cpus, uintptr_t *en) {
	uint32_t tot = be32(&b[4]), soff = be32(&b[8]), toff = be32(&b[12]);
	uint32_t tsz = be32(&b[32]), ssz = be32(&b[36]);
	if (tot > sz || (soff & 3) || soff > tot || ssz > (tot - soff) || toff > tot || tsz > (tot - toff))
		return false;
	uint8_t *p = &b[soff], *end = &b[soff + ssz];
	const char *strs = (const char *)&b[toff];
	uintptr_t depth = 0;
	// incpus is set while /cpus is open, cpu while the properties of the node
	// of a hart are read: its property reg gives hart, and st points to the
	// token of its property status.
	bool incpus = false, cpu = false, hashart = false;
	uint32_t hart = 0;
	uint8_t *st = 0;
	*cpus = *en = 0;
	for (;;) {
		if ((end - p) < 4)
			return false;
		uint32_t tok = be32(p);
		p += 4;
		// The properties of a node precede its children.
		if (cpu && (tok == FDT_BEGIN_NODE || tok == FDT_END_NODE)) {
			uint32_t sl = (st ? be32(&st[4]) : 0);
			bool on = (!st || (sl == 5 && !memcmp(&st[12], "okay", 5)) || (sl == 3 && !memcmp(&st[12], "ok", 3)));
			if (!on && hashart && hart < ncpu && sl == 9 && !memcmp(&st[12], "disabled", 9)) {
				if (edit) {
					setbe32(&st[4], 5);
					memcpy(&st[12], "okay\0\0\0", 8);
					setbe32(&st[20], FDT_NOP);
				}
				on = true;
			}
			++*cpus;
			*en += on;
			cpu = false;
		}
		if (tok == FDT_BEGIN_NODE) {
			// The name of the node, its null byte, padded to 4 bytes.
			const char *name = (const char *)p;
			uintptr_t l = 0;
			while (&p[l] < end && name[l])
				++l;
			uintptr_t n = ((l + 4) & ~(uintptr_t)3);
			if (n > (uintptr_t)(end - p))
				return false;
			p += n;
			if (++depth == 2)
				incpus = (l == 4 && !memcmp(name, "cpus", 4));
			else if (depth == 3 && incpus && ((l == 3 && !memcmp(name, "cpu", 3)) || (l > 4 && !memcmp(name, "cpu@", 4)))) {
				cpu = true;
				hashart = false;
				st = 0;
			}
		} else if (tok == FDT_END_NODE) {
			if (!depth)
				return false;
			if (--depth < 2)
				incpus = false;
		} else if (tok == FDT_PROP) {
			// The length of the value, the offset of the name in the strings
			// block, then the value, padded to 4 bytes.
			if ((end - p) < 8)
				return false;
			uint32_t len = be32(p), noff = be32(&p[4]);
			uint8_t *v = &p[8];
			uintptr_t room = (end - v);
			if (len > room || ((len + 3) & ~(uintptr_t)3) > room || noff >= tsz)
				return false;
			if (cpu) {
				const char *name = &strs[noff];
				uintptr_t n = (tsz - noff);
				if (n >= 4 && !memcmp(name, "reg", 4) && len >= 4) {
					hart = be32(v);
					hashart = true;
				} else if (n >= 7 && !memcmp(name, "status", 7))
					st = (p - 4);
			}
			p = &v[(len + 3) & ~(uintptr_t)3];
		} else if (tok == FDT_END)
			return !depth;
		else if (tok != FDT_NOP)
			return false;
	}
}

// Enable in the stack data, when it is a device tree blob, the harts which
// the bitstream has, ie: those which underLineOS started, below _ncpu(), as
// dtbwalk() describes, once a first walk found the blob well formed; other
// stack data is left as is. A device tree blob which is malformed, or of a
// version below 17, stops the boot, unedited.
static uintptr_t dtbharts (void) {
	uint8_t *b = __bootldr_stackdata;
	uintptr_t sz = __bootldr_stackdatasz, ncpu = _ncpu(), cpus, en;
	if (sz < 4 || be32(b) != 0xd00dfeed)
		return 1;
	if (sz < 40 || be32(&b[20]) < 17 || !dtbwalk(b, sz, ncpu, false, &cpus, &en)) {
		printf("❌ ERROR: the stack data is a device tree blob which is malformed, or of a version below 17\n");
		return 0;
	}
	(void)dtbwalk(b, sz, ncpu, true, &cpus, &en);
	printf("🌳 Device tree: %u of %u cpu%s enabled\n", (unsigned)en, (unsigned)cpus, ((cpus == 1) ? "" : "s"));
	return 1;
}

uintptr_t (*const __bootldr_init_array[])(void) = {litedram_init, dtbharts, 0};

#else

uintptr_t (*const __bootldr_init_array[])(void) = {litedram_init, 0};

#endif /* BOOTLDR_STACKDATA */
