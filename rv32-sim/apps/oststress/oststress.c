// SPDX-License-Identifier: GPL-2.0-only
// 20260703 (c) William Fonkou Tambe

// Stress-test _OS (UnderLineOS) synchronization primitives; it targets
// the code paths that thrdtst does not exercise:
// - Timed waits that get woken up early (before their timeout expires),
//   which must disarm the thread sleep _timer so that it neither fires
//   stale nor gets re-armed from another CPU.
// - _mutex_lock() losing the wake-up race and sleeping again until its
//   timeout expires; with _DATE_MAX it must never fail.
// - _fifo_put()/_fifo_get() retry loops with mismatched chunk sizes.
// - _thread_schedone() right after its wait-queue emptied, while wq->p
//   is non-null; it must not spinloop forever.
// - Re-arming the nearest _timer to a later date, which must reprogram
//   the timer compare value so that the CPU is not stormed with timer
//   interrupts until the new nearest _timer expires.

#include <stdio.h>
#include <string.h>
#include <time.h>

#include <_os.h>

// Declared in <time.h> only when POSIX visibility is enabled.
int nanosleep (const struct timespec *rqtp, struct timespec *rmtp);

static uintptr_t failcnt = 0;
#define CHECK(COND, MSG) ({ \
	if (!(COND)) { \
		_atomic_inc(&failcnt); \
		printf("FAIL: %s\n", (MSG)); \
	} })

#define SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)

// Raw-serial prints which do not go through newlib stdio locks,
// so that they can be used to diagnose synchronization hangs.
static void rawstr (const char *s) {
	for (char c; (c = *s); ++s)
		*(volatile char *)SERIAL0_ADDR = c;
}
static void rawhex (uintptr_t v) {
	for (unsigned i = 0; i < (2*sizeof(v)); ++i) {
		char d = ((v >> ((8*sizeof(v))-4-(i*4))) & 0xf);
		*(volatile char *)SERIAL0_ADDR = (d + ((d >= 10) ? ('a'-10) : '0'));
	}
}

#define THREADS_STACKSZ 2048

// Wait for a thread to terminate, then dispose of it.
static void thrd_join (_thread_t *thrd) {
	while (!_is_thread_terminated(thrd))
		_thread_sleep(_MSECS(2));
	_thread_dispose(thrd);
}

// Test1: timed _sem_get() woken up early; the sleep _timer armed for the
// timeout must not fire stale after the thread resumed and moved on.
#define TEST1_NTHREADS 2
#define TEST1_NTOKENS 4
static _SEM_DEF(test1_sem, (TEST1_NTHREADS*TEST1_NTOKENS), 0);
static _date_t test1_deadline;
static void test1_fn (void *arg) {
	for (uintptr_t i = 0; i < TEST1_NTOKENS; ++i)
		CHECK(_sem_get(&test1_sem, _MSECS(60)), "test1: _sem_get() timed out");
	// Busy-wait past the date the timed-out sleep _timers were armed for,
	// without sleeping, so that a stale _timer would fire while running.
	while (_clkcycles() < test1_deadline);
}
static void test1 (void) {
	printf("test1: early-woken timed _sem_get()\n");
	test1_deadline = (_clkcycles() + _MSECS(80));
	_thread_t *thrds[TEST1_NTHREADS];
	for (uintptr_t i = 0; i < TEST1_NTHREADS; ++i) {
		thrds[i] = _thread_create(0, THREADS_STACKSZ, test1_fn, 0);
		_thread_sched(thrds[i]);
	}
	// Pace the tokens so every _sem_get() sleeps, then gets woken up early.
	for (uintptr_t i = 0; i < (TEST1_NTHREADS*TEST1_NTOKENS); ++i) {
		_thread_sleep(_MSECS(2));
		CHECK(_sem_put(&test1_sem, _DATE_MAX), "test1: _sem_put() failed");
	}
	for (uintptr_t i = 0; i < TEST1_NTHREADS; ++i)
		thrd_join(thrds[i]);
}

// Test2: mutex contention; _DATE_MAX must always succeed, and a timeout
// much larger than the hold durations must always succeed as well, even
// when another thread wins the wake-up race, forcing a sleep-again.
#define TEST2_NTHREADS 3
#define TEST2_NLOOPS 100
static _mutex_t test2_mutex = _MUTEX_NIL;
static uintptr_t test2_cntr = 0;
static uintptr_t test2_prog[TEST2_NTHREADS]; // Per-thread progress, for the stall watchdog.
static void test2_fn (void *arg) {
	for (uintptr_t i = 0; i < TEST2_NLOOPS; ++i) {
		test2_prog[(uintptr_t)arg] = i;
		_date_t timeout = ((i & 1) ? _DATE_MAX : _MSECS(50));
		if (_mutex_lock(&test2_mutex, timeout)) {
			++test2_cntr; // Protected by test2_mutex.
			_mutex_unlock(&test2_mutex);
		} else
			CHECK(0, "test2: _mutex_lock() timed out");
	}
	test2_prog[(uintptr_t)arg] = TEST2_NLOOPS;
}
static void test2 (void) {
	printf("test2: contended timed _mutex_lock()\n");
	_thread_t *thrds[TEST2_NTHREADS];
	for (uintptr_t i = 0; i < TEST2_NTHREADS; ++i) {
		thrds[i] = _thread_create(0, THREADS_STACKSZ, test2_fn, (void *)i);
		_thread_sched(thrds[i]);
	}
	// Wait for the workers, raw-printing diagnosis info if progress stalls.
	uintptr_t prev[TEST2_NTHREADS] = {0}, alive;
	do {
		_thread_sleep(_MSECS(100));
		alive = 0;
		bool moved = false;
		for (uintptr_t i = 0; i < TEST2_NTHREADS; ++i) {
			uintptr_t p = *(volatile uintptr_t *)&test2_prog[i];
			if (p != prev[i])
				moved = true;
			prev[i] = p;
			if (!_is_thread_terminated(thrds[i]))
				++alive;
		}
		if (alive && !moved) {
			rawstr("test2 stalled: prog");
			for (uintptr_t i = 0; i < TEST2_NTHREADS; ++i) {
				rawstr(" "); rawhex(prev[i]);
			}
			rawstr(" acqcnt "); rawhex(test2_mutex.acqcnt);
			rawstr(" owner "); rawhex((uintptr_t)test2_mutex.owner);
			rawstr(" wq.p "); rawhex(test2_mutex.waitq.p);
			rawstr(" wq.l "); rawhex((uintptr_t)test2_mutex.waitq.l);
			rawstr("\n");
		}
	} while (alive);
	for (uintptr_t i = 0; i < TEST2_NTHREADS; ++i)
		thrd_join(thrds[i]);
	CHECK(test2_cntr == (TEST2_NTHREADS*TEST2_NLOOPS), "test2: mutual exclusion lost increments");
}

// Test3: fifo with mismatched put/get chunk sizes, forcing both the
// writer and the reader through their sleep-retry loops; data must
// come out in order and complete.
#define TEST3_TOTAL 175 /* Multiple of both chunk sizes 5 and 7 */
static _fifo_t test3_fifo;
static uint8_t test3_buf[16];
static void test3_fn (void *arg) {
	uint8_t chunk[5];
	uintptr_t n = 0;
	while (n < TEST3_TOTAL) {
		for (uintptr_t i = 0; i < sizeof(chunk); ++i)
			chunk[i] = (n + i);
		CHECK(_fifo_put(&test3_fifo, chunk, sizeof(chunk), _MSECS(60)),
			"test3: _fifo_put() timed out");
		n += sizeof(chunk);
	}
}
static void test3 (void) {
	printf("test3: fifo put/get retry loops\n");
	_fifo_init(&test3_fifo, test3_buf, sizeof(test3_buf));
	_thread_t *thrd = _thread_create(0, THREADS_STACKSZ, test3_fn, 0);
	_thread_sched(thrd);
	uint8_t chunk[7], peeked[3];
	uintptr_t n = 0;
	while (n < TEST3_TOTAL) {
		// Every other chunk, peek first and compare with what gets removed.
		bool peek = (((n / sizeof(chunk)) & 1) ? true : false);
		if (peek)
			CHECK(_fifo_get(&test3_fifo, peeked, sizeof(peeked), true, _MSECS(60)),
				"test3: _fifo_get() peek timed out");
		CHECK(_fifo_get(&test3_fifo, chunk, sizeof(chunk), false, _MSECS(60)),
			"test3: _fifo_get() timed out");
		if (peek)
			CHECK(!memcmp(peeked, chunk, sizeof(peeked)), "test3: peeked data mismatch");
		for (uintptr_t i = 0; i < sizeof(chunk); ++i)
			CHECK(chunk[i] == (uint8_t)(n + i), "test3: data mismatch");
		n += sizeof(chunk);
	}
	CHECK(!_fifo_usage(&test3_fifo), "test3: fifo not empty");
	thrd_join(thrd);
}

// Test4: unlock, lock, unlock in quick succession with a woken-up waiter
// that has not yet run; the second unlock _thread_schedone() must not
// spinloop on wq->p forever; done with preemption disabled so that, on a
// single CPU, the waiter cannot run in-between.
static _mutex_t test4_mutex = _MUTEX_NIL;
static _SEM_DEF(test4_done, 1, 0);
static void test4_fn (void *arg) {
	if (_mutex_lock(&test4_mutex, _DATE_MAX))
		_mutex_unlock(&test4_mutex);
	else
		CHECK(0, "test4: _mutex_lock() failed");
	_sem_put(&test4_done, _DATE_MAX);
}
#define TEST4_NLOOPS 25
static void test4 (void) {
	printf("test4: _thread_schedone() after wait-queue emptied\n");
	for (uintptr_t i = 0; i < TEST4_NLOOPS; ++i) {
		CHECK(_mutex_lock(&test4_mutex, _DATE_MAX), "test4: initial _mutex_lock() failed");
		_thread_t *thrd = _thread_create(0, THREADS_STACKSZ, test4_fn, 0);
		_thread_sched(thrd);
		_thread_sleep(_MSECS(10)); // Let the thread block on test4_mutex.
		_preempt_disable();
		_mutex_unlock(&test4_mutex); // Wakes up the waiter which cannot run yet.
		if (_mutex_lock(&test4_mutex, 0)) // Try-lock; succeeds if the waiter has not run.
			_mutex_unlock(&test4_mutex); // Pre-fix, spinloops forever on a single CPU.
		_preempt_enable();
		if (!_sem_get(&test4_done, _MSECS(500))) {
			CHECK(0, "test4: waiter never completed");
			// Raw-print diagnosis info about the stuck waiter and the mutex.
			rawstr("test4 iter "); rawhex(i);
			rawstr(" thrd.state "); rawhex(thrd->state);
			rawstr(" .cpu "); rawhex(thrd->cpu);
			rawstr(" .wq "); rawhex((uintptr_t)thrd->wq);
			rawstr(" .claim "); rawhex(thrd->claim);
			rawstr(" .z.armed "); rawhex((uintptr_t)thrd->z.l.prev);
			rawstr("\ntest4 acqcnt "); rawhex(test4_mutex.acqcnt);
			rawstr(" owner "); rawhex((uintptr_t)test4_mutex.owner);
			rawstr(" wq.p "); rawhex(test4_mutex.waitq.p);
			rawstr(" wq.l "); rawhex((uintptr_t)test4_mutex.waitq.l);
			rawstr(" thrdptr "); rawhex((uintptr_t)thrd);
			rawstr("\n");
			// Do not thrd_join() the stuck waiter; it would never return.
			return;
		}
		thrd_join(thrd);
	}
}

// Test5: re-arm the nearest _timer to a later date; the CPU must keep
// making progress until the new nearest _timer expires, instead of
// being stormed with timer interrupts.
static _date_t test5_a_fired = 0, test5_b_fired = 0;
static void test5_a_cb (_timer_t *t) { test5_a_fired = _clkcycles(); }
static void test5_b_cb (_timer_t *t) { test5_b_fired = _clkcycles(); }
static _TIMER_DEF(test5_a, test5_a_cb);
static _TIMER_DEF(test5_b, test5_b_cb);
static void test5 (void) {
	printf("test5: nearest _timer re-armed to a later date\n");
	_preempt_disable(); // Insure both arms and the re-arm happen on the same CPU.
	_date_t now = _clkcycles();
	_timer_arm(&test5_a, now + _MSECS(10)); // Becomes the nearest.
	_timer_arm(&test5_b, now + _MSECS(15));
	_timer_arm(&test5_a, now + _MSECS(30)); // Re-arm the nearest to a later date.
	_preempt_enable();
	// Busy-loop counting iterations within the window where a stale timer
	// compare value would storm this CPU with timer interrupts.
	_date_t window = (now + _MSECS(10)); // Hoisted; _MSECS() divides in 64bits.
	uintptr_t iters = 0;
	while (!*(volatile _date_t *)&test5_b_fired) {
		if (_clkcycles() > window)
			++iters;
	}
	printf("test5: %u iterations in the storm window\n", iters);
	CHECK(iters > 50, "test5: CPU starved by timer interrupt storm");
	while (!*(volatile _date_t *)&test5_a_fired); // No sleeping; stay on this CPU.
	CHECK(test5_b_fired < test5_a_fired, "test5: timers fired out of order");
}

// Test6: nanosleep() must sleep at least the duration requested.
static void test6 (void) {
	printf("test6: nanosleep()\n");
	_date_t start = _clkcycles();
	nanosleep(&(struct timespec){0, 20000000}, 0); // 20ms.
	CHECK((_clkcycles() - start) >= _MSECS(20), "test6: nanosleep() too short");
}

void main (void) {
	printf("oststress: starting on %u cpu(s) ...\n", _ncpu());
	test1();
	test2();
	test3();
	test4();
	test5();
	test6();
	// Atomic read; failcnt is atomically incremented by other threads, and
	// atomics do not participate in the coherency protocol, so a plain read
	// could miss their increments.
	uintptr_t fails = _atomic_add(&failcnt, 0);
	if (fails)
		printf("oststress: %u FAILURE(S)\n", fails);
	else
		printf("oststress: ALL PASS\n");
}
