// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "./pu.v"

`include "lib/perint/pi1q.v"

module multipu (

	 rst_i

	,rst_o

	,clk_i
	,clk_mem_i

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
);

`include "lib/clog2.v"

parameter PUCOUNT        = 2;
parameter CLKFREQ        = 1;
parameter ICACHESETCOUNT = 2;
parameter DCACHESETCOUNT = 2;
parameter TLBSETCOUNT    = 2;

parameter ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

output wire rst_o;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
input wire [2 -1 : 0] clk_mem_i;
`else
input wire [1 -1 : 0] clk_i;
input wire [1 -1 : 0] clk_mem_i;
`endif

output wire [2 -1 : 0]             pi1_op_o;
output wire [ADDRBITSZ -1 : 0]     pi1_addr_o;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_o;
input  wire                        pi1_rdy_i;

input  wire [PUCOUNT -1 : 0] intrqst_i;
output wire [PUCOUNT -1 : 0] intrdy_o;
output wire [PUCOUNT -1 : 0] halted_o;

input wire [(ARCHBITSZ-1) -1 : 0] rstaddr_i;
input wire [(ARCHBITSZ-1) -1 : 0] rstaddr2_i;

input wire [ARCHBITSZ -1 : 0] id_i;

localparam PI1QMASTERCOUNT = PUCOUNT;
localparam PI1QARCHBITSZ   = ARCHBITSZ;
wire pi1q_rst_w = rst_i;
wire m_pi1q_clk_w = clk_i;
wire s_pi1q_clk_w = clk_mem_i;
`include "lib/perint/inst.pi1q.v"

assign pi1_op_o       = s_pi1q_op_w;
assign pi1_addr_o     = s_pi1q_addr_w;
assign s_pi1q_data_w1 = pi1_data_i;
assign pi1_data_o     = s_pi1q_data_w0;
assign pi1_sel_o      = s_pi1q_sel_w;
assign s_pi1q_rdy_w   = pi1_rdy_i;

wire [PUCOUNT -1 : 0] rst_ow;
assign rst_o = |rst_ow;

generate for (i = 0; i < PUCOUNT; i = i + 1) begin :genpu
pu #(

	 .CLKFREQ        (CLKFREQ)
	,.ICACHESETCOUNT (ICACHESETCOUNT)
	,.DCACHESETCOUNT (DCACHESETCOUNT)
	,.TLBSETCOUNT    (TLBSETCOUNT)

) pu (

	 .rst_i (rst_i)

	,.rst_o (rst_ow[i])

	,.clk_i (clk_i)

	,.pi1_op_o   (m_pi1q_op_w[i])
	,.pi1_addr_o (m_pi1q_addr_w[i])
	,.pi1_data_o (m_pi1q_data_w1[i])
	,.pi1_data_i (m_pi1q_data_w0[i])
	,.pi1_sel_o  (m_pi1q_sel_w[i])
	,.pi1_rdy_i  (m_pi1q_rdy_w[i])

	,.intrqst_i (intrqst_i[i])
	,.intrdy_o  (intrdy_o[i])
	,.halted_o  (halted_o[i])

	,.rstaddr_i (i ? rstaddr2_i : rstaddr_i)

	,.id_i (id_i + i)
);
end endgenerate

endmodule
