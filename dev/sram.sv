// SPDX-License-Identifier: GPL-2.0-only
// 20260420 (c) William Fonkou Tambe

// Static memory peripheral.

// Parameters:
//
// SIZE
// 	Size in (WORDBITSZ/8) bytes.
// 	It must be at least 2 and a power of 2.
//
// DELAY
// 	Number of clock cycles that it takes for a memory operation
// 	to complete; hence implementing a delay when accessing memory,
// 	which is useful for testing devices issuing memory accesses.
//
// INITFILE
// 	File from which memory will be initialized using $readmemh().

// Ports:
//
// rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module resets.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.

module sram (

	 rst_i

	,clk_i

	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter SIZE = 0;
parameter DELAY = 0;
parameter INITFILE = "";

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (SIZE*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            wb_dat_o;

localparam CLOG2DELAY = clog2(DELAY);

reg hold;

// Register which when non-null set the output "wb_bsy_o"
// high, implementing a delay when accessing memory, which
// is useful for testing devices issuing memory accesses.
reg [(CLOG2DELAY +1) -1 : 0] cntr;

assign wb_bsy_o = (hold || (|cntr));

reg [WORDBITSZ -1 : 0] ram [SIZE];

initial begin
	if (INITFILE != "") begin
		$readmemh (INITFILE, ram);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

reg                               wb_stb_r;
reg                               wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        wb_sel_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;

wire wb_stb_r_ = (wb_stb_i && !wb_bsy_o);
always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
end

always_ff @(posedge clk_i)
	hold <= (wb_stb_r_ && wb_addr_i == wb_addr_r && wb_we_r);

always_ff @(posedge clk_i) begin
	if (hold);
	else if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_sel_r <= wb_sel_i;
		wb_dat_r <= wb_dat_i;
	end else
		wb_we_r <= 1'b0;
end

wire [WORDBITSZ -1 : 0] _wb_sel_r;

always_ff @(posedge clk_i) begin
	if (wb_stb_r_ || hold)
		wb_dat_o <= ram[hold ? wb_addr_r : wb_addr_i];
	if (wb_stb_r && wb_we_r && !hold)
		ram[wb_addr_r] <= ((wb_dat_r & _wb_sel_r) | (wb_dat_o & ~_wb_sel_r));
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= (cntr - 1'b1);
	else if (wb_stb_r_)
		cntr <= DELAY;
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_ack_o <= 0;
	else if (DELAY)
		wb_ack_o <= (cntr == 1);
	else
		wb_ack_o <= wb_stb_r_;
end

generate if (WORDBITSZ == 16) begin
	assign _wb_sel_r = {{8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 32) begin
	assign _wb_sel_r = {{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 64) begin
	assign _wb_sel_r = {
		{8{wb_sel_r[7]}}, {8{wb_sel_r[6]}}, {8{wb_sel_r[5]}}, {8{wb_sel_r[4]}},
		{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 128) begin
	assign _wb_sel_r = {
		{8{wb_sel_r[15]}}, {8{wb_sel_r[14]}}, {8{wb_sel_r[13]}}, {8{wb_sel_r[12]}},
		{8{wb_sel_r[11]}}, {8{wb_sel_r[10]}}, {8{wb_sel_r[9]}}, {8{wb_sel_r[8]}},
		{8{wb_sel_r[7]}}, {8{wb_sel_r[6]}}, {8{wb_sel_r[5]}}, {8{wb_sel_r[4]}},
		{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 256) begin
	assign _wb_sel_r = {
		{8{wb_sel_r[31]}}, {8{wb_sel_r[30]}}, {8{wb_sel_r[29]}}, {8{wb_sel_r[28]}},
		{8{wb_sel_r[27]}}, {8{wb_sel_r[26]}}, {8{wb_sel_r[25]}}, {8{wb_sel_r[24]}},
		{8{wb_sel_r[23]}}, {8{wb_sel_r[22]}}, {8{wb_sel_r[21]}}, {8{wb_sel_r[20]}},
		{8{wb_sel_r[19]}}, {8{wb_sel_r[18]}}, {8{wb_sel_r[17]}}, {8{wb_sel_r[16]}},
		{8{wb_sel_r[15]}}, {8{wb_sel_r[14]}}, {8{wb_sel_r[13]}}, {8{wb_sel_r[12]}},
		{8{wb_sel_r[11]}}, {8{wb_sel_r[10]}}, {8{wb_sel_r[9]}}, {8{wb_sel_r[8]}},
		{8{wb_sel_r[7]}}, {8{wb_sel_r[6]}}, {8{wb_sel_r[5]}}, {8{wb_sel_r[4]}},
		{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};
end endgenerate

endmodule
