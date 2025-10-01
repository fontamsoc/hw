// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_CDC_V
`define WB_CDC_V

`include "lib/fifo.sv"
`include "lib/fifo_async.sv"

module wb_cdc (

	 rst_i

	,m_clk_i
	,s_clk_i

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

parameter WORDBITSZ = 32;

parameter ADDRLIMIT = 'h2000;

parameter MAXPENDINGACK = 2;

parameter ASYNC = 0;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire m_clk_i;
input wire s_clk_i;

input  wire                               m_wb_cyc_i;
input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output reg                                m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;

output reg                                s_wb_cyc_o;
output reg                                s_wb_stb_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

wire m_wb_bsy_o_;

reg [(clog2(MAXPENDINGACK) +1) -1 : 0] m_wb_pending_acks;

assign m_wb_bsy_o = (m_wb_bsy_o_ || m_wb_pending_acks == MAXPENDINGACK);

wire rqst_write_w = (m_wb_cyc_i && m_wb_stb_i && !m_wb_bsy_o);

always_ff @(posedge m_clk_i) begin
	if (rst_i)
		m_wb_pending_acks <= 0;
	else if (rqst_write_w && m_wb_ack_o);
	else if (m_wb_ack_o)
		m_wb_pending_acks <= m_wb_pending_acks - 1'b1;
	else if (rqst_write_w)
		m_wb_pending_acks <= m_wb_pending_acks + 1'b1;
end

wire rqst_read_w = (!s_wb_stb_o || !s_wb_bsy_i);

wire rqst_empty_w;

always_ff @(posedge s_clk_i) begin
	s_wb_cyc_o <= (m_wb_cyc_i || (|m_wb_pending_acks));
end

always_ff @(posedge s_clk_i) begin
	if (rst_i)
		s_wb_stb_o <= 0;
	else if (rqst_read_w)
		s_wb_stb_o <= !rqst_empty_w;
end

generate if (ASYNC) begin
fifo_async #(
	 .WIDTH (1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH (MAXPENDINGACK)
) rqst (

	 .rst_i (rst_i)

	,.clk_write_i (m_clk_i)
	,.write_i     (rqst_write_w)
	,.data_i      ({m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.full_o      (m_wb_bsy_o_)

	,.clk_read_i (s_clk_i)
	,.read_i     (rqst_read_w)
	,.data_o     ({s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.empty_o    (rqst_empty_w)
);
end else begin
fifo #(
	 .WIDTH (1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH (MAXPENDINGACK)
) rqst (

	 .rst_i (rst_i)

	,.clk_write_i (m_clk_i)
	,.write_i     (rqst_write_w)
	,.data_i      ({m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.full_o      (m_wb_bsy_o_)

	,.clk_read_i (s_clk_i)
	,.read_i     (rqst_read_w)
	,.data_o     ({s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.empty_o    (rqst_empty_w)
);
end endgenerate

wire rsp_empty_w;

always_ff @(posedge m_clk_i) begin
	if (rst_i)
		m_wb_ack_o <= 0;
	else
		m_wb_ack_o <= !rsp_empty_w;
end

generate if (ASYNC) begin
fifo_async #(
	 .WIDTH (WORDBITSZ)
	,.DEPTH (MAXPENDINGACK)
) rsp (

	 .rst_i (rst_i)

	,.clk_write_i (s_clk_i)
	,.write_i     (s_wb_ack_i)
	,.data_i      (s_wb_dat_i)

	,.clk_read_i (m_clk_i)
	,.read_i     (1'b1)
	,.data_o     (m_wb_dat_o)
	,.empty_o    (rsp_empty_w)
);
end else begin
fifo #(
	 .WIDTH (WORDBITSZ)
	,.DEPTH (MAXPENDINGACK)
) rsp (

	 .rst_i (rst_i)

	,.clk_write_i (s_clk_i)
	,.write_i     (s_wb_ack_i)
	,.data_i      (s_wb_dat_i)

	,.clk_read_i (m_clk_i)
	,.read_i     (1'b1)
	,.data_o     (m_wb_dat_o)
	,.empty_o    (rsp_empty_w)
);
end endgenerate

endmodule

`endif /* WB_CDC_V */
