// SPDX-License-Identifier: GPL-2.0-only
// 20250110 (c) William Fonkou Tambe

// Test _OS (UnderLineOS) sw-timers and multi-threading.
// Preempting scheduling get tested when at some point,
// both thrd0 and thrd1 spinloop instead of sleeping.

#include <stdio.h>

#include <_os.h>

#define SERIAL0_ADDR (0xf80 /* By convention, the first UART is located at 0xf80 */)

// Used by _timer_t callback because printf() cannot
// be used due to relying on the thread pointer register.
static void printstr (char *s) {
	for (char c; c = *s; ++s)
		*(volatile char *)SERIAL0_ADDR = c;
}

_timer_t timer0;
void timer0_cb (_timer_t *t) {
	printstr("timer0()\n");
	_timer_arm(t, _clkcycles() + _MSECS(10));
}

_timer_t timer1;
void timer1_cb (_timer_t *t) {
	printstr("timer1()\n");
	_timer_arm(t, _clkcycles() + _MSECS(20));
}

_sem_t tsttSem __attribute__((noinit));

typedef struct {
	uintptr_t id;
	uintptr_t cntr_start;
	uintptr_t cntr_thresh;
} thrd_arg;

void thrd_fn (void *arg) {
	uintptr_t id = ((thrd_arg *)arg)->id;
	if (id == 0) {
		_timer_init(&timer0, timer0_cb);
		_timer_arm(&timer0, _clkcycles() + _MSECS(10));
	} else {
		_timer_init(&timer1, timer1_cb);
		_timer_arm(&timer1, _clkcycles() + _MSECS(10));
	}
	uintptr_t cntr = ((thrd_arg *)arg)->cntr_start;
	uintptr_t cntr_thresh = ((thrd_arg *)arg)->cntr_thresh;
	while(1) {
		printf("thrd%u(): %d: 0x%08x\n", id, cntr, (uint32_t)_clkcycles());
		if (!cntr) {
			printf("thrd%u(): 0x%08x: exiting ...\n", id, (uint32_t)_clkcycles());
			return; //_thread_exit();
		}
		if (--cntr >= cntr_thresh) {
			if (id == 0)
				_thread_sleep(_MSECS(60));
			else // Test semaphore timeout.
				_sem_get(&tsttSem, _MSECS(60));
		} else
			for (uintptr_t i = 0; i < _MSECS(1); ++i);
	}
}

void main (void) {

	printf("Starting ...\n");

	_sem_init(&tsttSem, 1, 0);

	_thread_t *thrd0 = _thread_create (0, 2048, thrd_fn, &(thrd_arg){0, 16, 8});
	_thread_sched(thrd0);

	_thread_sleep(_MSECS(20));

	_thread_t *thrd1 = _thread_create (0, 2048, thrd_fn, &(thrd_arg){1, 20, 10});
	_thread_sched(thrd1);

	_thread_sleep(_MSECS(20));

	while(1) {
		printf("main(): 0x%08x\n", (uint32_t)_clkcycles());
		_thread_sleep(_MSECS(60));
		if (thrd0 && _is_thread_terminated(thrd0)) {
			_thread_dispose(thrd0);
			thrd0 = 0;
		}
		if (thrd1 && _is_thread_terminated(thrd1)) {
			_thread_dispose(thrd1);
			thrd1 = 0;
		}
		if (!thrd0 && !thrd1) {
			printf("main() exiting ...\n", (uint32_t)_clkcycles());
			_thread_sleep(_MSECS(40));
			return;
		}
	}
}
