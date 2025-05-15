/* 
	File : core_portme.c
*/
/*
	Author : Shay Gal-On, EEMBC
	Legal : TODO!
*/ 
#include "coremark.h"
#include "core_portme.h"

#include <stdlib.h>

void *portable_malloc(size_t size) {
	return malloc(size);
}
void portable_free(void *p) {
	free(p);
}

#if VALIDATION_RUN
	volatile ee_s32 seed1_volatile=0x3415;
	volatile ee_s32 seed2_volatile=0x3415;
	volatile ee_s32 seed3_volatile=0x66;
#endif
#if PERFORMANCE_RUN
	volatile ee_s32 seed1_volatile=0x0;
	volatile ee_s32 seed2_volatile=0x0;
	volatile ee_s32 seed3_volatile=0x66;
#endif
#if PROFILE_RUN
	volatile ee_s32 seed1_volatile=0x8;
	volatile ee_s32 seed2_volatile=0x8;
	volatile ee_s32 seed3_volatile=0x8;
#endif
	volatile ee_s32 seed4_volatile=ITERATIONS;
	volatile ee_s32 seed5_volatile=0;
/* Porting : Timing functions
	How to capture time and convert to seconds must be ported to whatever is supported by the platform.
	e.g. Read value from on board RTC, read value from cpu clock cycles performance counter etc. 
	Sample implementation for standard time.h and windows.h definitions included.
*/
CORETIMETYPE barebones_clock() {
	inline unsigned long get_cycles_hi (void) {
		unsigned long hi;
		asm volatile ("csrr %0, cycleh\n" : "=r"(hi) :: "memory");
		return hi;
	}
	unsigned long lo, hi;
	do {
		hi = get_cycles_hi();
		asm volatile ("csrr %0, cycle\n"  : "=r"(lo) :: "memory");
	} while (hi != get_cycles_hi());
	return (((ee_u64)hi << 32) | lo);
}
/* Define : TIMER_RES_DIVIDER
	Divider to trade off timer resolution and total time that can be measured.

	Use lower values to increase resolution, but make sure that overflow does not occur.
	If there are issues with the return value overflowing, increase this value.
	*/
#define GETMYTIME(_t) (*_t=barebones_clock())
#define MYTIMEDIFF(fin,ini) ((fin)-(ini))
#define TIMER_RES_DIVIDER 1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define CLOCKS_PER_SEC() ({ \
	unsigned long freq; \
	asm volatile ("csrr %0, 0xcc0\n" : "=r"(freq) :: "memory"); \
	freq; })
#define EE_TICKS_PER_SEC (CLOCKS_PER_SEC() / TIMER_RES_DIVIDER)

/** Define Host specific (POSIX), or target specific global time variables. */
static CORETIMETYPE start_time_val, stop_time_val;

/* Function : start_time
	This function will be called right before starting the timed portion of the benchmark.

	Implementation may be capturing a system timer (as implemented in the example code) 
	or zeroing some system parameters - e.g. setting the cpu clocks cycles to 0.
*/
void start_time(void) {
	GETMYTIME(&start_time_val );      
}
/* Function : stop_time
	This function will be called right after ending the timed portion of the benchmark.

	Implementation may be capturing a system timer (as implemented in the example code) 
	or other system parameters - e.g. reading the current value of cpu cycles counter.
*/
void stop_time(void) {
	GETMYTIME(&stop_time_val );      
}
/* Function : get_time
	Return an abstract "ticks" number that signifies time on the system.
	
	Actual value returned may be cpu cycles, milliseconds or any other value,
	as long as it can be converted to seconds by <time_in_secs>.
	This methodology is taken to accomodate any hardware or simulated platform.
	The sample implementation returns millisecs by default, 
	and the resolution is controlled by <TIMER_RES_DIVIDER>
*/
CORE_TICKS get_time(void) {
	CORE_TICKS elapsed=(CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
	return elapsed;
}
/* Function : time_in_secs
	Convert the value returned by get_time to seconds.

	The <secs_ret> type is used to accomodate systems with no support for floating point.
	Default implementation implemented by the EE_TICKS_PER_SEC macro above.
*/
secs_ret time_in_secs(CORE_TICKS ticks) {
	secs_ret retval=((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
	return retval;
}

#if (MULTITHREAD>1)
#if USE__OS
#define _OS_THRD_STACKSZ 2048
void *_os_thrd_stack;
static unsigned long _os_busy_ctnr;
static _SEM_DEF(_os_thrd_sem, 1, 0);
void _os_thrd_fn (void *arg) {
	iterate((core_results *)arg);
	if (_atomic_dec(&_os_busy_ctnr) == 1)
		_sem_put(&_os_thrd_sem, _DATE_MAX);
}
unsigned long ncpu;
ee_u8 core_start_parallel(core_results *res) {
	static unsigned long i = 0;
	_thread_schedoncpu(
		_thread_create(_os_thrd_stack + (i*_OS_THRD_STACKSZ), _OS_THRD_STACKSZ,
			_os_thrd_fn, (void *)res),
		// Try to use a cpu other than _cpuid() to immediately start computing.
		// TODO: With load-balancing, just use _thread_sched() on _thread_create() output.
		((_cpuid() + i + 1) % ncpu), true);
	++i;
	return 0;
}
ee_u8 core_stop_parallel(core_results *res) {
	if (_os_busy_ctnr)
		_sem_get(&_os_thrd_sem, _DATE_MAX);
	return 0;
}
#else /* no standard multicore implementation */
#error "Please implement multicore functionality in core_portme.c to use multiple contexts."
#endif /* multithread implementations */
#endif

ee_u32 default_num_contexts=1;

/* Function : portable_init
	Target specific initialization code
	Test for some common mistakes.
*/
void portable_init(core_portable *p, int *argc, char *argv[]) {
	ee_printf("CoreMark @ %u Hz\n", CLOCKS_PER_SEC());
	if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
		ee_printf("ERROR! Please define ee_ptr_int to a type that holds a pointer!\n");
	}
	if (sizeof(ee_u32) != 4) {
		ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
	}
	p->portable_id=1;
#if (MULTITHREAD>1)
#if USE__OS
	_os_busy_ctnr=ncpu=_ncpu();
	if (_os_busy_ctnr>MULTITHREAD) {
		ee_printf("WARNING! _ncpu()>MULTITHREAD!\n");
		_os_busy_ctnr=MULTITHREAD;
	}
	default_num_contexts=_os_busy_ctnr;
	_os_thrd_stack = malloc(default_num_contexts*_OS_THRD_STACKSZ);
	if (!_os_thrd_stack)
		ee_printf("ERROR! Failed to allocate stack!\n");
#endif
#endif
}
/* Function : portable_fini
	Target specific final code
*/
void portable_fini(core_portable *p)
{
	p->portable_id=0;
	ee_printf("CoreMark done\n");
}
