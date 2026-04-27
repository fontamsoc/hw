// SPDX-License-Identifier: GPL-2.0-only
// 20250112 (c) William Fonkou Tambe

// Ported from Zephyr sample SMP Pi:
// https://docs.zephyrproject.org/latest/samples/arch/smp/pi/README.html

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <_os.h>

// Size in bytes of threads' stack.
#define THREADS_STACKSZ 2048

// Amount of execution threads to create and run.
#define THREADS_NUM 16

// Amount of digits of Pi to calculate, must be a multiple of 4,
// as used algorithm spits 4 digits on every iteration.
#define DIGITS_NUM 240

#define LENGTH ((DIGITS_NUM / 4) * 14)

static char thrd_buffer[THREADS_NUM][DIGITS_NUM + 1];
static int thrd_array[THREADS_NUM][LENGTH + 1];

static uintptr_t busy_cntr = THREADS_NUM;

static _SEM_DEF(main_sem, 1, 0);

void thrd_fn (void *arg) {

	char *buffer = thrd_buffer[(uintptr_t)arg];
	int *array = thrd_array[(uintptr_t)arg];
	/*
	 * Adapted and improved (for random number of digits) version of Pi
	 * calculation program initially proposed by Dik T. Winter as:
	 * -------------------------------->8--------------------------------
	 * int a=10000,b,c=2800,d,e,f[2801],g;main(){for(;b-c;)f[b++]=a/5;
	 * for(;d=0,g=c*2;c-=14,printf("%.4d",e+d/a),e=d%a)for(b=c;d+=f[b]*a,
	 * f[b]=d%--g,d/=g--,--b;d*=b);}
	 * -------------------------------->8--------------------------------
	 */
	#define NEW_BASE   10000
	#define ARRAY_INIT 2000

	int carry = 0;
	int i, j;

	for (i = 0; i < LENGTH; i++) {
		array[i] = ARRAY_INIT;
	}

	for (i = LENGTH; i > 0; i -= 14) {
		int sum = 0, value;

		for (j = i; j > 0; --j) {
			sum = sum * j + NEW_BASE * array[j];
			array[j] = sum % (j * 2 - 1);
			sum /= j * 2 - 1;
		}

		value = carry + sum / NEW_BASE;
		carry = sum % NEW_BASE;

		// Convert 4-digit int to string.
		sprintf(buffer, "%.4d", value);
		buffer += 4;
	}

	if (_atomic_dec(&busy_cntr) == 1)
		_sem_put(&main_sem, _DATE_MAX);
}

void main (void) {

	printf("Calculate first %d digits of Pi independently by %d threads.\n",
		DIGITS_NUM, THREADS_NUM);

	uintptr_t ncpu = _ncpu();

	void *threads_stack = malloc(THREADS_NUM*THREADS_STACKSZ);

	// Prevent context switch until all threads have been scheduled.
	_preempt_disable();

	// Capture start timestamp.
	_date_t start_time = _clkcycles();

	for (uintptr_t i = 0; i < THREADS_NUM; ++i) {
		_thread_schedoncpu(
			_thread_create(threads_stack+(i*THREADS_STACKSZ), THREADS_STACKSZ,
				thrd_fn, (void *)i),
			// Try to use a cpu other than _cpuid() to immediately start computing.
			((_cpuid() + i + 1) % ncpu), true);
	}

	// Wait for all workers to finish their calculations.
	_sem_get(&main_sem, _DATE_MAX);

	// Capture end timestamp.
	_date_t end_time = _clkcycles();

	_preempt_enable();

	_date_t cycles_spent = (end_time - start_time);
	uintptr_t milliseconds_spent = ((cycles_spent * 1000) / _clkfreq());

	for (uintptr_t i = 0; i < THREADS_NUM; ++i) {
		printf("Pi value calculated by thread #%d: %s\n", i, thrd_buffer[i]);
	}

	for (uintptr_t i = 0; i < (THREADS_NUM - 1); ++i) {
		if (strcmp(thrd_buffer[i], thrd_buffer[i + 1])) {
			printf("Error: #%d != #%d\n", i, (i + 1));
			return;
		}
	}

	printf("All %d threads executed by %d cores in %d ms\n",
		THREADS_NUM, ncpu, milliseconds_spent);
}
