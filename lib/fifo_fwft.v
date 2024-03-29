// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef FIFO_FWFT_V
`define FIFO_FWFT_V

// Module implementing a first-word-fall-through fifo.
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
// 	When high on "clk_pop_i" posedge, the fifo reset
// 	itself empty; it must be low to push data in the fifo.
//
// usage_o
// 	Count of data in the fifo.
//  Because the fifo has two clock domains driven by
//  "clk_push_i" and "clk_pop_i", to prevent hazards
//  when sampling "usage_o", both clocks should transition
//  at the same time; also, both clocks should have
//  the same speed, or one clock should have a speed that
//  is the speed of the other clock times a power of 2.
//  If the frequency speed ratio described above between
//  the two clocks cannot be guaranteed, before attempting
//  to read data from the fifo, "usage_o" should be debounced
//  for at least two stable samples using the clock "clk_pop_i",
//  and its value checked to insure that the fifo is not empty;
//  and before attempting to write data to the fifo, "usage_o"
//  should be debounced for at least two stable samples using
//  the clock "clk_push_i", and its value checked to insure
//  that the fifo is not full. The debouncing removes noise
//  from hazards that could occur due to both clocks having
//  their posedge too narrow for the combinational logic
//  computing "usage_o" to settle.
//
// Ports for pushing data in the fifo:
//
// clk_push_i
// 	Clock used for pushing data in the fifo.
//
// push_i
// 	When high on "clk_push_i" posedge, "data_i" gets pushed in the fifo,
// 	which must not be full.
//
// data_i
// 	Data pushed in the fifo on "clk_push_i" posedge,
// 	if "push_i" is high.
//
// near_full_o
// 	High when the fifo is full or one write away to full.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".
//
// full_o
// 	High when the fifo is full.
//  Asynchronous-safe with respect to "clk_push_i" and "clk_pop_i".
//
// Ports for poping data from the fifo:
//
// clk_pop_i
// 	Clock used for poping data from the fifo.
//
// pop_i
// 	When high on "clk_pop_i" posedge, next data from the fifo gets set
// 	on "data_o"; the fifo must not be empty.
//
// data_o
// 	Data from the fifo; its value is updated
// 	on "clk_pop_i" posedge, if "pop_i" is high.
//
// near_empty_o
// 	High when the fifo is empty or one read away to empty.
//  Asynchronous-safe with respect to "clk_write_i" and "clk_read_i".
//
// empty_o
// 	High when the fifo is empty.
//  Asynchronous-safe with respect to "clk_push_i" and "clk_pop_i".

`include "lib/ram/ram1i2o.v"

module fifo_fwft (

	 rst_i

	,usage_o

	,clk_pop_i
	,pop_i
	,data_o
	,near_empty_o
	,empty_o

	,clk_push_i
	,push_i
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

input  wire                clk_pop_i;
input  wire                pop_i;
output wire [WIDTH -1 : 0] data_o;
output wire                near_empty_o;
output wire                empty_o;

input  wire                clk_push_i;
input  wire                push_i;
input  wire [WIDTH -1 : 0] data_i;
output wire                near_full_o;
output wire                full_o;

wire en = (pop_i && !empty_o);
wire we = (push_i && !full_o);

// Read and write index within ram1i2o.
// Only the CLOG2DEPTH lsb are used for indexing.
reg [(CLOG2DEPTH +1) -1 : 0] readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] writeidx = 0;

wire [(CLOG2DEPTH +1) -1 : 0] next_readidx = (readidx + 1'b1);
wire [(CLOG2DEPTH +1) -1 : 0] next_writeidx = (writeidx + 1'b1);

wire [(CLOG2DEPTH +1) -1 : 0] gray_next_readidx = (next_readidx ^ (next_readidx >> 1));
wire [(CLOG2DEPTH +1) -1 : 0] gray_next_writeidx = (next_writeidx ^ (next_writeidx >> 1));

reg [(CLOG2DEPTH +1) -1 : 0] gray_readidx = 0;
reg [(CLOG2DEPTH +1) -1 : 0] gray_writeidx = 0;

ram1i2o #(

	 .SZ (DEPTH)
	,.DW (WIDTH)

) fifobuf (

	  .rst_i (rst_i)

	,.clk0_i  (clk_pop_i)                  ,.clk1_i  (clk_push_i)
	                                       ,.we1_i   (we)
	,.addr0_i (readidx[CLOG2DEPTH -1 : 0]) ,.addr1_i (writeidx[CLOG2DEPTH -1 : 0])
	                                       ,.i1      (data_i)
	,.o0      (data_o)                     ,.o1      ()
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

always @ (posedge clk_pop_i) begin
	if (rst_i) begin
		readidx <= writeidx;
		gray_readidx <= gray_writeidx;
	end else if (en) begin
		readidx <= next_readidx;
		gray_readidx <= gray_next_readidx;
	end
end

always @ (posedge clk_push_i) begin
	if (!rst_i && we) begin
		writeidx <= next_writeidx;
		gray_writeidx <= gray_next_writeidx;
	end
end

endmodule

`endif /* FIFO_FWFT_V */
