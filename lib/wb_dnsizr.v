// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_DNSIZR_V
`define WB_DNSIZR_V

// (MARCHBITSZ >= SARCHBITSZ) must be true.

`include "lib/addr.v"

module wb_dnsizr (

	 rst_i

	,clk_i

	,m_wb_cyc_i
	,m_wb_stb_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_cyc_o
	,s_wb_stb_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.v"

parameter MARCHBITSZ = 0;
parameter SARCHBITSZ = 0;

localparam CLOG2SARCHBITSZ = clog2(SARCHBITSZ);

localparam CLOG2MARCHBITSZBY8 = clog2(MARCHBITSZ/8);
localparam CLOG2SARCHBITSZBY8 = clog2(SARCHBITSZ/8);

localparam MADDRBITSZ = (MARCHBITSZ-CLOG2MARCHBITSZBY8);
localparam SADDRBITSZ = (SARCHBITSZ-CLOG2SARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire                         m_wb_cyc_i;
input  wire                         m_wb_stb_i;
input  wire                         m_wb_we_i;
input  wire [MADDRBITSZ -1 : 0]     m_wb_addr_i;
input  wire [(MARCHBITSZ/8) -1 : 0] m_wb_sel_i;
input  wire [MARCHBITSZ -1 : 0]     m_wb_dat_i;
output wire                         m_wb_bsy_o;
output wire                         m_wb_ack_o;
output wire [MARCHBITSZ -1 : 0]     m_wb_dat_o;

output wire                         s_wb_cyc_o;
output wire                         s_wb_stb_o;
output wire                         s_wb_we_o;
output wire [SADDRBITSZ -1 : 0]     s_wb_addr_o;
output wire [(SARCHBITSZ/8) -1 : 0] s_wb_sel_o;
output wire [SARCHBITSZ -1 : 0]     s_wb_dat_o;
input  wire                         s_wb_bsy_i;
input  wire                         s_wb_ack_i;
input  wire [SARCHBITSZ -1 : 0]     s_wb_dat_i;

assign s_wb_cyc_o = m_wb_cyc_i;
assign s_wb_stb_o = m_wb_stb_i;
assign s_wb_we_o = m_wb_we_i;

reg m_wb_bsy_o_;
assign m_wb_bsy_o = ((m_wb_bsy_o_ && !m_wb_ack_o) || s_wb_bsy_i);
assign m_wb_ack_o = s_wb_ack_i;

generate if (MARCHBITSZ > SARCHBITSZ) begin :gen_dnsizr

	wire [MARCHBITSZ -1 : 0] _m_wb_addr_i;

	addr #(
		.ARCHBITSZ (MARCHBITSZ)
	) addr (
		 .addr_i (m_wb_addr_i)
		,.sel_i  (m_wb_sel_i)
		,.addr_o (_m_wb_addr_i)
	);

	assign s_wb_addr_o = _m_wb_addr_i[SARCHBITSZ -1 : CLOG2SARCHBITSZBY8];

	reg [SADDRBITSZ -1 : 0] s_wb_addr_o_hold = 0;
	always @ (posedge clk_i) begin
		if (rst_i || m_wb_ack_o) begin
			m_wb_bsy_o_ <= 0;
		end else if (m_wb_cyc_i && m_wb_stb_i && !s_wb_bsy_i) begin
			m_wb_bsy_o_ <= 1;
			s_wb_addr_o_hold <= s_wb_addr_o;
		end
	end

	assign m_wb_dat_o = ({{(MARCHBITSZ-SARCHBITSZ){1'b0}}, s_wb_dat_i} <<
		{s_wb_addr_o_hold[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZ{1'b0}}});

	assign s_wb_dat_o = {m_wb_dat_i >>
		{s_wb_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZ{1'b0}}}};

	assign s_wb_sel_o = {m_wb_sel_i >>
		{s_wb_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZBY8{1'b0}}}};

end else begin

	assign s_wb_addr_o = m_wb_addr_i;
	assign m_wb_dat_o = s_wb_dat_i;
	assign s_wb_dat_o = m_wb_dat_i;
	assign s_wb_sel_o = m_wb_sel_i;

end endgenerate

endmodule

`endif /* WB_DNSIZR_V */
