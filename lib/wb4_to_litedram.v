// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB4_TO_LITEDRAM_V
`define WB4_TO_LITEDRAM_V

module wb4_to_litedram (

	 rst_i

	,clk_i

	,wb4_cyc_i
	,wb4_stb_i
	,wb4_we_i
	,wb4_addr_i
	,wb4_data_i
	,wb4_sel_i
	,wb4_stall_o
	,wb4_ack_o
	,wb4_data_o

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

input  wire                        wb4_cyc_i;
input  wire                        wb4_stb_i;
input  wire                        wb4_we_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_addr_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_data_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_i;
output wire                        wb4_stall_o;
output wire                        wb4_ack_o;
output wire [ARCHBITSZ -1 : 0]     wb4_data_o;

input  wire                    litedram_cmd_ready_i;
output wire                    litedram_cmd_valid_o;
output wire                    litedram_cmd_we_o;
output wire [ADDRBITSZ -1 : 0] litedram_cmd_addr_o;

input  wire                        litedram_wdata_ready_i;
output wire                        litedram_wdata_valid_o;
output reg  [(ARCHBITSZ/8) -1 : 0] litedram_wdata_we_o;
output reg  [ARCHBITSZ -1 : 0]     litedram_wdata_data_o;

input  wire                    litedram_rdata_valid_i;
input  wire [ARCHBITSZ -1 : 0] litedram_rdata_data_i;
output wire                    litedram_rdata_ready_o;

reg aborted = 0;

assign wb4_ack_o = (
	((litedram_wdata_valid_o && litedram_wdata_ready_i) ||
		litedram_rdata_valid_i) &&
	(wb4_cyc_i && !aborted));

assign wb4_data_o = litedram_rdata_data_i;

assign litedram_cmd_valid_o = (wb4_cyc_i && wb4_stb_i);
assign litedram_cmd_we_o    = wb4_we_i;
assign litedram_cmd_addr_o  = wb4_addr_i[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];

localparam CMD   = 2'b00;
localparam WRITE = 2'b01;
localparam READ  = 2'b10;
reg [1:0] state = CMD;

assign litedram_wdata_valid_o = ((state == WRITE) && wb4_cyc_i);

assign litedram_rdata_ready_o = 1;

wire is_rdop = (litedram_cmd_valid_o && litedram_cmd_ready_i && ~litedram_cmd_we_o);
wire is_wrop = (litedram_cmd_valid_o && litedram_cmd_ready_i && litedram_cmd_we_o);

always @ (posedge clk_i) begin
	if (rst_i ||
		((state == WRITE) && (litedram_wdata_valid_o && litedram_wdata_ready_i)) ||
		((state == READ) && litedram_rdata_valid_i))
		state <= CMD;
	else if (state == CMD) begin
		if (is_wrop) begin
			state <= WRITE;
			litedram_wdata_we_o <= wb4_sel_i;
			litedram_wdata_data_o <= wb4_data_i;
		end else if (is_rdop) begin
			state <= READ;
		end
	end

	if (rst_i || ((state == CMD) && (is_rdop || is_wrop)))
		aborted <= 0;
	else if (((state == READ) || (state == WRITE)) && (!wb4_cyc_i | aborted))
		aborted <= 1;
end

endmodule

`endif /* WB4_TO_LITEDRAM_V */
