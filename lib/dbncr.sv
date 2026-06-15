// SPDX-License-Identifier: GPL-2.0-only
// 20250417 (c) William Fonkou Tambe

`ifndef LIBDBNCR
`define LIBDBNCR

// Counter Based Debouncer.

// Parameters.
//
// THRESBITSZ:
// 	Number of bits used by the input "thresh_i".
// 	It must be non-null.

// Ports.
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
// 	Number of clockcycles for which the input "i" must be stable.
// 	When null, this module acts as a delay of one clock cycle.

module dbncr (

	 clk_i

	,i
	,o

	,thresh_i
);

parameter THRESBITSZ = 0;

input wire clk_i;

input wire i;
output reg o;

input wire [THRESBITSZ -1 : 0] thresh_i;

reg [THRESBITSZ -1 : 0] cntr;

always_ff @(posedge clk_i) begin
	if (i != o) begin
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
