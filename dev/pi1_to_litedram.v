// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_TO_LITEDRAM_V
`define PI1_TO_LITEDRAM_V

module pi1_to_litedram (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,litedram_cmd_ready_i
	,litedram_cmd_valid_o
	,litedram_cmd_we_o
	,litedram_cmd_addr_o
	,litedram_wdata_ready_i
	,litedram_wdata_valid_o
	,litedram_wdata_we_o
	,litedram_wdata_data_o
	,litedram_rdata_valid_i
	,litedram_rdata_data_i
	,litedram_rdata_ready_o
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
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;

input  wire                    litedram_cmd_ready_i;
output wire                    litedram_cmd_valid_o;
output wire                    litedram_cmd_we_o;
output wire [ADDRBITSZ -1 : 0] litedram_cmd_addr_o;

input  wire                        litedram_wdata_ready_i;
output wire                        litedram_wdata_valid_o;
output reg  [(ARCHBITSZ/8) -1 : 0] litedram_wdata_we_o = 0;
output reg  [ARCHBITSZ -1 : 0]     litedram_wdata_data_o = 0;

input  wire                    litedram_rdata_valid_i;
input  wire [ARCHBITSZ -1 : 0] litedram_rdata_data_i;
output wire                    litedram_rdata_ready_o;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [2 -1 : 0] state = PINOOP;

reg donereading = 0;

reg [(ARCHBITSZ/8) -1 : 0] litedram_wdata_we_o_ = 0;
reg [ARCHBITSZ -1 : 0]     litedram_wdata_data_o_ = 0;
reg [ADDRBITSZ -1 : 0]     litedram_cmd_addr_o_ = 0;

assign litedram_cmd_valid_o = ((state == PINOOP) ?
	(pi1_op_i != PINOOP) : (state == PIRWOP && (litedram_rdata_valid_i || donereading)));
assign litedram_cmd_we_o    = ((state == PINOOP) ? (pi1_op_i == PIWROP) : (state == PIRWOP));
assign litedram_cmd_addr_o  = ((state == PINOOP) ? pi1_addr_i : litedram_cmd_addr_o_);

assign pi1_rdy_o = (state == PINOOP);

assign litedram_wdata_valid_o = (state == PIWROP);

assign litedram_rdata_ready_o = 1;

always @ (posedge clk_i) begin
	if (rst_i || (state == PIWROP && litedram_wdata_ready_i))
		state <= PINOOP;
	else if ((state == PIRDOP || state == PIRWOP) &&
		(litedram_rdata_valid_i || donereading)) begin
		if (state == PIRDOP)
			state <= PINOOP;
		else if (state == PIRWOP && litedram_cmd_ready_i) begin
			state <= PIWROP;
			litedram_wdata_we_o <= litedram_wdata_we_o_;
			litedram_wdata_data_o <= litedram_wdata_data_o_;
		end
		if (!donereading) begin
			donereading <= 1;
			pi1_data_o <= litedram_rdata_data_i;
		end
	end else if (state == PINOOP) begin
		if (litedram_cmd_ready_i && pi1_op_i == PIWROP) begin
			state <= PIWROP;
			litedram_wdata_we_o <= pi1_sel_i;
			litedram_wdata_data_o <= pi1_data_i;
		end else if (litedram_cmd_ready_i && pi1_op_i == PIRDOP) begin
			state <= PIRDOP;
			donereading <= 0;
		end else if (litedram_cmd_ready_i && pi1_op_i == PIRWOP) begin
			state <= PIRWOP;
			donereading <= 0;
			litedram_wdata_we_o_ <= pi1_sel_i;
			litedram_wdata_data_o_ <= pi1_data_i;
			litedram_cmd_addr_o_ <= litedram_cmd_addr_o;
		end
	end
end

endmodule

`endif /* PI1_TO_LITEDRAM_V */
