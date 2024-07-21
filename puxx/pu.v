// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Parameters:
//
// WORDBITSZ
// XWORDBITSZ
// 	TODO: Document ...
// 	TODO: XWORDBITSZ must be >= WORDBITSZ.
//
// CLKFREQ
// 	Frequency of the clock input "clk_i" in Hz.
//
// ICACHESETCNT
// 	Number of instruction cache set.
// 	Each cache set is XWORDBITSZ bits.
// 	It must be at least 2 and a power-of-2.
//
// DCACHESETCNT
// 	Number of data cache set.
// 	Each cache set is XWORDBITSZ bits.
// 	It must be at least 2 and a power-of-2.
//
// TLBSETCNT
// 	Number of tlb entries.
// 	It must be at least 2, a power-of-2,
// 	and less than or equal to 2^(PAGENUMBITSZ-1).
//
// ICACHEWAYCNT
// 	Number of icache ways.
// 	It must be non-null and a power-of-2.
//
// DCACHEWAYCNT
// 	Number of dcache ways.
// 	It must be non-null and a power-of-2.
//
// IMULCNT
// 	Number of units making up the imul pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// IDIVCNT
// 	Number of units making up the idiv pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// FADDFSUBCNT
// 	Number of units making up the faddfsub pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 2.
//
// FMULCNT
// 	Number of units making up the fmul pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal
// 	to 4 (ifdef PUFMULDSP) or 8.
//
// FDIVCNT
// 	Number of units making up the fdiv pipeline.
// 	It must be non-null, a power-of-2 less-than-or-equal to 8.
//
// MAXPENDINGACK
// 	TODO: Describe ...
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	When held high at the the clock signal posedge, the pu reset.
// 	It must be held low for the pu to begin executing instructions.
//
// clk_i
// 	Clock signal.
// clk_imul_i
// 	Clock signal used by imul.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
// clk_idiv_i
// 	Clock signal used by idiv.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
// clk_faddfsub_i
// 	Clock signal used by faddfsub.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
// clk_fmul_i
// 	Clock signal used by fmul.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
// clk_fdiv_i
// 	Clock signal used by fdiv.
// 	Its frequency must be a power-of-2 multiple of clk_i frequency.
//
// wb_cyc_o
// wb_stb_o
// wb_we_o
// wb_addr_o
// wb_sel_o
// wb_dat_o
// wb_bsy_i
// wb_ack_i
// wb_dat_i
// 	Wishbone master memory interface.
//
// rstaddr_i
// 	Address where the pu begin executing instruction after reset.
// 	It is to be a 32bits address for which the least significant
// 	bit has been discarded.
//
// irq_stb_i
// 	When this signal is held high and the output irq_rdy_o is low,
// 	the pu execute an EXTINTR context-switch.
//
// irq_rdy_o
// 	When this signal is high, the pu is in usermode with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal irq_stb_i become high.
//
// halted_o
// 	When this signal is high, the pu is halted with interrupt
// 	enabled (ie: isflagdisextintr is false), and will execute
// 	an EXTINTR context-switch if the signal irq_stb_i become high.
//
// id_i
// 	Index of the pu when used in a multi-pu configuration,
// 	otherwise must be 0.
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
`include "lib/fifo.v"
`include "lib/wb_upsizr.v"

`include "./opimul.pu.v"
`include "./opidiv.pu.v"
`include "./opfaddfsub.pu.v"
`include "./opfmul.pu.v"
`include "./opfdiv.pu.v"

`include "lib/icache.v"

`ifdef PUDCACHE
`include "lib/wb_skidbuf.v"
`include "lib/dcache.v"
`endif

module pu (

	 rst_i

	,rst_o

	,clk_i
	,clk_imul_i
	,clk_idiv_i
	,clk_faddfsub_i
	,clk_fmul_i
	,clk_fdiv_i

	,wb_cyc_o
	,wb_stb_o
	,wb_we_o
	,wb_addr_o
	,wb_sel_o
	,wb_dat_o
	,wb_bsy_i
	,wb_ack_i
	,wb_dat_i

	,irq_stb_i
	,irq_rdy_o
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
);

`include "lib/clog2.v"

parameter CLKFREQ       = 1;
parameter ICACHESETCNT  = 2;
parameter DCACHESETCNT  = 2;
parameter TLBSETCNT     = 2;
parameter ICACHEWAYCNT  = 1;
parameter DCACHEWAYCNT  = 1;
parameter IMULCNT       = 2;
parameter IDIVCNT       = 2;
parameter FADDFSUBCNT   = 1;
parameter FMULCNT       = 1;
parameter FDIVCNT       = 1;
parameter MAXPENDINGACK = 16; // Default to number of GPRs for which stores could be done.
parameter VERSION       = {8'd1/*major-version*/, 8'd0/*minor-version*/};

localparam CLOG2ICACHESETCNT = clog2(ICACHESETCNT);
localparam CLOG2DCACHESETCNT = clog2(DCACHESETCNT);
localparam CLOG2ICACHEWAYCNT = clog2(ICACHEWAYCNT);

parameter WORDBITSZ  = 32;
parameter XWORDBITSZ = 32; // TODO: Support all the way up to 1024 ...

localparam CLOG2WORDBITSZ = clog2(WORDBITSZ);
localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam CLOG2WORDBITSZBY16 = clog2(WORDBITSZ/16);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam CLOG2XWORDBITSZBY8 = clog2(XWORDBITSZ/8);
localparam CLOG2XWORDBITSZBY16 = clog2(XWORDBITSZ/16);
localparam XADDRBITSZ = (XWORDBITSZ-CLOG2XWORDBITSZBY8);

localparam CLOG2XWORDBITSZBY8DIFF = (CLOG2XWORDBITSZBY8-CLOG2WORDBITSZBY8);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

input wire rst_i;

output reg rst_o;

input wire clk_i;
input wire clk_imul_i;
input wire clk_idiv_i;
input wire clk_faddfsub_i;
input wire clk_fmul_i;
input wire clk_fdiv_i;

output reg                          wb_cyc_o;  // ### comb-block-reg.
output reg                          wb_stb_o;  // ### comb-block-reg.
output reg                          wb_we_o;   // ### comb-block-reg.
output reg  [XADDRBITSZ -1 : 0]     wb_addr_o; // ### comb-block-reg.
output reg  [(XWORDBITSZ/8) -1 : 0] wb_sel_o;  // ### comb-block-reg.
output reg  [XWORDBITSZ -1 : 0]     wb_dat_o;  // ### comb-block-reg.
input  wire                         wb_bsy_i;
input  wire                         wb_ack_i;
input  wire [XWORDBITSZ -1 : 0]     wb_dat_i;

input  wire irq_stb_i;
output wire irq_rdy_o;
output wire halted_o;

input wire [WORDBITSZ -1 : 0] rstaddr_i;

input wire[WORDBITSZ -1 : 0] id_i;

`ifdef PUDBG
input  wire            brkonrst_i;
input  wire            dbg_rx_rcvd_i;
input  wire [8 -1 : 0] dbg_rx_data_i;
output wire            dbg_rx_rdy_o; assign dbg_rx_rdy_o = 1'b1;
output wire            dbg_tx_stb_o;
output wire [8 -1 : 0] dbg_tx_data_o;
input  wire            dbg_tx_rdy_i;
`endif

// Total number of WORDBITSZ bits data that the instruction buffer can contain.
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
localparam ADDRWITHINPAGEBITSZ = (12-CLOG2WORDBITSZBY8);

// Number of bits in a page number.
localparam PAGENUMBITSZ = (WORDBITSZ-12);

`include "./opcodes.pu.v"
`include "./netsandregs.pu.v"
`include "./sequencer.pu.v"
`include "./instrctrl.pu.v"
`include "./gprctrl.pu.v"
`include "./memctrl.pu.v"
`ifdef PUDBG
`include "./dbg.pu.v"
`endif

assign irq_rdy_o = (inusermode && !isflagdisextintr && !dbgen);
wire inhalt = (dohalt && inusermode && !dbgen);
assign halted_o = (inhalt && !isflagdisextintr);

`ifdef SIMULATION_pc_w
integer fd;
initial begin
	fd = $fopen("pc_w.txt","w");
	if (!fd)
		$display("could not create \"pc_w.txt\"");
end
reg [WORDBITSZ -1 : 0] pc_w_saved = 0;
reg pc_dump_en = 0;
always @ (posedge clk_i) begin
	if (rst_i)
		pc_dump_en <= 0;
	else if (!pc_dump_en) begin
		if (pc_w == 'h8000)
			pc_dump_en <= 1;
	end else if (sequencerreadyandgprrdy12 && pc_w != pc_w_saved) begin
		pc_w_saved <= pc_w;
		$fwrite(fd, "0x%x: %d(0x%x) %d(0x%x)\n", pc_w, gpridx1[3:0], gprdata1, gpridx2[3:0], gprdata2);
		$fflush(fd);
	end
end
`endif

endmodule
