// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1B_V
`define PI1B_V

module pi1b (

	 rst_i

	,clk_i

	,m_op_i
	,m_addr_i
	,m_data_i
	,m_data_o
	,m_sel_i
	,m_rdy_o

	,s_op_o
	,s_addr_o
	,s_data_o
	,s_data_i
	,s_sel_o
	,s_rdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             m_op_i;
input  wire [ADDRBITSZ -1 : 0]     m_addr_i;
input  wire [ARCHBITSZ -1 : 0]     m_data_i;
output reg  [ARCHBITSZ -1 : 0]     m_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] m_sel_i;
output reg                         m_rdy_o;

output reg  [2 -1 : 0]             s_op_o;
output reg  [ADDRBITSZ -1 : 0]     s_addr_o;
output reg  [ARCHBITSZ -1 : 0]     s_data_o;
input  wire [ARCHBITSZ -1 : 0]     s_data_i;
output reg  [(ARCHBITSZ/8) -1 : 0] s_sel_o;
input  wire                        s_rdy_i;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [2 -1 : 0] _s_op_o;

always @(posedge clk_i) begin

	if (m_rdy_o || s_rdy_i) begin
		s_op_o <= (m_rdy_o ? m_op_i : PINOOP);
		s_addr_o <= m_addr_i;
		s_data_o <= m_data_i;
		s_sel_o <= m_sel_i;
	end

	if (s_rdy_i) begin
		_s_op_o <= s_op_o;
		m_data_o <= s_data_i;
	end

	if (rst_i)
		m_rdy_o <= 1;
	else if (s_rdy_i && !m_rdy_o)
		m_rdy_o <= (_s_op_o != PINOOP);
	else if (m_op_i != PINOOP && m_rdy_o)
		m_rdy_o <= 0;
end

initial begin
	m_data_o = 0;
	m_rdy_o = 0;
	s_op_o = PINOOP;
	s_addr_o = 0;
	s_data_o = 0;
	s_sel_o = 0;
	_s_op_o = PINOOP;
end

endmodule

`endif /* PI1B_V */
