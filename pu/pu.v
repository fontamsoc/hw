// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Parameters:
//
// CLKFREQ
// 	Frequency of the clock input "clk_i" in Hz.
//
// ICACHESETCOUNT
// 	Number of instruction cache set.
// 	Each cache set is ARCHBITSZ bits.
// 	It must be at least 2, a power of 2,
// 	and less than or equal to 2^(ADDRBITSZ-1).
//
// DCACHESETCOUNT
// 	Number of data cache set.
// 	Each cache set is ARCHBITSZ bits.
// 	It must be at least 2, a power of 2,
// 	and less than or equal to 2^(ADDRBITSZ-1).
//
// TLBSETCOUNT
// 	Number of tlb entries.
// 	It must be at least 2, a power of 2,
// 	and less than or equal to 2^(PAGENUMBITSZ-1).
//
// ICACHEWAYCOUNT
// 	Number of icache ways.
// 	It must be non-null and a power of 2.
//
// DCACHEWAYCOUNT
// 	Number of dcache ways.
// 	It must be non-null and a power of 2.
//
// MULDIVCNT
// 	Number of units making up the muldiv pipeline.
// 	It must be 4 or 8.

// Ports:
//
// rst_i
// 	When held high at the the clock signal posedge, the pu reset.
// 	It must be held low for the pu to begin executing instructions.
//
// clk_i
// 	Clock signal.
// clk_muldiv_i
// 	Clock signal used by muldiv.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
//
// pi1_op_o
// pi1_addr_o
// pi1_data_o
// pi1_data_i
// pi1_sel_o
// pi1_rdy_i
// 	PerInt master memory interface.
//
// rstaddr_i
// 	Address where the pu begin executing instruction after reset.
// 	It is to be a 32bits address for which the least significant
// 	bit has been discarded.
//
// intrqst_i
// 	When this signal is held high and the output intrdy_o is low,
// 	the pu execute an EXTINTR context-switch.
//
// intrdy_o
// 	When this signal is high, the pu is in usermode with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal intrqst_i become high.
//
// halted_o
// 	When this signal is high, the pu is halted with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal intrqst_i become high.
//
// id_i
// 	Index of the pu when used in multipu.
// 	Must be 0, when not used in multipu.
//
// brkonrst_i
// 	When the debugging interface is enabled by PUDBG,
// 	this signal determines whether the pu should be
// 	initially stopped after reset. When low, it lets
// 	the pu execute instructions after reset.
//
// dbg_rx_rcvd_i
// 	When the debugging interface is enabled by PUDBG, this signal is high
// 	for one clock cycle when a byte has been received on dbg_rx_data_i .
//
// dbg_rx_data_i
// 	When the debugging interface is enabled by PUDBG, this signal is
// 	the byte received which is valid only when "dbg_rx_rcvd_i" is high.
//
// dbg_rx_rdy_o
// 	When the debugging interface is enabled by PUDBG, this signal is
// 	high when ready to receive through "dbg_rx_data_i".
//
// dbg_tx_stb_o
// 	When the debugging interface is enabled by PUDBG, this signal is
// 	set high to transmit "dbg_tx_data_o" if "dbg_tx_rdy_i" is high.
//
// dbg_tx_data_o
// 	When the debugging interface is enabled by PUDBG, this signal is
// 	the byte transmitted when (dbg_tx_stb_o && dbg_tx_rdy_i) is true.
//
// dbg_tx_rdy_i
// 	When the debugging interface is enabled by PUDBG, this signal is
// 	high when ready to transmit through "dbg_tx_data_o".

`include "lib/ram/bram.v"
`include "lib/ram/ram2clk1i5o.v"

`include "./opmuldiv.pu.v"

`ifdef PUDCACHE
`include "dev/pi1_dcache.v"
`endif

module pu (

	 rst_i

	,rst_o

	,clk_i
	,clk_muldiv_i

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

	`ifdef PUDBG
	,brkonrst_i
	,dbg_rx_rcvd_i
	,dbg_rx_data_i
	,dbg_rx_rdy_o
	,dbg_tx_stb_o
	,dbg_tx_data_o
	,dbg_tx_rdy_i
	`endif

	`ifdef SIMULATION
	,pc_o
	`endif
);

`include "lib/clog2.v"

parameter CLKFREQ        = 1;
parameter ICACHESETCOUNT = 2;
parameter DCACHESETCOUNT = 2;
parameter TLBSETCOUNT    = 2;
parameter ICACHEWAYCOUNT = 1;
parameter DCACHEWAYCOUNT = 1;
parameter TLBWAYCOUNT    = 1;
parameter MULDIVCNT      = 4;

localparam CLOG2ICACHESETCOUNT = clog2(ICACHESETCOUNT);
localparam CLOG2DCACHESETCOUNT = clog2(DCACHESETCOUNT);
localparam CLOG2ICACHEWAYCOUNT = clog2(ICACHEWAYCOUNT);
localparam CLOG2TLBWAYCOUNT    = clog2(TLBWAYCOUNT);

parameter ARCHBITSZ = 0;

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam CLOG2ARCHBITSZBY16 = clog2(ARCHBITSZ/16);

// Number of bits in an address.
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

output reg rst_o;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
input wire [2 -1 : 0] clk_muldiv_i;
`else
input wire [1 -1 : 0] clk_i;
input wire [1 -1 : 0] clk_muldiv_i;
`endif

output reg[2 -1 : 0] pi1_op_o; // ### declared as reg so as to be usable by verilog within the always block.
output reg[ADDRBITSZ -1 : 0] pi1_addr_o; // ### declared as reg so as to be usable by verilog within the always block.
output reg[ARCHBITSZ -1 : 0] pi1_data_o; // ### declared as reg so as to be usable by verilog within the always block.
input wire[ARCHBITSZ -1 : 0] pi1_data_i;
output reg[(ARCHBITSZ/8) -1 : 0] pi1_sel_o; // ### declared as reg so as to be usable by verilog within the always block.
input wire pi1_rdy_i;

input wire intrqst_i;
output wire intrdy_o;
output wire halted_o;

input wire[(ARCHBITSZ-1) -1 : 0] rstaddr_i;

input wire[ARCHBITSZ -1 : 0] id_i;

`ifdef PUDBG
input  wire            brkonrst_i;
input  wire            dbg_rx_rcvd_i;
input  wire [8 -1 : 0] dbg_rx_data_i;
output wire            dbg_rx_rdy_o; assign dbg_rx_rdy_o = 1'b1;
output wire            dbg_tx_stb_o;
output wire [8 -1 : 0] dbg_tx_data_o;
input  wire            dbg_tx_rdy_i;
`endif

`ifdef SIMULATION
output wire [ARCHBITSZ -1 : 0] pc_o;
`endif

localparam MEMNOOP		= 2'b00;
localparam MEMWRITEOP		= 2'b01;
localparam MEMREADOP		= 2'b10;
localparam MEMREADWRITEOP	= 2'b11;

// Total number of ARCHBITSZ bits data that the instruction buffer can contain.
// This value determine the amount of prefetching done.
// The value of 2 must not change because it is enough and appropriate,
// as it allow for fetching the next data while the previously fetched
// data is being sequenced.
localparam INSTRBUFFERSIZE = 2;

localparam CLOG2INSTRBUFFERSIZE = clog2(INSTRBUFFERSIZE);

// Number of GPRs per context.
// The value of 16 cannot change because
// the instruction set is designed around it.
localparam GPRCNTPERCTX = 16;

localparam CLOG2GPRCNTPERCTX = clog2(GPRCNTPERCTX);

// Total number of GPRs across usermode and kernelmode.
localparam GPRCNTTOTAL = (GPRCNTPERCTX*2);

localparam CLOG2GPRCNTTOTAL = clog2(GPRCNTTOTAL);

// Number of bits in an address within a page.
localparam ADDRWITHINPAGEBITSZ = (12-CLOG2ARCHBITSZBY8);

// Number of bits in a page number.
localparam PAGENUMBITSZ = (ARCHBITSZ-12);

localparam ARCHBITSZMAX = 64;

`include "./opcodes.pu.v"
`include "./netsandregs.pu.v"

`include "./init.pu.v"

assign intrdy_o = (inusermode && !isflagdisextintr && !dbgen);
wire inhalt = (dohalt && inusermode && !dbgen);
assign halted_o = (inhalt && !isflagdisextintr);

// ### Block used to implement combinational logic;
// ### verilog simulation do not handle correctly
// ### combinational logic within a clock block,
// ### because signal changes are shown only after
// ### a clock edge but should show instantaneously.
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
	`include "./opst.pu.v"
	`include "./opldst.pu.v"
	`include "./sequencer.pu.v"
	`include "./timers.pu.v"
	`include "./opli.pu.v"
	`include "./opsetsysreg.pu.v"
	`include "./gprctrl.pu.v"
	`ifdef PUDBG
	`include "./dbg.pu.v"
	`endif
end

endmodule
