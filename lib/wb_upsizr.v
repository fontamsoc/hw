// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_UPSIZR_V
`define WB_UPSIZR_V

// (MARCHBITSZ <= SARCHBITSZ) must be true.

`include "lib/fifo.v"
`include "lib/fifo_fwft.v"

module wb_upsizr (

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

generate if (MARCHBITSZ < SARCHBITSZ) begin :gen_upsizr

	assign s_wb_addr_o = {
		{(SADDRBITSZ-(MADDRBITSZ-(CLOG2SARCHBITSZBY8-CLOG2MARCHBITSZBY8))){1'b0}},
		m_wb_addr_i[MADDRBITSZ -1 : (CLOG2SARCHBITSZBY8-CLOG2MARCHBITSZBY8)]};

	wire [MADDRBITSZ -1 : 0] _m_wb_addr_i;

	if (USEFWFTFIFO) begin :gen_upsizr_fifo_fwft
	fifo_fwft #(
		 .WIDTH (MADDRBITSZ)
		,.DEPTH (MAXPENDINGACK)
	) fifo_fwft (
		 .rst_i      (rst_i)
		,.clk_push_i (clk_i)
		,.push_i     (m_wb_cyc_i && m_wb_stb_i && !s_wb_bsy_i)
		,.data_i     (m_wb_addr_i)
		,.full_o     (m_wb_bsy_o_)
		,.clk_pop_i  (clk_i)
		,.pop_i      (s_wb_ack_i)
		,.data_o     (_m_wb_addr_i)
	);
	end else begin :gen_upsizr_fifo
	fifo #(
		 .WIDTH (MADDRBITSZ)
		,.DEPTH (MAXPENDINGACK)
	) fifo (
		 .rst_i       (rst_i)
		,.clk_write_i (clk_i)
		,.write_i     (m_wb_cyc_i && m_wb_stb_i && !s_wb_bsy_i)
		,.data_i      (m_wb_addr_i)
		,.full_o      (m_wb_bsy_o_)
		,.clk_read_i  (clk_i)
		,.read_i      (s_wb_ack_i)
		,.data_o      (_m_wb_addr_i)
	);
	end

	reg [SARCHBITSZ -1 : 0] _s_wb_dat_i;

	assign m_wb_dat_o = {_s_wb_dat_i >>
		(_m_wb_addr_i[(CLOG2SARCHBITSZBY8-CLOG2MARCHBITSZBY8) -1 : 0]*MARCHBITSZ)};

	assign s_wb_dat_o = (
		{{(SARCHBITSZ-MARCHBITSZ){1'b0}}, m_wb_dat_i} <<
		(m_wb_addr_i[(CLOG2SARCHBITSZBY8-CLOG2MARCHBITSZBY8) -1 : 0]*MARCHBITSZ));

	assign s_wb_sel_o = ({{((SARCHBITSZ-MARCHBITSZ)/8){1'b0}}, m_wb_sel_i} <<
		(m_wb_addr_i[(CLOG2SARCHBITSZBY8-CLOG2MARCHBITSZBY8) -1 : 0]*(MARCHBITSZ/8)));

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

`endif /* WB_UPSIZR_V */
