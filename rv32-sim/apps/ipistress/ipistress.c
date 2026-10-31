// SPDX-License-Identifier: GPL-2.0-only
// 20261031 (c) William Fonkou Tambe

// Test that every interprocessor interrupt (IPI) which dev/irqctrl.sv
// accepts gets delivered.
//
// Each odd cpu runs a pinned thread which keeps toggling mstatus.MIE through
// _preempt_disable() and _preempt_enable(), hence its irq_rdy_o, while a pinned
// thread on each even cpu sends it IPIs through _thread_preempt(); with an odd
// cpu count, the last even cpu targets the odd cpu below it, ie: with three
// cpus, cpu0 and cpu2 both target cpu1. An _irq_t registered for the reserved
// interrupt number -1 counts the IPIs that each cpu acknowledges.
//
// The controller used to drop an accepted IPI whenever its destination stopped
// being ready before the IPI got presented to it, ie: when the destination
// masked its interrupts before the sender closed its transaction; it aborted
// the IPI as it aborts an interrupt from a source, which gets dispatched again
// since its source keeps requesting, whereas no source is left to raise an IPI
// again, while the sender had read back success.
//
// An IPI sent to a destination which already has one pending merges with it,
// a single acknowledgement servicing both, hence what is checked is that each
// IPI gets followed by an acknowledgement, rather than that the counts match:
// after each IPI, the sender waits for the count of its destination to move
// past the value read before sending it, and a wait longer than TIMEOUT cycles
// is a lost IPI; the count is checked before the elapsed time, hence a sender
// preempted while waiting does not report an IPI acknowledged meanwhile as lost.
// Each sender runs two phases, first sending its IPIs back-to-back, then
// spacing them with a varying spin, so that they land at every point of the
// toggling loop rather than right after the destination acknowledged the
// previous one, when the trap handling it still has the destination interrupts
// disabled; the first phase hardly ever lost an IPI, the second one lost more
// than a quarter of them.

#include <stdio.h>

#include <_os.h>

#define THREADS_STACKSZ 2048

// Bound on the cpu count, sizing the per cpu variables.
#define MAXCPU 16

#ifndef IPIS
#define IPIS 1000 // IPIs sent by each sender in each phase.
#endif

#ifndef IPIGAP
#define IPIGAP 600 // Bound of the spin between two IPIs of the second phase.
#endif

#ifndef TIMEOUT
#define TIMEOUT 200000 // Clock cycles within which an IPI must get acknowledged.
#endif

// A phase stops after that many lost IPIs, which bounds a failing run.
#define MAXLOST 16

// Every variable shared between the cpus is accessed only through atomics,
// per the atomics coherency contract in cpu/README.md: atomic memory operations
// bypass the data-cache, hence a plain store to a word of the same cache line
// could later be written back over an atomic write.
static uintptr_t acked[MAXCPU]; // IPIs acknowledged by each cpu.
static uintptr_t sent[MAXCPU][2]; // IPIs sent by each sender in each phase.
static uintptr_t lost[MAXCPU][2]; // IPIs lost by each sender in each phase.
static uintptr_t stop = 0;

static void ipicount_fn (_irq_t *i) {
	(void)i;
	_atomic_inc(&acked[_cpuid()]);
}

static _IRQ_DEF(ipicount, -1, ipicount_fn);

// Destination of the sender running on the even cpu src.
static uintptr_t dstcpu (uintptr_t src, uintptr_t ncpu) {
	return (((src + 1) < ncpu) ? (src + 1) : (src - 1));
}

static void toggler_fn (void *arg) {
	(void)arg;
	while (!_atomic_add(&stop, 0)) {
		for (uintptr_t i = 0; i < 64; ++i) {
			_preempt_disable();
			_preempt_enable();
		}
	}
}

static void sender_fn (void *arg) {
	uintptr_t src = (uintptr_t)arg;
	uintptr_t dst = dstcpu(src, _ncpu());
	for (uintptr_t phase = 0; phase < 2; ++phase) {
		uintptr_t n, l = 0;
		for (n = 0; n < IPIS && l < MAXLOST; ++n) {
			uintptr_t a = _atomic_add(&acked[dst], 0);
			_thread_preempt(dst);
			_date_t t = _clkcycles();
			while (_atomic_add(&acked[dst], 0) == a) {
				if ((_clkcycles() - t) > TIMEOUT) {
					++l;
					break;
				}
			}
			if (phase)
				for (volatile uintptr_t d = 0; d < ((n * 37) % IPIGAP); ++d);
		}
		_xchg(&sent[src][phase], n);
		_xchg(&lost[src][phase], l);
	}
}

// _is_thread_terminated() is a plain read, which the compiler would otherwise
// hoist out of the loop, as the spin touches no memory but its own counter.
static void join (_thread_t *thrd) {
	while (!_is_thread_terminated(thrd)) {
		for (volatile uintptr_t d = 0; d < 2000; ++d);
		__asm__ __volatile__ ("" ::: "memory");
	}
}

void main (void) {
	printf("Starting ...\n");

	uintptr_t ncpu = _ncpu();
	if (ncpu < 2) {
		printf("ipistress: single hart, skipped\n");
		printf("PASS\n");
		return;
	}
	if (ncpu > MAXCPU) {
		printf("FAILED: more than %u cpus\n", (unsigned)MAXCPU);
		return;
	}

	_irq_register(&ipicount);

	_thread_t *togglers[MAXCPU], *senders[MAXCPU];
	for (uintptr_t cpu = 1; cpu < ncpu; cpu += 2) {
		togglers[cpu] = _thread_create(0, THREADS_STACKSZ, toggler_fn, 0);
		_thread_schedoncpu(togglers[cpu], cpu, true);
	}
	for (uintptr_t cpu = 0; cpu < ncpu; cpu += 2) {
		senders[cpu] = _thread_create(0, THREADS_STACKSZ, sender_fn, (void *)cpu);
		_thread_schedoncpu(senders[cpu], cpu, true);
	}

	for (uintptr_t cpu = 0; cpu < ncpu; cpu += 2) {
		join(senders[cpu]);
		_thread_dispose(senders[cpu]);
	}
	_xchg(&stop, 1);
	for (uintptr_t cpu = 1; cpu < ncpu; cpu += 2) {
		join(togglers[cpu]);
		_thread_dispose(togglers[cpu]);
	}

	_irq_unregister(&ipicount);

	uintptr_t total = 0;
	for (uintptr_t cpu = 0; cpu < ncpu; cpu += 2) {
		uintptr_t l0 = _atomic_add(&lost[cpu][0], 0), l1 = _atomic_add(&lost[cpu][1], 0);
		printf("ipistress: cpu%u to cpu%u: back-to-back %u sent %u lost, spaced %u sent %u lost\n",
			(unsigned)cpu, (unsigned)dstcpu(cpu, ncpu),
			(unsigned)_atomic_add(&sent[cpu][0], 0), (unsigned)l0,
			(unsigned)_atomic_add(&sent[cpu][1], 0), (unsigned)l1);
		total += (l0 + l1);
	}

	if (total)
		printf("FAILED: %u IPIs lost\n", (unsigned)total);
	else
		printf("PASS\n");
}
