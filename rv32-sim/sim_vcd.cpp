// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include <termios.h>

#include "Vsim.h"
#include "Vsim_sim.h"

#define USE_VCDTRACE
#if defined(USE_VCDTRACE)
#include "verilated_vcd_c.h"
#if !defined(VCDTRACE_BEGIN)
/* makefile defined *///#define VCDTRACE_BEGIN (4000000*0)
#endif
#if !defined(VCDTRACE_LEN)
#define VCDTRACE_LEN 4000000
#endif
//#define VCDDUMPTHRESH0 (/*0x763fa*/0xffffffff) /* tb->sim->pc_w[0] value which sets vcdDumpBegin non-null */
#endif

int main (int argc, char **argv) {
	// Initialize Verilators variables
	Verilated::commandArgs (argc, argv);

	// Create an instance of our module under test
	Vsim *tb = new Vsim;

	#if defined(USE_VCDTRACE)
	Verilated::traceEverOn(true);
	VerilatedVcdC* vcdtrace = new VerilatedVcdC;
	tb->trace(vcdtrace, 99); // Trace 99 levels of hierarchy
	vcdtrace->open("sim.vcd");

	uintptr_t tickCnt = 0;
	uintptr_t vcdDumpBegin = 0;

	#if defined(VCDDUMPTHRESH0)
	uintptr_t sim_pc_w_0_saved;
	uintptr_t sim_pc_w_0_prev = 0;
	uintptr_t thresh0FoundCnt = 0;
	#endif
	#endif

	auto exitsim = [&]() -> void {
		#if defined(USE_VCDTRACE)
		vcdtrace->close();
		#endif
		exit(0);
	};

	auto tickclk = [&]() -> void {
		#if defined(VCDDUMPTHRESH0) && defined(USE_VCDTRACE)
		sim_pc_w_0_saved = tb->sim->pc_w[0];
		#endif
		tb->clk_i = 0;
		tb->eval();
		#if defined(USE_VCDTRACE)
		if (vcdDumpBegin)
			vcdtrace->dump(tickCnt);
		++tickCnt;
		#endif
		tb->clk_i = 1;
		tb->eval();
		#if defined(USE_VCDTRACE)
		if (vcdDumpBegin)
			vcdtrace->dump(tickCnt);
		++tickCnt;
		#endif
		#if defined(USE_VCDTRACE)
		#if defined(VCDTRACE_BEGIN)
		if (!vcdDumpBegin && tickCnt >= (VCDTRACE_BEGIN)) {
			fprintf (stderr, "vcdDumpBegin(%lu)\n", tickCnt); fflush(stderr);
			vcdDumpBegin = tickCnt;
		}
		#endif
		if (!vcdDumpBegin) {
			#if defined(VCDDUMPTHRESH0)
			bool pc0Changed = (sim_pc_w_0_saved != sim_pc_w_0_prev);
			if (pc0Changed && sim_pc_w_0_saved == VCDDUMPTHRESH0 && thresh0FoundCnt++ == 0) {
				fprintf (stderr, "sim_pc_w_0_saved(0x%lx); tickCnt(%lu)\n",
					sim_pc_w_0_saved, tickCnt); fflush(stderr);
				vcdDumpBegin = tickCnt;
			}
			//if (pc0Changed && sim_pc_w_0_saved >= 0x50000000) {
			//	fprintf (stderr, "0x%lx\n",  (sim_pc_w_0_saved)); fflush(stderr);
			//}
			sim_pc_w_0_prev = sim_pc_w_0_saved;
			#endif
		}
		#endif
	};

	// Reset module sim.
	auto rstcycle = [&]() -> void {
		tb->rst_i = 1;
		tickclk();
		tb->rst_i = 0;
	};

	struct termios saved_termios;
	if (isatty(STDIN_FILENO)) {
		if (tcgetattr(STDIN_FILENO, &saved_termios) == -1) {
			fprintf (stderr, "tcgetattr() failed\n"); fflush(stderr);
			goto exit;
		}
	}

	rstcycle();

	// Tick the clock until we are done
	while (!Verilated::gotFinish()
		#if defined(USE_VCDTRACE)
		&& (!vcdDumpBegin ||
			/* remaining tickCnt to run after vcdDumpBegin is set non-null */
			(tickCnt < (vcdDumpBegin + VCDTRACE_LEN)))
		#endif
		) tickclk();

	#if defined(USE_VCDTRACE)
	fprintf (stderr, "tickCnt(%lu)\n", tickCnt); fflush(stderr);
	#endif

	tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved_termios);

	exit: exitsim();
}
