// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_DOWNCONVERTER_V
`define PI1_DOWNCONVERTER_V

// (MARCHBITSZ >= SARCHBITSZ) must be true.

module pi1_downconverter (

	clk_i

	,m_pi1_op_i
	,m_pi1_addr_i
	,m_pi1_data_i
	,m_pi1_data_o
	,m_pi1_sel_i
	,m_pi1_rdy_o
	,m_pi1_mapsz_o

	,s_pi1_op_o
	,s_pi1_addr_o
	,s_pi1_data_i
	,s_pi1_data_o
	,s_pi1_sel_o
	,s_pi1_rdy_i
	,s_pi1_mapsz_i
);

`include "lib/clog2.v"

parameter MARCHBITSZ = 0;
parameter SARCHBITSZ = 0;

localparam CLOG2MARCHBITSZBY8 = clog2(MARCHBITSZ/8);
localparam CLOG2SARCHBITSZBY8 = clog2(SARCHBITSZ/8);

localparam MADDRBITSZ = (MARCHBITSZ-CLOG2MARCHBITSZBY8);
localparam SADDRBITSZ = (SARCHBITSZ-CLOG2SARCHBITSZBY8);

input wire clk_i;

input  wire [2 -1 : 0]              m_pi1_op_i;
input  wire [MADDRBITSZ -1 : 0]     m_pi1_addr_i;
input  wire [MARCHBITSZ -1 : 0]     m_pi1_data_i;
output wire [MARCHBITSZ -1 : 0]     m_pi1_data_o;
input  wire [(MARCHBITSZ/8) -1 : 0] m_pi1_sel_i;
output wire                         m_pi1_rdy_o;
output wire [MADDRBITSZ -1 : 0]     m_pi1_mapsz_o;

output wire [2 -1 : 0]              s_pi1_op_o;
output wire [SADDRBITSZ -1 : 0]     s_pi1_addr_o;
output wire [SARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [SARCHBITSZ -1 : 0]     s_pi1_data_i;
output wire [(SARCHBITSZ/8) -1 : 0] s_pi1_sel_o;
input wire                          s_pi1_rdy_i;
input wire  [SADDRBITSZ -1 : 0]     s_pi1_mapsz_i;

assign s_pi1_op_o = m_pi1_op_i;

assign m_pi1_rdy_o = s_pi1_rdy_i;

generate if (MARCHBITSZ > SARCHBITSZ) begin :pi1_downconverter0

	wire [(256/*MARCHBITSZ*//8) -1 : 0] _m_pi1_sel_i = m_pi1_sel_i;
	// ### Net declared as reg so as to be useable by verilog within the always block.
	reg [MARCHBITSZ -1 : 0] m_pi1_addr_w;
	always @* begin
		if (MARCHBITSZ == 16)
			m_pi1_addr_w = {m_pi1_addr_i, {
				_m_pi1_sel_i[0] ? 1'b0 :
				_m_pi1_sel_i[1] ? 1'b1 : 1'b0
				/*
				_m_pi1_sel_i == 2'b11 ? 1'b0 :
				_m_pi1_sel_i == 2'b01 ? 1'b0 :
				_m_pi1_sel_i == 2'b10 ? 1'b1 : 1'b0 */}};
		else if (MARCHBITSZ == 32)
			m_pi1_addr_w = {m_pi1_addr_i, {
				_m_pi1_sel_i[0] ? 2'b00 :
				_m_pi1_sel_i[1] ? 2'b01 :
				_m_pi1_sel_i[2] ? 2'b10 :
				_m_pi1_sel_i[3] ? 2'b11 : 2'b00
				/*
				_m_pi1_sel_i == 4'b1111 ? 2'b00 :
				_m_pi1_sel_i == 4'b0011 ? 2'b00 :
				_m_pi1_sel_i == 4'b1100 ? 2'b10 :
				_m_pi1_sel_i == 4'b0001 ? 2'b00 :
				_m_pi1_sel_i == 4'b0010 ? 2'b01 :
				_m_pi1_sel_i == 4'b0100 ? 2'b10 :
				_m_pi1_sel_i == 4'b1000 ? 2'b11 : 2'b00 */}};
		else if (MARCHBITSZ == 64)
			m_pi1_addr_w = {m_pi1_addr_i, {
				_m_pi1_sel_i[0] ? 3'b000 :
				_m_pi1_sel_i[1] ? 3'b001 :
				_m_pi1_sel_i[2] ? 3'b010 :
				_m_pi1_sel_i[3] ? 3'b011 :
				_m_pi1_sel_i[4] ? 3'b100 :
				_m_pi1_sel_i[5] ? 3'b101 :
				_m_pi1_sel_i[6] ? 3'b110 :
				_m_pi1_sel_i[7] ? 3'b111 : 3'b000
				/*
				_m_pi1_sel_i == 8'b11111111 ? 3'b000 :
				_m_pi1_sel_i == 8'b00001111 ? 3'b000 :
				_m_pi1_sel_i == 8'b11110000 ? 3'b100 :
				_m_pi1_sel_i == 8'b00000011 ? 3'b000 :
				_m_pi1_sel_i == 8'b00001100 ? 3'b010 :
				_m_pi1_sel_i == 8'b00110000 ? 3'b100 :
				_m_pi1_sel_i == 8'b11000000 ? 3'b110 :
				_m_pi1_sel_i == 8'b00000001 ? 3'b000 :
				_m_pi1_sel_i == 8'b00000010 ? 3'b001 :
				_m_pi1_sel_i == 8'b00000100 ? 3'b010 :
				_m_pi1_sel_i == 8'b00001000 ? 3'b011 :
				_m_pi1_sel_i == 8'b00010000 ? 3'b100 :
				_m_pi1_sel_i == 8'b00100000 ? 3'b101 :
				_m_pi1_sel_i == 8'b01000000 ? 3'b110 :
				_m_pi1_sel_i == 8'b10000000 ? 3'b111 : 3'b000 */}};
		else if (MARCHBITSZ == 128)
			m_pi1_addr_w = {m_pi1_addr_i, {
				_m_pi1_sel_i[0]  ? 4'b0000 :
				_m_pi1_sel_i[1]  ? 4'b0001 :
				_m_pi1_sel_i[2]  ? 4'b0010 :
				_m_pi1_sel_i[3]  ? 4'b0011 :
				_m_pi1_sel_i[4]  ? 4'b0100 :
				_m_pi1_sel_i[5]  ? 4'b0101 :
				_m_pi1_sel_i[6]  ? 4'b0110 :
				_m_pi1_sel_i[7]  ? 4'b0111 :
				_m_pi1_sel_i[8]  ? 4'b1000 :
				_m_pi1_sel_i[9]  ? 4'b1001 :
				_m_pi1_sel_i[10] ? 4'b1010 :
				_m_pi1_sel_i[11] ? 4'b1011 :
				_m_pi1_sel_i[12] ? 4'b1100 :
				_m_pi1_sel_i[13] ? 4'b1101 :
				_m_pi1_sel_i[14] ? 4'b1110 :
				_m_pi1_sel_i[15] ? 4'b1111 : 4'b0000
				/*
				_m_pi1_sel_i == 16'b0000000011111111 ? 4'b0000 :
				_m_pi1_sel_i == 16'b1111111100000000 ? 4'b1000 :
				_m_pi1_sel_i == 16'b0000000000001111 ? 4'b0000 :
				_m_pi1_sel_i == 16'b0000000011110000 ? 4'b0100 :
				_m_pi1_sel_i == 16'b0000111100000000 ? 4'b1000 :
				_m_pi1_sel_i == 16'b1111000000000000 ? 4'b1100 :
				_m_pi1_sel_i == 16'b0000000000000011 ? 4'b0000 :
				_m_pi1_sel_i == 16'b0000000000001100 ? 4'b0010 :
				_m_pi1_sel_i == 16'b0000000000110000 ? 4'b0100 :
				_m_pi1_sel_i == 16'b0000000011000000 ? 4'b0110 :
				_m_pi1_sel_i == 16'b0000001100000000 ? 4'b1000 :
				_m_pi1_sel_i == 16'b0000110000000000 ? 4'b1010 :
				_m_pi1_sel_i == 16'b0011000000000000 ? 4'b1100 :
				_m_pi1_sel_i == 16'b1100000000000000 ? 4'b1110 :
				_m_pi1_sel_i == 16'b0000000000000001 ? 4'b0000 :
				_m_pi1_sel_i == 16'b0000000000000010 ? 4'b0001 :
				_m_pi1_sel_i == 16'b0000000000000100 ? 4'b0010 :
				_m_pi1_sel_i == 16'b0000000000001000 ? 4'b0011 :
				_m_pi1_sel_i == 16'b0000000000010000 ? 4'b0100 :
				_m_pi1_sel_i == 16'b0000000000100000 ? 4'b0101 :
				_m_pi1_sel_i == 16'b0000000001000000 ? 4'b0110 :
				_m_pi1_sel_i == 16'b0000000010000000 ? 4'b0111 :
				_m_pi1_sel_i == 16'b0000000100000000 ? 4'b1000 :
				_m_pi1_sel_i == 16'b0000001000000000 ? 4'b1001 :
				_m_pi1_sel_i == 16'b0000010000000000 ? 4'b1010 :
				_m_pi1_sel_i == 16'b0000100000000000 ? 4'b1011 :
				_m_pi1_sel_i == 16'b0001000000000000 ? 4'b1100 :
				_m_pi1_sel_i == 16'b0010000000000000 ? 4'b1101 :
				_m_pi1_sel_i == 16'b0100000000000000 ? 4'b1110 :
				_m_pi1_sel_i == 16'b1000000000000000 ? 4'b1111 : 4'b0000 */}};
		else if (MARCHBITSZ == 256)
			m_pi1_addr_w = {m_pi1_addr_i, {
				_m_pi1_sel_i[0]  ? 5'b00000 :
				_m_pi1_sel_i[1]  ? 5'b00001 :
				_m_pi1_sel_i[2]  ? 5'b00010 :
				_m_pi1_sel_i[3]  ? 5'b00011 :
				_m_pi1_sel_i[4]  ? 5'b00100 :
				_m_pi1_sel_i[5]  ? 5'b00101 :
				_m_pi1_sel_i[6]  ? 5'b00110 :
				_m_pi1_sel_i[7]  ? 5'b00111 :
				_m_pi1_sel_i[8]  ? 5'b01000 :
				_m_pi1_sel_i[9]  ? 5'b01001 :
				_m_pi1_sel_i[10] ? 5'b01010 :
				_m_pi1_sel_i[11] ? 5'b01011 :
				_m_pi1_sel_i[12] ? 5'b01100 :
				_m_pi1_sel_i[13] ? 5'b01101 :
				_m_pi1_sel_i[14] ? 5'b01110 :
				_m_pi1_sel_i[15] ? 5'b01111 :
				_m_pi1_sel_i[16] ? 5'b10000 :
				_m_pi1_sel_i[17] ? 5'b10001 :
				_m_pi1_sel_i[18] ? 5'b10010 :
				_m_pi1_sel_i[19] ? 5'b10011 :
				_m_pi1_sel_i[20] ? 5'b10100 :
				_m_pi1_sel_i[21] ? 5'b10101 :
				_m_pi1_sel_i[22] ? 5'b10110 :
				_m_pi1_sel_i[23] ? 5'b10111 :
				_m_pi1_sel_i[24] ? 5'b11000 :
				_m_pi1_sel_i[25] ? 5'b11001 :
				_m_pi1_sel_i[26] ? 5'b11010 :
				_m_pi1_sel_i[27] ? 5'b11011 :
				_m_pi1_sel_i[28] ? 5'b11100 :
				_m_pi1_sel_i[29] ? 5'b11101 :
				_m_pi1_sel_i[30] ? 5'b11110 :
				_m_pi1_sel_i[31] ? 5'b11111 : 5'b00000 }};
		else
			m_pi1_addr_w = {MARCHBITSZ{1'b0}};
	end
	assign s_pi1_addr_o = m_pi1_addr_w[SADDRBITSZ -1 : CLOG2SARCHBITSZBY8];

	reg [MADDRBITSZ -1 : 0] s_pi1_addr_o_hold = 0;
	always @ (posedge clk_i) begin
		if (s_pi1_rdy_i)
			s_pi1_addr_o_hold <= s_pi1_addr_o;
	end

	assign m_pi1_data_o = ({{(MARCHBITSZ-SARCHBITSZ){1'b0}}, s_pi1_data_i} <<
		(s_pi1_addr_o_hold[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0]*SARCHBITSZ));

	assign s_pi1_data_o = {m_pi1_data_i >>
		(s_pi1_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0]*SARCHBITSZ)};

	assign s_pi1_sel_o = {m_pi1_sel_i >>
		(s_pi1_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0]*(SARCHBITSZ/8))};

	assign m_pi1_mapsz_o = {
		{(MADDRBITSZ-(SADDRBITSZ-(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8))){1'b0}},
		s_pi1_mapsz_i[SADDRBITSZ -1 : (CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8)]};

end else begin  :pi1_downconverter1

	assign s_pi1_addr_o = m_pi1_addr_i;
	assign m_pi1_data_o = s_pi1_data_i;
	assign s_pi1_data_o = m_pi1_data_i;
	assign s_pi1_sel_o = m_pi1_sel_i;
	assign m_pi1_mapsz_o = s_pi1_mapsz_i;

end endgenerate

endmodule

`endif /* PI1_DOWNCONVERTER_V */
