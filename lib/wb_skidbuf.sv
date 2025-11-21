// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_SKIDBUF_V
`define WB_SKIDBUF_V

`include "lib/skidbuf.sv"

module wb_skidbuf (

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

`include "lib/clog2.sv"

parameter WORDBITSZ     = 32;
parameter ADDRLIMIT     = 'h2000;
parameter MAXPENDINGACK = 16;
parameter USEFWFTFIFO   = 0;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

input wire rst_i;

input wire clk_i;

input  wire                               m_wb_cyc_i;
input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output wire                               m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire                               s_wb_cyc_o;
output wire                               s_wb_stb_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

assign m_wb_ack_o = s_wb_ack_i;
assign m_wb_dat_o = s_wb_dat_i;

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] s_wb_pending_acks;

wire s_wb_stb_o_;
assign s_wb_stb_o = (s_wb_stb_o_ && !s_wb_pending_acks[CLOG2MAXPENDINGACK]);

wire _s_wb_bsy_i;

skidbuf #(
	 .WIDTH       (1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH       (MAXPENDINGACK)
	,.USEFWFTFIFO (USEFWFTFIFO)
) skidbuf (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (m_wb_cyc_i && m_wb_stb_i)
	,.dat_i ({m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.bsy_o (m_wb_bsy_o)

	,.stb_o (s_wb_stb_o_)
	,.dat_o ({s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.bsy_i (_s_wb_bsy_i)
);

always_ff @(posedge clk_i) begin
	if (rst_i)
		s_wb_pending_acks <= 0;
	else if (s_wb_stb_o && !_s_wb_bsy_i && s_wb_ack_i);
	else if (s_wb_ack_i)
		s_wb_pending_acks <= s_wb_pending_acks - 1'b1;
	else if (s_wb_stb_o && !_s_wb_bsy_i)
		s_wb_pending_acks <= s_wb_pending_acks + 1'b1;
end

assign s_wb_cyc_o = (s_wb_stb_o || (|s_wb_pending_acks));

assign _s_wb_bsy_i = (s_wb_bsy_i || s_wb_pending_acks[CLOG2MAXPENDINGACK]);

endmodule

`endif /* WB_SKIDBUF_V */
