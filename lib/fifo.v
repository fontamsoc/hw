// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef FIFO_V
`define FIFO_V

`include "lib/ram/bram.v"

module fifo (

	 rst_i

	,usage_o

	,clk_read_i
	,read_i
	,data_o
	,empty_o

	,clk_write_i
	,write_i
	,data_i
	,full_o
);

`include "lib/clog2.v"

parameter WIDTH = 1;
parameter DEPTH = 2;

localparam CLOG2DEPTH = clog2(DEPTH);

input wire rst_i;

output wire [(CLOG2DEPTH +1) -1 : 0] usage_o;

input  wire                clk_read_i;
input  wire                read_i;
output wire [WIDTH -1 : 0] data_o;
output wire                empty_o;

input  wire                clk_write_i;
input  wire                write_i;
input  wire [WIDTH -1 : 0] data_i;
output wire                full_o;

wire en = (read_i && !empty_o);
wire we = (write_i && !full_o);

reg [(CLOG2DEPTH +1) -1 : 0] readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] writeidx = 0;

bram #(

	 .SZ (DEPTH)
	,.DW (WIDTH)

) fifobuf (

	 .clk0_i  (clk_read_i)                  ,.clk1_i  (clk_write_i)
	,.en0_i   (en)                          ,.en1_i   (1'b1)
	                                        ,.we1_i   (we)
	,.addr0_i (readidx[CLOG2DEPTH -1 : 0])  ,.addr1_i (writeidx[CLOG2DEPTH -1 : 0])
	                                        ,.i1      (data_i)
	,.o0      (data_o)                      ,.o1      ()
);

assign usage_o = (writeidx - readidx);

assign full_o = (usage_o >= DEPTH);

assign empty_o = (usage_o == 0);

always @ (posedge clk_read_i) begin
	if (rst_i)
		readidx <= writeidx;
	else if (en)
		readidx <= readidx + 1'b1;
end

always @ (posedge clk_write_i) begin
	if (we)
		writeidx <= writeidx + 1'b1;
end

endmodule

`endif
