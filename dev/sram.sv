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

parameter SIZE = 2;
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


// Register which when non-null set the output "wb_bsy_o"
// high, implementing a delay when accessing memory, which
// is useful for testing devices issuing memory accesses.
reg [(CLOG2DELAY +1) -1 : 0] cntr;

assign wb_bsy_o = (|cntr);

reg [WORDBITSZ -1 : 0] ram [SIZE];

initial begin
	if (INITFILE != "") begin
		$readmemh (INITFILE, ram);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

wire _wb_stb_i = (wb_stb_i && !wb_bsy_o);

always_ff @(posedge clk_i) begin
	if (_wb_stb_i)
		wb_dat_o <= ram[wb_addr_i];
	if (_wb_stb_i && wb_we_i) begin
		for (integer i = 0; i < (WORDBITSZ/8); i = i + 1) begin
			if (wb_sel_i[i])
				ram[wb_addr_i][(i*8) +: 8] <= wb_dat_i[(i*8) +: 8];
		end
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= (cntr - 1'b1);
	else if (_wb_stb_i)
		cntr <= DELAY;
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_ack_o <= 0;
	else if (DELAY)
		wb_ack_o <= (cntr == 1);
	else
		wb_ack_o <= _wb_stb_i;
end

endmodule
