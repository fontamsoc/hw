// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef DRAM_V
`define DRAM_V

module dram (
	          clk1_i
	         ,we1_i
	,addr0_i ,addr1_i
	         ,i1
	,o0      ,o1
);

`include "lib/clog2.v"

parameter SZ = 2;
parameter DW = 32;

parameter NO_RW_CHECK = 0;

parameter INITFILE = "";

input wire                  clk1_i;
input wire                  we1_i;
input wire  [clog2(SZ)-1:0] addr0_i;
input wire  [clog2(SZ)-1:0] addr1_i;
input wire  [DW-1:0]        i1;
output wire [DW-1:0]        o0;
output wire [DW-1:0]        o1;

generate if (NO_RW_CHECK) begin: gen_no_rw_check

(* no_rw_check, ramstyle = "no_rw_check", ram_style = "no_rw_check" *)
reg [DW-1:0] u [SZ];

`ifdef SIMULATION
integer init_u_idx;
`endif
initial begin
	`ifdef SIMULATION
	for (init_u_idx = 0; init_u_idx < SZ; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	`endif
	if (INITFILE != "") begin
		$readmemh (INITFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

assign o0 = u[addr0_i];
assign o1 = u[addr1_i];

always @ (posedge clk1_i) begin
	if (we1_i)
		u[addr1_i] <= i1;
end

end else begin: gen_rw_check

reg [DW-1:0] u [SZ];

`ifdef SIMULATION
integer init_u_idx;
`endif
initial begin
	`ifdef SIMULATION
	for (init_u_idx = 0; init_u_idx < SZ; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	`endif
	if (INITFILE != "") begin
		$readmemh (INITFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

assign o0 = u[addr0_i];
assign o1 = u[addr1_i];

always @ (posedge clk1_i) begin
	if (we1_i)
		u[addr1_i] <= i1;
end

end endgenerate

endmodule

`endif /* DRAM_V */
