// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_TO_WB4_V
`define PI1_TO_WB4_V

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

parameter ARCHBITSZ = 0;

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

assign pi1_rdy_o = (!rst_i && (!wb4_cyc_o || not_wrpending_and_wb4_ack_i));

wire [(128/8) -1 : 0] _pi1_sel_i = pi1_sel_i;
reg [ARCHBITSZ -1 : 0] wb4_addr_w;
always @* begin
	if (ARCHBITSZ == 16)
		wb4_addr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 1'b0 :
			_pi1_sel_i[1] ? 1'b1 : 1'b0 }};
	else if (ARCHBITSZ == 32)
		wb4_addr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 2'b00 :
			_pi1_sel_i[1] ? 2'b01 :
			_pi1_sel_i[2] ? 2'b10 :
			_pi1_sel_i[3] ? 2'b11 : 2'b00 }};
	else if (ARCHBITSZ == 64)
		wb4_addr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 3'b000 :
			_pi1_sel_i[1] ? 3'b001 :
			_pi1_sel_i[2] ? 3'b010 :
			_pi1_sel_i[3] ? 3'b011 :
			_pi1_sel_i[4] ? 3'b100 :
			_pi1_sel_i[5] ? 3'b101 :
			_pi1_sel_i[6] ? 3'b110 :
			_pi1_sel_i[7] ? 3'b111 : 3'b000 }};
	else if (ARCHBITSZ == 128)
		wb4_addr_w = {pi1_addr_i, {
			_pi1_sel_i[0]  ? 4'b0000 :
			_pi1_sel_i[1]  ? 4'b0001 :
			_pi1_sel_i[2]  ? 4'b0010 :
			_pi1_sel_i[3]  ? 4'b0011 :
			_pi1_sel_i[4]  ? 4'b0100 :
			_pi1_sel_i[5]  ? 4'b0101 :
			_pi1_sel_i[6]  ? 4'b0110 :
			_pi1_sel_i[7]  ? 4'b0111 :
			_pi1_sel_i[8]  ? 4'b1000 :
			_pi1_sel_i[9]  ? 4'b1001 :
			_pi1_sel_i[10] ? 4'b1010 :
			_pi1_sel_i[11] ? 4'b1011 :
			_pi1_sel_i[12] ? 4'b1100 :
			_pi1_sel_i[13] ? 4'b1101 :
			_pi1_sel_i[14] ? 4'b1110 :
			_pi1_sel_i[15] ? 4'b1111 : 4'b0000 }};
	else
		wb4_addr_w = {ARCHBITSZ{1'b0}};
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		wb4_cyc_o <= 0;
		wb4_stb_o <= 0;
		wrpending <= 0;

	end else if (pi1_rdy_o) begin

		pi1_op_i_hold <= pi1_op_i;
		wb4_addr_o <= wb4_addr_w;
		wb4_data_o <= pi1_data_i;
		wb4_sel_o <= _pi1_sel_i;

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
		wb4_stb_o <= 0;
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

`endif
