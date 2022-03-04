// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef RAM1I4O_V
`define RAM1I4O_V

module ram1i5o (
	 rst_i
	,clk0_i        ,addr0_i     ,o0
	,clk1_i        ,addr1_i     ,o1
	,clk2_i        ,addr2_i     ,o2
	,clk3_i        ,addr3_i     ,o3
	,clk4_i ,we4_i ,addr4_i ,i4 ,o4
);

`include "lib/clog2.v"

parameter SZ = 2;
parameter DW = 32;

parameter SRCFILE = "";

input wire rst_i;

input wire clk0_i;
input wire clk1_i;
input wire clk2_i;
input wire clk3_i;
input wire clk4_i;

input wire [clog2(SZ) -1 : 0] addr0_i;
input wire [clog2(SZ) -1 : 0] addr1_i;
input wire [clog2(SZ) -1 : 0] addr2_i;
input wire [clog2(SZ) -1 : 0] addr3_i;
input wire [clog2(SZ) -1 : 0] addr4_i;

input wire we4_i;

input wire [DW -1 : 0] i4;

output wire [DW -1 : 0] o0;
output wire [DW -1 : 0] o1;
output wire [DW -1 : 0] o2;
output wire [DW -1 : 0] o3;
output wire [DW -1 : 0] o4;

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

assign o0 = u[addr0_i];
assign o1 = u[addr1_i];
assign o2 = u[addr2_i];
assign o3 = u[addr3_i];
assign o4 = u[addr4_i];

always @ (posedge clk4_i) begin
	if (we4_i)
		u[addr4_i] <= i4;
end

endmodule

`endif /* RAM1I4O_V */
