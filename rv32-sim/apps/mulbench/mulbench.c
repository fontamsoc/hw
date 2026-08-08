// SPDX-License-Identifier: GPL-2.0-only

// Integer-multiply throughput/latency microbenchmark.
//
// Two loops of 200000 hardware multiplies each, in asm so their shape is exact:
// a DEPENDENT chain (each mul consumes the previous result, measuring latency
// through the scoreboard) and eight INDEPENDENT streams issued back-to-back
// (measuring acceptance throughput, ie: how often the imul unit's rdy lets the
// next mul in -- the number that separates a serialized multiplier from a
// pipelined one such as PUIMULDSPREG). The multiplier operand is runtime-variable
// and data-dependent so nothing constant-folds.

#include <stdio.h>

#include <_os.h>

void main () {
	volatile unsigned vm = 0x9e3779b9u;
	unsigned m = vm;
	unsigned acc = 1234567u;
	unsigned a0 = 1u, a1 = 2u, a2 = 3u, a3 = 4u, a4 = 5u, a5 = 6u, a6 = 7u, a7 = 8u;
	const unsigned N = 200000u;

	_date_t t0 = _clkcycles();
	for (unsigned i = 0; i < (N / 8u); ++i) {
		asm volatile (
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1\n\t"
			"mul %0, %0, %1"
			: "+r"(acc)
			: "r"(m));
		m = vm + (acc & 1u);
	}
	_date_t t1 = _clkcycles();
	for (unsigned i = 0; i < (N / 8u); ++i) {
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
		m = vm + ((a0 ^ a7) & 1u);
	}
	_date_t t2 = _clkcycles();

	printf("dependent-chain loop (%u muls): %u cycles\n", N, (unsigned)(t1 - t0));
	printf("8-way-indep    loop (%u muls): %u cycles\n", N, (unsigned)(t2 - t1));
	printf("acc=%u a=%u\n", acc, a0 ^ a1 ^ a2 ^ a3 ^ a4 ^ a5 ^ a6 ^ a7);
}
