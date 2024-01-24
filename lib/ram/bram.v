// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef BRAM_V
`define BRAM_V

module bram (
	 clk0_i  ,clk1_i
	,en0_i   ,en1_i
	         ,we1_i
	,addr0_i ,addr1_i
	         ,i1
	,o0      ,o1
);

`include "lib/clog2.v"

parameter SZ = 2;
parameter DW = 32;

parameter SRCFILE = "";

input wire                 clk0_i;
input wire                 clk1_i;
(* direct_enable = "true" *)
input wire                 en0_i;
(* direct_enable = "true" *)
input wire                 en1_i;
input wire                 we1_i;
input wire [clog2(SZ)-1:0] addr0_i;
input wire [clog2(SZ)-1:0] addr1_i;
input wire [DW-1:0]        i1;
output reg [DW-1:0]        o0;
output reg [DW-1:0]        o1;

reg [DW-1:0] u [0:SZ-1];
`ifdef SIMULATION
integer init_u_idx;
`endif
initial begin
	`ifdef SIMULATION
	for (init_u_idx = 0; init_u_idx < SZ; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	`endif
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", SRCFILE);
		`endif
		// Initial state initialized here, otherwise
		// block ram fails to be inferred by yosys.
		o0 = 0;
		o1 = 0;
	end
end

always @ (posedge clk0_i) begin
	if (en0_i)
		o0 <= u[addr0_i];
end

always @ (posedge clk1_i) begin
	if (en1_i) begin
		o1 <= u[addr1_i];
		if (we1_i)
			u[addr1_i] <= i1;
	end
end

endmodule

`endif /* BRAM_V */
