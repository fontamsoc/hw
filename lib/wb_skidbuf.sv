// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_SKIDBUF_V
`define WB_SKIDBUF_V

`include "lib/skidbuf.sv"

module wb_skidbuf (

	 rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_lock_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o
	,m_wb_bsy_i // Response back-pressure knob.
	,m_wb_ack_avail_o // Un-gated 'response available': true even while held by m_wb_bsy_i.

	,s_wb_stb_o
	,s_wb_lock_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ   = 32;
parameter ADDRLIMIT   = 'h2000;
parameter DEPTH       = 16;
parameter USEFWFTFIFO = 0;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_lock_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output wire                               m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;
input  wire                               m_wb_bsy_i;
output wire                               m_wb_ack_avail_o;

output wire                               s_wb_stb_o;
output wire                               s_wb_lock_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

localparam CLOG2DEPTH = clog2(DEPTH);

reg [(CLOG2DEPTH +1) -1 : 0] rqst_cnt;
reg [(CLOG2DEPTH +1) -1 : 0] resp_cnt;

wire [(CLOG2DEPTH +1) -1 : 0] pending_acks = (rqst_cnt - resp_cnt);

wire max_pending = pending_acks[CLOG2DEPTH];

wire rqst_bsy_o_w;

assign m_wb_bsy_o = (rqst_bsy_o_w || max_pending);

always_ff @(posedge clk_i) begin
	if (rst_i)
		rqst_cnt <= 0;
	else if (m_wb_stb_i && !m_wb_bsy_o)
		rqst_cnt <= (rqst_cnt + 1'b1);
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		resp_cnt <= 0;
	else if (s_wb_ack_i)
		resp_cnt <= (resp_cnt + 1'b1);
end

skidbuf #(
	 .WIDTH       (1 + 1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH       (DEPTH)
	,.USEFWFTFIFO (USEFWFTFIFO)
) skidbuf_rqst (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (m_wb_stb_i && !max_pending)
	,.dat_i ({m_wb_lock_i, m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.bsy_o (rqst_bsy_o_w)

	,.stb_o (s_wb_stb_o)
	,.dat_o ({s_wb_lock_o, s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.bsy_i (s_wb_bsy_i)
);

wire resp_stb_o_w;

assign m_wb_ack_o = (resp_stb_o_w && !m_wb_bsy_i);
// Un-gated response-available: stays high while a completed response is held by
// m_wb_bsy_i, so a consumer can detect a held response precisely.
assign m_wb_ack_avail_o = resp_stb_o_w;

skidbuf #(
	 .WIDTH       (WORDBITSZ)
	,.DEPTH       (DEPTH)
	,.USEFWFTFIFO (USEFWFTFIFO)
) skidbuf_resp (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (s_wb_ack_i)
	,.dat_i (s_wb_dat_i)
	,.bsy_o (/* never becomes true because `max_pending` protects */)

	,.stb_o (resp_stb_o_w)
	,.dat_o (m_wb_dat_o)
	,.bsy_i (m_wb_bsy_i)
);

endmodule

`endif /* WB_SKIDBUF_V */
