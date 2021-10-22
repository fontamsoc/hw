// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef RAM2CLK1I2O_V
`define RAM2CLK1I2O_V

`ifdef USE2CLK
`include "lib/ram/bram.v"
`endif

module ram2clk1i2o (
	 rst_i
	,clk0_i        ,addr0_i     ,o0
	,clk1_i ,we1_i ,addr1_i ,i1 ,o1
);

`include "lib/clog2.v"

parameter SZ = 2;
parameter DW = 32;

parameter SRCFILE = "";

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk0_i;
input wire [2 -1 : 0] clk1_i;
`else
input wire [1 -1 : 0] clk0_i;
input wire [1 -1 : 0] clk1_i;
`endif

input wire [clog2(SZ) -1 : 0] addr0_i;
input wire [clog2(SZ) -1 : 0] addr1_i;

input wire we1_i;

input wire [DW -1 : 0] i1;

output wire [DW -1 : 0] o0;
output wire [DW -1 : 0] o1;

`ifdef USE2CLK

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram0 (

	 .clk0_i  (clk0_i[1])  ,.clk1_i  (clk1_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we1_i)
	,.addr0_i (addr0_i)    ,.addr1_i (addr1_i)
	                       ,.i1      (i1)
	,.o0      (o0)         ,.o1      ()
);

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram1 (

	 .clk0_i  (clk1_i[1])  ,.clk1_i  (clk1_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we1_i)
	,.addr0_i (addr1_i)    ,.addr1_i (addr1_i)
	                       ,.i1      (i1)
	,.o0      (o1)         ,.o1      ()
);

`else

reg [DW -1 : 0] u [SZ -1 : 0];
integer init_u_idx;
initial begin
	for (init_u_idx = 0; init_u_idx < SZ; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
	end
end

assign o0 = u[addr0_i];
assign o1 = u[addr1_i];

always @ (posedge clk1_i[0]) begin
	if (we1_i)
		u[addr1_i] <= i1;
end

`endif

endmodule

`endif
