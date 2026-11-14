// SPDX-License-Identifier: GPL-2.0-only
// 20261113 (c) William Fonkou Tambe

// Test that atomics and plain accesses can share words across harts, as SMP Linux
// does: its ticket spinlock takes a ticket with an atomic add and releases the
// lock with a plain store to half of the same word; atomic_read and atomic_set
// are plain accesses; a compare-and-swap whose compare fails branches over its
// store-conditional, the plain accesses which follow being to any word; and its
// smp_mb() is a fence which is to order a store before a later load.
//
// cpu/dcache.sv lets an atomic take its word from the coherency ring before it
// reads it; cpu/dcache.pu.sv releases the lock of a load-reserved, with a read
// selecting no byte, ahead of the access which follows it when that is not its
// store-conditional, and once its reservation is cancelled, which a jump backward
// insures on a coherency ring (cpu/lsu.pu.sv); and a fence ordering stores before
// loads waits until the stores of its hart are seen by every data-cache.
//
// The take and the release are made only in a ccx built with ATOMIC_COHERENCE
// non-null, which every top leaves null by default: build the simulator so, ie:
// make CPU_COUNT=2 ATOMIC_COHERENCE=1, removing obj_dir/Vsim first, which depends
// on sim.sv and sim.cpp only. With it null, the cases break the rules that
// cpu/README.md then states, and most of them fail; case5, which tests the fence,
// does not need it.
//
// case1: a ticket spinlock taken with an atomic add, released with a plain store.
// case2: an atomic counter set with a plain store and read with plain loads.
// case3: a plain store and a plain load after a compare-and-swap whose compare fails.
// case4: a load-reserved spinning until another hart's plain store lands.
// case5: store buffering through fence rw,rw.
// case6: an lr/sc exchange of half a word against plain stores of one of its bytes.
// case7: a plain store that another hart's atomic add is to read.
// case8: plain-load spins on a word set by an atomic swap, then by a store-conditional.
// case9: a spin touching no memory after a compare-and-swap whose compare fails,
// during which the other hart's stores are to keep going, with the branch over the
// store-conditional mispredicted, then predicted.
// case10: a store-conditional 14 instructions after its load-reserved, a taken
// forward branch among them, as a constrained LR/SC loop allows, which is to succeed.
// case11: a load-reserved abandoned by a wfi, with a load waiting behind it, during
// which the other hart's stores are to keep going.
// case12: load-reserveds made back to back on a word that another hart keeps
// loading, whose loads are to keep completing.
//
// Each case is bounded, and reports FAIL rather than waiting forever; a hart that
// holds the bus forever stops the others, which then presents as a run printing
// neither PASS nor FAILED.

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include <_os.h>

#define THREADS_STACKSZ 2048

// Iterations per case, and the bound of every spin.
#define TICKETS 64
#define ADDS 256
#define FOLLOWS 64
#define SBITERS 512
#define BYTES 128
#define PLAINS 32
#define SPINN 100000
#define LRBURST 2000
#define SPINMAX 200000

#define READ_ONCE(X) (*(volatile __typeof__(X) *)&(X))
#define WRITE_ONCE(X, V) (*(volatile __typeof__(X) *)&(X) = (V))

static uintptr_t failcnt = 0;
#define CHECK(COND, ...) ({ \
	if (!(COND)) { \
		_atomic_inc(&failcnt); \
		printf("FAIL: " __VA_ARGS__); \
		printf("\n"); \
	} })

#define fence_rw_rw() __asm__ volatile ("fence rw,rw" ::: "memory")
#define fence_rw_w() __asm__ volatile ("fence rw,w" ::: "memory")
#define fence_r_rw() __asm__ volatile ("fence r,rw" ::: "memory")

static unsigned ncpu;

// Per-thread completion flags, for the waits.
static uintptr_t done[8];

// Waits for the threads of a case to be done; they signal through plain stores,
// which the coherency ring carries.
static void waitall (unsigned n) {
	for (unsigned i = 0; i < n; ++i) {
		uintptr_t spins = 0;
		while (!READ_ONCE(done[i]))
			if (++spins == (SPINMAX * 10)) {
				CHECK(0, "thread %u never finished", i);
				return;
			}
	}
}

static void startall (unsigned n, void (*fn)(void *)) {
	for (unsigned i = 0; i < n; ++i)
		WRITE_ONCE(done[i], 0);
	for (uintptr_t i = 1; i < n; ++i)
		_thread_schedoncpu(_thread_create(0, THREADS_STACKSZ, fn, (void *)i), i, true);
	fn((void *)0);
	waitall(n);
}

// case1: a ticket spinlock, asm-generic's: the lock is taken with an atomic add of
// the next ticket, waited for with plain loads of the owner, and released with a
// plain store of the owner's half; the critical section increments a plain counter.
static uint32_t tlock; // owner in bits 15:0, next in bits 31:16
static uintptr_t tcount;

static void ticket_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	for (unsigned i = 0; i < TICKETS; ++i) {
		uint16_t ticket = (uint16_t)(_atomic_add((uintptr_t *)&tlock, 1 << 16) >> 16);
		uintptr_t spins = 0;
		while (READ_ONCE(*(uint16_t *)&tlock) != ticket)
			if (++spins == SPINMAX) {
				CHECK(0, "case1: cpu%u waits forever for ticket %u", (unsigned)id, ticket);
				WRITE_ONCE(done[id], 1);
				return;
			}
		fence_r_rw();
		WRITE_ONCE(tcount, READ_ONCE(tcount) + 1);
		fence_rw_w();
		WRITE_ONCE(*(uint16_t *)&tlock, (uint16_t)(ticket + 1));
	}
	WRITE_ONCE(done[id], 1);
}

// case2: an atomic counter set by a plain store, incremented atomically by every
// hart, and read with plain loads, which never see it go back.
static uintptr_t acount;

static void count_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	uintptr_t last = 0;
	for (unsigned i = 0; i < ADDS; ++i) {
		_atomic_add(&acount, 1);
		uintptr_t v = READ_ONCE(acount);
		if (v < last || v < 1000) {
			CHECK(0, "case2: cpu%u reads %u after %u", (unsigned)id, (unsigned)v, (unsigned)last);
			break;
		}
		last = v;
	}
	WRITE_ONCE(done[id], 1);
}

// case3: gcc's compare-and-swap whose compare fails, ie: a load-reserved branching
// over its store-conditional; the plain store which follows is to a word that the
// other hart holds and waits on, and the plain load which follows the next one is
// of a word that the other hart wrote.
static uintptr_t casword;
static uintptr_t fwd; // cpu0 -> cpu1
static uintptr_t bwd; // cpu1 -> cpu0

static void failing_cas (void) {
	uintptr_t expected = ~(uintptr_t)0; // Never the value held, hence never swapped.
	__atomic_compare_exchange_n(&casword, &expected, (uintptr_t)1, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
}

static void follow_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	for (uintptr_t i = 1; i <= FOLLOWS; ++i) {
		uintptr_t spins = 0;
		if (id == 0) {
			failing_cas();
			WRITE_ONCE(fwd, i); // The access after the abandoned load-reserved.
			for (;;) {
				failing_cas();
				uintptr_t v = READ_ONCE(bwd); // The access after the abandoned load-reserved.
				if (v == i)
					break;
				if (++spins == SPINMAX) {
					CHECK(0, "case3: cpu0 never reads %u from cpu1, reads %u", (unsigned)i, (unsigned)v);
					WRITE_ONCE(done[id], 1);
					return;
				}
			}
		} else {
			while (READ_ONCE(fwd) != i)
				if (++spins == SPINMAX) {
					CHECK(0, "case3: cpu1 never reads %u from cpu0", (unsigned)i);
					WRITE_ONCE(done[id], 1);
					return;
				}
			WRITE_ONCE(bwd, i);
		}
	}
	WRITE_ONCE(done[id], 1);
}

// case4: a load-reserved spinning, with nothing between two of them, until another
// hart's plain store lands; that hart first reads a buffer it does not hold, which
// needs the coherency ring and the bus while the load-reserved spins.
static uintptr_t lrflag;
static uintptr_t buf[64];

static void lrspin_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id == 0) {
		uintptr_t v, spins = 0;
		do {
			__asm__ volatile ("lr.w %0, (%1)" : "=r" (v) : "r" (&lrflag) : "memory");
			if (++spins == SPINMAX) {
				CHECK(0, "case4: the load-reserved never reads the store of cpu1");
				break;
			}
		} while (v);
		WRITE_ONCE(buf[0], 0); // The access after the abandoned load-reserved.
	} else {
		uintptr_t sum = 0;
		for (unsigned i = 0; i < 64; ++i)
			sum += READ_ONCE(buf[i]);
		(void)sum;
		WRITE_ONCE(lrflag, 0);
	}
	WRITE_ONCE(done[id], 1);
}

// case5: store buffering: each of two harts stores to its word, a fence orders that
// store before its load of the other hart's word; both loads reading the old values
// is forbidden. The two harts are as far apart on the coherency ring as can be, the
// others flooding the ring meanwhile with stores to words that every data-cache
// holds, so that a store takes long to reach the other data-cache. Both harts hold
// both words, start together, the first released by a plain store which the other
// spins on, and each delays its store by a count which varies with the iteration,
// the skew between them sweeping the window in which neither store has reached the
// other data-cache yet.
static uintptr_t sbx, sby, sbgo, sbr0, sbr1;
static uintptr_t sbarrive;
static uintptr_t sbstop;
static uintptr_t noise[8];
static unsigned sbforbidden;
static uintptr_t sbpeer;

static void delay (unsigned n) {
	for (unsigned i = 0; i < n; ++i)
		__asm__ volatile ("nop");
}

// The n-th time: both harts of the case increment sbarrive, then wait for each other.
static void sbsync (uintptr_t n) {
	_atomic_inc(&sbarrive);
	uintptr_t spins = 0;
	while (_atomic_add(&sbarrive, 0) < (2*n))
		if (++spins == SPINMAX)
			break;
}

static void sb_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id != 0 && id != sbpeer) {
		// Flood the ring: every data-cache holds the noise words, hence each store
		// below is a write request going around it.
		for (unsigned j = 0; j < 8; ++j)
			(void)READ_ONCE(noise[j]);
		uintptr_t k = 0;
		while (!READ_ONCE(sbstop)) {
			WRITE_ONCE(noise[k & 7], k);
			++k;
		}
		WRITE_ONCE(done[id], 1);
		return;
	}
	for (uintptr_t i = 1; i <= SBITERS; ++i) {
		for (unsigned j = 0; j < 8; ++j)
			(void)READ_ONCE(noise[j]);
		(void)READ_ONCE(sbx);
		(void)READ_ONCE(sby);
		sbsync(3*i - 2);
		if (id == 0) {
			WRITE_ONCE(sbgo, i);
			delay(i % 37);
			WRITE_ONCE(sbx, i);
			fence_rw_rw();
			WRITE_ONCE(sbr0, READ_ONCE(sby));
		} else {
			uintptr_t spins = 0;
			while (READ_ONCE(sbgo) != i)
				if (++spins == SPINMAX)
					break;
			delay((i / 37) % 7);
			WRITE_ONCE(sby, i);
			fence_rw_rw();
			WRITE_ONCE(sbr1, READ_ONCE(sbx));
		}
		sbsync(3*i - 1);
		if (id == 0 && READ_ONCE(sbr0) < i && READ_ONCE(sbr1) < i)
			++sbforbidden;
		sbsync(3*i);
	}
	if (id == 0)
		WRITE_ONCE(sbstop, 1);
	WRITE_ONCE(done[id], 1);
}

// case6: qspinlock's sub-word exchange: an lr/sc sequence rewriting the upper half
// of a word against plain stores of its lowest byte, which must never be undone.
static uint32_t qword;

static void qspin_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id == 0) {
		for (uintptr_t i = 1; i <= (BYTES * 4); ++i) {
			uint32_t old = __atomic_load_n(&qword, __ATOMIC_RELAXED);
			for (;;) {
				uint32_t nw = (old & 0x0000ffff) | ((uint32_t)i << 16);
				if (__atomic_compare_exchange_n(&qword, &old, nw, false, __ATOMIC_RELAXED, __ATOMIC_RELAXED))
					break;
			}
		}
	} else {
		for (uintptr_t i = 1; i <= BYTES; ++i) {
			WRITE_ONCE(*(uint8_t *)&qword, (uint8_t)i);
			uint8_t v = READ_ONCE(*(uint8_t *)&qword);
			if (v != (uint8_t)i) {
				CHECK(0, "case6: byte 0 reads %u after its store of %u", (unsigned)v, (unsigned)i);
				break;
			}
		}
	}
	WRITE_ONCE(done[id], 1);
}

// case7: a plain store that the other hart's atomic add is to read, and whose result
// is then read back with a plain load.
static uint32_t pword;
static uintptr_t pseen;
static uintptr_t pfwd; // cpu0 -> cpu1
static uintptr_t pbwd; // cpu1 -> cpu0

static void plainamo_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	for (uintptr_t i = 1; i <= PLAINS; ++i) {
		uintptr_t spins = 0;
		if (id == 0) {
			WRITE_ONCE(pword, (uint32_t)(i * 100));
			WRITE_ONCE(pfwd, i);
			while (READ_ONCE(pbwd) != i)
				if (++spins == SPINMAX) {
					CHECK(0, "case7: cpu0 never hears from cpu1 at %u", (unsigned)i);
					WRITE_ONCE(done[id], 1);
					return;
				}
			uintptr_t seen = READ_ONCE(pseen);
			uint32_t back = READ_ONCE(pword);
			if (seen != (i * 100) || back != ((i * 100) + 1)) {
				CHECK(0, "case7: the atomic add read %u, expected %u; read back %u",
					(unsigned)seen, (unsigned)(i * 100), (unsigned)back);
				break;
			}
		} else {
			while (READ_ONCE(pfwd) != i)
				if (++spins == SPINMAX) {
					CHECK(0, "case7: cpu1 never hears from cpu0 at %u", (unsigned)i);
					WRITE_ONCE(done[id], 1);
					return;
				}
			WRITE_ONCE(pseen, _atomic_add((uintptr_t *)&pword, 1));
			WRITE_ONCE(pbwd, i);
		}
	}
	WRITE_ONCE(done[id], 1);
}

// A store-conditional writing v, after its load-reserved; tried a bounded number of times.
static bool lrsc_store (uint32_t *p, uint32_t v) {
	uint32_t rslt, old;
	for (unsigned i = 0; i < 16; ++i) {
		__asm__ volatile (
			"lr.w %0, (%2)\n"
			"sc.w %1, %3, (%2)\n"
			: "=&r" (old), "=&r" (rslt)
			: "r" (p), "r" (v)
			: "memory");
		if (!rslt)
			return true;
	}
	return false;
}

// case8: a hart spinning with plain loads on a word that it holds, which another hart
// sets with an atomic swap, then on one that it writes with a store-conditional.
static uint32_t aflag;
static uint32_t scword;
static uintptr_t sready;

static void plainspin_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	uintptr_t spins = 0;
	if (id == 0) {
		while (READ_ONCE(sready) != 1)
			if (++spins == SPINMAX)
				break;
		_xchg((uintptr_t *)&aflag, 1);
		spins = 0;
		while (READ_ONCE(sready) != 2)
			if (++spins == SPINMAX)
				break;
		CHECK(lrsc_store(&scword, 7), "case8: the store-conditional never succeeded");
	} else {
		(void)READ_ONCE(aflag);
		WRITE_ONCE(sready, 1);
		while (READ_ONCE(aflag) != 1)
			if (++spins == SPINMAX) {
				CHECK(0, "case8: the atomic swap is not seen by a plain-load spin");
				break;
			}
		(void)READ_ONCE(scword);
		WRITE_ONCE(sready, 2);
		spins = 0;
		while (READ_ONCE(scword) != 7)
			if (++spins == SPINMAX) {
				CHECK(0, "case8: the store-conditional is not seen by a plain-load spin");
				break;
			}
	}
	WRITE_ONCE(done[id], 1);
}

// A spin of n iterations touching no memory.
static __attribute__((noinline)) void regspin (uint32_t n) {
	__asm__ volatile (
		"1: addi %0, %0, -1\n"
		"bnez %0, 1b\n"
		: "+r" (n));
}

// A compare-and-swap whose compare fails, then a spin touching no memory; returns how
// many stores the other hart made meanwhile to a word that this hart holds.
static uint32_t progress;
static uintptr_t pstop;

static __attribute__((noinline)) uint32_t casspin (uint32_t n) {
	uint32_t before = READ_ONCE(progress);
	failing_cas();
	regspin(n);
	return (READ_ONCE(progress) - before);
}

// case9: the load-reserved of a compare-and-swap whose compare fails is not to hold the
// other harts until this hart's next memory access: first with its branch over the
// store-conditional mispredicted, which cancels the reservation, then with that branch
// and those of the spin predicted, where the first jump backward of the spin does.
static void holdspin_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id == 0) {
		uint32_t cold = casspin(SPINN);
		for (unsigned i = 0; i < 16; ++i)
			(void)casspin(4);
		uint32_t trained = casspin(SPINN);
		WRITE_ONCE(pstop, 1);
		CHECK(cold > 100, "case9: cpu1 was held by the abandoned load-reserved, %u stores", (unsigned)cold);
		CHECK(trained > 100, "case9: cpu1 was held by the abandoned load-reserved once its branches were predicted, %u stores", (unsigned)trained);
		printf("case9: cpu1 made %u then %u stores during the spins\n", (unsigned)cold, (unsigned)trained);
	} else {
		uintptr_t spins = 0;
		while (!READ_ONCE(pstop)) {
			WRITE_ONCE(progress, READ_ONCE(progress) + 1);
			if (++spins == (SPINMAX * 10))
				break;
		}
	}
	WRITE_ONCE(done[id], 1);
}

// case10: a store-conditional 14 instructions after its load-reserved, a taken forward
// branch among them, which is as much as a constrained LR/SC loop allows: it is to
// succeed, a reservation being cancelled on a coherency ring by a jump backward, and
// by a branch which is mispredicted, which this one is at most the first times.
static uint32_t gapword;

static void lrscgap (void) {
	uint32_t rslt = 1, old;
	for (unsigned i = 0; i < 8 && rslt; ++i) {
		__asm__ volatile (
			"lr.w %0, (%2)\n"
			"beqz x0, 1f\n"
			"nop\n"
			"1:\n"
			".rept 12\n"
			"nop\n"
			".endr\n"
			"sc.w %1, %3, (%2)\n"
			: "=&r" (old), "=&r" (rslt)
			: "r" (&gapword), "r" (14)
			: "memory");
	}
	CHECK(!rslt, "case10: a store-conditional 14 instructions after its load-reserved never succeeds");
	CHECK(READ_ONCE(gapword) == 14, "case10: the word holds %u, expected 14", (unsigned)READ_ONCE(gapword));
}

// case11: a load-reserved is abandoned by a wfi, which cancels its reservation as any
// system instruction does, with a load right behind it: the pu halts with that load at
// decode, not issued, and is to release the other harts all the same, until an
// interrupt ends the wait.
static uint32_t wfiword;
static _timer_t wfitimer;

static void wfitimer_cb (_timer_t *t) {
	(void)t;
}

// Returns how many stores the other hart made during the wait.
static __attribute__((noinline)) uint32_t lrwfi (void) {
	uint32_t before = READ_ONCE(progress);
	uint32_t old, tmp;
	__asm__ volatile (
		"lr.w %0, (%2)\n"
		"wfi\n"
		"lw %1, 0(%3)\n"
		: "=&r" (old), "=&r" (tmp)
		: "r" (&wfiword), "r" (&pstop)
		: "memory");
	return (READ_ONCE(progress) - before);
}

static void holdwfi_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	if (id == 0) {
		unsigned waits = 0, held = 0;
		uint32_t least = ~0u;
		_timer_init(&wfitimer, wfitimer_cb);
		// Another interrupt may end a wait early: only the waits which lasted are counted.
		for (unsigned i = 0; i < 8; ++i) {
			_timer_arm(&wfitimer, _clkcycles() + _MSECS(1));
			uint32_t t0 = (uint32_t)_clkcycles();
			uint32_t n = lrwfi();
			uint32_t t = ((uint32_t)_clkcycles() - t0);
			if (t < 20000)
				continue;
			++waits;
			if (n < (t / 64))
				++held;
			if (n < least)
				least = n;
		}
		_timer_disarm(&wfitimer);
		WRITE_ONCE(pstop, 1);
		CHECK(waits >= 2, "case11: only %u waits lasted", waits);
		CHECK(!held, "case11: cpu1 was held by the load-reserved that a wfi abandoned, during %u of %u waits", held, waits);
		printf("case11: cpu1 made %u stores at least during each of %u waits\n", (unsigned)least, waits);
	} else {
		uintptr_t spins = 0;
		while (!READ_ONCE(pstop)) {
			WRITE_ONCE(progress, READ_ONCE(progress) + 1);
			if (++spins == (SPINMAX * 10))
				break;
		}
	}
	WRITE_ONCE(done[id], 1);
}

// case12: load-reserveds made back to back on a word, with nothing but their loop
// between two of them, while another hart keeps loading that word, each of its loads
// missing as the take of a load-reserved removes the word from its data-cache: those
// loads are to keep completing, a take which meets the read of such a load being
// marked and issued again rather than breaking it.
#define LRWORDVAL 0x5a5a5a5a
static uint32_t lrword;
static uintptr_t lrgo;
static uintptr_t lrstop;
static uint32_t lrloads;

static __attribute__((noinline)) void lrburst (uint32_t *p, uint32_t n) {
	uint32_t v;
	__asm__ volatile (
		"1: lr.w %0, (%2)\n"
		"addi %1, %1, -1\n"
		"bnez %1, 1b\n"
		: "=&r" (v), "+r" (n)
		: "r" (p)
		: "memory");
}

static void lrload_fn (void *arg) {
	uintptr_t id = (uintptr_t)arg;
	uintptr_t spins = 0;
	if (id == 0) {
		while (!READ_ONCE(lrgo))
			if (++spins == SPINMAX)
				break;
		uint32_t before = READ_ONCE(lrloads);
		lrburst(&lrword, LRBURST);
		uint32_t n = (READ_ONCE(lrloads) - before);
		WRITE_ONCE(lrstop, 1);
		CHECK(n > (LRBURST / 64), "case12: cpu1 completed %u loads during %u load-reserveds", (unsigned)n, (unsigned)LRBURST);
		printf("case12: cpu1 completed %u loads during %u load-reserveds\n", (unsigned)n, (unsigned)LRBURST);
	} else {
		uint32_t n = 0;
		WRITE_ONCE(lrgo, 1);
		while (!READ_ONCE(lrstop)) {
			uint32_t v = READ_ONCE(lrword);
			if (v != LRWORDVAL) {
				CHECK(0, "case12: cpu1 reads %08x", (unsigned)v);
				break;
			}
			WRITE_ONCE(lrloads, ++n);
			if (++spins == (SPINMAX * 10))
				break;
		}
	}
	WRITE_ONCE(done[id], 1);
}

void main (void) {
	printf("Starting ...\n");

	ncpu = _ncpu();
	if (ncpu < 2) {
		printf("smpatomic: single hart, skipped\n");
		printf("PASS\n");
		return;
	}
	if (ncpu > 8)
		ncpu = 8;

	printf("case1: ticket spinlock released by a plain store ...\n");
	tlock = 0; tcount = 0;
	startall(ncpu, ticket_fn);
	CHECK(READ_ONCE(tcount) == (TICKETS * ncpu), "case1: counter %u, expected %u",
		(unsigned)READ_ONCE(tcount), (unsigned)(TICKETS * ncpu));
	CHECK((tlock & 0xffff) == (tlock >> 16), "case1: lock left at %08x", (unsigned)tlock);

	printf("case2: atomic counter set and read with plain accesses ...\n");
	WRITE_ONCE(acount, 1000);
	startall(ncpu, count_fn);
	CHECK(READ_ONCE(acount) == (1000 + ADDS * ncpu), "case2: counter %u, expected %u",
		(unsigned)READ_ONCE(acount), (unsigned)(1000 + ADDS * ncpu));

	printf("case3: plain accesses after a failed compare-and-swap ...\n");
	casword = 0; fwd = 0; bwd = 0;
	startall(2, follow_fn);

	printf("case4: a spinning load-reserved against another hart ...\n");
	lrflag = 1;
	startall(2, lrspin_fn);

	printf("case5: store buffering through fences ...\n");
	sbx = 0; sby = 0; sbgo = 0; sbarrive = 0; sbforbidden = 0; sbstop = 0;
	sbpeer = (ncpu / 2);
	startall(ncpu, sb_fn);
	CHECK(sbforbidden == 0, "case5: both loads read null %u times of %u", sbforbidden, SBITERS);
	printf("case5: %u forbidden outcomes of %u\n", sbforbidden, SBITERS);

	printf("case6: lr/sc on the upper half against plain stores of a byte ...\n");
	qword = 0;
	startall(2, qspin_fn);
	CHECK((qword & 0xff) == (BYTES & 0xff), "case6: byte 0 left at %u", (unsigned)(qword & 0xff));
	CHECK((qword >> 16) == (BYTES * 4), "case6: upper half left at %u", (unsigned)(qword >> 16));

	printf("case7: a plain store read by another hart's atomic add ...\n");
	pword = 0; pfwd = 0; pbwd = 0;
	startall(2, plainamo_fn);

	printf("case8: plain-load spins on an atomic swap and on a store-conditional ...\n");
	aflag = 0; scword = 0; sready = 0;
	startall(2, plainspin_fn);

	printf("case9: a spin touching no memory after a failed compare-and-swap ...\n");
	progress = 0; pstop = 0;
	startall(2, holdspin_fn);

	printf("case10: a store-conditional 14 instructions after its load-reserved ...\n");
	gapword = 0;
	lrscgap();

	printf("case11: a load-reserved abandoned by a wfi, a load waiting behind it ...\n");
	progress = 0; pstop = 0; wfiword = 0;
	startall(2, holdwfi_fn);

	printf("case12: load-reserveds back to back against loads of their word ...\n");
	lrword = LRWORDVAL; lrgo = 0; lrstop = 0; lrloads = 0;
	startall(2, lrload_fn);

	uintptr_t fails = _atomic_add(&failcnt, 0);
	if (fails)
		printf("FAILED: %u failures\n", (unsigned)fails);
	else
		printf("PASS\n");
}
