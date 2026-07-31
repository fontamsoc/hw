// SPDX-License-Identifier: GPL-2.0-only
// 20260730 (c) William Fonkou Tambe

// Test that a hart running an atomic sequence cannot starve the other harts.
//
// A load-reserved, and the read phase of an atomic memory operation, raise the
// Wishbone bus lock (rvxx/dcache.pu.sv). lib/wb_arbiter.sv turns that lock into
// a grant hold: while it is set the granted master cannot change and every other
// master is held busy, which reaches instruction fetching through
// rvxx/memctrl.pu.sv, so a hart that is not granted executes nothing at all. The
// lock is released by the next accepted access that does not carry it, ie: the
// store-conditional's store, or the atomic memory operation's write-back.
//
// A store-conditional is allowed to issue no store at all, and then supplies no
// release: it can be branched over, which is what gcc emits for
// __atomic_compare_exchange, its reservation can be cancelled, or there may be
// no store-conditional after the load-reserved.
//
// Every case below checks the same thing, that a counter incremented by a thread
// pinned on cpu1 keeps advancing while cpu0 exercises an atomic sequence.
//
// The counter is accessed only through atomics, per the atomics coherency
// contract in rvxx/README.md: atomic memory operations bypass the data-cache and
// the coherency protocol, so a plain load can observe a stale value. That also
// makes cpu0's polling itself a bus access, which is the point: on hardware whose
// lock release is too narrow, those accesses do not release the lock either.
//
// Each check is bounded, so a starved cpu1 is reported rather than waited on
// forever. Expect no report at all on hardware that holds the lock, though: cpu0
// is observed to stop making progress as well rather than running on, so the whole
// machine wedges rather than merely losing cpu1. There is no bus watchdog and the
// simulation has no cycle limit, hence that presents as a silent run forever, and
// a run of this test which prints neither PASS nor FAILED is itself the failure.

#include <stdio.h>

#include <_os.h>

#define THREADS_STACKSZ 2048

// Enough polls that cpu1, when it is running at all, increments the counter many
// times over; a wedged bus instead runs them all without cpu1 ever executing.
#define POLLS 4000

// Contended atomic increments per hart, for the last case.
#define ADDS 2000

static uintptr_t failcnt = 0;
#define CHECK(COND, MSG) ({ \
	if (!(COND)) { \
		_atomic_inc(&failcnt); \
		printf("FAIL: %s\n", (MSG)); \
	} })

static uintptr_t progress = 0;
static uintptr_t stopticker = 0;
static uintptr_t tickerdone = 0;
static uintptr_t adderdone = 0;
static uintptr_t sum = 0;

// The words the atomic sequences below reserve. A word of its own per case, so
// that a case which leaves the lock held cannot have it released by the next
// case's recovery store, which would hide it.
static uintptr_t lockword[3] = {0, 0, 0};

static void ticker_fn (void *arg) {
	(void)arg;
	while (!_atomic_add(&stopticker, 0))
		_atomic_inc(&progress);
	_atomic_inc(&tickerdone);
}

static void adder_fn (void *arg) {
	(void)arg;
	for (uintptr_t i = 0; i < ADDS; ++i)
		_atomic_add(&sum, 1);
	_atomic_inc(&adderdone);
}

// Wait for a thread pinned on another cpu to have run to completion. It signals
// through an atomic flag of its own, rather than through _is_thread_terminated(),
// which reads the thread's saved-context pointer: that is cleared by the scheduler
// on the cpu the thread ran on, and waiting on it from here was observed to hang.
// The threads are accordingly never disposed, which costs only their bookkeeping,
// as this returns from main() right after.
//
// The wait needs no pacing. It was paced with a cached-only loop against
// wb_arbiter.sv rotating its grant only in a clockcycle for which the granted
// master is not requesting, ie: against an unpaced spin holding the grant and
// starving the hart it waits on. That does not happen here, and it was measured
// not to: every iteration is an atomic whose write-back releases the bus, and the
// loop is otherwise served out of the caches, so this hart's strobe drops between
// iterations and the grant rotates as it always did. Unpaced, against hardware
// which bounded the hold not at all, this test still passes. The arbiter now
// bounds it outright in any case.
static void waitdone (uintptr_t *donep) {
	while (!_atomic_add(donep, 0));
}

// True if cpu1 got to run at all within POLLS accesses from this hart.
static bool cpu1_advanced (void) {
	uintptr_t was = _atomic_add(&progress, 0);
	for (uintptr_t i = 0; i < POLLS; ++i) {
		if (_atomic_add(&progress, 0) != was)
			return true;
	}
	return false;
}

// Release a lock that the case under test left held, so that the cases after it
// still report. Only an access that does not carry the lock can do it, and on
// hardware whose release is address-matched it must be at the reserved word.
static void recover (uintptr_t *p) {
	*(volatile uintptr_t *)p = 0;
}

// A load-reserved with no store-conditional after it at all.
static void orphaned_lr (uintptr_t *p) {
	uintptr_t v;
	__asm__ volatile (
		"	lr.w	%0, (%1)	\n"
		: "=r" (v)
		: "r" (p)
		: "memory");
	(void)v;
}

// gcc's compare-and-swap: a load-reserved, a branch taken when the compare
// fails, and the store-conditional that it branches over.
static void failing_cas (uintptr_t *p) {
	uintptr_t expected = ~(uintptr_t)0; // Never the value held, hence never swapped.
	__atomic_compare_exchange_n(
		p, &expected, (uintptr_t)1, false, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE);
}

// A matched pair, ie: the sequence that does supply its own release. The retries
// are bounded rather than until-success: a store-conditional is allowed to fail,
// an interrupt taken between the two cancels the reservation, and what is under
// test here is the release of the lock, not whether the pair ever completed.
static void matched_lrsc (uintptr_t *p) {
	uintptr_t v, rslt;
	for (uintptr_t i = 0; i < 16; ++i) {
		__asm__ volatile (
			"	lr.w	%0, (%2)	\n"
			"	addi	%0, %0, 1	\n"
			"	sc.w	%1, %0, (%2)	\n"
			: "=&r" (v), "=&r" (rslt)
			: "r" (p)
			: "memory");
		if (!rslt)
			break;
	}
}

void main (void) {
	printf("Starting ...\n");

	if (_ncpu() < 2) {
		// Nothing to starve: lib/wb_arbiter.sv is instantiated only for
		// more than one hart, and rvxx/cpu.sv bypasses it otherwise.
		printf("smplock: single hart, skipped\n");
		printf("PASS\n");
		return;
	}

	_thread_schedoncpu(_thread_create(0, THREADS_STACKSZ, ticker_fn, 0), 1, true);

	// Baseline, and the control for every case after it: with no load-reserved
	// anywhere, the only sequences raising the lock are this hart's own polling
	// atomics, whose write-back always releases it.
	printf("case1: baseline ...\n");
	bool baseline = cpu1_advanced();
	CHECK(baseline, "case1: cpu1 never ran, the cases below cannot mean anything");

	if (baseline) {
		printf("case2: load-reserved with no store-conditional ...\n");
		orphaned_lr(&lockword[0]);
		CHECK(cpu1_advanced(), "case2: cpu1 starved by an orphaned load-reserved");
		recover(&lockword[0]);

		printf("case3: compare-and-swap branching over its store-conditional ...\n");
		failing_cas(&lockword[1]);
		CHECK(cpu1_advanced(), "case3: cpu1 starved by a branched-over store-conditional");
		recover(&lockword[1]);

		printf("case4: matched load-reserved and store-conditional ...\n");
		for (uintptr_t i = 0; i < 16; ++i)
			matched_lrsc(&lockword[2]);
		CHECK(cpu1_advanced(), "case4: cpu1 starved by matched load-reserved pairs");
	}

	_atomic_inc(&stopticker);
	waitdone(&tickerdone);

	// Guards the lock itself rather than its release: an atomic memory operation
	// whose read and write-back get split by another hart's access to the same
	// word loses an update, so this counts them.
	printf("case5: contended atomic increments ...\n");
	_thread_schedoncpu(_thread_create(0, THREADS_STACKSZ, adder_fn, 0), 1, true);
	for (uintptr_t i = 0; i < ADDS; ++i)
		_atomic_add(&sum, 1);
	waitdone(&adderdone);
	uintptr_t total = _atomic_add(&sum, 0);
	CHECK(total == (2*ADDS), "case5: atomic increments were lost");
	printf("case5: %u increments of %u\n", (unsigned)total, (unsigned)(2*ADDS));

	// Atomic read; failcnt is atomically incremented, and per the hw
	// atomics coherency contract, it must only be accessed atomically.
	uintptr_t fails = _atomic_add(&failcnt, 0);
	if (fails)
		printf("FAILED: %u failures\n", (unsigned)fails);
	else
		printf("PASS\n");
}
