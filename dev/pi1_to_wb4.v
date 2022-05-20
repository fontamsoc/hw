// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_TO_WB4_V
`define PI1_TO_WB4_V

`include "lib/addr.v"

module pi1_to_wb4 (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,wb4_cyc_o
	,wb4_stb_o
	,wb4_we_o
	,wb4_addr_o
	,wb4_data_o
	,wb4_sel_o
	,wb4_stall_i
	,wb4_ack_i
	,wb4_data_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;

output reg                        wb4_cyc_o;
output reg                        wb4_stb_o;
output reg                        wb4_we_o;
output reg [ARCHBITSZ -1 : 0]     wb4_addr_o;
output reg [ARCHBITSZ -1 : 0]     wb4_data_o;
output reg [(ARCHBITSZ/8) -1 : 0] wb4_sel_o;
input wire                        wb4_stall_i;
input wire                        wb4_ack_i;
input wire [ARCHBITSZ -1 : 0]     wb4_data_i;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg wrpending;

reg [2 -1 : 0]         pi1_op_i_hold;
reg [ARCHBITSZ -1 : 0] wb4_data_i_hold;

wire not_wrpending_and_wb4_ack_i = (!wrpending && wb4_ack_i);

assign pi1_data_o = not_wrpending_and_wb4_ack_i ?
	((pi1_op_i_hold == PIRWOP) ? wb4_data_i_hold : wb4_data_i) :
	{ARCHBITSZ{1'b0}};

assign pi1_rdy_o = (/*!rst_i &&*/(!wb4_cyc_o || not_wrpending_and_wb4_ack_i));

wire [ARCHBITSZ -1 : 0] wb4_addr_w;

addr #(
	.ARCHBITSZ (ARCHBITSZ)
) addr (
	 .addr_i (pi1_addr_i)
	,.sel_i  (pi1_sel_i)
	,.addr_o (wb4_addr_w)
);

always @ (posedge clk_i) begin

	if (rst_i) begin

		wb4_cyc_o <= 0;
		wb4_stb_o <= 0;
		wrpending <= 0;

	end else if (pi1_rdy_o) begin

		pi1_op_i_hold <= pi1_op_i;
		wb4_addr_o <= wb4_addr_w;
		wb4_data_o <= pi1_data_i;
		wb4_sel_o <= pi1_sel_i;

		if (pi1_op_i == PIRDOP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 0;

		end else if (pi1_op_i == PIWROP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 1;

		end else if (pi1_op_i == PIRWOP) begin

			wb4_cyc_o <= 1;
			wb4_stb_o <= 1;
			wb4_we_o <= 0;
			wrpending <= 1;

		end else begin

			wb4_cyc_o <= 0;
			wb4_stb_o <= 0;
			wb4_we_o <= 0;
		end

	end else if (wrpending && wb4_ack_i) begin

		wb4_data_i_hold <= wb4_data_i;

		wb4_stb_o <= 1;
		wb4_we_o <= 1;
		wrpending <= 0;

	end else if (!wb4_stall_i)
		wb4_stb_o <= 0; // Request accepted.
end

initial begin
	wb4_cyc_o = 0;
	wb4_stb_o = 0;
	wb4_we_o = 0;
	wb4_addr_o = 0;
	wb4_data_o = 0;
	wb4_sel_o = 0;
	wb4_data_i_hold = 0;
	pi1_op_i_hold = 0;
	wrpending = 0;
end

endmodule

`endif /* PI1_TO_WB4_V */
