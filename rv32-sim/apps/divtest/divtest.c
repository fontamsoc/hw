// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
//
// Self-checking integer-divide test (div/divu/rem/remu). No independent reference divider:
// every result is checked by the division IDENTITY  q*d + r == n  (with |r| < |d| and the RISC-V
// remainder-sign rule), using the hardware multiplier (verified separately). Divide-by-zero and the
// signed MIN/-1 overflow are checked explicitly. Covers all four ops over edge cases + an xorshift32
// random sweep, so it validates whichever idiv core is built (radix-4 or PUIDIVDSP).

#include <stdio.h>
#include <stdint.h>

static int passed = 0, failed = 0;

// Data-dependent + noinline so the compiler emits real div/divu/rem/remu/mul (no constant folding).
static uint32_t __attribute__((noinline)) h_divu(uint32_t a, uint32_t b){ return a / b; }
static uint32_t __attribute__((noinline)) h_remu(uint32_t a, uint32_t b){ return a % b; }
static int32_t  __attribute__((noinline)) h_div (int32_t  a, int32_t  b){ return a / b; }
static int32_t  __attribute__((noinline)) h_rem (int32_t  a, int32_t  b){ return a % b; }
static uint32_t __attribute__((noinline)) h_mul (uint32_t a, uint32_t b){ return a * b; }

static void ck(int ok, const char *m, uint32_t a, uint32_t b) {
	if (ok) passed++;
	else { failed++; printf("FAIL %s a=%08x b=%08x\n", m, a, b); }
}

static void check(uint32_t a, uint32_t b) {
	// unsigned
	uint32_t qu = h_divu(a, b), ru = h_remu(a, b);
	if (b == 0) {
		ck(qu == 0xffffffffu, "divu0", a, b);
		ck(ru == a,           "remu0", a, b);
	} else {
		ck(h_mul(qu, b) + ru == a && ru < b, "divu", a, b);
	}
	// signed
	int32_t sa = (int32_t)a, sb = (int32_t)b;
	int32_t qs = h_div(sa, sb), rs = h_rem(sa, sb);
	if (sb == 0) {
		ck((uint32_t)qs == 0xffffffffu, "div0", a, b);
		ck(rs == sa,                    "rem0", a, b);
	} else if (a == 0x80000000u && sb == -1) {
		ck((uint32_t)qs == 0x80000000u, "divovf", a, b);
		ck(rs == 0,                     "removf", a, b);
	} else {
		uint32_t ident = h_mul((uint32_t)qs, (uint32_t)sb) + (uint32_t)rs;   // q*d + r
		uint32_t ar = (rs < 0) ? (uint32_t)(-rs) : (uint32_t)rs;             // |r|
		uint32_t ab = (sb < 0) ? (uint32_t)(-sb) : (uint32_t)sb;             // |d|
		int signok = (rs == 0) || ((rs < 0) == (sa < 0));                    // sign(r)==sign(n)
		ck(ident == a && ar < ab && signok, "div", a, b);
	}
}

void main (void) {
	static const uint32_t edges[] = {
		0u, 1u, 2u, 3u, 0xffffffffu, 0x80000000u, 0x7fffffffu, 6u, 0xfffffffau,
		20u, 0xffffffecu, 0x80000001u, 100u, 7u, 0x40000000u, 0xc0000000u };
	int ne = (int)(sizeof(edges)/sizeof(edges[0]));
	for (int i = 0; i < ne; i++)
		for (int j = 0; j < ne; j++)
			check(edges[i], edges[j]);

	uint32_t x = 0x12345678u, y = 0x9e3779b9u;
	for (int k = 0; k < 6000; k++) {
		x ^= x << 13; x ^= x >> 17; x ^= x << 5;
		y ^= y << 13; y ^= y >> 17; y ^= y << 5;
		check(x, y);
		check(x, y & 0xffu);        // small divisors (large quotients)
		check(x & 0xffffu, y);      // small dividends
		check(x, y | 0x80000000u);  // divisors with MSB set (clz=0)
	}
	printf("DIVTEST: %d passed, %d failed\n", passed, failed);
}
