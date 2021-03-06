// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_DOWNCONVERTER_V
`define PI1_DOWNCONVERTER_V

// (MARCHBITSZ >= SARCHBITSZ) must be true.

`include "lib/addr.v"

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
output wire [MARCHBITSZ -1 : 0]     m_pi1_mapsz_o;

output wire [2 -1 : 0]              s_pi1_op_o;
output wire [SADDRBITSZ -1 : 0]     s_pi1_addr_o;
output wire [SARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [SARCHBITSZ -1 : 0]     s_pi1_data_i;
output wire [(SARCHBITSZ/8) -1 : 0] s_pi1_sel_o;
input wire                          s_pi1_rdy_i;
input wire  [SARCHBITSZ -1 : 0]     s_pi1_mapsz_i;

assign s_pi1_op_o = m_pi1_op_i;

assign m_pi1_rdy_o = s_pi1_rdy_i;

generate if (MARCHBITSZ > SARCHBITSZ) begin :pi1_downconverter0

	wire [MARCHBITSZ -1 : 0] m_pi1_addr_w;

	addr #(
		.ARCHBITSZ (MARCHBITSZ)
	) addr (
		 .addr_i (m_pi1_addr_i)
		,.sel_i  (m_pi1_sel_i)
		,.addr_o (m_pi1_addr_w)
	);

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

end else begin  :pi1_downconverter1

	assign s_pi1_addr_o = m_pi1_addr_i;
	assign m_pi1_data_o = s_pi1_data_i;
	assign s_pi1_data_o = m_pi1_data_i;
	assign s_pi1_sel_o = m_pi1_sel_i;

end endgenerate

assign m_pi1_mapsz_o = s_pi1_mapsz_i;

endmodule

`endif /* PI1_DOWNCONVERTER_V */
