// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef LIBDBNCR
`define LIBDBNCR

// Debouncer implementing a lowpass filter.
// A lowpass filter does not let through signal
// that changes too fast beyond a thresh_i.

// Parameters.
//
// THRESBITSZ:
// 	Number of bits used by the input "thresh_i".
// 	It must be non-null.
//
// INIT:
// 	PowerOn initial state of the output "o".

// Ports.
//
// input rst_i
// 	Reset signal which set the output "o" to the input "i".
//
// input clk_i
// 	Clock signal used to sample the input "i".
// 	Its frequency must be greater than or equal to the highest frequency
// 	of changes in the input "i", otherwise states (high or low) from the signal
// 	will be missed due to the fact that they are too short in duration to be
// 	seen when sampling; worst, that higher frequency of change becomes noise,
// 	because it is not being properly detected and it is taking space in the signal;
// 	in fact, that higher frequency of changes will get randomly sampled, and if
// 	those samples hold the same state for a clock cycle count given by the input
// 	"thresh_i", the output "o" will reflect that state, which is noise.
// 	Note that the frequency of a clock signal is always half its frequency of change,
// 	because a single clock cycle is two state changes of the clock; hence the frequency
// 	of changes of the clock must be at least twice the highest frequency of changes
// 	in the input "i".
//
// input i
// 	Input signal.
//
// output o
// 	Output signal.
// 	It is set to the input "i" only after that input has been
// 	stable for a clock cycle count given by the input "thresh_i",
//	otherwise it keeps its value.
//
// input[THRESBITSZ] thresh_i
// 	Number of clockcycles for which the input "i" must be stable;
// 	it is essentially the lowpass cutoff frequency when multiplied
// 	by twice the input "clk_i" period and then inverted (ie: 1/x).
// 	When null, this module acts as a delay of one clock cycle.

module dbncr (

	 rst_i

	,clk_i

	,i
	,o

	,thresh_i
);

parameter THRESBITSZ = 0;
parameter INIT       = 1'b0;

input wire rst_i;

input wire clk_i;

input  wire i;
output reg  o = INIT;

input wire [THRESBITSZ -1 : 0] thresh_i;

// Register used to keep track of how many clockcycles the input "i" has been stable.
reg [THRESBITSZ -1 : 0] cntr = 0;

wire d = (i != o);

always @ (posedge clk_i) begin
	if (rst_i) begin
		o <= i;
		cntr <= 0;
	end else if (d) begin
		if (cntr >= thresh_i) begin
			o <= i;
			cntr <= 0;
		end else
			cntr <= cntr + 1'b1;
	end else
		cntr <= 0;
end

endmodule

`endif /* LIBDBNCR */
