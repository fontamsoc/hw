// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1Q_TO_WB4_V
`define PI1Q_TO_WB4_V

`include "lib/perint/pi1q.v"

`include "lib/addr.v"

module pi1q_to_wb4 (

	 wb4_rst_i

	,pi1_clk_i
	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,wb4_clk_i
	,wb4_cyc_o
	,wb4_stb_o
	,wb4_we_o
	,wb4_addr_o
	,wb4_data_o
	,wb4_sel_o
	,wb4_stall_i
	,wb4_ack_i
	,wb4_data_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire wb4_rst_i;

input wire                         pi1_clk_i;
input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;

input wire                        wb4_clk_i;
output reg                        wb4_cyc_o;
output reg                        wb4_stb_o;
output reg                        wb4_we_o;
output reg [ARCHBITSZ -1 : 0]     wb4_addr_o;
output reg [ARCHBITSZ -1 : 0]     wb4_data_o;
output reg [(ARCHBITSZ/8) -1 : 0] wb4_sel_o;
input wire                        wb4_stall_i;
input wire                        wb4_ack_i;
input wire [ARCHBITSZ -1 : 0]     wb4_data_i;

localparam PI1QMASTERCOUNT       = 1;
localparam PI1QARCHBITSZ         = ARCHBITSZ;
localparam CLOG2PI1QARCHBITSZBY8 = clog2(PI1QARCHBITSZ/8);
localparam PI1QADDRBITSZ         = (PI1QARCHBITSZ-CLOG2PI1QARCHBITSZBY8);

wire pi1q_rst_w = wb4_rst_i;
wire m_pi1q_clk_w = pi1_clk_i;
wire s_pi1q_clk_w = wb4_clk_i;
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

assign m_pi1q_op_w[0] = pi1_op_i;
assign m_pi1q_addr_w[0] = pi1_addr_i;
assign m_pi1q_data_w1[0] = pi1_data_i;
assign pi1_data_o = m_pi1q_data_w0[0];
assign m_pi1q_sel_w[0] = pi1_sel_i;
assign pi1_rdy_o = m_pi1q_rdy_w[0];

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg wrpending;

reg [2 -1 : 0]         s_pi1q_op_w_hold;
reg [ARCHBITSZ -1 : 0] wb4_data_i_hold;

wire not_wrpending_and_wb4_ack_i = (!wrpending && wb4_ack_i);

assign s_pi1q_data_w1 = not_wrpending_and_wb4_ack_i ?
	((s_pi1q_op_w_hold == PIRWOP) ? wb4_data_i_hold : wb4_data_i) :
	{ARCHBITSZ{1'b0}};

assign s_pi1q_rdy_w = (/*!wb4_rst_i &&*/(!wb4_cyc_o || not_wrpending_and_wb4_ack_i));

wire [ARCHBITSZ -1 : 0] wb4_addr_w;

addr #(
	.ARCHBITSZ (ARCHBITSZ)
) addr (
	 .addr_i (s_pi1q_addr_w)
	,.sel_i  (s_pi1q_sel_w)
	,.addr_o (wb4_addr_w)
);

always @ (posedge wb4_clk_i) begin

	if (wb4_rst_i) begin

		wb4_cyc_o <= 0;
		wb4_stb_o <= 0;
		wrpending <= 0;

	end else if (s_pi1q_rdy_w) begin

		s_pi1q_op_w_hold <= s_pi1q_op_w;
		wb4_addr_o <= wb4_addr_w;
		wb4_data_o <= s_pi1q_data_w0;
		wb4_sel_o <= s_pi1q_sel_w;

		if (s_pi1q_op_w == PIRDOP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 0;

		end else if (s_pi1q_op_w == PIWROP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 1;

		end else if (s_pi1q_op_w == PIRWOP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 0;
			wrpending <= 1;

		end else begin

			wb4_cyc_o <= 0;
			wb4_stb_o <= 0;
			wb4_we_o <= 0;
		end

	end else if (wrpending && wb4_ack_i) begin

		wb4_data_i_hold <= wb4_data_i;

		wb4_stb_o <= 1;
		wb4_we_o <= 1;
		wrpending <= 0;

	end else if (!wb4_stall_i)
		wb4_stb_o <= 0; // Request accepted.
end

initial begin
	wb4_cyc_o = 0;
	wb4_stb_o = 0;
	wb4_we_o = 0;
	wb4_addr_o = 0;
	wb4_data_o = 0;
	wb4_sel_o = 0;
	wb4_data_i_hold = 0;
	s_pi1q_op_w_hold = 0;
	wrpending = 0;
end

endmodule

`endif /* PI1Q_TO_WB4_V */
