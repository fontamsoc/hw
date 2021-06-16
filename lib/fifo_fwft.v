// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef FIFO_FWFT_V
`define FIFO_FWFT_V

`include "lib/ram/ram2clk1i2o.v"

module fifo_fwft (

	 rst_i

	,usage_o

	,clk_pop_i
	,pop_i
	,data_o
	,empty_o

	,clk_push_i
	,push_i
	,data_i
	,full_o
);

`include "lib/clog2.v"

parameter WIDTH = 1;
parameter DEPTH = 2;

localparam CLOG2DEPTH = clog2(DEPTH);

input wire rst_i;

output wire [(CLOG2DEPTH +1) -1 : 0] usage_o;

`ifdef USE2CLK
input  wire [2 -1 : 0]     clk_pop_i;
`else
input  wire [1 -1 : 0]     clk_pop_i;
`endif
input  wire                pop_i;
output wire [WIDTH -1 : 0] data_o;
output wire                empty_o;

`ifdef USE2CLK
input  wire [2 -1 : 0]     clk_push_i;
`else
input  wire [1 -1 : 0]     clk_push_i;
`endif
input  wire                push_i;
input  wire [WIDTH -1 : 0] data_i;
output wire                full_o;

reg [(CLOG2DEPTH +1) -1 : 0] readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] writeidx = 0;

ram2clk1i2o #(

	 .SZ (DEPTH)
	,.DW (WIDTH)

) fifobuf (

	  .rst_i (rst_i)

	,.clk0_i  (clk_pop_i)                  ,.clk1_i  (clk_push_i)
	                                       ,.we1_i   (push_i)
	,.addr0_i (readidx[CLOG2DEPTH -1 : 0]) ,.addr1_i (writeidx[CLOG2DEPTH -1 : 0])
	                                       ,.i1      (data_i)
	,.o0      (data_o)                     ,.o1      ()
);

assign usage_o = (writeidx - readidx);

assign full_o = (usage_o >= DEPTH);

assign empty_o = (usage_o == 0);

always @ (posedge clk_pop_i[0]) begin
	if (rst_i)
		readidx <= writeidx;
	else if (pop_i)
		readidx <= readidx + 1'b1;
end

always @ (posedge clk_push_i[0]) begin
	if (push_i)
		writeidx <= writeidx + 1'b1;
end

endmodule

`endif
