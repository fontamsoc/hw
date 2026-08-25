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

// The element type is per-byte packed, per the tool byte-enabled ram
// template, so that the per-byte writes below infer block-ram.
(* no_rw_check, ramstyle = "no_rw_check", syn_ramstyle = "no_rw_check" *)
reg [(WORDBITSZ/8) -1 : 0][8 -1 : 0] ram [SIZE];


initial begin
	if (INITFILE != "") begin
		$readmemh (INITFILE, ram);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

wire _wb_stb_i = (wb_stb_i && !wb_bsy_o);

// The per-byte writes are unrolled with constant lane indices and the
// read is unguarded in the same always block, per the tool
// byte-enabled ram template; a for-loop write index or an enable on
// the read makes some tools implement ram in logic instead of
// block-ram. The unguarded read is harmless: wb_dat_o is sampled in
// the clockcycle wb_ack_o is high, and a master holds its request
// while wb_bsy_o is high.
generate if (WORDBITSZ == 32) begin :gen_ramwr32

always_ff @(posedge clk_i) begin
	if (_wb_stb_i && wb_we_i) begin
		if (wb_sel_i[0]) ram[wb_addr_i][0] <= wb_dat_i[7:0];
		if (wb_sel_i[1]) ram[wb_addr_i][1] <= wb_dat_i[15:8];
		if (wb_sel_i[2]) ram[wb_addr_i][2] <= wb_dat_i[23:16];
		if (wb_sel_i[3]) ram[wb_addr_i][3] <= wb_dat_i[31:24];
	end
	wb_dat_o <= ram[wb_addr_i];
end

end else if (WORDBITSZ == 64) begin :gen_ramwr64

always_ff @(posedge clk_i) begin
	if (_wb_stb_i && wb_we_i) begin
		if (wb_sel_i[0]) ram[wb_addr_i][0] <= wb_dat_i[7:0];
		if (wb_sel_i[1]) ram[wb_addr_i][1] <= wb_dat_i[15:8];
		if (wb_sel_i[2]) ram[wb_addr_i][2] <= wb_dat_i[23:16];
		if (wb_sel_i[3]) ram[wb_addr_i][3] <= wb_dat_i[31:24];
		if (wb_sel_i[4]) ram[wb_addr_i][4] <= wb_dat_i[39:32];
		if (wb_sel_i[5]) ram[wb_addr_i][5] <= wb_dat_i[47:40];
		if (wb_sel_i[6]) ram[wb_addr_i][6] <= wb_dat_i[55:48];
		if (wb_sel_i[7]) ram[wb_addr_i][7] <= wb_dat_i[63:56];
	end
	wb_dat_o <= ram[wb_addr_i];
end

end else begin :gen_ramwr

always_ff @(posedge clk_i) begin
	if (_wb_stb_i && wb_we_i) begin
		for (integer i = 0; i < (WORDBITSZ/8); i = i + 1) begin
			if (wb_sel_i[i])
				ram[wb_addr_i][i] <= wb_dat_i[(i*8) +: 8];
		end
	end
	wb_dat_o <= ram[wb_addr_i];
end

end endgenerate

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
