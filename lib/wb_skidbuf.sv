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

// Single up/down occupancy counter (accepted requests not yet delivered, deliveries
// counted one cycle late), instead of separate rqst_cnt/resp_cnt and a subtract:
// max_outstanding comes from a registered bit rather than a subtract result.
reg [(CLOG2DEPTH +1) -1 : 0] outstanding_rqsts;

wire max_outstanding = outstanding_rqsts[CLOG2DEPTH];

wire rqst_bsy_o_w;

assign m_wb_bsy_o = (rqst_bsy_o_w || max_outstanding);

wire rqst_accepted = (m_wb_stb_i && !m_wb_bsy_o); // a request enters
reg  resp_received; // a response was delivered to the master a cycle ago; registered so
// that the counter cone stays off the m_wb_bsy_i/resp_stb_o_w combinational fanin; the
// lagged decrement only throttles earlier, so (accepted - delivered) <= DEPTH still holds.
always_ff @(posedge clk_i)
	resp_received <= (!rst_i && m_wb_ack_o);

always_ff @(posedge clk_i) begin
	if (rst_i)
		outstanding_rqsts <= 0;
	else if (rqst_accepted != resp_received) // net change only when exactly one occurs
		outstanding_rqsts <= (rqst_accepted ? (outstanding_rqsts + 1'b1) : (outstanding_rqsts - 1'b1));
end

skidbuf #(
	 .WIDTH       (1 + 1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH       (DEPTH)
	,.USEFWFTFIFO (USEFWFTFIFO)
) skidbuf_rqst (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (m_wb_stb_i && !max_outstanding)
	,.dat_i ({m_wb_lock_i, m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.bsy_o (rqst_bsy_o_w)

	,.stb_o (s_wb_stb_o)
	,.dat_o ({s_wb_lock_o, s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.bsy_i (s_wb_bsy_i)
);

wire resp_stb_o_w;
wire resp_bsy_o_w; // only read by the SIMULATION_MONITOR guard below; pruned in synthesis.

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
	,.bsy_o (resp_bsy_o_w /* stays low: max_outstanding bounds undelivered responses to DEPTH, so no ack ever arrives while full */)

	,.stb_o (resp_stb_o_w)
	,.dat_o (m_wb_dat_o)
	,.bsy_i (m_wb_bsy_i)
);

`ifdef SIMULATION_MONITOR
// Guard for the invariant stated at the `skidbuf_resp` bsy_o port above: an ack
// is a pulse (never held/retried), so a push while full would be silently dropped.
always_ff @(posedge clk_i) begin
	if (!rst_i && s_wb_ack_i && resp_bsy_o_w)
		$error("%m: response fifo overflow: ack dropped");
end
`endif

endmodule

`endif /* WB_SKIDBUF_V */
