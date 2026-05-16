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

`include "lib/clog2.sv"

parameter SZ = 2;
parameter DW = 32;

parameter NO_RW_CHECK = 0;

parameter INITFILE = "";

input wire                 clk0_i;
input wire                 clk1_i;
input wire                 en0_i;
input wire                 en1_i;
input wire                 we1_i;
input wire [clog2(SZ)-1:0] addr0_i;
input wire [clog2(SZ)-1:0] addr1_i;
input wire [DW-1:0]        i1;
output reg [DW-1:0]        o0;
output reg [DW-1:0]        o1;

generate if (NO_RW_CHECK) begin: gen_no_rw_check

(* no_rw_check, ramstyle = "no_rw_check", syn_ramstyle = "no_rw_check" *)
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
		// Initial state initialized here, otherwise
		// block ram fails to be inferred by yosys.
		o0 = 0;
		o1 = 0;
	end
end

always_ff @(posedge clk0_i) begin
	if (en0_i)
		o0 <= u[addr0_i];
end

always_ff @(posedge clk1_i) begin
	if (en1_i) begin
		o1 <= u[addr1_i];
		if (we1_i)
			u[addr1_i] <= i1;
	end
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
		// Initial state initialized here, otherwise
		// block ram fails to be inferred by yosys.
		o0 = 0;
		o1 = 0;
	end
end

always_ff @(posedge clk0_i) begin
	if (en0_i)
		o0 <= u[addr0_i];
end

always_ff @(posedge clk1_i) begin
	if (en1_i) begin
		o1 <= u[addr1_i];
		if (we1_i)
			u[addr1_i] <= i1;
	end
end

end endgenerate

endmodule

`endif /* BRAM_V */
