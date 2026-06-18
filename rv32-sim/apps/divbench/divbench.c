// SPDX-License-Identifier: GPL-2.0-only

// Integer-divide latency microbenchmark.
//
// The divisor is kept runtime-variable and data-dependent so the compiler cannot
// replace the divisions with reciprocal multiplies; each loop iteration issues one
// unsigned and (in the second loop) one signed hardware divide plus remainder.
// Prints the cycle count of each loop, useful for comparing divider implementations
// (e.g. radix-2 vs radix-4). The divisor is constrained to be non-zero throughout.

#include <stdio.h>

#include <_os.h>

void main () {
	volatile unsigned vd  = 7;
	volatile int      vsd = -7;
	unsigned acc  = 1234567u;
	int      sacc = -98765432;
	unsigned d  = vd;     // in {7,8}, never 0
	int      sd = vsd;    // in {-7,-8}, never 0
	const unsigned N = 200000u;

	_date_t t0 = _clkcycles();
	for (unsigned i = 0; i < N; ++i) {
		acc = (acc + i) / d;
		acc += (1234567u % d);
		d = vd + (acc & 1u);
	}
	_date_t t1 = _clkcycles();
	for (unsigned i = 0; i < N; ++i) {
		sacc = (sacc - (int)i) / sd;
		sacc += (-98765432 % sd);
		sd = vsd - (int)(sacc & 1);
	}
	_date_t t2 = _clkcycles();

	printf("divu+remu loop (%u iters): %u cycles\n", N, (unsigned)(t1 - t0));
	printf("div+rem   loop (%u iters): %u cycles\n", N, (unsigned)(t2 - t1));
	printf("acc=%u sacc=%d\n", acc, sacc);
}
