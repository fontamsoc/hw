// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/ram/bram.v"
`include "lib/ram/ram2clk1i5o.v"

`define PUMMU
`define PUHPTW

`include "./opmuldiv.pu.v"

module pu (

	 rst_i

	,rst_o

	,clk_i

	,pi1_op_o
	,pi1_addr_o
	,pi1_data_o
	,pi1_data_i
	,pi1_sel_o
	,pi1_rdy_i

	,intrqst_i
	,intrdy_o
	,halted_o

	,rstaddr_i

	,id_i
);

`include "lib/clog2.v"

parameter CLKFREQ        = 1;
parameter ICACHESETCOUNT = 2;
parameter DCACHESETCOUNT = 2;
parameter TLBSETCOUNT    = 2;

localparam CLOG2ICACHESETCOUNT = clog2(ICACHESETCOUNT);
localparam CLOG2DCACHESETCOUNT = clog2(DCACHESETCOUNT);

parameter ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam CLOG2ARCHBITSZBY16 = clog2(ARCHBITSZ/16);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

output reg rst_o;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
`else
input wire [1 -1 : 0] clk_i;
`endif

output reg[2 -1 : 0] pi1_op_o;
output reg[ADDRBITSZ -1 : 0] pi1_addr_o;
output reg[ARCHBITSZ -1 : 0] pi1_data_o;
input wire[ARCHBITSZ -1 : 0] pi1_data_i;
output reg[(ARCHBITSZ/8) -1 : 0] pi1_sel_o;
input wire pi1_rdy_i;

input wire intrqst_i;
output wire intrdy_o;
output wire halted_o;

input wire[(ARCHBITSZ-1) -1 : 0] rstaddr_i;

input wire[ARCHBITSZ -1 : 0] id_i;

localparam MEMNOOP		= 2'b00;
localparam MEMWRITEOP		= 2'b01;
localparam MEMREADOP		= 2'b10;
localparam MEMREADWRITEOP	= 2'b11;

localparam INSTRBUFFERSIZE = 2;

localparam CLOG2INSTRBUFFERSIZE = clog2(INSTRBUFFERSIZE);

localparam GPRCNTPERCTX = 16;

localparam CLOG2GPRCNTPERCTX = clog2(GPRCNTPERCTX);

localparam GPRCNTTOTAL = (GPRCNTPERCTX*2);

localparam CLOG2GPRCNTTOTAL = clog2(GPRCNTTOTAL);

localparam ADDRWITHINPAGEBITSZ = (12-CLOG2ARCHBITSZBY8);

localparam PAGENUMBITSZ = (ARCHBITSZ-12);

`include "./opcodes.pu.v"
`include "./netsandregs.pu.v"

`include "./init.pu.v"

assign intrdy_o = (inusermode && !isflagdisextintr);
wire inhalt = (dohalt && inusermode);
assign halted_o = (inhalt && !isflagdisextintr);

always @* begin
	`include "./dcache.comb.pu.v"
	`include "./memctrl.comb.pu.v"
	`include "./opalu.pu.v"
	`include "./opgetsysreg.pu.v"
	`include "./gprctrl.comb.pu.v"
end

always @ (posedge clk_i[0]) begin
	`ifdef PUMMU
	`include "./mmu.pu.v"
	`ifdef PUHPTW
	`include "./hptw.pu.v"
	`endif
	`endif
	`include "./memctrl.pu.v"
	`include "./instrctrl.pu.v"
	`include "./opld.pu.v"
	`include "./opldst.pu.v"
	`include "./sequencer.pu.v"
	`include "./timers.pu.v"
	`include "./opli.pu.v"
	`include "./opsetsysreg.pu.v"
	`include "./gprctrl.pu.v"
end

endmodule
