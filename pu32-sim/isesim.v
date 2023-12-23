// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`timescale 1ps / 1ps

`include "./sim.v"

module isesim;

reg rst_w; // ### comb-block-reg.
reg clk_w; // ### comb-block-reg.

sim sim (
	 .rst_i (rst_w)
	,.clk_i (clk_w)
);

always begin
	#1 clk_w = ~clk_w;
end

initial begin
	#0 rst_w = 1; clk_w = 0;
	#7 rst_w = 0;
end

initial begin
	#8 $stop;
end

endmodule
