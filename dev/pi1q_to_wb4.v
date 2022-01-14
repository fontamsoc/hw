// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1Q_TO_WB4_V
`define PI1Q_TO_WB4_V

`include "lib/perint/pi1q.v"

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

parameter ARCHBITSZ = 0;

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

localparam PI1QMASTERCOUNT = 1;
localparam PI1QARCHBITSZ   = ARCHBITSZ;
wire pi1q_rst_w = wb4_rst_i;
wire m_pi1q_clk_w = pi1_clk_i;
wire s_pi1q_clk_w = wb4_clk_i;
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

assign s_pi1q_rdy_w = (!wb4_rst_i && (!wb4_cyc_o || not_wrpending_and_wb4_ack_i));

wire [(256/8) -1 : 0] _s_pi1q_sel_w = s_pi1q_sel_w;
reg [ARCHBITSZ -1 : 0] wb4_addr_w;
always @* begin
	if (ARCHBITSZ == 16)
		wb4_addr_w = {s_pi1q_addr_w, {
			_s_pi1q_sel_w[0] ? 1'b0 :
			_s_pi1q_sel_w[1] ? 1'b1 : 1'b0 }};
	else if (ARCHBITSZ == 32)
		wb4_addr_w = {s_pi1q_addr_w, {
			_s_pi1q_sel_w[0] ? 2'b00 :
			_s_pi1q_sel_w[1] ? 2'b01 :
			_s_pi1q_sel_w[2] ? 2'b10 :
			_s_pi1q_sel_w[3] ? 2'b11 : 2'b00 }};
	else if (ARCHBITSZ == 64)
		wb4_addr_w = {s_pi1q_addr_w, {
			_s_pi1q_sel_w[0] ? 3'b000 :
			_s_pi1q_sel_w[1] ? 3'b001 :
			_s_pi1q_sel_w[2] ? 3'b010 :
			_s_pi1q_sel_w[3] ? 3'b011 :
			_s_pi1q_sel_w[4] ? 3'b100 :
			_s_pi1q_sel_w[5] ? 3'b101 :
			_s_pi1q_sel_w[6] ? 3'b110 :
			_s_pi1q_sel_w[7] ? 3'b111 : 3'b000 }};
	else if (ARCHBITSZ == 128)
		wb4_addr_w = {s_pi1q_addr_w, {
			_s_pi1q_sel_w[0]  ? 4'b0000 :
			_s_pi1q_sel_w[1]  ? 4'b0001 :
			_s_pi1q_sel_w[2]  ? 4'b0010 :
			_s_pi1q_sel_w[3]  ? 4'b0011 :
			_s_pi1q_sel_w[4]  ? 4'b0100 :
			_s_pi1q_sel_w[5]  ? 4'b0101 :
			_s_pi1q_sel_w[6]  ? 4'b0110 :
			_s_pi1q_sel_w[7]  ? 4'b0111 :
			_s_pi1q_sel_w[8]  ? 4'b1000 :
			_s_pi1q_sel_w[9]  ? 4'b1001 :
			_s_pi1q_sel_w[10] ? 4'b1010 :
			_s_pi1q_sel_w[11] ? 4'b1011 :
			_s_pi1q_sel_w[12] ? 4'b1100 :
			_s_pi1q_sel_w[13] ? 4'b1101 :
			_s_pi1q_sel_w[14] ? 4'b1110 :
			_s_pi1q_sel_w[15] ? 4'b1111 : 4'b0000 }};
	else if (ARCHBITSZ == 256)
		wb4_addr_w = {s_pi1q_addr_w, {
			_s_pi1q_sel_w[0]  ? 5'b00000 :
			_s_pi1q_sel_w[1]  ? 5'b00001 :
			_s_pi1q_sel_w[2]  ? 5'b00010 :
			_s_pi1q_sel_w[3]  ? 5'b00011 :
			_s_pi1q_sel_w[4]  ? 5'b00100 :
			_s_pi1q_sel_w[5]  ? 5'b00101 :
			_s_pi1q_sel_w[6]  ? 5'b00110 :
			_s_pi1q_sel_w[7]  ? 5'b00111 :
			_s_pi1q_sel_w[8]  ? 5'b01000 :
			_s_pi1q_sel_w[9]  ? 5'b01001 :
			_s_pi1q_sel_w[10] ? 5'b01010 :
			_s_pi1q_sel_w[11] ? 5'b01011 :
			_s_pi1q_sel_w[12] ? 5'b01100 :
			_s_pi1q_sel_w[13] ? 5'b01101 :
			_s_pi1q_sel_w[14] ? 5'b01110 :
			_s_pi1q_sel_w[15] ? 5'b01111 :
			_s_pi1q_sel_w[16] ? 5'b10000 :
			_s_pi1q_sel_w[17] ? 5'b10001 :
			_s_pi1q_sel_w[18] ? 5'b10010 :
			_s_pi1q_sel_w[19] ? 5'b10011 :
			_s_pi1q_sel_w[20] ? 5'b10100 :
			_s_pi1q_sel_w[21] ? 5'b10101 :
			_s_pi1q_sel_w[22] ? 5'b10110 :
			_s_pi1q_sel_w[23] ? 5'b10111 :
			_s_pi1q_sel_w[24] ? 5'b11000 :
			_s_pi1q_sel_w[25] ? 5'b11001 :
			_s_pi1q_sel_w[26] ? 5'b11010 :
			_s_pi1q_sel_w[27] ? 5'b11011 :
			_s_pi1q_sel_w[28] ? 5'b11100 :
			_s_pi1q_sel_w[29] ? 5'b11101 :
			_s_pi1q_sel_w[30] ? 5'b11110 :
			_s_pi1q_sel_w[31] ? 5'b11111 : 5'b00000 }};
	else
		wb4_addr_w = {ARCHBITSZ{1'b0}};
end

always @ (posedge wb4_clk_i) begin

	if (wb4_rst_i) begin

		wb4_cyc_o <= 0;
		wb4_stb_o <= 0;
		wrpending <= 0;

	end else if (s_pi1q_rdy_w) begin

		s_pi1q_op_w_hold <= s_pi1q_op_w;
		wb4_addr_o <= wb4_addr_w;
		wb4_data_o <= s_pi1q_data_w0;
		wb4_sel_o <= _s_pi1q_sel_w;

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
		wb4_stb_o <= 0;
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

`endif
