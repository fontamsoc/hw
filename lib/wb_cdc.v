// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_CDC_V
`define WB_CDC_V

`include "lib/fifo.v"

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

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter RQSTDEPTH = 2;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire m_clk_i;
input wire s_clk_i;

input  wire                        m_wb_cyc_i;
input  wire                        m_wb_stb_i;
input  wire                        m_wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     m_wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] m_wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     m_wb_dat_i;
output wire                        m_wb_bsy_o;
output reg                         m_wb_ack_o;
output wire [ARCHBITSZ -1 : 0]     m_wb_dat_o;

output reg                         s_wb_cyc_o;
output reg                         s_wb_stb_o;
output wire                        s_wb_we_o;
output wire [ADDRBITSZ -1 : 0]     s_wb_addr_o;
output wire [(ARCHBITSZ/8) -1 : 0] s_wb_sel_o;
output wire [ARCHBITSZ -1 : 0]     s_wb_dat_o;
input  wire                        s_wb_bsy_i;
input  wire                        s_wb_ack_i;
input  wire [ARCHBITSZ -1 : 0]     s_wb_dat_i;

always @ (posedge m_clk_i)
	s_wb_cyc_o <= m_wb_cyc_i;

wire rqst_write_w = (m_wb_cyc_i && m_wb_stb_i);

wire rqst_read_w = !(rqst_empty_o || s_wb_bsy_i);

wire rqst_empty_o;
always @ (posedge s_clk_i)
	s_wb_stb_o <= rqst_read_w;

fifo #(

	 .WIDTH (1 + ADDRBITSZ + (ARCHBITSZ/8) + ARCHBITSZ)
	,.DEPTH (RQSTDEPTH)

) rqst (

	 .rst_i (rst_i)

	,.clk_write_i (m_clk_i)
	,.write_i     (rqst_write_w)
	,.data_i      ({m_wb_we_i, m_wb_addr_i, m_wb_sel_i, m_wb_dat_i})
	,.full_o      (m_wb_bsy_o)

	,.clk_read_i (s_clk_i)
	,.read_i     (rqst_read_w)
	,.data_o     ({s_wb_we_o, s_wb_addr_o, s_wb_sel_o, s_wb_dat_o})
	,.empty_o    (rqst_empty_o)
);

wire rsp_empty_o;
always @ (posedge m_clk_i)
	m_wb_ack_o <= ~rsp_empty_o;

fifo #(

	 .WIDTH (ARCHBITSZ)
	,.DEPTH (RQSTDEPTH)

) rsp (

	 .rst_i (rst_i)

	,.clk_write_i (s_clk_i)
	,.write_i     (s_wb_ack_i)
	,.data_i      (s_wb_dat_i)

	,.clk_read_i (m_clk_i)
	,.read_i     (1'b1)
	,.data_o     (m_wb_dat_o)
	,.empty_o    (rsp_empty_o)
);

/*
// Alternative logic for setting s_wb_cyc_o,
// which can have s_wb_cyc_o becoming low while
// m_wb_cyc_i is still high.
reg [(clog2(RQSTDEPTH) +1) -1 : 0] rsp_pending;
always @ (posedge s_clk_i) begin
	if (rst_i)
		rsp_pending <= 0;
	else if (!(s_wb_bsy_i || rqst_empty_o))
		rsp_pending <= rsp_pending + 1'b1;
	else if (s_wb_ack_i)
		rsp_pending <= rsp_pending - 1'b1;
end
always @*
	s_wb_cyc_o = (!rqst_empty_o || rsp_pending);
*/

endmodule

`endif /* WB_CDC_V */
