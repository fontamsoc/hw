// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include "Vsim.h"
#include "Vsim_sim.h"

int main (int argc, char **argv) {
	// Initialize Verilators variables
	Verilated::commandArgs (argc, argv);

	// Create an instance of our module under test
	Vsim *tb = new Vsim;

	auto exitsim = [&]() -> void {
		exit(EXIT_SUCCESS);
	};

	auto tickclk = [&]() -> void {
		tb->clk_i = 0;
		tb->eval();
		tb->clk_i = 1;
		tb->eval();
	};

	// Reset module sim.
	auto rstcycle = [&]() -> void {
		tb->rst_i = 1;
		tickclk();
		tb->rst_i = 0;
	};

	rstcycle();

	// Tick the clock until we are done
	while (!Verilated::gotFinish())
		tickclk();

	exitsim();
}
