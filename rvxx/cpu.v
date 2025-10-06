// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Parameters:
//
// PUCNT
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

	,wb_cyc_o
	,wb_stb_o
	,wb_we_o
	,wb_addr_o
	,wb_sel_o
	,wb_dat_o
	,wb_bsy_i
	,wb_ack_i
	,wb_dat_i

	,dcache_addr_o
	,dcache_miss_i

	,irq_stb_i
	,irq_stb_o
	,irq_rdy_o
	,halted_o

	,rstaddr_i
	,rstaddr2_i

	,spval_i

	,id_i
);

`include "lib/clog2.v"

parameter WORDBITSZ     = 32;
parameter XWORDBITSZ    = 32; // TODO: Support all the way up to 1024 ...
parameter ADDRLIMIT     = 'h2000;
parameter CLKFREQ       = 1;
parameter ICACHESETCNT  = 2;
parameter DCACHESETCNT  = 0;
parameter ICACHEWAYCNT  = 1;
parameter DCACHEWAYCNT  = 1;
parameter IMULCNT       = 2;
parameter IDIVCNT       = 2;
parameter MAXPENDINGACK = 16;
parameter PUCNT         = 1;

localparam CLOG2XWORDBITSZBY8 = clog2(XWORDBITSZ/8);
localparam XADDRBITSZ = (XWORDBITSZ-CLOG2XWORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam XMSBSZIGN = (XWORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

output wire rst_o;

input wire clk_i;
input wire clk_mem_i;
input wire clk_imul_i;
input wire clk_idiv_i;

output wire                                 wb_cyc_o;
output wire                                 wb_stb_o;
output wire                                 wb_we_o;
output wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] wb_addr_o;
output wire [(XWORDBITSZ/8) -1 : 0]         wb_sel_o;
output wire [XWORDBITSZ -1 : 0]             wb_dat_o;
input  wire                                 wb_bsy_i;
input  wire                                 wb_ack_i;
input  wire [XWORDBITSZ -1 : 0]             wb_dat_i;

output wire [((XWORDBITSZ-XMSBSZIGN)*PUCNT) -1 : 0] dcache_addr_o;
input  wire [PUCNT -1 : 0]                          dcache_miss_i;

input  wire [PUCNT -1 : 0] irq_stb_i;
output wire [PUCNT -1 : 0] irq_stb_o;
output wire [PUCNT -1 : 0] irq_rdy_o;
output wire [PUCNT -1 : 0] halted_o;

input wire [WORDBITSZ -1 : 0] rstaddr_i;
input wire [WORDBITSZ -1 : 0] rstaddr2_i;

input wire [WORDBITSZ -1 : 0] spval_i;

input wire [WORDBITSZ -1 : 0] id_i;

wire                                 arbiter_wb_cyc_i  [PUCNT];
wire                                 arbiter_wb_stb_i  [PUCNT];
wire                                 arbiter_wb_we_i   [PUCNT];
wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] arbiter_wb_addr_i [PUCNT];
wire [(XWORDBITSZ/8) -1 : 0]         arbiter_wb_sel_i  [PUCNT];
wire [XWORDBITSZ -1 : 0]             arbiter_wb_dat_i  [PUCNT];
wire                                 arbiter_wb_bsy_o  [PUCNT];
wire                                 arbiter_wb_ack_o  [PUCNT];
wire [XWORDBITSZ -1 : 0]             arbiter_wb_dat_o  [PUCNT];

wire [(1 * PUCNT) -1 : 0]                      _arbiter_wb_cyc_i;
wire [(1 * PUCNT) -1 : 0]                      _arbiter_wb_stb_i;
wire [(1 * PUCNT) -1 : 0]                      _arbiter_wb_we_i;
wire [((XADDRBITSZ-XMSBSZIGN) * PUCNT) -1 : 0] _arbiter_wb_addr_i;
wire [((XWORDBITSZ/8) * PUCNT) -1 : 0]         _arbiter_wb_sel_i;
wire [(XWORDBITSZ * PUCNT) -1 : 0]             _arbiter_wb_dat_i;
wire [(1 * PUCNT) -1 : 0]                      arbiter_wb_bsy_o_;
wire [(1 * PUCNT) -1 : 0]                      arbiter_wb_ack_o_;
wire [(XWORDBITSZ * PUCNT) -1 : 0]             arbiter_wb_dat_o_;

wire                                 wb_cyc_o_;
wire                                 wb_stb_o_;
wire                                 wb_we_o_;
wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] wb_addr_o_;
wire [(XWORDBITSZ/8) -1 : 0]         wb_sel_o_;
wire [XWORDBITSZ -1 : 0]             wb_dat_o_;
wire                                 _wb_bsy_i;
wire                                 _wb_ack_i;
wire [XWORDBITSZ -1 : 0]             _wb_dat_i;

generate if (PUCNT > 1) begin: gen_wb_arbiter

wb_arbiter #(
	 .WORDBITSZ   (XWORDBITSZ)
	,.ADDRLIMIT   (ADDRLIMIT)
	,.MASTERCOUNT (PUCNT)
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

end else begin

assign wb_cyc_o_ = _arbiter_wb_cyc_i;
assign wb_stb_o_ = _arbiter_wb_stb_i;
assign wb_we_o_ = _arbiter_wb_we_i;
assign wb_addr_o_ = _arbiter_wb_addr_i;
assign wb_sel_o_ = _arbiter_wb_sel_i;
assign wb_dat_o_ = _arbiter_wb_dat_i;
assign arbiter_wb_bsy_o_ = _wb_bsy_i;
assign arbiter_wb_ack_o_ = _wb_ack_i;
assign arbiter_wb_dat_o_ = _wb_dat_i;

end endgenerate

wb_cdc #(
	 .WORDBITSZ     (XWORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
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

wire [PUCNT -1 : 0] rst_ow;
assign rst_o = |rst_ow;

genvar genpu_idx;
generate for (
	genpu_idx = 0;
	genpu_idx < PUCNT;
	genpu_idx = genpu_idx + 1) begin :genpu

pu #(
	 .WORDBITSZ     (WORDBITSZ)
	,.XWORDBITSZ    (XWORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.CLKFREQ       (CLKFREQ)
	,.ICACHESETCNT  (ICACHESETCNT)
	,.DCACHESETCNT  ((PUCNT > 1) ? 0 : DCACHESETCNT) /* TODO: cache-coherence */
	,.ICACHEWAYCNT  (ICACHEWAYCNT)
	,.DCACHEWAYCNT  (DCACHEWAYCNT)
	,.IMULCNT       (IMULCNT)
	,.IDIVCNT       (IDIVCNT)
	,.MAXPENDINGACK (MAXPENDINGACK)
) pu (

	 .rst_i (rst_i)

	,.rst_o (rst_ow[genpu_idx])

	,.clk_i      (clk_i)
	,.clk_imul_i (clk_imul_i)
	,.clk_idiv_i (clk_idiv_i)

	,.wb_cyc_o  (arbiter_wb_cyc_i[genpu_idx])
	,.wb_stb_o  (arbiter_wb_stb_i[genpu_idx])
	,.wb_we_o   (arbiter_wb_we_i[genpu_idx])
	,.wb_addr_o (arbiter_wb_addr_i[genpu_idx])
	,.wb_sel_o  (arbiter_wb_sel_i[genpu_idx])
	,.wb_dat_o  (arbiter_wb_dat_i[genpu_idx])
	,.wb_bsy_i  (arbiter_wb_bsy_o[genpu_idx])
	,.wb_ack_i  (arbiter_wb_ack_o[genpu_idx])
	,.wb_dat_i  (arbiter_wb_dat_o[genpu_idx])

	,.dcache_addr_o (dcache_addr_o[((genpu_idx+1) * (XWORDBITSZ-XMSBSZIGN)) -1 : genpu_idx * (XWORDBITSZ-XMSBSZIGN)])
	,.dcache_miss_i (dcache_miss_i[genpu_idx])

	,.irq_stb_i (irq_stb_i[genpu_idx])
	,.irq_stb_o (irq_stb_o[genpu_idx])
	,.irq_rdy_o (irq_rdy_o[genpu_idx])
	,.halted_o  (halted_o[genpu_idx])

	,.rstaddr_i (genpu_idx ? rstaddr2_i : rstaddr_i)

	,.spval_i (spval_i)

	,.id_i (id_i + genpu_idx)
);

assign _arbiter_wb_cyc_i[genpu_idx] = arbiter_wb_cyc_i[genpu_idx];
assign _arbiter_wb_stb_i[genpu_idx] = arbiter_wb_stb_i[genpu_idx];
assign _arbiter_wb_we_i[genpu_idx] = arbiter_wb_we_i[genpu_idx];
assign _arbiter_wb_addr_i[((genpu_idx+1) * (XADDRBITSZ-XMSBSZIGN)) -1 : (genpu_idx * (XADDRBITSZ-XMSBSZIGN))] =
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
