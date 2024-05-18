// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_DNSIZR_V
`define WB_DNSIZR_V

// (MARCHBITSZ >= SARCHBITSZ) must be true.

`include "lib/addr.v"
`include "lib/fifo.v"
`include "lib/fifo_fwft.v"

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

parameter MAXPENDINGACK = 8; // It must be at least 2 and a power of 2.

parameter USEFWFTFIFO = 0;

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
output reg                          m_wb_ack_o;
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

wire m_wb_bsy_o_;
assign s_wb_cyc_o = m_wb_cyc_i;
assign s_wb_stb_o = (m_wb_stb_i && !m_wb_bsy_o_);
assign s_wb_we_o = m_wb_we_i;
assign m_wb_bsy_o = (m_wb_bsy_o_ || s_wb_bsy_i);

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

	wire [SADDRBITSZ -1 : 0] _s_wb_addr_o;

	if (USEFWFTFIFO) begin :gen_dnsizr_fifo_fwft
	fifo_fwft #(
		 .WIDTH (SADDRBITSZ)
		,.DEPTH (MAXPENDINGACK)
	) fifo_fwft (
		 .rst_i      (rst_i)
		,.clk_push_i (clk_i)
		,.push_i     (m_wb_cyc_i && m_wb_stb_i && !s_wb_bsy_i)
		,.data_i     (s_wb_addr_o)
		,.full_o     (m_wb_bsy_o_)
		,.clk_pop_i  (clk_i)
		,.pop_i      (s_wb_ack_i)
		,.data_o     (_s_wb_addr_o)
	);
	end else begin :gen_dnsizr_fifo
	fifo #(
		 .WIDTH (SADDRBITSZ)
		,.DEPTH (MAXPENDINGACK)
	) fifo (
		 .rst_i       (rst_i)
		,.clk_write_i (clk_i)
		,.write_i     (m_wb_cyc_i && m_wb_stb_i && !s_wb_bsy_i)
		,.data_i      (s_wb_addr_o)
		,.full_o      (m_wb_bsy_o_)
		,.clk_read_i  (clk_i)
		,.read_i      (s_wb_ack_i)
		,.data_o      (_s_wb_addr_o)
	);
	end

	reg [SARCHBITSZ -1 : 0] _s_wb_dat_i;

	assign m_wb_dat_o = ({{(MARCHBITSZ-SARCHBITSZ){1'b0}}, _s_wb_dat_i} <<
		{_s_wb_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZ{1'b0}}});

	assign s_wb_dat_o = {m_wb_dat_i >>
		{s_wb_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZ{1'b0}}}};

	assign s_wb_sel_o = {m_wb_sel_i >>
		{s_wb_addr_o[(CLOG2MARCHBITSZBY8-CLOG2SARCHBITSZBY8) -1 : 0], {CLOG2SARCHBITSZBY8{1'b0}}}};

	if (USEFWFTFIFO) begin
	always @* begin
		_s_wb_dat_i = s_wb_dat_i;
		m_wb_ack_o = s_wb_ack_i;
	end
	end else begin
	always @ (posedge clk_i) begin
		_s_wb_dat_i <= s_wb_dat_i;
		m_wb_ack_o <= s_wb_ack_i;
	end
	end

end else begin

	assign m_wb_bsy_o_ = 0;

	assign s_wb_addr_o = m_wb_addr_i;
	assign m_wb_dat_o = s_wb_dat_i;
	assign s_wb_dat_o = m_wb_dat_i;
	assign s_wb_sel_o = m_wb_sel_i;

	always @*
		m_wb_ack_o = s_wb_ack_i;

end endgenerate

endmodule

`endif /* WB_DNSIZR_V */
