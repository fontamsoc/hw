// SPDX-License-Identifier: GPL-2.0-only
// 20260706 (c) William Fonkou Tambe

// Application exercising libgdbstub.a; it runs forever incrementing
// counters and periodically printing them, so that a host gdb can
// attach to it at any time; see rv32-sim/makefile about SERIAL_PTY0.
//
// From gdb, `set var fault_sel=N` exercises the fault handlers:
// 1 = illegal instruction (SIGILL), 2 = misaligned load (SIGBUS),
// 3 = _oops(), 4 = misaligned jump (SIGBUS).
//
// A zoo of threads exercises the per-thread debugging, exported so
// that gdb can select them symbolically (ie: set var __gdbstub_tp =
// thrd_spin): two spinners (thrd_spin/thrd_spin2) busy-looping through
// the shared spin_work() (stepping one within it makes the other an
// interloper on the step plants), a sleeper (thrd_sleep) which
// `set var exit_req=1` makes main kill/dispose/respawn, a blocker
// (thrd_block) waiting on a mutex main holds forever (ie: a
// cooperatively switched-out context), and a never-scheduled thread
// (thrd_fresh). A reporter thread prints the spinner and sleeper
// counters every ~100ms as a progress channel independent of main.

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include <_os.h>

volatile unsigned fault_sel = 0;

unsigned counter = 0;
// Incremented using gcc atomics (ie: lr.w/sc.w, which unlike
// the _os.h AMO macros participate in the dcache, hence can
// be mixed with plain loads).
static unsigned acounter = 0;

// The thread zoo; exported for gdb.
_thread_t *thrd_spin = 0;
_thread_t *thrd_spin2 = 0;
_thread_t *thrd_sleep = 0;
_thread_t *thrd_block = 0;
_thread_t *thrd_fresh = 0;
volatile unsigned spin_cnt = 0;
volatile unsigned spin2_cnt = 0;
volatile unsigned sleep_cnt = 0;
volatile unsigned exit_req = 0;

// Data-dependent branches to single-step over.
__attribute__((noinline)) unsigned compute (unsigned x) {
	unsigned r = 0;
	for (unsigned i = 0; i < (x & 7); ++i)
		r += (x ^ i);
	return r;
}

// Emits an lr.w/sc.w sequence, which a single-step
// must step over as a whole.
__attribute__((noinline)) unsigned cas_inc (unsigned *p) {
	unsigned o = __atomic_load_n(p, __ATOMIC_RELAXED);
	while (!__atomic_compare_exchange_n(p, &o, (o + 1), 0,
		__ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST));
	return (o + 1);
}

__attribute__((noinline)) static void do_fault (unsigned sel) {
	switch (sel) {
		case 1: // Illegal instruction; note that an all-zeros
			// instruction does not trap on this hardware (it
			// executes as a load at address 0), hence a write
			// to the read-only CSR cycle is used instead.
			__asm__ __volatile__ ("csrrw x0, 0xc00, x0\n" ::: "memory");
			break;
		case 2: { // Misaligned load.
			volatile unsigned *p =
				(volatile unsigned *)((uintptr_t)&counter | 1);
			*p;
			break;
		}
		case 3:
			_oops();
			break;
		case 4: { // Misaligned jump; jalr masks only bit 0,
			// hence bit 1 raises instruction address misaligned.
			void (*p)(void) = (void (*)(void))((uintptr_t)&compute | 2);
			p();
			break;
		}
	}
}

// Both spinners busy-loop through this shared function, the
// single-stepping target of the per-thread debugging tests.
__attribute__((noinline)) unsigned spin_work (unsigned x) {
	unsigned r = 0;
	for (unsigned i = 0; i < 4; ++i)
		r += (x ^ (i << 1));
	return r;
}

static void spin_thread (void *arg) {
	volatile unsigned *cnt = (volatile unsigned *)arg;
	while (1) {
		spin_work(*cnt);
		*cnt += 1;
	}
}

static void sleep_thread (void *arg) {
	while (1) {
		_thread_sleep(_MSECS(20));
		sleep_cnt += 1;
	}
}

static _mutex_t block_mutex = _MUTEX_NIL;

static void block_thread (void *arg) {
	// main holds block_mutex forever: this thread stays
	// cooperatively switched-out on its wait-queue.
	_mutex_lock(&block_mutex, _DATE_MAX);
	_mutex_unlock(&block_mutex);
}

static void fresh_thread (void *arg) {
	// Never scheduled; only its initial context is ever looked at.
}

static void report_thread (void *arg) {
	while (1) {
		_thread_sleep(_MSECS(100));
		printf("rpt: spin=%u spin2=%u sleep=%u\n",
			spin_cnt, spin2_cnt, sleep_cnt);
	}
}

void main (void) {
	printf("gdbstubtest starting\n");
	_mutex_lock(&block_mutex, _DATE_MAX);
	thrd_spin = _thread_create(0, 4096, spin_thread, (void *)&spin_cnt);
	thrd_spin2 = _thread_create(0, 4096, spin_thread, (void *)&spin2_cnt);
	thrd_sleep = _thread_create(0, 4096, sleep_thread, 0);
	thrd_block = _thread_create(0, 4096, block_thread, 0);
	thrd_fresh = _thread_create(0, 4096, fresh_thread, 0);
	_thread_t *thrd_report = _thread_create(0, 8192, report_thread, 0);
	_thread_sched(thrd_spin);
	_thread_sched(thrd_spin2);
	_thread_sched(thrd_sleep);
	_thread_sched(thrd_block);
	_thread_sched(thrd_report);
	for (unsigned i = 0;; ++i) {
		counter += compute(i);
		cas_inc(&acounter);
		unsigned sel = fault_sel;
		if (sel) {
			fault_sel = 0;
			do_fault(sel);
		}
		if (exit_req) { // Kill/dispose/respawn the sleeper.
			exit_req = 0;
			// Its wake-up _timer is armed while it sleeps and
			// _thread_kill() does not disarm it: the expiry
			// would walk the _timer_t after the dispose below
			// freed it; disarm first (no-op when unarmed).
			_timer_disarm(&thrd_sleep->z);
			_thread_kill(thrd_sleep);
			_thread_dispose(thrd_sleep);
			thrd_sleep = _thread_create(0, 4096, sleep_thread, 0);
			_thread_sched(thrd_sleep);
		}
		if (!(i & 0xfff))
			printf("i=%u counter=%u acounter=%u\n", i, counter, acounter);
	}
}
