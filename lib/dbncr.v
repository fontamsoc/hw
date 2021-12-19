// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef LIBDBNCR
`define LIBDBNCR

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

`endif
