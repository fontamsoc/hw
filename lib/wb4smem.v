// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// WishBone4 static memory peripheral.

// Parameters.
//
// SIZE:
// 	Size in (ARCHBITSZ/8) bytes.
// 	It must be at least 2 and a power of 2.
//
// DELAY:
// 	Number of clock cycles that it takes for a memory operation
// 	to complete; hence implementing a delay when accessing memory,
// 	which is useful for testing devices issuing memory accesses.
//
// SRCFILE:
// 	File from which memory will be initialized using $readmemh().

// Ports.
//
// input clk_i
// 	Clock signal.
//
// input rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module reset.
// 	It must be held low for normal operation.
//

// input wb4_cyc_i;
// input wb4_stb_i;
// input wb4_we_i;
// input [ARCHBITSZ-1:0] wb4_addr_i;
// input [ARCHBITSZ-1:0] wb4_data_i;
// input [(ARCHBITSZ/8)-1:0] wb4_sel_i;
// output wb4_stall_o;
// output wb4_ack_o;
// output [ARCHBITSZ-1:0] wb4_data_o;
// 	WishBone4 slave memory interface.

module wb4smem (

	clk_i,

	rst_i,

	wb4_cyc_i,
	wb4_stb_i,
	wb4_we_i,
	wb4_addr_i,
	wb4_data_i,
	wb4_sel_i,
	wb4_stall_o,
	wb4_ack_o,
	wb4_data_o
);

`include "lib/clog2.v"

parameter SIZE = 0;
parameter DELAY = 0;
parameter SRCFILE = "";

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire clk_i;

input wire rst_i;

input  wire                        wb4_cyc_i;
input  wire                        wb4_stb_i;
input  wire                        wb4_we_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_addr_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_data_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_i;
output wire                        wb4_stall_o;
output reg                         wb4_ack_o = 0;
output reg  [ARCHBITSZ -1 : 0]     wb4_data_o;

localparam CNTRBITSZ = clog2(DELAY);

// Register which when non-null set the output "wb4_stall_o"
// high, implementing a delay when accessing memory, which
// is useful for testing devices issuing memory accesses.
reg [CNTRBITSZ -1 : 0] cntr = 0;

assign wb4_stall_o = |cntr;

reg [ARCHBITSZ -1 : 0] u [SIZE -1 : 0];

initial begin
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", SRCFILE);
		`endif
		// Initial state initialized here, otherwise
		// block ram fails to be inferred by yosys.
		wb4_data_o = 0;
	end
end

wire [ARCHBITSZ -1 : 0] sel_w;
generate if (ARCHBITSZ == 16) begin
	assign sel_w = {{8{wb4_sel_i[1]}}, {8{wb4_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 32) begin
	assign sel_w = {{8{wb4_sel_i[3]}}, {8{wb4_sel_i[2]}}, {8{wb4_sel_i[1]}}, {8{wb4_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 64) begin
	assign sel_w = {
		{8{wb4_sel_i[7]}}, {8{wb4_sel_i[6]}}, {8{wb4_sel_i[5]}}, {8{wb4_sel_i[4]}},
		{8{wb4_sel_i[3]}}, {8{wb4_sel_i[2]}}, {8{wb4_sel_i[1]}}, {8{wb4_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 128) begin
	assign sel_w = {
		{8{wb4_sel_i[15]}}, {8{wb4_sel_i[14]}}, {8{wb4_sel_i[13]}}, {8{wb4_sel_i[12]}},
		{8{wb4_sel_i[11]}}, {8{wb4_sel_i[10]}}, {8{wb4_sel_i[9]}}, {8{wb4_sel_i[8]}},
		{8{wb4_sel_i[7]}}, {8{wb4_sel_i[6]}}, {8{wb4_sel_i[5]}}, {8{wb4_sel_i[4]}},
		{8{wb4_sel_i[3]}}, {8{wb4_sel_i[2]}}, {8{wb4_sel_i[1]}}, {8{wb4_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 256) begin
	assign sel_w = {
		{8{wb4_sel_i[31]}}, {8{wb4_sel_i[30]}}, {8{wb4_sel_i[29]}}, {8{wb4_sel_i[28]}},
		{8{wb4_sel_i[27]}}, {8{wb4_sel_i[26]}}, {8{wb4_sel_i[25]}}, {8{wb4_sel_i[24]}},
		{8{wb4_sel_i[23]}}, {8{wb4_sel_i[22]}}, {8{wb4_sel_i[21]}}, {8{wb4_sel_i[20]}},
		{8{wb4_sel_i[19]}}, {8{wb4_sel_i[18]}}, {8{wb4_sel_i[17]}}, {8{wb4_sel_i[16]}},
		{8{wb4_sel_i[15]}}, {8{wb4_sel_i[14]}}, {8{wb4_sel_i[13]}}, {8{wb4_sel_i[12]}},
		{8{wb4_sel_i[11]}}, {8{wb4_sel_i[10]}}, {8{wb4_sel_i[9]}}, {8{wb4_sel_i[8]}},
		{8{wb4_sel_i[7]}}, {8{wb4_sel_i[6]}}, {8{wb4_sel_i[5]}}, {8{wb4_sel_i[4]}},
		{8{wb4_sel_i[3]}}, {8{wb4_sel_i[2]}}, {8{wb4_sel_i[1]}}, {8{wb4_sel_i[0]}}};
end endgenerate

wire [ADDRBITSZ -1 : 0] addr_w = wb4_addr_i[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];

wire [ARCHBITSZ -1 : 0] ram_w0 = u[addr_w];
wire [ARCHBITSZ -1 : 0] ram_w1 = ((wb4_data_i & sel_w) | (ram_w0 & ~sel_w));

always @ (posedge clk_i) begin

	if (wb4_cyc_i && wb4_stb_i) begin
		if (wb4_we_i)
			u[addr_w] <= ram_w1;
		else
			wb4_data_o <= ram_w0;
	end

	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= cntr - 1'b1;
	else if (wb4_cyc_i && wb4_stb_i)
		cntr <= DELAY;

	if (DELAY) begin
		if (cntr == 1)
			wb4_ack_o <= 1;
		else
			wb4_ack_o <= 0;
	end else if (wb4_cyc_i && wb4_stb_i)
		wb4_ack_o <= 1;
	else
		wb4_ack_o <= 0;
end

endmodule
