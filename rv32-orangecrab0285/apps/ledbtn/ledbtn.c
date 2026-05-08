#include <stdio.h>

#include <_os.h>

#define SHOW_CLOCK 1

#define countof(A) (sizeof(A)/sizeof(A[0]))

volatile uintptr_t* const leds[] = {(void*)0xd80, (void*)0xda0, (void*)0xdc0};
static_assert((countof(leds) <= (sizeof(uintptr_t)*8)),
	"Too many LEDs to drive"/* not enough bits in uintptr_t */);
#define btns leds

static volatile uintptr_t pwm_onpulse[countof(leds)] = {0};
static volatile uintptr_t pwm_period;

static void pwm (_timer_t *t) {
	static _date_t expdate[countof(leds)] = {0};
	static uintptr_t states = 0;
	_date_t nxt_expdate = _DATE_MAX;
	_date_t curdate = _clkcycles();
	for (uintptr_t i = 0; i < countof(leds); ++i) {
		if (curdate >= expdate[i]) {
			uintptr_t b = ((uintptr_t)1 << i);
			uintptr_t s = ((states & b) != 0);
			uintptr_t pulselen; do {
				pulselen = (s ? (pwm_period - pwm_onpulse[i]) : pwm_onpulse[i]);
				s ^= 1;
			} while (!pulselen);
			expdate[i] += pulselen;
			if (expdate[i] <= curdate)
				expdate[i] = (curdate + pulselen);
			if (s) {
				states |= b;
				*leds[i] = 1;
			} else {
				states &= ~b;
				*leds[i] = 0;
			}
		}
		if (expdate[i] < nxt_expdate)
			nxt_expdate = expdate[i];
	}
	_timer_arm(t, nxt_expdate);
}

volatile uintptr_t blink_en = 0;

void blink (void *) {

	printf("🚀 blink() thread started\n");

	uintptr_t stepdir = 0; // 0 = Fading Up, 1 = Fading Down.
	uintptr_t steplen = (_SECS(1)/16);
	uintptr_t dutypct = 0;
	uintptr_t idx = 0;

	while (1) {
		if (blink_en || stepdir != 0 || dutypct != 0) {
			if (dutypct >= 100) {
				dutypct = 0;
				stepdir ^= 1;
			} else if ((dutypct += (stepdir ? 10 : 20)) > 100)
				dutypct = 100;
			pwm_onpulse[idx] = (((stepdir ? (100 - dutypct) : dutypct) * pwm_period) / 100);
		}
		if (stepdir == 0 && dutypct == 0 && blink_en)
			idx = ((idx + 1) % countof(leds));
		_thread_sleep(steplen);
	}
}

#ifdef SHOW_CLOCK
// Clears the current line using Carriage-Return + Erase-in-Line:
#define CrEl "\r\033[K"

void print_days_hhmmss (uintptr_t totalSecs) {
	uintptr_t days  = totalSecs / 86400;          // 86400 seconds in a day.
	uintptr_t hours = (totalSecs % 86400) / 3600; // 3600 seconds in an hour.
	uintptr_t mins  = (totalSecs % 3600) / 60;    // 60 seconds in a minute.
	uintptr_t secs  = totalSecs % 60;
	printf(CrEl"⌚ %ud %uh %um %us", days, hours, mins, secs);
	fflush(stdout);
}
#else
#define CrEl ""
#endif

// Declared `volatile` to prevent them getting optimized out.
volatile _thread_t *main_thrd;
volatile _thread_t *blink_thrd;

void main () {

	main_thrd = _thread_cur;

	printf("🚀 main() thread started\n");

	// LEDs initially off.
	for (int i = 0; i < countof(leds); ++i)
		*leds[i] = 0;

	pwm_period = _MSECS(1);
	static _timer_t pwm_timer;
	_timer_init(&pwm_timer, pwm);
	_timer_arm(&pwm_timer, 0);
	printf("⏰ pwm() timer started\n");

	// Create and schedule blink() thread.
	blink_thrd = _thread_create(0, 2048, blink, 0);
	_thread_sched(blink_thrd);

	uintptr_t btn_poll_period = _MSECS(1);

	uintptr_t btnval = 1, btnval_old = 1;

#ifdef SHOW_CLOCK
	uintptr_t oneSec = _SECS(1);
	_date_t curDate, nxtDate = 0;
#endif

	while (1) {
		if (btnval != btnval_old) {
			if (btnval) {
				if (blink_en ^= 1)
					printf(CrEl"💡 blinking ...\n");
				else
					printf(CrEl"❌ stopping ...\n");
			}
			btnval_old = btnval;
		}
#ifdef SHOW_CLOCK
		curDate = _clkcycles();
		if (curDate >= nxtDate) {
			nxtDate = (curDate + oneSec);
			print_days_hhmmss(curDate/oneSec);
		}
#endif
		_thread_sleep(btn_poll_period);
		// Read button state once every polling period.
		btnval = *btns[0];
	}
}
