// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Ports:
//
// clk_i
// 	Clock signal.
//
// pi1_op_i
// pi1_addr_i
// pi1_data_i
// pi1_data_o
// pi1_sel_i
// pi1_rdy_o
// pi1_mapsz_o
// 	PerInt slave memory interface.

module bootldr (

	clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i /* not used */
	,pi1_data_o
	,pi1_sel_i /* not used */
	,pi1_rdy_o
	,pi1_mapsz_o
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
parameter SIZE = (16/(ARCHBITSZ/16));

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i; /* not used */
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i; /* not used */
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

assign pi1_rdy_o = 1'b1;

assign pi1_mapsz_o = SIZE;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [ARCHBITSZ -1 : 0] u [0 : SIZE -1];
`ifdef SIMULATION
integer init_u_idx;
`endif
initial begin
	`ifdef SIMULATION
	for (init_u_idx = 0; init_u_idx < SIZE; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	`endif
	$readmemh (SRCFILE, u);
	`ifdef SIMULATION
	$display ("%s loaded", SRCFILE);
	pi1_data_o = 0;
	`endif
end

always @ (posedge clk_i) begin
	if (pi1_rdy_o && pi1_op_i == PIRDOP)
		pi1_data_o <= u[pi1_addr_i];
end

endmodule
