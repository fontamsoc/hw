// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
//
// Self-checking integer-multiply test (mul/mulh/mulhsu/mulhu). The reference 32x32->64
// product is built in software from shifts and adds ONLY (no mul instruction; verified in
// the objdump), and the signed/mixed variants derive from it by the standard high-word
// corrections. Beyond edge cases + an xorshift32 random sweep, directed blocks put SEVERAL
// multiplies in flight at once -- back-to-back independent muls, same-rd stacking, all four
// op types adjacently on the same operands, and mul/div interleave -- which is what
// exercises a pipelined imul (PUIMULDSP/PUIMULDSPREG) and its result queue/tag paths that
// single-multiply tests never reach.

#include <stdio.h>
#include <stdint.h>

static int passed = 0, failed = 0;

// Software reference product, shift-and-add only; noinline + the loop form keeps the
// compiler from recognizing the idiom and emitting the very mul being tested.
static uint64_t __attribute__((noinline)) ref_mulu64 (uint32_t a, uint32_t b) {
	uint64_t r = 0, aa = a;
	while (b) {
		if (b & 1)
			r += aa;
		aa <<= 1;
		b >>= 1;
	}
	return r;
}

// High-word references derived from the unsigned product:
// mulh(a,b)   = mulhu(a,b) - (a<0 ? b : 0) - (b<0 ? a : 0)
// mulhsu(a,b) = mulhu(a,b) - (a<0 ? b : 0)
static uint32_t ref_mulhu (uint32_t a, uint32_t b) { return (uint32_t)(ref_mulu64(a, b) >> 32); }
static uint32_t ref_mul   (uint32_t a, uint32_t b) { return (uint32_t)ref_mulu64(a, b); }
static uint32_t ref_mulh  (uint32_t a, uint32_t b) {
	return ref_mulhu(a, b) - (((int32_t)a < 0) ? b : 0) - (((int32_t)b < 0) ? a : 0);
}
static uint32_t ref_mulhsu (uint32_t a, uint32_t b) {
	return ref_mulhu(a, b) - (((int32_t)a < 0) ? b : 0);
}

// Hardware ops as single instructions (C 64-bit products would emit mul/mulhu pairs of
// the compiler's choosing; mulhsu has no C idiom at all).
static uint32_t __attribute__((noinline)) h_mul (uint32_t a, uint32_t b) {
	uint32_t r; asm volatile ("mul %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r;
}
static uint32_t __attribute__((noinline)) h_mulh (uint32_t a, uint32_t b) {
	uint32_t r; asm volatile ("mulh %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r;
}
static uint32_t __attribute__((noinline)) h_mulhsu (uint32_t a, uint32_t b) {
	uint32_t r; asm volatile ("mulhsu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r;
}
static uint32_t __attribute__((noinline)) h_mulhu (uint32_t a, uint32_t b) {
	uint32_t r; asm volatile ("mulhu %0, %1, %2" : "=r"(r) : "r"(a), "r"(b)); return r;
}

static void ck (int ok, const char *m, uint32_t a, uint32_t b) {
	if (ok) passed++;
	else { failed++; printf("FAIL %s a=%08x b=%08x\n", m, (unsigned)a, (unsigned)b); }
}

static void check (uint32_t a, uint32_t b) {
	ck(h_mul(a, b)    == ref_mul(a, b),    "mul",    a, b);
	ck(h_mulh(a, b)   == ref_mulh(a, b),   "mulh",   a, b);
	ck(h_mulhsu(a, b) == ref_mulhsu(a, b), "mulhsu", a, b);
	ck(h_mulhu(a, b)  == ref_mulhu(a, b),  "mulhu",  a, b);
}

// Eight INDEPENDENT multiplies issued back-to-back: with nothing between the mul
// instructions, dispatch is limited only by the imul unit's rdy, so this is what fills a
// pipelined imul's result queue (and, before it, what exercises IMULCNT rotation).
static void __attribute__((noinline)) blk_indep (uint32_t s) {
	uint32_t a0 = s, a1 = s + 1, a2 = s + 2, a3 = s + 3;
	uint32_t a4 = s + 4, a5 = s + 5, a6 = s + 6, a7 = s + 7;
	uint32_t m = s | 1;
	asm volatile (
		"mul %0, %0, %8\n\t"
		"mul %1, %1, %8\n\t"
		"mul %2, %2, %8\n\t"
		"mul %3, %3, %8\n\t"
		"mul %4, %4, %8\n\t"
		"mul %5, %5, %8\n\t"
		"mul %6, %6, %8\n\t"
		"mul %7, %7, %8"
		: "+r"(a0), "+r"(a1), "+r"(a2), "+r"(a3), "+r"(a4), "+r"(a5), "+r"(a6), "+r"(a7)
		: "r"(m));
	ck(a0 == ref_mul(s,     m), "indep0", s,     m);
	ck(a1 == ref_mul(s + 1, m), "indep1", s + 1, m);
	ck(a2 == ref_mul(s + 2, m), "indep2", s + 2, m);
	ck(a3 == ref_mul(s + 3, m), "indep3", s + 3, m);
	ck(a4 == ref_mul(s + 4, m), "indep4", s + 4, m);
	ck(a5 == ref_mul(s + 5, m), "indep5", s + 5, m);
	ck(a6 == ref_mul(s + 6, m), "indep6", s + 6, m);
	ck(a7 == ref_mul(s + 7, m), "indep7", s + 7, m);
}

// Dependent chain: each mul consumes the previous one's result through the scoreboard.
static void __attribute__((noinline)) blk_chain (uint32_t s) {
	uint32_t x = s, m = (s | 1);
	uint32_t r = s;
	asm volatile (
		"mul %0, %0, %1\n\t"
		"mul %0, %0, %1\n\t"
		"mul %0, %0, %1\n\t"
		"mul %0, %0, %1"
		: "+r"(x)
		: "r"(m));
	for (int i = 0; i < 4; i++)
		r = ref_mul(r, m);
	ck(x == r, "chain", s, m);
}

// Same rd stacked at 0/1/2-instruction spacings: only the LAST producer's value may
// land in the destination, whatever the spacing between the two writers.
static void __attribute__((noinline)) blk_samerd (uint32_t s) {
	uint32_t a = s | 1, b = s + 3, r0, r1, r2;
	asm volatile ( // back-to-back writers of %0
		"mul %0, %1, %2\n\t"
		"mul %0, %2, %2"
		: "=&r"(r0) : "r"(a), "r"(b));
	ck(r0 == ref_mul(b, b), "samerd0", a, b);
	asm volatile ( // one unrelated instruction apart
		"mul %0, %1, %2\n\t"
		"addi %1, %1, 0\n\t"
		"mul %0, %2, %2"
		: "=&r"(r1), "+r"(a) : "r"(b));
	ck(r1 == ref_mul(b, b), "samerd1", a, b);
	asm volatile ( // two apart
		"mul %0, %1, %2\n\t"
		"addi %1, %1, 0\n\t"
		"addi %1, %1, 0\n\t"
		"mul %0, %2, %1"
		: "=&r"(r2), "+r"(a) : "r"(b));
	ck(r2 == ref_mul(b, a), "samerd2", a, b);
}

// All four op types adjacently on the SAME operands: four differently-typed multiplies
// in flight at once, which is what proves the result-half select travels with its own
// multiply (a single held type would return the wrong half of somebody else's product).
static void __attribute__((noinline)) blk_types (uint32_t a, uint32_t b) {
	uint32_t r0, r1, r2, r3;
	asm volatile (
		"mul    %0, %4, %5\n\t"
		"mulh   %1, %4, %5\n\t"
		"mulhsu %2, %4, %5\n\t"
		"mulhu  %3, %4, %5"
		: "=&r"(r0), "=&r"(r1), "=&r"(r2), "=&r"(r3)
		: "r"(a), "r"(b));
	ck(r0 == ref_mul(a, b),    "types.mul",    a, b);
	ck(r1 == ref_mulh(a, b),   "types.mulh",   a, b);
	ck(r2 == ref_mulhsu(a, b), "types.mulhsu", a, b);
	ck(r3 == ref_mulhu(a, b),  "types.mulhu",  a, b);
}

// mul/div interleave on independent registers: imul and idiv results contend at the
// WriteBack arbiter, where imul has priority over a held idiv result.
static void __attribute__((noinline)) blk_muldiv (uint32_t s) {
	uint32_t a = s | 0x10, b = (s >> 3) | 1, m0, q0, m1, q1;
	asm volatile (
		"mul  %0, %4, %5\n\t"
		"divu %1, %4, %5\n\t"
		"mul  %2, %5, %4\n\t"
		"remu %3, %4, %5"
		: "=&r"(m0), "=&r"(q0), "=&r"(m1), "=&r"(q1)
		: "r"(a), "r"(b));
	ck(m0 == ref_mul(a, b), "muldiv.mul0", a, b);
	ck(q0 == a / b,         "muldiv.divu", a, b);
	ck(m1 == ref_mul(b, a), "muldiv.mul1", a, b);
	ck(q1 == a % b,         "muldiv.remu", a, b);
}

void main (void) {
	static const uint32_t edges[] = {
		0u, 1u, 2u, 3u, 0xffffffffu, 0x80000000u, 0x7fffffffu, 6u, 0xfffffffau,
		20u, 0xffffffecu, 0x80000001u, 100u, 7u, 0x40000000u, 0xc0000000u };
	int ne = (int)(sizeof(edges)/sizeof(edges[0]));
	for (int i = 0; i < ne; i++)
		for (int j = 0; j < ne; j++) {
			check(edges[i], edges[j]);
			blk_types(edges[i], edges[j]);
		}

	uint32_t x = 0x12345678u, y = 0x9e3779b9u;
	for (int k = 0; k < 4000; k++) {
		x ^= x << 13; x ^= x >> 17; x ^= x << 5;
		y ^= y << 13; y ^= y >> 17; y ^= y << 5;
		check(x, y);
		blk_indep(x);
		blk_chain(y);
		blk_samerd(x ^ y);
		blk_types(x, y | 0x80000000u); // one negative-msb operand each round
		blk_muldiv(x);
	}
	printf("MULTEST: %d passed, %d failed\n", passed, failed);
}
