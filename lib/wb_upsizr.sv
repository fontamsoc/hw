// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_UPSIZR_V
`define WB_UPSIZR_V

// (MWORDBITSZ <= SWORDBITSZ) must be true.

`include "lib/fifo.sv"
`include "lib/fifo_fwft.sv"

module wb_upsizr (

	 rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_tag_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_stb_o
	,s_wb_tag_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.sv"

parameter MWORDBITSZ = 0;
parameter SWORDBITSZ = 0;

parameter ADDRLIMIT = 'h2000;

parameter WBTAGBITSZ = 1;

parameter MAXPENDINGACK = 8; // It must be at least 2 and a power of 2.

parameter USEFWFTFIFO = 0;

localparam CLOG2MWORDBITSZBY8 = clog2(MWORDBITSZ/8);
localparam CLOG2SWORDBITSZBY8 = clog2(SWORDBITSZ/8);

localparam MADDRBITSZ = (MWORDBITSZ-CLOG2MWORDBITSZBY8);
localparam SADDRBITSZ = (SWORDBITSZ-CLOG2SWORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MMSBSZIGN = (MWORDBITSZ-clog2(ADDRLIMIT)-1);
localparam SMSBSZIGN = (SWORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire                                 m_wb_stb_i;
input  wire [WBTAGBITSZ -1 : 0]             m_wb_tag_i;
input  wire                                 m_wb_we_i;
input  wire [(MADDRBITSZ-MMSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(MWORDBITSZ/8) -1 : 0]         m_wb_sel_i;
input  wire [MWORDBITSZ -1 : 0]             m_wb_dat_i;
output wire                                 m_wb_bsy_o;
output reg                                  m_wb_ack_o;
output wire [MWORDBITSZ -1 : 0]             m_wb_dat_o;

output wire                                 s_wb_stb_o;
output wire [WBTAGBITSZ -1 : 0]             s_wb_tag_o;
output wire                                 s_wb_we_o;
output wire [(SADDRBITSZ-SMSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(SWORDBITSZ/8) -1 : 0]         s_wb_sel_o;
output wire [SWORDBITSZ -1 : 0]             s_wb_dat_o;
input  wire                                 s_wb_bsy_i;
input  wire                                 s_wb_ack_i;
input  wire [SWORDBITSZ -1 : 0]             s_wb_dat_i;

wire m_wb_bsy_o_;

assign s_wb_stb_o = (m_wb_stb_i && !m_wb_bsy_o_);
assign s_wb_tag_o = m_wb_tag_i;
assign s_wb_we_o = m_wb_we_i;
assign m_wb_bsy_o = (m_wb_bsy_o_ || s_wb_bsy_i);

generate if (MWORDBITSZ < SWORDBITSZ) begin :gen_upsizr

	assign s_wb_addr_o = {
		{((SADDRBITSZ-SMSBSZIGN)-((MADDRBITSZ-MMSBSZIGN)-(CLOG2SWORDBITSZBY8-CLOG2MWORDBITSZBY8))){1'b0}},
		m_wb_addr_i[(MADDRBITSZ-MMSBSZIGN) -1 : (CLOG2SWORDBITSZBY8-CLOG2MWORDBITSZBY8)]};

	wire [(MADDRBITSZ-MMSBSZIGN) -1 : 0] _m_wb_addr_i;

	if (USEFWFTFIFO) begin :gen_upsizr_fifo_fwft
	fifo_fwft #(
		 .WIDTH ((MADDRBITSZ-MMSBSZIGN))
		,.DEPTH (MAXPENDINGACK)
	) fifo_fwft (
		 .rst_i      (rst_i)
		,.clk_push_i (clk_i)
		,.push_i     (m_wb_stb_i && !s_wb_bsy_i)
		,.data_i     (m_wb_addr_i)
		,.full_o     (m_wb_bsy_o_)
		,.clk_pop_i  (clk_i)
		,.pop_i      (s_wb_ack_i)
		,.data_o     (_m_wb_addr_i)
	);
	end else begin :gen_upsizr_fifo
	fifo #(
		 .WIDTH ((MADDRBITSZ-MMSBSZIGN))
		,.DEPTH (MAXPENDINGACK)
	) fifo (
		 .rst_i       (rst_i)
		,.clk_write_i (clk_i)
		,.write_i     (m_wb_stb_i && !s_wb_bsy_i)
		,.data_i      (m_wb_addr_i)
		,.full_o      (m_wb_bsy_o_)
		,.clk_read_i  (clk_i)
		,.read_i      (s_wb_ack_i)
		,.data_o      (_m_wb_addr_i)
	);
	end

	reg [SWORDBITSZ -1 : 0] _s_wb_dat_i;

	assign m_wb_dat_o = {_s_wb_dat_i >>
		(_m_wb_addr_i[(CLOG2SWORDBITSZBY8-CLOG2MWORDBITSZBY8) -1 : 0]*MWORDBITSZ)};

	assign s_wb_dat_o = (
		{{(SWORDBITSZ-MWORDBITSZ){1'b0}}, m_wb_dat_i} <<
		(m_wb_addr_i[(CLOG2SWORDBITSZBY8-CLOG2MWORDBITSZBY8) -1 : 0]*MWORDBITSZ));

	assign s_wb_sel_o = ({{((SWORDBITSZ-MWORDBITSZ)/8){1'b0}}, m_wb_sel_i} <<
		(m_wb_addr_i[(CLOG2SWORDBITSZBY8-CLOG2MWORDBITSZBY8) -1 : 0]*(MWORDBITSZ/8)));

	if (USEFWFTFIFO) begin
	always_comb begin
		_s_wb_dat_i = s_wb_dat_i;
		m_wb_ack_o = s_wb_ack_i;
	end
	end else begin
	always_ff @(posedge clk_i) begin
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

	always_comb
		m_wb_ack_o = s_wb_ack_i;

end endgenerate

endmodule

`endif /* WB_UPSIZR_V */
