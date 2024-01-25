// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Static memory peripheral.

// Parameters:
//
// SIZE
// 	Size in (ARCHBITSZ/8) bytes.
// 	It must be at least 2 and a power of 2.
//
// DELAY
// 	Number of clock cycles that it takes for a memory operation
// 	to complete; hence implementing a delay when accessing memory,
// 	which is useful for testing devices issuing memory accesses.
//
// SRCFILE
// 	File from which memory will be initialized using $readmemh().

// Ports:
//
// rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module reset.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// wb_cyc_i
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.
//
// mmapsz_o
// 	Memory map size in bytes.

module sram (

	 rst_i

	,clk_i

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,mmapsz_o
);

`include "lib/clog2.v"

parameter SIZE = 0;
parameter DELAY = 0;
parameter SRCFILE = "";

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output reg  [ARCHBITSZ -1 : 0]     wb_dat_o;

output wire [ARCHBITSZ -1 : 0] mmapsz_o;

localparam CLOG2DELAY = clog2(DELAY);

// Register which when non-null set the output "wb_bsy_o"
// high, implementing a delay when accessing memory, which
// is useful for testing devices issuing memory accesses.
reg [CLOG2DELAY -1 : 0] cntr = 0;

assign wb_bsy_o = |cntr;

assign mmapsz_o = (SIZE*(ARCHBITSZ/8));

reg [ARCHBITSZ -1 : 0] ram [SIZE -1 : 0];

initial begin
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, ram);
		`ifdef SIMULATION
		$display ("%s loaded", SRCFILE);
		`endif
		// Initial state initialized here, otherwise
		// block ram fails to be inferred by yosys.
		wb_dat_o = 0;
	end
end

wire [ARCHBITSZ -1 : 0] _wb_sel_i;
wire [ARCHBITSZ -1 : 0] ram_w0 = ram[wb_addr_i];
wire [ARCHBITSZ -1 : 0] ram_w1 = ((wb_dat_i & _wb_sel_i) | (ram_w0 & ~_wb_sel_i));

wire _wb_stb_i = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin

	if (_wb_stb_i) begin
		if (wb_we_i)
			ram[wb_addr_i] <= ram_w1;
		else
			wb_dat_o <= ram_w0;
	end

	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= (cntr - 1'b1);
	else if (_wb_stb_i)
		cntr <= DELAY;

	if (rst_i)
		wb_ack_o <= 0;
	else if (DELAY)
		wb_ack_o <= (cntr == 1);
	else
		wb_ack_o <= _wb_stb_i;
end

generate if (ARCHBITSZ == 16) begin
	assign _wb_sel_i = {{8{wb_sel_i[1]}}, {8{wb_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 32) begin
	assign _wb_sel_i = {{8{wb_sel_i[3]}}, {8{wb_sel_i[2]}}, {8{wb_sel_i[1]}}, {8{wb_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 64) begin
	assign _wb_sel_i = {
		{8{wb_sel_i[7]}}, {8{wb_sel_i[6]}}, {8{wb_sel_i[5]}}, {8{wb_sel_i[4]}},
		{8{wb_sel_i[3]}}, {8{wb_sel_i[2]}}, {8{wb_sel_i[1]}}, {8{wb_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 128) begin
	assign _wb_sel_i = {
		{8{wb_sel_i[15]}}, {8{wb_sel_i[14]}}, {8{wb_sel_i[13]}}, {8{wb_sel_i[12]}},
		{8{wb_sel_i[11]}}, {8{wb_sel_i[10]}}, {8{wb_sel_i[9]}}, {8{wb_sel_i[8]}},
		{8{wb_sel_i[7]}}, {8{wb_sel_i[6]}}, {8{wb_sel_i[5]}}, {8{wb_sel_i[4]}},
		{8{wb_sel_i[3]}}, {8{wb_sel_i[2]}}, {8{wb_sel_i[1]}}, {8{wb_sel_i[0]}}};
end endgenerate
generate if (ARCHBITSZ == 256) begin
	assign _wb_sel_i = {
		{8{wb_sel_i[31]}}, {8{wb_sel_i[30]}}, {8{wb_sel_i[29]}}, {8{wb_sel_i[28]}},
		{8{wb_sel_i[27]}}, {8{wb_sel_i[26]}}, {8{wb_sel_i[25]}}, {8{wb_sel_i[24]}},
		{8{wb_sel_i[23]}}, {8{wb_sel_i[22]}}, {8{wb_sel_i[21]}}, {8{wb_sel_i[20]}},
		{8{wb_sel_i[19]}}, {8{wb_sel_i[18]}}, {8{wb_sel_i[17]}}, {8{wb_sel_i[16]}},
		{8{wb_sel_i[15]}}, {8{wb_sel_i[14]}}, {8{wb_sel_i[13]}}, {8{wb_sel_i[12]}},
		{8{wb_sel_i[11]}}, {8{wb_sel_i[10]}}, {8{wb_sel_i[9]}}, {8{wb_sel_i[8]}},
		{8{wb_sel_i[7]}}, {8{wb_sel_i[6]}}, {8{wb_sel_i[5]}}, {8{wb_sel_i[4]}},
		{8{wb_sel_i[3]}}, {8{wb_sel_i[2]}}, {8{wb_sel_i[1]}}, {8{wb_sel_i[0]}}};
end endgenerate

endmodule
