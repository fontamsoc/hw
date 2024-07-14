// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Parameters:
//
// PUCOUNT
// 	Number of PU making up the cpu.

// Ports:
//
// rstaddr2_i
// 	Address where PUs with non-null id_i begin executing
// 	instructions when woken-up. It is to be a 32bits address
// 	for which the least significant bit has been discarded.
//
// Refer to documentation in pu.v head for remaining parameters and ports.

`include "./pu.v"

`include "lib/wb_arbiter.v"
`include "lib/wb_cdc.v"

module cpu (

	 rst_i

	,rst_o

	,clk_i
	,clk_mem_i
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
	,rstaddr2_i

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

parameter CLKFREQ        = 1;
parameter ICACHESETCOUNT = 2;
parameter DCACHESETCOUNT = 2;
parameter TLBSETCOUNT    = 2;
parameter ICACHEWAYCOUNT = 1;
parameter DCACHEWAYCOUNT = 1;
parameter IMULCNT        = 2;
parameter IDIVCNT        = 2;
parameter FADDFSUBCNT    = 1;
parameter FMULCNT        = 1;
parameter FDIVCNT        = 1;
parameter MAXPENDINGACK  = 16;
parameter VERSION        = {8'd1/*major-version*/, 8'd0/*minor-version*/};

parameter WORDBITSZ  = 32;
parameter XWORDBITSZ = 32;

localparam CLOG2XWORDBITSZBY8 = clog2(XWORDBITSZ/8);
localparam XADDRBITSZ = (XWORDBITSZ-CLOG2XWORDBITSZBY8);

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

input wire rst_i;

output wire rst_o;

input wire clk_i;
input wire clk_mem_i;
input wire clk_imul_i;
input wire clk_idiv_i;
input wire clk_faddfsub_i;
input wire clk_fmul_i;
input wire clk_fdiv_i;

output wire                         wb_cyc_o;
output wire                         wb_stb_o;
output wire                         wb_we_o;
output wire [XADDRBITSZ -1 : 0]     wb_addr_o;
output wire [(XWORDBITSZ/8) -1 : 0] wb_sel_o;
output wire [XWORDBITSZ -1 : 0]     wb_dat_o;
input  wire                         wb_bsy_i;
input  wire                         wb_ack_i;
input  wire [XWORDBITSZ -1 : 0]     wb_dat_i;

input  wire [PUCOUNT -1 : 0] irq_stb_i;
output wire [PUCOUNT -1 : 0] irq_rdy_o;
output wire [PUCOUNT -1 : 0] halted_o;

input wire [(WORDBITSZ-1) -1 : 0] rstaddr_i;
input wire [(WORDBITSZ-1) -1 : 0] rstaddr2_i;

input wire [WORDBITSZ -1 : 0] id_i;

`ifdef PUDBG
input  wire            brkonrst_i;
input  wire            dbg_rx_rcvd_i;
input  wire [8 -1 : 0] dbg_rx_data_i;
output wire            dbg_rx_rdy_o;
output reg             dbg_tx_stb_o;  // ### comb-block-reg.
output reg  [8 -1 : 0] dbg_tx_data_o; // ### comb-block-reg.
input  wire            dbg_tx_rdy_i;
`endif

wire                         arbiter_wb_cyc_i  [PUCOUNT -1 : 0];
wire                         arbiter_wb_stb_i  [PUCOUNT -1 : 0];
wire                         arbiter_wb_we_i   [PUCOUNT -1 : 0];
wire [XADDRBITSZ -1 : 0]     arbiter_wb_addr_i [PUCOUNT -1 : 0];
wire [(XWORDBITSZ/8) -1 : 0] arbiter_wb_sel_i  [PUCOUNT -1 : 0];
wire [XWORDBITSZ -1 : 0]     arbiter_wb_dat_i  [PUCOUNT -1 : 0];
wire                         arbiter_wb_bsy_o  [PUCOUNT -1 : 0];
wire                         arbiter_wb_ack_o  [PUCOUNT -1 : 0];
wire [XWORDBITSZ -1 : 0]     arbiter_wb_dat_o  [PUCOUNT -1 : 0];

wire [(1 * PUCOUNT) -1 : 0]              _arbiter_wb_cyc_i;
wire [(1 * PUCOUNT) -1 : 0]              _arbiter_wb_stb_i;
wire [(1 * PUCOUNT) -1 : 0]              _arbiter_wb_we_i;
wire [(XADDRBITSZ * PUCOUNT) -1 : 0]     _arbiter_wb_addr_i;
wire [((XWORDBITSZ/8) * PUCOUNT) -1 : 0] _arbiter_wb_sel_i;
wire [(XWORDBITSZ * PUCOUNT) -1 : 0]     _arbiter_wb_dat_i;
wire [(1 * PUCOUNT) -1 : 0]              arbiter_wb_bsy_o_;
wire [(1 * PUCOUNT) -1 : 0]              arbiter_wb_ack_o_;
wire [(XWORDBITSZ * PUCOUNT) -1 : 0]     arbiter_wb_dat_o_;

wire                         wb_cyc_o_;
wire                         wb_stb_o_;
wire                         wb_we_o_;
wire [XADDRBITSZ -1 : 0]     wb_addr_o_;
wire [(XWORDBITSZ/8) -1 : 0] wb_sel_o_;
wire [XWORDBITSZ -1 : 0]     wb_dat_o_;
wire                         _wb_bsy_i;
wire                         _wb_ack_i;
wire [XWORDBITSZ -1 : 0]     _wb_dat_i;

wb_arbiter #(

	 .WORDBITSZ   (XWORDBITSZ)
	,.MASTERCOUNT (PUCOUNT)

) wb_arbiter (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_wb_cyc_i  (_arbiter_wb_cyc_i)
	,.m_wb_stb_i  (_arbiter_wb_stb_i)
	,.m_wb_we_i   (_arbiter_wb_we_i)
	,.m_wb_addr_i (_arbiter_wb_addr_i)
	,.m_wb_sel_i  (_arbiter_wb_sel_i)
	,.m_wb_dat_i  (_arbiter_wb_dat_i)
	,.m_wb_bsy_o  (arbiter_wb_bsy_o_)
	,.m_wb_ack_o  (arbiter_wb_ack_o_)
	,.m_wb_dat_o  (arbiter_wb_dat_o_)

	,.s_wb_cyc_o  (wb_cyc_o_)
	,.s_wb_stb_o  (wb_stb_o_)
	,.s_wb_we_o   (wb_we_o_)
	,.s_wb_addr_o (wb_addr_o_)
	,.s_wb_sel_o  (wb_sel_o_)
	,.s_wb_dat_o  (wb_dat_o_)
	,.s_wb_bsy_i  (_wb_bsy_i)
	,.s_wb_ack_i  (_wb_ack_i)
	,.s_wb_dat_i  (_wb_dat_i)
);

// This module insert the necessary clock cycle between
// (cyc && stb && !bsy) cycle and corresponding ack cycle,
// needed by pu.opldrqstseqs if there is no dcache.
wb_cdc #(

	 .WORDBITSZ     (XWORDBITSZ)
	,.MAXPENDINGACK (MAXPENDINGACK)

) wb_cdc (

	 .rst_i (rst_i)

	,.m_clk_i (clk_i)
	,.s_clk_i (clk_mem_i)

	,.m_wb_cyc_i  (wb_cyc_o_)
	,.m_wb_stb_i  (wb_stb_o_)
	,.m_wb_we_i   (wb_we_o_)
	,.m_wb_addr_i (wb_addr_o_)
	,.m_wb_sel_i  (wb_sel_o_)
	,.m_wb_dat_i  (wb_dat_o_)
	,.m_wb_bsy_o  (_wb_bsy_i)
	,.m_wb_ack_o  (_wb_ack_i)
	,.m_wb_dat_o  (_wb_dat_i)

	,.s_wb_cyc_o  (wb_cyc_o)
	,.s_wb_stb_o  (wb_stb_o)
	,.s_wb_we_o   (wb_we_o)
	,.s_wb_addr_o (wb_addr_o)
	,.s_wb_sel_o  (wb_sel_o)
	,.s_wb_dat_o  (wb_dat_o)
	,.s_wb_bsy_i  (wb_bsy_i)
	,.s_wb_ack_i  (wb_ack_i)
	,.s_wb_dat_i  (wb_dat_i)
);

wire [PUCOUNT -1 : 0] rst_ow;
assign rst_o = |rst_ow;

`ifdef PUDBG
wire [PUCOUNT -1 : 0] dbg_tx_stb_o_;
wire [8 -1 : 0]       dbg_tx_data_o_ [PUCOUNT -1 : 0];
integer gen_pudbg_idx;
always @* begin
	for (gen_pudbg_idx = 0; gen_pudbg_idx < PUCOUNT; gen_pudbg_idx = gen_pudbg_idx + 1) begin :gen_pudbg
		if (dbg_tx_stb_o_[gen_pudbg_idx]) begin
			dbg_tx_stb_o = 1'b1;
			dbg_tx_data_o = dbg_tx_data_o_[gen_pudbg_idx];
		end else begin
			dbg_tx_stb_o = 1'b0;
			dbg_tx_data_o = 8'b0;
		end
	end
end
`endif

genvar genpu_idx;
generate for (
	genpu_idx = 0;
	genpu_idx < PUCOUNT;
	genpu_idx = genpu_idx + 1) begin :genpu

pu #(

	 .WORDBITSZ      (WORDBITSZ)
	,.XWORDBITSZ     (XWORDBITSZ)
	,.CLKFREQ        (CLKFREQ)
	,.ICACHESETCOUNT (ICACHESETCOUNT)
	,.DCACHESETCOUNT (DCACHESETCOUNT)
	,.TLBSETCOUNT    (TLBSETCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.IMULCNT        (IMULCNT)
	,.IDIVCNT        (IDIVCNT)
	,.FADDFSUBCNT    (FADDFSUBCNT)
	,.FMULCNT        (FMULCNT)
	,.FDIVCNT        (FDIVCNT)
	,.MAXPENDINGACK  (MAXPENDINGACK)
	,.VERSION        (VERSION)

) pu (

	 .rst_i (rst_i)

	,.rst_o (rst_ow[genpu_idx])

	,.clk_i          (clk_i)
	,.clk_imul_i     (clk_imul_i)
	,.clk_idiv_i     (clk_idiv_i)
	,.clk_faddfsub_i (clk_faddfsub_i)
	,.clk_fmul_i     (clk_fmul_i)
	,.clk_fdiv_i     (clk_fdiv_i)

	,.wb_cyc_o  (arbiter_wb_cyc_i[genpu_idx])
	,.wb_stb_o  (arbiter_wb_stb_i[genpu_idx])
	,.wb_we_o   (arbiter_wb_we_i[genpu_idx])
	,.wb_addr_o (arbiter_wb_addr_i[genpu_idx])
	,.wb_sel_o  (arbiter_wb_sel_i[genpu_idx])
	,.wb_dat_o  (arbiter_wb_dat_i[genpu_idx])
	,.wb_bsy_i  (arbiter_wb_bsy_o[genpu_idx])
	,.wb_ack_i  (arbiter_wb_ack_o[genpu_idx])
	,.wb_dat_i  (arbiter_wb_dat_o[genpu_idx])

	,.irq_stb_i (irq_stb_i[genpu_idx])
	,.irq_rdy_o (irq_rdy_o[genpu_idx])
	,.halted_o  (halted_o[genpu_idx])

	,.rstaddr_i (genpu_idx ? rstaddr2_i : rstaddr_i)

	,.id_i (id_i + genpu_idx)

	`ifdef PUDBG
	,.brkonrst_i (genpu_idx ? 1'b0 : brkonrst_i)
	,.dbg_rx_rcvd_i (dbg_rx_rcvd_i)
	,.dbg_rx_data_i (dbg_rx_data_i)
	,.dbg_rx_rdy_o  (dbg_rx_rdy_o)
	,.dbg_tx_stb_o  (dbg_tx_stb_o_[genpu_idx])
	,.dbg_tx_data_o (dbg_tx_data_o_[genpu_idx])
	,.dbg_tx_rdy_i  (dbg_tx_rdy_i)
	`endif
);

assign _arbiter_wb_cyc_i[genpu_idx] = arbiter_wb_cyc_i[genpu_idx];
assign _arbiter_wb_stb_i[genpu_idx] = arbiter_wb_stb_i[genpu_idx];
assign _arbiter_wb_we_i[genpu_idx] = arbiter_wb_we_i[genpu_idx];
assign _arbiter_wb_addr_i[((genpu_idx+1) * XADDRBITSZ) -1 : (genpu_idx * XADDRBITSZ)] =
	arbiter_wb_addr_i[genpu_idx];
assign _arbiter_wb_sel_i[((genpu_idx+1) * (XWORDBITSZ/8)) -1 : (genpu_idx * (XWORDBITSZ/8))] =
	arbiter_wb_sel_i[genpu_idx];
assign _arbiter_wb_dat_i[((genpu_idx+1) * XWORDBITSZ) -1 : (genpu_idx * XWORDBITSZ)] =
	arbiter_wb_dat_i[genpu_idx];
assign arbiter_wb_bsy_o[genpu_idx] = arbiter_wb_bsy_o_[genpu_idx];
assign arbiter_wb_ack_o[genpu_idx] = arbiter_wb_ack_o_[genpu_idx];
assign arbiter_wb_dat_o[genpu_idx] =
	arbiter_wb_dat_o_[((genpu_idx+1) * XWORDBITSZ) -1 : (genpu_idx * XWORDBITSZ)];

end endgenerate

endmodule
