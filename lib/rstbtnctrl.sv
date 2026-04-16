// SPDX-License-Identifier: GPL-2.0-only
// 20260416 (c) William Fonkou Tambe

`ifndef RSTBTNCTRL
`define RSTBTNCTRL

// Reset button controller.

`include "lib/dbncr.sv"

module rstbtnctrl (

	 clk_i

	,i ,o ,b
);

`include "lib/clog2.sv"

parameter RSTDURATION = 1;
parameter RSTTHRESH = 0;
parameter DBNCRTHRESH = 0;

localparam CLOG2RSTDURATION = clog2(RSTDURATION+1);
localparam CLOG2RSTTHRESH = clog2(RSTTHRESH+1);

input wire clk_i;

input wire i;
output reg o = 1'b1;
output wire b;

reg rsthold = 1'b1; // After power-on, hold in reset until button pressed.

reg [CLOG2RSTDURATION -1 : 0] rstduration = RSTDURATION;
always @ (posedge clk_i)
	o <= (|rstduration);

reg [CLOG2RSTTHRESH -1 : 0] rstthresh;

reg i_r;

wire i_n = !i;

always @ (posedge clk_i) begin
	if (i_n || i_r || (!rsthold && o)) begin
		rstthresh <= RSTTHRESH;
		if (!rsthold && rstduration)
			rstduration <= (rstduration - 1'b1);
		if (i_n)
			i_r <= 1'b0;
	end else if (rsthold || !rstthresh) begin
		rsthold <= 1'b0;
		rstduration <= RSTDURATION;
		i_r <= 1'b1;
	end else
		rstthresh <= (rstthresh - 1'b1);
end

generate if (DBNCRTHRESH) begin: gen_dbncr
dbncr #(
	 .THRESBITSZ (clog2(DBNCRTHRESH+1))
	,.INIT       (1'b0)
) dbncr (
	 .clk_i    (clk_i)
	,.i        (i)
	,.o        (b)
	,.thresh_i (DBNCRTHRESH)
);
end else begin
assign b = i;
end endgenerate

endmodule

`endif /* RSTBTNCTRL */
