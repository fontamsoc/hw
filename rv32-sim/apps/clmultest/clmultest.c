// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
//
// Self-checking Zbc carry-less multiply test: clmul/clmulh/clmulr.
// A pure-software reference (shift-XOR over the 64-bit carry-less product) is
// compared against the hardware instructions for edge cases, an exhaustive
// single-bit sweep, and an xorshift32 random sweep. The hardware and the
// reference compute the SAME carry-less product, so this is a complete
// equivalence check for whichever clmul core is built (iterative or PUCLMULCOMB).

#include <stdio.h>
#include <stdint.h>

static int passed = 0, failed = 0;

// Hardware ops via inline asm (GPR operands; requires -march=...zbc).
static inline uint32_t hw_clmul (uint32_t a, uint32_t b){ uint32_t z; asm volatile("clmul  %0,%1,%2":"=r"(z):"r"(a),"r"(b)); return z; }
static inline uint32_t hw_clmulh(uint32_t a, uint32_t b){ uint32_t z; asm volatile("clmulh %0,%1,%2":"=r"(z):"r"(a),"r"(b)); return z; }
static inline uint32_t hw_clmulr(uint32_t a, uint32_t b){ uint32_t z; asm volatile("clmulr %0,%1,%2":"=r"(z):"r"(a),"r"(b)); return z; }

// Software reference: full 64-bit carry-less product P = XOR_i (b[i] ? a<<i : 0).
static uint64_t sw_clmul64(uint32_t a, uint32_t b) {
	uint64_t p = 0;
	for (int i = 0; i < 32; i++)
		if (b & (1u << i)) p ^= ((uint64_t)a) << i;
	return p;
}

static void check(uint32_t a, uint32_t b) {
	uint64_t p = sw_clmul64(a, b);
	uint32_t e_l = (uint32_t)(p);        // clmul : P[31:0]
	uint32_t e_h = (uint32_t)(p >> 32);  // clmulh: P[63:32]
	uint32_t e_r = (uint32_t)(p >> 31);  // clmulr: P[62:31]
	uint32_t g_l = hw_clmul (a, b);
	uint32_t g_h = hw_clmulh(a, b);
	uint32_t g_r = hw_clmulr(a, b);
	if (g_l != e_l) { failed++; printf("FAIL clmul  a=%08x b=%08x got=%08x exp=%08x\n", a, b, g_l, e_l); } else passed++;
	if (g_h != e_h) { failed++; printf("FAIL clmulh a=%08x b=%08x got=%08x exp=%08x\n", a, b, g_h, e_h); } else passed++;
	if (g_r != e_r) { failed++; printf("FAIL clmulr a=%08x b=%08x got=%08x exp=%08x\n", a, b, g_r, e_r); } else passed++;
}

void main (void) {
	static const uint32_t edges[] = {
		0x00000000u, 0x00000001u, 0x00000002u, 0x00000003u, 0xffffffffu,
		0x80000000u, 0x7fffffffu, 0xaaaaaaaau, 0x55555555u, 0x00010001u,
		0x0000ffffu, 0xffff0000u, 0x12345678u, 0xdeadbeefu, 0xcafebabeu };
	int ne = (int)(sizeof(edges)/sizeof(edges[0]));

	// All edge x edge pairs.
	for (int i = 0; i < ne; i++)
		for (int j = 0; j < ne; j++)
			check(edges[i], edges[j]);

	// Exhaustive single-bit x single-bit (verifies each partial product/shift).
	for (int i = 0; i < 32; i++)
		for (int j = 0; j < 32; j++)
			check(1u << i, 1u << j);

	// xorshift32 random sweep.
	uint32_t x = 0x00000001u, y = 0xdeadbeefu;
	for (int k = 0; k < 4000; k++) {
		x ^= x << 13; x ^= x >> 17; x ^= x << 5;
		y ^= y << 13; y ^= y >> 17; y ^= y << 5;
		check(x, y);
	}

	printf("CLMULTEST: %d passed, %d failed\n", passed, failed);
}
