// SPDX-License-Identifier: GPL-2.0-only
// 20261119 (c) William Fonkou Tambe

// Test that two harts never see the stores of two others in opposite orders
// (IRIW) through a full fence, nor through an atomic memory operation which is
// fully ordered, as RVWMO, the Linux memory model and C11 require.
//
// A write request reaches the data-caches of a coherency ring one after the
// other (cpu/dcache.sv), the ring running cpu0 -> cpu1 -> ... -> cpu7 -> cpu0
// (cpu/ccx.sv). cpu0 stores x and cpu4 stores y, words which the data-caches of
// cpu0, cpu1, cpu4 and cpu5 hold, so that each store is a write request
// travelling the ring, and every load a cache-hit: cpu0 sets go, then stores x
// after a delay which varies with the iteration, and cpu4 stores y once it sees
// go, which sweeps the skew between the two stores. cpu1 samples pairs
// "ld x; separator; ld y", and cpu5 pairs "ld y; separator; ld x": each is 1
// hop from its near store, and 5 from its far one. cpu2, cpu3, cpu6 and cpu7
// keep storing meanwhile to words which their data-caches hold, slowing the
// ring. The outcome is forbidden when, in the same iteration, a pair of cpu1
// reads x new and y old while a pair of cpu5 reads y new and x old. The
// readers sample from the exit of the barrier which starts each iteration, so
// that cpu5, 5 hops from cpu0, already samples when the store of x reaches it.
//
// On a ring of more than two harts, cpu/dcache.pu.sv makes a full fence, and
// an atomic memory operation whose aq and rl bits are both set, sync with the
// ring, which rules the outcome out. The lighter fences and the address
// dependencies do not, the Linux memory model and C11 allowing the outcome
// through them, unlike RVWMO.
//
// case1: fence rw,rw as the separator; a forbidden outcome fails.
// case2: amoadd.w.aqrl to a word of the reader as the separator, each pair
// ending with a plain load of that word, so that its data-cache holds it
// exclusive for the next pair, whose atomic then takes no word from the ring;
// a forbidden outcome fails. The atomic holds the ring of its data-cache off
// until its write, hence leaves the readers little window: the outcome hardly
// ever occurs through it even when nothing syncs.
// case3: fence r,r as the separator; the outcomes are counted, not checked.
// case4: an address dependency as the separator; likewise counted.
// Cases 3 and 4 show that the outcome is caught when it occurs.
//
// It needs 8 harts, ie: make CPU_COUNT=8, removing obj_dir/Vsim first, which
// depends on sim.sv and sim.cpp only; with fewer, it runs nothing. The barrier
// uses atomics only, hence it runs whatever ATOMIC_COHERENCE.

#include <stdio.h>
#include <stdint.h>

#include <_os.h>

#define THREADS_STACKSZ 2048

#ifndef ITERS
#define ITERS 1024 // Iterations of each case.
#endif

#define CASES 4
#define SAMPLES 160 // Pairs which each reader samples in each iteration.
#define SPINMAX 400000 // Bound of every spin.

#define READ_ONCE(X) (*(volatile __typeof__(X) *)&(X))
#define WRITE_ONCE(X, V) (*(volatile __typeof__(X) *)&(X) = (V))

// On a word of its own, whatever the width of a data-cache word, up to 256 bits.
#define OWNWORD __attribute__((aligned(32)))

static uintptr_t x OWNWORD, y OWNWORD, go OWNWORD, hit1 OWNWORD, hit5 OWNWORD, stop OWNWORD;
static uintptr_t priv1 OWNWORD, priv5 OWNWORD; // Accessed by a single hart each.
static uintptr_t noise[8] OWNWORD;
static uintptr_t arrive OWNWORD; // Atomic only.
static uintptr_t done[8];
static uintptr_t timeouts OWNWORD; // Atomic only.
static unsigned forbidden[CASES], only1[CASES], only5[CASES];

static const char *const separators[CASES] = {
	"fence rw,rw",
	"amoadd.w.aqrl to an exclusive word",
	"fence r,r",
	"an address dependency",
};

static void delay (unsigned n) {
	for (unsigned i = 0; i < n; ++i)
		__asm__ volatile ("nop");
}

// The n-th time: the 4 harts of the litmus increment arrive, then wait for each other.
static void sync4 (uintptr_t n) {
	_atomic_inc(&arrive);
	uintptr_t spins = 0;
	while (_atomic_add(&arrive, 0) < (4*n))
		if (++spins == SPINMAX) {
			_atomic_inc(&timeouts);
			break;
		}
}

// Ends the sampling of a pair: a, then b, are the values read from near, then
// far; hit is set when near is v, ie: new, and far not, ie: old.
#define TALLY \
	"xor %1, %1, %7\n" \
	"xor %2, %2, %7\n" \
	"seqz %1, %1\n" \
	"snez %2, %2\n" \
	"and %1, %1, %2\n" \
	"or %0, %0, %1\n" \
	"addi %4, %4, -1\n" \
	"bnez %4, 1b\n"

// Samples k pairs "ld near; separator; ld far" of the case c; returns non-null
// when one of them read near new and far old.
static __attribute__((noinline)) uintptr_t sample (
	unsigned c, uintptr_t *near, uintptr_t *far, uintptr_t *priv, uintptr_t v, uintptr_t k) {
	uintptr_t hit = 0, a, b, t;
	if (c == 0)
		__asm__ volatile (
			"1: lw %1, 0(%5)\n"
			"fence rw,rw\n"
			"lw %2, 0(%6)\n"
			TALLY
			: "+r" (hit), "=&r" (a), "=&r" (b), "=&r" (t), "+r" (k)
			: "r" (near), "r" (far), "r" (v), "r" (priv)
			: "memory");
	else if (c == 1)
		__asm__ volatile (
			"1: lw %1, 0(%5)\n"
			"amoadd.w.aqrl %3, zero, (%8)\n"
			"lw %2, 0(%6)\n"
			"lw %3, 0(%8)\n"
			TALLY
			: "+r" (hit), "=&r" (a), "=&r" (b), "=&r" (t), "+r" (k)
			: "r" (near), "r" (far), "r" (v), "r" (priv)
			: "memory");
	else if (c == 2)
		__asm__ volatile (
			"1: lw %1, 0(%5)\n"
			"fence r,r\n"
			"lw %2, 0(%6)\n"
			TALLY
			: "+r" (hit), "=&r" (a), "=&r" (b), "=&r" (t), "+r" (k)
			: "r" (near), "r" (far), "r" (v), "r" (priv)
			: "memory");
	else
		__asm__ volatile (
			"1: lw %1, 0(%5)\n"
			"xor %3, %1, %1\n"
			"add %3, %3, %6\n"
			"lw %2, 0(%3)\n"
			TALLY
			: "+r" (hit), "=&r" (a), "=&r" (b), "=&r" (t), "+r" (k)
			: "r" (near), "r" (far), "r" (v), "r" (priv)
			: "memory");
	return hit;
}

static void noise_fn (uintptr_t id) {
	for (unsigned j = 0; j < 8; ++j)
		(void)READ_ONCE(noise[j]);
	uintptr_t k = id;
	while (!READ_ONCE(stop)) {
		WRITE_ONCE(noise[k & 7], k);
		++k;
	}
}

static void iriw_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id == 2 || id == 3 || id == 6 || id == 7) {
		noise_fn(id);
		WRITE_ONCE(done[id], 1);
		return;
	}
	uintptr_t n = 0;
	for (unsigned c = 0; c < CASES; ++c) {
		for (uintptr_t i = 1; i <= ITERS; ++i) {
			uintptr_t v = ((c * ITERS) + i); // Differs from the value of every earlier iteration.
			// Every data-cache of the litmus holds x, y and go.
			(void)READ_ONCE(x);
			(void)READ_ONCE(y);
			(void)READ_ONCE(go);
			sync4(++n);
			if (id == 0) {
				WRITE_ONCE(go, v);
				// Sweeps the skew between the two stores around the point at which each
				// reaches its far reader as the other reaches its near one.
				delay(i % 12);
				WRITE_ONCE(x, v);
			} else if (id == 4) {
				uintptr_t spins = 0;
				while (READ_ONCE(go) != v)
					if (++spins == SPINMAX) {
						_atomic_inc(&timeouts);
						break;
					}
				WRITE_ONCE(y, v);
			} else if (id == 1)
				WRITE_ONCE(hit1, sample(c, &x, &y, &priv1, v, SAMPLES));
			else
				WRITE_ONCE(hit5, sample(c, &y, &x, &priv5, v, SAMPLES));
			sync4(++n);
			if (id == 0) {
				uintptr_t a = READ_ONCE(hit1), b = READ_ONCE(hit5);
				if (a && b)
					++forbidden[c];
				else if (a)
					++only1[c];
				else if (b)
					++only5[c];
			}
			sync4(++n);
		}
	}
	if (id == 0)
		WRITE_ONCE(stop, 1);
	WRITE_ONCE(done[id], 1);
}

void main (void) {
	printf("Starting ...\n");
	uintptr_t ncpu = _ncpu();
	if (ncpu < 8) {
		printf("iriw: needs 8 harts, ie: CPU_COUNT=8, not %u, skipped\n", (unsigned)ncpu);
		printf("PASS\n");
		return;
	}
	for (uintptr_t i = 1; i < 8; ++i)
		_thread_schedoncpu(_thread_create(0, THREADS_STACKSZ, iriw_fn, (void *)i), i, true);
	iriw_fn((void *)0);
	for (unsigned i = 0; i < 8; ++i) {
		uintptr_t spins = 0;
		while (!READ_ONCE(done[i]))
			if (++spins == (SPINMAX * 10)) {
				_atomic_inc(&timeouts);
				break;
			}
	}
	unsigned fails = 0;
	for (unsigned c = 0; c < CASES; ++c) {
		printf("case%u: %s between the loads: %u forbidden outcomes of %u, cpu1 alone %u, cpu5 alone %u%s\n",
			c+1, separators[c], forbidden[c], (unsigned)ITERS, only1[c], only5[c],
			(c < 2) ? "" : ", allowed by the Linux memory model");
		if (c < 2)
			fails += forbidden[c];
	}
	uintptr_t t = _atomic_add(&timeouts, 0);
	if (t)
		printf("FAIL: %u spins timed out\n", (unsigned)t);
	if (fails || t)
		printf("FAILED: %u forbidden outcomes\n", fails);
	else
		printf("PASS\n");
}
