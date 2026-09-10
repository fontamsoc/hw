// SPDX-License-Identifier: GPL-2.0-only
// 20260731 (c) William Fonkou Tambe

// Test that a hart whose bus access is not being accepted cannot starve the
// other harts.
//
// lib/wb_arbiter.sv rotates its grant, and the granted master is the only one
// not held busy (m_wb_bsy_o), which reaches instruction fetching through
// cpu/memctrl.pu.sv, so a hart that is not granted executes nothing at all.
// No bus lock is involved here, ie: wb_lock is null throughout.
//
// A slave is allowed to hold wb_bsy_o for as long as it likes, and the character
// devices do: dev/serial_sim.sv, and likewise serial_uart, serial_usb and
// serial_jtag, hold it for as long as their receive buffer is empty, so that a
// read of the data register waits for a byte to arrive. A master presenting such
// an access holds its strobe asserted until it is accepted, ie: possibly forever,
// hence the grant must not be held by the master presenting it.
//
// What stalls below is an instruction fetch, ie: cpu1 jumps into the character
// device's address space, and that is deliberate rather than incidental. A
// stalled DATA access parks the data-cache outside READY and TSTHIT, which
// cpu/dcache.sv holds the coherency ring busy for, and the ring then stops the
// other harts' data-caches without their ever presenting a bus request at all,
// ie: a wedge that has nothing to do with arbitration and that no arbitration
// bound can lift. A stalled fetch leaves the data-cache in READY, so the ring
// keeps flowing and what is left is exactly the grant hold this tests.
//
// The stalled hart never returns, hence there is nothing to join and the check
// is made by the other hart: it must complete a bounded run of bus accesses and
// report. On hardware with no bound it is starved down to its instruction
// fetching and completes none of them; there is no bus watchdog and the
// simulation has no cycle limit, hence that presents as a silent run forever,
// and a run of this test which prints neither PASS nor FAILED is itself the
// failure.

#include <stdio.h>

#include <_os.h>

#define THREADS_STACKSZ 2048

// The character device's data register. All four SoC tops map the device at
// this address, ie: the WBPI_SDEVS entry (32'hf80, 32'(2*(WORDBITSZ/8))), which
// is also the convention _os_params.h states as SERIAL0_ADDR. The second word
// is the command register, whose accesses are always accepted; it is the data
// register that waits.
#define SERIALDAT 0xf80

// Enough accesses that the hart under test is running for far longer than the
// few instructions the other one needs to reach its stalling fetch, so that a
// bus with no fairness bound starves this hart partway rather than after it.
#define ACCESSES 4000

static uintptr_t failcnt = 0;
#define CHECK(COND, MSG) ({ \
	if (!(COND)) { \
		_atomic_inc(&failcnt); \
		printf("FAIL: %s\n", (MSG)); \
	} })

static uintptr_t stalling = 0;
static uintptr_t progress = 0;

// Announce, then fetch from an address the device will not serve. Reached only
// as an instruction fetch, hence no data access of this hart's is outstanding
// and its data-cache stays in READY.
static void staller_fn (void *arg) {
	(void)arg;
	_atomic_inc(&stalling);
	__asm__ volatile ("jr %0" :: "r" (SERIALDAT) : "memory");
	__builtin_unreachable();
}

void main (void) {
	printf("Starting ...\n");

	if (_ncpu() < 2) {
		// Nothing to starve: lib/wb_arbiter.sv is instantiated only for
		// more than one hart, and cpu/ccx.sv bypasses it otherwise.
		printf("smpfair: single hart, skipped\n");
		printf("PASS\n");
		return;
	}

	// Initialize the flag atomically before the other hart touches it: the boot
	// zeroed .bss with plain stores, which sit dirty in this hart's dcache, and
	// an atomic access on a locally cached word writes the cached value back
	// before its read-modify-write, which would overwrite the other hart's
	// increment with the stale zero; whether the entry is still cached when
	// that happens depends on the image layout.
	_xchg(&stalling, 0);
	_thread_schedoncpu(_thread_create(0, THREADS_STACKSZ, staller_fn, 0), 1, true);

	// Wait for cpu1 to be about to stall. Paced with a cached-only loop, which
	// issues no bus access, so that this wait cannot itself be what holds the
	// grant while cpu1 is still trying to announce.
	printf("waiting for cpu1 to present its stalling fetch ...\n");
	while (!_atomic_add(&stalling, 0))
		for (volatile uintptr_t d = 0; d < 200; ++d);

	// Accessed only through atomics, per the atomics coherency contract in
	// cpu/README.md: atomic memory operations bypass the data-cache and the
	// coherency protocol, so a plain load can observe a stale value. That also
	// makes every iteration below a bus access, which is the point, as a hart
	// running out of its caches would not need the grant at all.
	printf("cpu0 running while cpu1 is stalled ...\n");
	for (uintptr_t i = 0; i < ACCESSES; ++i)
		_atomic_inc(&progress);

	CHECK(_atomic_add(&progress, 0) == ACCESSES, "cpu0 lost accesses");

	printf("cpu0 completed %u accesses\n", (unsigned)ACCESSES);

	// Atomic read; failcnt is atomically incremented, and per the hw
	// atomics coherency contract, it must only be accessed atomically.
	uintptr_t fails = _atomic_add(&failcnt, 0);
	if (fails)
		printf("FAILED: %u failures\n", (unsigned)fails);
	else
		printf("PASS\n");
}
