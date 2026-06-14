// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

#include <termios.h>

#include "Vsim.h"

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
	while (!Verilated::gotFinish())
		tickclk();

	tcsetattr(STDIN_FILENO, TCSAFLUSH, &saved_termios);

	exit: exitsim();
}
