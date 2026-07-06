// SPDX-License-Identifier: GPL-2.0-only
// 20260706 (c) William Fonkou Tambe

// Test _OS (UnderLineOS) trap tail-chaining: interrupts that are already
// pending when the trap handler is about to return must be dispatched
// back-to-back within that same trap entry, and the interrupted context
// must resume correctly afterward.
//
// Test1 (any cpu count) choreographs, on the boot CPU, the sequence:
// - main() spinloops with preemption enabled after arming _timer cb0.
// - cb0 expires (machine-timer trap) and triggers a self-IPI, making a
//   machine-external interrupt pending while still inside the trap.
// - The IPI callback (registered for the reserved interrupt number -1)
//   arms _timer cb1 with an already-expired date, making the machine-timer
//   interrupt pending again.
// - cb1 runs; the timer list is then empty with the timer compare value
//   in the past, which must not livelock or storm the CPU.
// The callbacks must run in the order cb0, ipi, cb1; with tail-chaining
// they all dispatch within cb0's trap entry, and the printed latencies
// (self-IPI to ipi callback, ipi callback to cb1) shrink by the cost of
// a full context restore + mret + trap re-entry + context re-save.
//
// Test2 (cpu count >= 2) stress-tests chaining against context-switching:
// two threads pinned on cpu1 spinloop while a short-period _timer re-arms,
// as main() on cpu0 storms cpu1 with IPIs; every IPI preemption then
// round-robins cpu1 between the two threads, so trap returns routinely
// resume a different thread's saved context, with timer callbacks and
// IPI dispatches tail-chaining around the scheduler preemption path.
// All timer ticks must be accounted for.
//
// Test2 also regression-tests a since-fixed rvxx interrupt-starvation
// hardware bug: the threads spinloop on `while (test2_ticks < TEST2_TICKS);`,
// a two-instruction load loop, whose held load result used to assert
// rW_multicyclePending in lockstep with a self-blanking excIrq pulse
// (rvxx/sys.pu.sv) which alternated every other cycle while an interrupt
// was pending; when the loop period aligned, `excIrq[x] && !rW_multicyclePending`
// was false on every cycle and the CPU never took the trap: it was observed
// spinning with mstatus.mie set, mie 0x880 and mip 0x880 indefinitely,
// while cpu0 hung awaiting acknowledgment of the IPI it had triggered.
// excIrq is now set null only after a cycle for which it was allowed
// to trigger, staying visible while a pending interrupt is gated, and
// this test wedging is how a regression of that fix would manifest.

#include <stdio.h>

#include <_os.h>

static uintptr_t failcnt = 0;
#define CHECK(COND, MSG) ({ \
	if (!(COND)) { \
		_atomic_inc(&failcnt); \
		printf("FAIL: %s\n", (MSG)); \
	} })

#define SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)

// Raw-serial prints used from callbacks, which run inside the machine-mode
// trap handler where printf() cannot be used.
static void rawstr (const char *s) {
	for (char c; (c = *s); ++s)
		*(volatile char *)SERIAL0_ADDR = c;
}

// Local copy of hwdrvirqctrl_int() from machine/hwdrvirqctrl.h,
// which does not get installed with the toolchain.
#define IRQCTRLADDR ((uintptr_t *)0xf00 /* By convention, the interrupt controller is located at 0xf00 */)
static inline uintptr_t irqctrl_int (uintptr_t idx) {
	uintptr_t irqdst;
	do {
		irqdst = ((idx<<2) | 0b10);
		irqdst = _xchg(IRQCTRLADDR, irqdst);
	} while (irqdst & 0b11);
	irqdst = 0;
	irqdst = _xchg(IRQCTRLADDR, irqdst);
	return ((intptr_t)irqdst >> 2);
}

// Trigger an IPI targeting the given cpu, retrying while the irqctrl
// is busy with an interrupt pending acknowledgement; the retries are
// paced so that they do not starve the pending acknowledgement of the
// bus access it needs to complete.
// Callable from trap context, hence no CHECK() which uses printf().
static void send_ipi (uintptr_t cpu) {
	uintptr_t ret;
	while ((ret = irqctrl_int(cpu)) == -2)
		for (volatile uintptr_t i = 0; i < 100; ++i);
	if (ret != cpu) {
		_atomic_inc(&failcnt);
		rawstr("FAIL: send_ipi(): invalid destination\n");
	}
}

// Test1: back-to-back machine-timer and machine-external interrupts
// dispatched from a single trap entry on the boot CPU.

static volatile uintptr_t test1_seq = 0;
static uintptr_t test1_seq_cb0, test1_seq_ipi, test1_seq_cb1;
static _date_t test1_c0, test1_c1, test1_c2;
static uintptr_t test1_ipi_expected = 0;

static void test1_cb1_fn (_timer_t *t) {
	test1_c2 = _clkcycles();
	test1_seq_cb1 = ++test1_seq;
	rawstr("cb1\n");
}
static _TIMER_DEF(test1_cb1, test1_cb1_fn);

static void test1_ipi_fn (_irq_t *i) {
	// Runs for every IPI acknowledged by this CPU (the registered
	// interrupt list is shared); only test1's self-IPI participates.
	if (!test1_ipi_expected)
		return;
	test1_ipi_expected = 0;
	test1_c1 = _clkcycles();
	test1_seq_ipi = ++test1_seq;
	rawstr("ipi\n");
	// Already expired, making the machine-timer interrupt pending again.
	_timer_arm(&test1_cb1, _clkcycles());
}
static _IRQ_DEF(test1_ipi, -1, test1_ipi_fn);

static void test1_cb0_fn (_timer_t *t) {
	test1_seq_cb0 = ++test1_seq;
	rawstr("cb0\n");
	test1_ipi_expected = 1;
	test1_c0 = _clkcycles();
	// Makes a machine-external interrupt pending while inside this trap.
	send_ipi(_cpuid());
}
static _TIMER_DEF(test1_cb0, test1_cb0_fn);

static void test1 (void) {
	printf("test1: single-entry chain ...\n");
	_timer_arm(&test1_cb0, _clkcycles() + _USECS(500));
	// Spinloop instead of sleeping so that this CPU keeps a runnable
	// thread: the choreography must not depend on the idle wfi paths.
	_date_t giveup = (_clkcycles() + _MSECS(50));
	while ((test1_seq < 3) && (_clkcycles() < giveup));
	CHECK(test1_seq == 3, "test1: callbacks did not all run");
	CHECK(test1_seq_cb0 == 1, "test1: cb0 ran out of order");
	CHECK(test1_seq_ipi == 2, "test1: ipi ran out of order");
	CHECK(test1_seq_cb1 == 3, "test1: cb1 ran out of order");
	printf("test1: self-ipi to ipi(): %u cycles\n", (unsigned)(test1_c1 - test1_c0));
	printf("test1: ipi() to cb1(): %u cycles\n", (unsigned)(test1_c2 - test1_c1));
}

// Test2: IPI-storming a CPU which is busy taking timer interrupts.

#define TEST2_ENABLE 1
#define TEST2_TICKS 20
#define THREADS_STACKSZ 2048

static volatile uintptr_t test2_ticks = 0;

static void test2_tick_fn (_timer_t *t) {
	uintptr_t ticks = (test2_ticks + 1);
	test2_ticks = ticks;
	if (ticks < TEST2_TICKS)
		_timer_arm(t, _clkcycles() + _USECS(100));
}
static _TIMER_DEF(test2_tick, test2_tick_fn);

static void test2_fn (void *arg) {
	if (arg)
		_timer_arm(&test2_tick, _clkcycles() + _USECS(100));
	while (test2_ticks < TEST2_TICKS);
}

static void test2 (void) {
	printf("test2: ipi-storm chaining ...\n");
	// Two threads pinned on cpu1 so that every IPI preemption
	// switches context, resuming through a saved trap context.
	_thread_t *thrds[2];
	for (uintptr_t i = 0; i < 2; ++i) {
		thrds[i] = _thread_create(0, THREADS_STACKSZ, test2_fn, (void *)i);
		_thread_schedoncpu(thrds[i], 1, true);
	}
	uintptr_t ipis = 0;
	while (!_is_thread_terminated(thrds[0]) || !_is_thread_terminated(thrds[1])) {
		send_ipi(1);
		++ipis;
		for (volatile uintptr_t i = 0; i < 2000; ++i);
	}
	for (uintptr_t i = 0; i < 2; ++i)
		_thread_dispose(thrds[i]);
	CHECK(test2_ticks == TEST2_TICKS, "test2: timer ticks were lost");
	printf("test2: %u ipis across %u ticks\n", (unsigned)ipis, (unsigned)TEST2_TICKS);
}

void main (void) {
	printf("Starting ...\n");
	_irq_register(&test1_ipi);
	test1();
	if (TEST2_ENABLE && (_ncpu() >= 2))
		test2();
	else
		printf("test2: skipped\n");
	_irq_unregister(&test1_ipi);
	// Atomic read; failcnt is atomically incremented, and per the hw
	// atomics coherency contract, it must only be accessed atomically.
	uintptr_t fails = _atomic_add(&failcnt, 0);
	if (fails)
		printf("FAILED: %u failures\n", (unsigned)fails);
	else
		printf("PASS\n");
}
