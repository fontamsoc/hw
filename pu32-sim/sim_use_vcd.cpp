// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include "Vsim.h"
#include "Vsim_sim.h"

#define USE_VCDTRACE
#if defined(USE_VCDTRACE)
#include "verilated_vcd_c.h"
#endif

#define VCDDUMPENTHRESH (0xffffffff) /* threshold which sets vcddumpen non-null */
#define SIMEXITTICKCNT (vcddumpen + 4000000) /* tickcnt for which to run after vcddumpen is set non-null */

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
	#endif

	#if defined(USE_VCDTRACE)
	unsigned long tickcnt = 0;
	unsigned long vcddumpen = 0;
	unsigned long sim_pc_w_0_saved;
	unsigned long sim_pc_w_0_prev = 0;
	unsigned long threshfoundcnt = 0;
	#endif

	auto exitsim = [&]() -> void {
		#if defined(USE_VCDTRACE)
		vcdtrace->close();
		#endif
		exit(EXIT_SUCCESS);
	};

	auto tickclk = [&]() -> void {
		#if defined(USE_VCDTRACE)
		sim_pc_w_0_saved = tb->sim->pc_w[0];
		#endif
		tb->clk_i = 0;
		tb->eval();
		#if defined(USE_VCDTRACE)
		if (vcddumpen)
			vcdtrace->dump(tickcnt);
		++tickcnt;
		#endif
		tb->clk_i = 1;
		tb->eval();
		#if defined(USE_VCDTRACE)
		if (vcddumpen)
			vcdtrace->dump(tickcnt);
		++tickcnt;
		#endif
		#if defined(USE_VCDTRACE)
		if (!vcddumpen) {
			unsigned long pc_changed = ((tb->sim->pc_w[0]) != (sim_pc_w_0_prev));
			if ((pc_changed && (tb->sim->pc_w[0]) == VCDDUMPENTHRESH && (threshfoundcnt++ == 0))
				/*|| tickcnt >= ((unsigned long)1898465178-((unsigned long)4000000*1))*/) {
				fprintf (stderr, "sim_pc_w_0_saved(0x%lx); tickcnt(%lu)\n",
					sim_pc_w_0_saved, tickcnt); fflush(stderr);
				vcddumpen = tickcnt;
			}
			//if (pc_changed && (tb->sim->pc_w[0]) >= 0x50000000) {
			//	fprintf (stderr, "0x%lx\n",  (tb->sim->pc_w[0])); fflush(stderr);
			//}
			sim_pc_w_0_prev = (tb->sim->pc_w[0]);
		}
		#endif
	};

	// Reset module sim.
	auto rstcycle = [&]() -> void {
		tb->rst_i = 1;
		tickclk();
		tb->rst_i = 0;
	};

	rstcycle();

	// Tick the clock until we are done
	while (!Verilated::gotFinish()
		#if defined(USE_VCDTRACE)
		&& (!vcddumpen || tickcnt < SIMEXITTICKCNT)
		#endif
		) tickclk();

	#if defined(USE_VCDTRACE)
	fprintf (stderr, "tickcnt == %ld\n", tickcnt); fflush(stderr);
	#endif

	exitsim();
}
