// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Macros:
//
// PUCOUNT
// 	Number of PU making up the multipu.
// 	When defined, it must be non-null.
// 	When not defined, clk_mem_i is not available.

// Ports:
//
// rstaddr2_i
// 	Address where PUs with non-null id_i begin executing
// 	instructions when woken-up. It is to be a 32bits address
// 	for which the least significant bit has been discarded.
//
// Refer to documentation in pu.v head for remaining parameters and ports.

`include "./pu.v"

`ifdef PUCOUNT
`include "lib/perint/pi1q.v"
`else
`include "lib/perint/pi1b.v"
`endif

module multipu (

	 rst_i

	,rst_o

	,clk_i
	,clk_imul_i
	,clk_idiv_i
	,clk_faddfsub_i
	,clk_fmul_i
	,clk_fdiv_i
	`ifdef PUCOUNT
	,clk_mem_i
	`endif

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
parameter IMULCNT        = 2;
parameter IDIVCNT        = 2;
parameter FADDFSUBCNT    = 1;
parameter FMULCNT        = 1;
parameter FDIVCNT        = 1;
parameter VERSION        = {8'd1/*major-version*/, 8'd0/*minor-version*/};

parameter ARCHBITSZ  = 16;
parameter XARCHBITSZ = 16;

localparam CLOG2XARCHBITSZBY8 = clog2(XARCHBITSZ/8);
localparam XADDRBITSZ = (XARCHBITSZ-CLOG2XARCHBITSZBY8);

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

input wire rst_i;

output wire rst_o;

input wire clk_i;
input wire clk_imul_i;
input wire clk_idiv_i;
input wire clk_faddfsub_i;
input wire clk_fmul_i;
input wire clk_fdiv_i;
`ifdef PUCOUNT
input wire clk_mem_i;
`endif

output wire [2 -1 : 0]              pi1_op_o;
output wire [XADDRBITSZ -1 : 0]     pi1_addr_o;
output wire [XARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [XARCHBITSZ -1 : 0]     pi1_data_i;
output wire [(XARCHBITSZ/8) -1 : 0] pi1_sel_o;
input  wire                         pi1_rdy_i;

input  wire [PUCOUNT -1 : 0] intrqst_i;
output wire [PUCOUNT -1 : 0] intrdy_o;
output wire [PUCOUNT -1 : 0] halted_o;

input wire [(ARCHBITSZ-1) -1 : 0] rstaddr_i;
input wire [(ARCHBITSZ-1) -1 : 0] rstaddr2_i;

input wire [ARCHBITSZ -1 : 0] id_i;

`ifdef PUDBG
input  wire            brkonrst_i;
input  wire            dbg_rx_rcvd_i;
input  wire [8 -1 : 0] dbg_rx_data_i;
output wire            dbg_rx_rdy_o;
output reg             dbg_tx_stb_o;  // ### declared as reg so as to be usable by verilog within the always block.
output reg  [8 -1 : 0] dbg_tx_data_o; // ### declared as reg so as to be usable by verilog within the always block.
input  wire            dbg_tx_rdy_i;
`endif

`ifdef SIMULATION
output wire [(ARCHBITSZ * PUCOUNT) -1 : 0] pc_o;
`endif

`ifdef PUCOUNT
localparam PI1QMASTERCOUNT       = PUCOUNT;
localparam PI1QARCHBITSZ         = XARCHBITSZ;
localparam CLOG2PI1QARCHBITSZBY8 = clog2(PI1QARCHBITSZ/8);
localparam PI1QADDRBITSZ         = (PI1QARCHBITSZ-CLOG2PI1QARCHBITSZBY8);
wire pi1q_rst_w = rst_i;
wire m_pi1q_clk_w = clk_i;
wire s_pi1q_clk_w = clk_mem_i;
// PerIntQ is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerIntQ:
// 	input  [2 -1 : 0]                 m_pi1q_op_w    [PI1QMASTERCOUNT -1 : 0];
// 	input  [PI1QADDRBITSZ -1 : 0]     m_pi1q_addr_w  [PI1QMASTERCOUNT -1 : 0];
// 	input  [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w1 [PI1QMASTERCOUNT -1 : 0];
// 	output [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w0 [PI1QMASTERCOUNT -1 : 0];
// 	input  [(PI1QARCHBITSZ/8) -1 : 0] m_pi1q_sel_w   [PI1QMASTERCOUNT -1 : 0];
// 	output                            m_pi1q_rdy_w   [PI1QMASTERCOUNT -1 : 0];
// Slave should use the following signals to plug onto PerIntQ:
// 	output [2 -1 : 0]                 s_pi1q_op_w;
// 	output [PI1QADDRBITSZ -1 : 0]     s_pi1q_addr_w;
// 	output [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w0;
// 	input  [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w1;
// 	output [(PI1QARCHBITSZ/8) -1 : 0] s_pi1q_sel_w;
// 	input                             s_pi1q_rdy_w;
`include "lib/perint/inst.pi1q.v"
assign pi1_op_o       = s_pi1q_op_w;
assign pi1_addr_o     = s_pi1q_addr_w;
assign s_pi1q_data_w1 = pi1_data_i;
assign pi1_data_o     = s_pi1q_data_w0;
assign pi1_sel_o      = s_pi1q_sel_w;
assign s_pi1q_rdy_w   = pi1_rdy_i;
`else
wire [2 -1 : 0]              pi1b_op_o;
wire [XADDRBITSZ -1 : 0]     pi1b_addr_o;
wire [XARCHBITSZ -1 : 0]     pi1b_data_o;
wire [XARCHBITSZ -1 : 0]     pi1b_data_i;
wire [(XARCHBITSZ/8) -1 : 0] pi1b_sel_o;
wire                         pi1b_rdy_i;
pi1b #(

	.ARCHBITSZ (XARCHBITSZ)

) pi1b (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_op_i (pi1b_op_o)
	,.m_addr_i (pi1b_addr_o)
	,.m_data_i (pi1b_data_o)
	,.m_data_o (pi1b_data_i)
	,.m_sel_i (pi1b_sel_o)
	,.m_rdy_o (pi1b_rdy_i)

	,.s_op_o (pi1_op_o)
	,.s_addr_o (pi1_addr_o)
	,.s_data_o (pi1_data_o)
	,.s_data_i (pi1_data_i)
	,.s_sel_o (pi1_sel_o)
	,.s_rdy_i (pi1_rdy_i)
);
`endif

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

`ifdef SIMULATION
wire [ARCHBITSZ -1 : 0] pc_w [PUCOUNT -1 : 0];
`endif

genvar genpu_idx;
generate for (genpu_idx = 0; genpu_idx < PUCOUNT; genpu_idx = genpu_idx + 1) begin :genpu
`ifdef SIMULATION
assign pc_o[((genpu_idx+1) * ARCHBITSZ) -1 : genpu_idx * ARCHBITSZ] = pc_w[genpu_idx];
`endif
pu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (XARCHBITSZ)
	,.CLKFREQ        (CLKFREQ)
	,.ICACHESETCOUNT (ICACHESETCOUNT)
	,.DCACHESETCOUNT (DCACHESETCOUNT)
	,.TLBSETCOUNT    (TLBSETCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.IMULCNT        (IMULCNT)
	,.IDIVCNT        (IDIVCNT)
	,.FADDFSUBCNT    (FADDFSUBCNT)
	,.FMULCNT        (FMULCNT)
	,.FDIVCNT        (FDIVCNT)
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

	`ifdef PUCOUNT
	,.pi1_op_o   (m_pi1q_op_w[genpu_idx])
	,.pi1_addr_o (m_pi1q_addr_w[genpu_idx])
	,.pi1_data_o (m_pi1q_data_w1[genpu_idx])
	,.pi1_data_i (m_pi1q_data_w0[genpu_idx])
	,.pi1_sel_o  (m_pi1q_sel_w[genpu_idx])
	,.pi1_rdy_i  (m_pi1q_rdy_w[genpu_idx])
	`else
	,.pi1_op_o   (pi1b_op_o)
	,.pi1_addr_o (pi1b_addr_o)
	,.pi1_data_o (pi1b_data_o)
	,.pi1_data_i (pi1b_data_i)
	,.pi1_sel_o  (pi1b_sel_o)
	,.pi1_rdy_i  (pi1b_rdy_i)
	`endif

	,.intrqst_i (intrqst_i[genpu_idx])
	,.intrdy_o  (intrdy_o[genpu_idx])
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

	`ifdef SIMULATION
	,.pc_o (pc_w[genpu_idx])
	`endif
);
end endgenerate

endmodule
