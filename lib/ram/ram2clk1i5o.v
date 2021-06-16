// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef RAM2CLK1I4O_V
`define RAM2CLK1I4O_V

`ifdef USE2CLK
`include "lib/ram/bram.v"
`endif

module ram2clk1i5o (
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

`ifdef USE2CLK
input wire [2 -1 : 0] clk0_i;
input wire [2 -1 : 0] clk1_i;
input wire [2 -1 : 0] clk2_i;
input wire [2 -1 : 0] clk3_i;
input wire [2 -1 : 0] clk4_i;
`else
input wire [1 -1 : 0] clk0_i;
input wire [1 -1 : 0] clk1_i;
input wire [1 -1 : 0] clk2_i;
input wire [1 -1 : 0] clk3_i;
input wire [1 -1 : 0] clk4_i;
`endif

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

`ifdef USE2CLK

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram0 (

	 .clk0_i  (clk0_i[1])  ,.clk1_i  (clk4_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we4_i)
	,.addr0_i (addr0_i)    ,.addr1_i (addr4_i)
	                       ,.i1      (i4)
	,.o0      (o0)         ,.o1      ()
);

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram1 (

	 .clk0_i  (clk1_i[1])  ,.clk1_i  (clk4_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we4_i)
	,.addr0_i (addr1_i)    ,.addr1_i (addr4_i)
	                       ,.i1      (i4)
	,.o0      (o1)         ,.o1      ()
);

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram2 (

	 .clk0_i  (clk2_i[1])  ,.clk1_i  (clk4_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we4_i)
	,.addr0_i (addr2_i)    ,.addr1_i (addr4_i)
	                       ,.i1      (i4)
	,.o0      (o2)         ,.o1      ()
);

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram3 (

	 .clk0_i  (clk3_i[1])  ,.clk1_i  (clk4_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we4_i)
	,.addr0_i (addr3_i)    ,.addr1_i (addr4_i)
	                       ,.i1      (i4)
	,.o0      (o3)         ,.o1      ()
);

bram #(

	 .SZ      (SZ)
	,.DW      (DW)
	,.SRCFILE (SRCFILE)

) bram4 (

	 .clk0_i  (clk4_i[1])  ,.clk1_i  (clk4_i[0])
	,.en0_i   (1'b1)       ,.en1_i   (1'b1)
	                       ,.we1_i   (we4_i)
	,.addr0_i (addr4_i)    ,.addr1_i (addr4_i)
	                       ,.i1      (i4)
	,.o0      (o4)         ,.o1      ()
);

`else

integer idx;

reg [DW -1 : 0] u [SZ -1 : 0];
initial begin
	for (idx = 0; idx < SZ; idx = idx + 1)
		u[idx] = 0;
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
	end
end

assign o0 = u[addr0_i];
assign o1 = u[addr1_i];
assign o2 = u[addr2_i];
assign o3 = u[addr3_i];
assign o4 = u[addr4_i];

always @ (posedge clk4_i[0]) begin
	if (we4_i)
		u[addr4_i] <= i4;
end

`endif

endmodule

`endif
