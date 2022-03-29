// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1Q_TO_LITEDRAM_V
`define PI1Q_TO_LITEDRAM_V

`include "lib/perint/pi1q.v"

module pi1q_to_litedram (

	 litedram_rst_i

	,pi1_clk_i
	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,litedram_clk_i
	,litedram_cmd_ready_i
	,litedram_cmd_valid_o
	,litedram_cmd_we_o
	,litedram_cmd_addr_o
	,litedram_wdata_ready_i
	,litedram_wdata_valid_o
	,litedram_wdata_we_o
	,litedram_wdata_data_o
	,litedram_rdata_valid_i
	,litedram_rdata_data_i
	,litedram_rdata_ready_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire litedram_rst_i;

input  wire                        pi1_clk_i;
input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;

input wire litedram_clk_i;

input  wire                    litedram_cmd_ready_i;
output wire                    litedram_cmd_valid_o;
output wire                    litedram_cmd_we_o;
output wire [ADDRBITSZ -1 : 0] litedram_cmd_addr_o;

input  wire                        litedram_wdata_ready_i;
output wire                        litedram_wdata_valid_o;
output reg  [(ARCHBITSZ/8) -1 : 0] litedram_wdata_we_o = 0;
output reg  [ARCHBITSZ -1 : 0]     litedram_wdata_data_o = 0;

input  wire                    litedram_rdata_valid_i;
input  wire [ARCHBITSZ -1 : 0] litedram_rdata_data_i;
output wire                    litedram_rdata_ready_o;

localparam PI1QMASTERCOUNT       = 1;
localparam PI1QARCHBITSZ         = ARCHBITSZ;
localparam CLOG2PI1QARCHBITSZBY8 = clog2(PI1QARCHBITSZ/8);
localparam PI1QADDRBITSZ         = (PI1QARCHBITSZ-CLOG2PI1QARCHBITSZBY8);

wire pi1q_rst_w = litedram_rst_i;
wire m_pi1q_clk_w = pi1_clk_i;
wire s_pi1q_clk_w = litedram_clk_i;
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

reg [ARCHBITSZ -1 : 0] s_pi1q_data_w1_;
assign s_pi1q_data_w1 = s_pi1q_data_w1_;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [2 -1 : 0] state = PINOOP;

reg donereading = 0;

reg [(ARCHBITSZ/8) -1 : 0] litedram_wdata_we_o_ = 0;
reg [ARCHBITSZ -1 : 0]     litedram_wdata_data_o_ = 0;
reg [ADDRBITSZ -1 : 0]     litedram_cmd_addr_o_ = 0;

assign litedram_cmd_valid_o = ((state == PINOOP) ?
	(s_pi1q_op_w != PINOOP) : (state == PIRWOP && (litedram_rdata_valid_i || donereading)));
assign litedram_cmd_we_o    = ((state == PINOOP) ? (s_pi1q_op_w == PIWROP) : (state == PIRWOP));
assign litedram_cmd_addr_o  = ((state == PINOOP) ? s_pi1q_addr_w : litedram_cmd_addr_o_);

assign s_pi1q_rdy_w = (state == PINOOP);

assign litedram_wdata_valid_o = (state == PIWROP);

assign litedram_rdata_ready_o = 1;

always @ (posedge litedram_clk_i) begin
	if (litedram_rst_i || (state == PIWROP && litedram_wdata_ready_i))
		state <= PINOOP;
	else if ((state == PIRDOP || state == PIRWOP) &&
		(litedram_rdata_valid_i || donereading)) begin
		if (state == PIRDOP)
			state <= PINOOP;
		else if (state == PIRWOP && litedram_cmd_ready_i) begin
			state <= PIWROP;
			litedram_wdata_we_o <= litedram_wdata_we_o_;
			litedram_wdata_data_o <= litedram_wdata_data_o_;
		end
		if (!donereading) begin
			donereading <= 1;
			s_pi1q_data_w1_ <= litedram_rdata_data_i;
		end
	end else if (state == PINOOP) begin
		if (litedram_cmd_ready_i && s_pi1q_op_w == PIWROP) begin
			state <= PIWROP;
			litedram_wdata_we_o <= s_pi1q_sel_w;
			litedram_wdata_data_o <= s_pi1q_data_w0;
		end else if (litedram_cmd_ready_i && s_pi1q_op_w == PIRDOP) begin
			state <= PIRDOP;
			donereading <= 0;
		end else if (litedram_cmd_ready_i && s_pi1q_op_w == PIRWOP) begin
			state <= PIRWOP;
			donereading <= 0;
			litedram_wdata_we_o_ <= s_pi1q_sel_w;
			litedram_wdata_data_o_ <= s_pi1q_data_w0;
			litedram_cmd_addr_o_ <= litedram_cmd_addr_o;
		end
	end
end

endmodule

`endif /* PI1Q_TO_LITEDRAM_V */
