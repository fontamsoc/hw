// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
//
// Self-checking Zbc carry-less multiply test: clmul/clmulh/clmulr.
// A pure-software reference (shift-XOR over the 64-bit carry-less product) is
// compared against the hardware instructions for edge cases, an exhaustive
// single-bit sweep, and an xorshift32 random sweep. The hardware and the
// reference compute the SAME carry-less product, so this is a complete
// equivalence check for the clmul core. Beyond check() -- whose three ops -O3
// happens to schedule adjacently, a property of the compiled schedule, not of
// this source -- directed blocks put SEVERAL carry-less multiplies in flight at
// once by construction: back-to-back independent clmuls, a dependent chain,
// same-rd stacking, the three op types adjacently, and a clmul/mul/div
// interleave -- which is what exercises the multi-cycle unit's (PUCLMULMC)
// pipelined acceptance and result queue/type paths that one-at-a-time tests
// never reach.

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

static void ck (int ok, const char *m, uint32_t a, uint32_t b) {
	if (ok) passed++;
	else { failed++; printf("FAIL %s a=%08x b=%08x\n", m, (unsigned)a, (unsigned)b); }
}

// Eight INDEPENDENT carry-less multiplies issued back-to-back: with nothing between the
// clmul instructions, dispatch is limited only by the unit's rdy, so this is what fills
// a pipelined clmul's result queue (and, before it, what exercises CLMULCNT rotation).
static void __attribute__((noinline)) blk_indep (uint32_t s) {
	uint32_t a0 = s, a1 = s + 1, a2 = s + 2, a3 = s + 3;
	uint32_t a4 = s + 4, a5 = s + 5, a6 = s + 6, a7 = s + 7;
	uint32_t m = s | 1;
	asm volatile (
		"clmul %0, %0, %8\n\t"
		"clmul %1, %1, %8\n\t"
		"clmul %2, %2, %8\n\t"
		"clmul %3, %3, %8\n\t"
		"clmul %4, %4, %8\n\t"
		"clmul %5, %5, %8\n\t"
		"clmul %6, %6, %8\n\t"
		"clmul %7, %7, %8"
		: "+r"(a0), "+r"(a1), "+r"(a2), "+r"(a3), "+r"(a4), "+r"(a5), "+r"(a6), "+r"(a7)
		: "r"(m));
	ck(a0 == (uint32_t)sw_clmul64(s,     m), "indep0", s,     m);
	ck(a1 == (uint32_t)sw_clmul64(s + 1, m), "indep1", s + 1, m);
	ck(a2 == (uint32_t)sw_clmul64(s + 2, m), "indep2", s + 2, m);
	ck(a3 == (uint32_t)sw_clmul64(s + 3, m), "indep3", s + 3, m);
	ck(a4 == (uint32_t)sw_clmul64(s + 4, m), "indep4", s + 4, m);
	ck(a5 == (uint32_t)sw_clmul64(s + 5, m), "indep5", s + 5, m);
	ck(a6 == (uint32_t)sw_clmul64(s + 6, m), "indep6", s + 6, m);
	ck(a7 == (uint32_t)sw_clmul64(s + 7, m), "indep7", s + 7, m);
}

// Dependent chain: each clmul consumes the previous one's result through the scoreboard.
static void __attribute__((noinline)) blk_chain (uint32_t s) {
	uint32_t x = s, m = (s | 1);
	uint32_t r = s;
	asm volatile (
		"clmul %0, %0, %1\n\t"
		"clmul %0, %0, %1\n\t"
		"clmul %0, %0, %1\n\t"
		"clmul %0, %0, %1"
		: "+r"(x)
		: "r"(m));
	for (int i = 0; i < 4; i++)
		r = (uint32_t)sw_clmul64(r, m);
	ck(x == r, "chain", s, m);
}

// Same rd stacked at 0/1/2-instruction spacings: only the LAST producer's value may
// land in the destination, whatever the spacing between the two writers.
static void __attribute__((noinline)) blk_samerd (uint32_t s) {
	uint32_t a = s | 1, b = s + 3, r0, r1, r2;
	asm volatile ( // back-to-back writers of %0
		"clmul %0, %1, %2\n\t"
		"clmul %0, %2, %2"
		: "=&r"(r0) : "r"(a), "r"(b));
	ck(r0 == (uint32_t)sw_clmul64(b, b), "samerd0", a, b);
	asm volatile ( // one unrelated instruction apart
		"clmul %0, %1, %2\n\t"
		"addi %1, %1, 0\n\t"
		"clmul %0, %2, %2"
		: "=&r"(r1), "+r"(a) : "r"(b));
	ck(r1 == (uint32_t)sw_clmul64(b, b), "samerd1", a, b);
	asm volatile ( // two apart
		"clmul %0, %1, %2\n\t"
		"addi %1, %1, 0\n\t"
		"addi %1, %1, 0\n\t"
		"clmul %0, %2, %1"
		: "=&r"(r2), "+r"(a) : "r"(b));
	ck(r2 == (uint32_t)sw_clmul64(b, a), "samerd2", a, b);
}

// The three op types adjacently on the SAME operands, guaranteed by construction (not by
// the compiler's schedule as in check()): three differently-typed carry-less multiplies
// in flight at once, which is what proves the slice select travels with its own multiply
// (a single held type would return the wrong slice of somebody else's product).
static void __attribute__((noinline)) blk_types (uint32_t a, uint32_t b) {
	uint32_t r0, r1, r2;
	asm volatile (
		"clmul  %0, %3, %4\n\t"
		"clmulh %1, %3, %4\n\t"
		"clmulr %2, %3, %4"
		: "=&r"(r0), "=&r"(r1), "=&r"(r2)
		: "r"(a), "r"(b));
	uint64_t p = sw_clmul64(a, b);
	ck(r0 == (uint32_t)p,         "types.clmul",  a, b);
	ck(r1 == (uint32_t)(p >> 32), "types.clmulh", a, b);
	ck(r2 == (uint32_t)(p >> 31), "types.clmulr", a, b);
}

// clmul/mul/div interleave on independent registers: their results contend at the
// WriteBack arbiter, where clmul is the lowest-priority multi-cycle unit, ie: its queued
// results are the ones held longest while imul and idiv results drain first.
static void __attribute__((noinline)) blk_mix (uint32_t s) {
	uint32_t a = s | 0x10, b = (s >> 3) | 1, c0, m0, q0, c1, q1;
	asm volatile (
		"clmul  %0, %5, %6\n\t"
		"mul    %1, %5, %6\n\t"
		"divu   %2, %5, %6\n\t"
		"clmulh %3, %5, %6\n\t"
		"remu   %4, %5, %6"
		: "=&r"(c0), "=&r"(m0), "=&r"(q0), "=&r"(c1), "=&r"(q1)
		: "r"(a), "r"(b));
	uint64_t p = sw_clmul64(a, b);
	ck(c0 == (uint32_t)p,         "mix.clmul",  a, b);
	ck(m0 == a * b,               "mix.mul",    a, b);
	ck(q0 == a / b,               "mix.divu",   a, b);
	ck(c1 == (uint32_t)(p >> 32), "mix.clmulh", a, b);
	ck(q1 == a % b,               "mix.remu",   a, b);
}

void main (void) {
	static const uint32_t edges[] = {
		0x00000000u, 0x00000001u, 0x00000002u, 0x00000003u, 0xffffffffu,
		0x80000000u, 0x7fffffffu, 0xaaaaaaaau, 0x55555555u, 0x00010001u,
		0x0000ffffu, 0xffff0000u, 0x12345678u, 0xdeadbeefu, 0xcafebabeu };
	int ne = (int)(sizeof(edges)/sizeof(edges[0]));

	// All edge x edge pairs.
	for (int i = 0; i < ne; i++)
		for (int j = 0; j < ne; j++) {
			check(edges[i], edges[j]);
			blk_types(edges[i], edges[j]);
		}

	// Exhaustive single-bit x single-bit (verifies each partial product/shift).
	for (int i = 0; i < 32; i++)
		for (int j = 0; j < 32; j++)
			check(1u << i, 1u << j);

	// xorshift32 random sweep, driving every directed block each round.
	uint32_t x = 0x00000001u, y = 0xdeadbeefu;
	for (int k = 0; k < 4000; k++) {
		x ^= x << 13; x ^= x >> 17; x ^= x << 5;
		y ^= y << 13; y ^= y >> 17; y ^= y << 5;
		check(x, y);
		blk_indep(x);
		blk_chain(y);
		blk_samerd(x ^ y);
		blk_types(x, y);
		blk_mix(x);
	}

	printf("CLMULTEST: %d passed, %d failed\n", passed, failed);
}
