// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef FIFO_V
`define FIFO_V

// Module implementing a fifo.
// A fifo is useful, not only for buffering data, but also
// to safely move data between two modules that use different
// clocks, in order words to move data between two clock domains.

// Parameters:
//
// WIDTH
// 	Number of bits used by each data in the fifo.
// 	It must be non-null.
//
// DEPTH
// 	Max number of data that the fifo can contain.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	When high on "clk_write_i" posedge, the fifo reset
// 	itself empty; it must be low to write data in the fifo.
//
// usage_o
// 	Count of data in the fifo.
//  Because the fifo has two clock domains driven by
//  "clk_write_i" and "clk_read_i", to prevent hazards
//  when sampling "usage_o", both clocks should transition
//  at the same time; also, both clocks should have
//  the same speed, or one clock should have a speed that
//  is the speed of the other clock times a power of 2.
//  If the frequency speed ratio described above between
//  the two clocks cannot be guaranteed, before attempting
//  to read data from the fifo, "usage_o" should be debounced
//  for at least two stable samples using the clock "clk_read_i",
//  and its value checked to insure that the fifo is not empty;
//  and before attempting to write data to the fifo, "usage_o"
//  should be debounced for at least two stable samples using
//  the clock "clk_write_i", and its value checked to insure
//  that the fifo is not full. The debouncing removes noise
//  from hazards that could occur due to both clocks having
//  their posedge too narrow for the combinational logic
//  computing "usage_o" to settle.
//
// Ports for writing data in the fifo:
//
// clk_write_i
// 	Clock used for writing data in the fifo.
//
// write_i
// 	When high on "clk_write_i" posedge, "data_i" gets written in the fifo,
// 	which must not be full.
//
// data_i
// 	Data written in the fifo on "clk_write_i" posedge,
// 	if "write_i" is high.
//
// near_full_o
// 	High when the fifo is full or one write away to full.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".
//
// full_o
// 	High when the fifo is full.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".
//
// Ports for reading data from the fifo:
//
// clk_read_i
// 	Clock used for reading data from the fifo.
//
// read_i
// 	When high on "clk_read_i" posedge, next data from the fifo gets set
// 	on "data_o"; the fifo must not be empty.
//
// data_o
// 	Data from the fifo; its value is updated
// 	on "clk_read_i" posedge, if "read_i" is high.
//
// near_empty_o
// 	High when the fifo is empty or one read away to empty.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".
//
// empty_o
// 	High when the fifo is empty.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".

`include "lib/ram/bram.v"

module fifo (

	 rst_i

	,usage_o

	,clk_read_i
	,read_i
	,data_o
	,near_empty_o
	,empty_o

	,clk_write_i
	,write_i
	,data_i
	,near_full_o
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
output wire                near_empty_o;
output wire                empty_o;

input  wire                clk_write_i;
input  wire                write_i;
input  wire [WIDTH -1 : 0] data_i;
output wire                near_full_o;
output wire                full_o;

wire en = (read_i && !empty_o);
wire we = (write_i && !full_o);

// Read and write index within the bram.
// Only the CLOG2DEPTH lsb are used for indexing.
reg [(CLOG2DEPTH +1) -1 : 0] readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] writeidx = 0;

wire [(CLOG2DEPTH +1) -1 : 0] next_readidx = (readidx + 1'b1);
wire [(CLOG2DEPTH +1) -1 : 0] next_writeidx = (writeidx + 1'b1);

wire [(CLOG2DEPTH +1) -1 : 0] gray_next_readidx = (next_readidx ^ (next_readidx >> 1));
wire [(CLOG2DEPTH +1) -1 : 0] gray_next_writeidx = (next_writeidx ^ (next_writeidx >> 1));

reg [(CLOG2DEPTH +1) -1 : 0] gray_readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] gray_writeidx = 0;

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

wire near_full_o_;
generate
if (CLOG2DEPTH < 2) begin
assign near_full_o_ = (gray_next_writeidx[CLOG2DEPTH:CLOG2DEPTH-1] == ~gray_readidx[CLOG2DEPTH:CLOG2DEPTH-1]);
end else begin
assign near_full_o_ = (gray_next_writeidx[CLOG2DEPTH:CLOG2DEPTH-1] == ~gray_readidx[CLOG2DEPTH:CLOG2DEPTH-1]) &&
	(gray_next_writeidx[CLOG2DEPTH-2:0] == gray_readidx[CLOG2DEPTH-2:0]);
end
endgenerate

generate
if (CLOG2DEPTH < 2) begin
assign full_o = (gray_writeidx[CLOG2DEPTH:CLOG2DEPTH-1] == ~gray_readidx[CLOG2DEPTH:CLOG2DEPTH-1]);
end else begin
assign full_o = (gray_writeidx[CLOG2DEPTH:CLOG2DEPTH-1] == ~gray_readidx[CLOG2DEPTH:CLOG2DEPTH-1]) &&
	(gray_writeidx[CLOG2DEPTH-2:0] == gray_readidx[CLOG2DEPTH-2:0]);
end
endgenerate

assign near_full_o = (near_full_o_ || full_o);

assign near_empty_o = (gray_writeidx == gray_next_readidx);

assign empty_o = (gray_writeidx == gray_readidx);

always @ (posedge clk_read_i) begin
	if (rst_i) begin
		readidx <= writeidx;
		gray_readidx <= gray_writeidx;
	end else if (en) begin
		readidx <= next_readidx;
		gray_readidx <= gray_next_readidx;
	end
end

always @ (posedge clk_write_i) begin
	if (!rst_i && we) begin
		writeidx <= next_writeidx;
		gray_writeidx <= gray_next_writeidx;
	end
end

endmodule

`endif /* FIFO_V */
