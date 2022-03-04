// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef RAM1I1O_V
`define RAM1I1O_V

module ram1i1o (
	rst_i, clk_i ,we_i ,addr_i ,i ,o
);

`include "lib/clog2.v"

parameter SZ = 2;
parameter DW = 32;

parameter SRCFILE = "";

input wire rst_i;

input wire clk_i;

input wire we_i;

input wire [clog2(SZ) -1 : 0] addr_i;

input  wire [DW -1 : 0] i;
output wire [DW -1 : 0] o;

reg [DW -1 : 0] u [SZ -1 : 0];
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
	end
end

assign o = u[addr_i];

always @ (posedge clk_i) begin
	if (we_i)
		u[addr_i] <= i;
end

endmodule

`endif /* RAM1I1O_V */
