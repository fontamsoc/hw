// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Ports:
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
// wb_mapsz_o
// 	Memory map size in bytes.

module bootldr (

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
	,wb_mapsz_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam SRCFILE =
	ARCHBITSZ == 16 ? "bootldr16.hex" :
	ARCHBITSZ == 32 ? "bootldr32.hex" :
	ARCHBITSZ == 64 ? "bootldr64.hex" :
	ARCHBITSZ == 128 ? "bootldr128.hex" :
	ARCHBITSZ == 256 ? "bootldr256.hex" :
	                   "";
localparam SIZE = ((32/*instruction count*/*2)/(ARCHBITSZ/8));

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
output wire [ARCHBITSZ -1 : 0]     wb_mapsz_o;

assign wb_mapsz_o = (SIZE*(ARCHBITSZ/8))
	`ifdef SIMULATION
	*2 // Double the memory mapping to catch pu prefetch
	   // memory access that can occur beyond its size.
	`endif
	;

reg [ARCHBITSZ -1 : 0] rom [0 : SIZE -1];

initial begin
	$readmemh (SRCFILE, rom);
	`ifdef SIMULATION
	$display ("%s loaded", SRCFILE);
	`endif
	// Initial state initialized here, otherwise
	// block ram fails to be inferred by yosys.
	wb_dat_o = 0;
end

wire _wb_stb_i = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin

	if (_wb_stb_i)
		wb_dat_o <= rom[wb_addr_i];

	wb_ack_o <= (!rst_i && _wb_stb_i);
end

endmodule
