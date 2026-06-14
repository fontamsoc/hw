// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include <termios.h>

#include "Vsim.h"
#include "Vsim_sim.h"

#define USE_TRACE
#if defined(USE_TRACE)
#include "verilated_fst_c.h"
#if !defined(TRACE_BEGIN)
/* makefile defined *///#define TRACE_BEGIN (4000000*0)
#endif
#if !defined(TRACE_LEN)
#define TRACE_LEN 4000000
#endif
//#define TRACE_DUMP_THRESH0 (/*0x763fa*/0xffffffff) /* tb->sim->pc_w[0] value which sets traceDumpBegin non-null */
#endif

int main (int argc, char **argv) {
	// Initialize Verilators variables
	Verilated::commandArgs (argc, argv);

	// Create an instance of our module under test
	Vsim *tb = new Vsim;

	#if defined(USE_TRACE)
	Verilated::traceEverOn(true);
	VerilatedFstC* traceObj = new VerilatedFstC;
	tb->trace(traceObj, 99); // Trace 99 levels of hierarchy
	traceObj->open("sim.fst");

	uintptr_t tickCnt = 0;
	uintptr_t traceDumpBegin = 0;

	#if defined(TRACE_DUMP_THRESH0)
	uintptr_t sim_pc_w_0_saved;
	uintptr_t sim_pc_w_0_prev = 0;
	uintptr_t thresh0FoundCnt = 0;
	#endif
	#endif

	auto exitsim = [&]() -> void {
		#if defined(USE_TRACE)
		traceObj->close();
		#endif
		exit(0);
	};

	auto tickclk = [&]() -> void {
		#if defined(TRACE_DUMP_THRESH0) && defined(USE_TRACE)
		sim_pc_w_0_saved = tb->sim->pc_w[0];
		#endif
		tb->clk_i = 0;
		tb->eval();
		#if defined(USE_TRACE)
		if (traceDumpBegin)
			traceObj->dump(tickCnt);
		++tickCnt;
		#endif
		tb->clk_i = 1;
		tb->eval();
		#if defined(USE_TRACE)
		if (traceDumpBegin)
			traceObj->dump(tickCnt);
		++tickCnt;
		#endif
		#if defined(USE_TRACE)
		#if defined(TRACE_BEGIN)
		if (!traceDumpBegin && tickCnt >= (TRACE_BEGIN)) {
			fprintf (stderr, "traceDumpBegin(%lu)\n", tickCnt); fflush(stderr);
			traceDumpBegin = tickCnt;
		}
		#endif
		if (!traceDumpBegin) {
			#if defined(TRACE_DUMP_THRESH0)
			bool pc0Changed = (sim_pc_w_0_saved != sim_pc_w_0_prev);
			if (pc0Changed && sim_pc_w_0_saved == TRACE_DUMP_THRESH0 && thresh0FoundCnt++ == 0) {
				fprintf (stderr, "sim_pc_w_0_saved(0x%lx); tickCnt(%lu)\n",
					sim_pc_w_0_saved, tickCnt); fflush(stderr);
				traceDumpBegin = tickCnt;
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
	// Hold reset for at least 2 cycles: with wb_mux ADDRSPACE_SEQINIT,
	// addrspace[] is loaded on the first reset cycle and its consumers
	// (addrspace_slvidx_lo/hi) only read valid values on the next cycle.
	auto rstcycle = [&]() -> void {
		tb->rst_i = 1;
		tickclk();
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
		#if defined(USE_TRACE)
		&& (!traceDumpBegin ||
			/* remaining tickCnt to run after traceDumpBegin is set non-null */
			(tickCnt < (traceDumpBegin + TRACE_LEN)))
		#endif
		) tickclk();

	#if defined(USE_TRACE)
	fprintf (stderr, "tickCnt(%lu)\n", tickCnt); fflush(stderr);
	#endif

	tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved_termios);

	exit: exitsim();
}
