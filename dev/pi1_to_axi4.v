// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef PI1_TO_AXI4_V
`define PI1_TO_AXI4_V

module pi1_to_axi4 (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o

	,axi4_awid_o
	,axi4_awaddr_o
	,axi4_awlen_o
	,axi4_awsize_o
	,axi4_awburst_o
	,axi4_awlock_o
	,axi4_awcache_o
	,axi4_awprot_o
	,axi4_awqos_o
	,axi4_awvalid_o
	,axi4_awready_i

	,axi4_wdata_o
	,axi4_wstrb_o
	,axi4_wlast_o
	,axi4_wvalid_o
	,axi4_wready_i

	,axi4_bready_o
	,axi4_bid_i
	,axi4_bresp_i
	,axi4_bvalid_i

	,axi4_arid_o
	,axi4_araddr_o
	,axi4_arlen_o
	,axi4_arsize_o
	,axi4_arburst_o
	,axi4_arlock_o
	,axi4_arcache_o
	,axi4_arprot_o
	,axi4_arqos_o
	,axi4_arvalid_o
	,axi4_arready_i

	,axi4_rready_o
	,axi4_rid_i
	,axi4_rdata_i
	,axi4_rresp_i
	,axi4_rlast_i
	,axi4_rvalid_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter AXI4_ID_WIDTH = 4;

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

output wire [AXI4_ID_WIDTH -1 : 0] axi4_awid_o;
output reg  [ARCHBITSZ -1 : 0]     axi4_awaddr_o;
output wire [7:0]                  axi4_awlen_o;
output wire [2:0]                  axi4_awsize_o;
output wire [1:0]                  axi4_awburst_o;
output wire [0:0]                  axi4_awlock_o;
output wire [3:0]                  axi4_awcache_o;
output wire [2:0]                  axi4_awprot_o;
output wire [3:0]                  axi4_awqos_o;
output wire                        axi4_awvalid_o;
input  wire                        axi4_awready_i;

output reg  [ARCHBITSZ -1 : 0]     axi4_wdata_o;
output reg  [(ARCHBITSZ/8) -1 : 0] axi4_wstrb_o;
output wire                        axi4_wlast_o;
output wire                        axi4_wvalid_o;
input  wire                        axi4_wready_i;

output reg                         axi4_bready_o;
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_bid_i;
input  wire [1:0]                  axi4_bresp_i;
input  wire                        axi4_bvalid_i;

output wire [AXI4_ID_WIDTH -1 : 0] axi4_arid_o;
output reg  [ARCHBITSZ -1 : 0]     axi4_araddr_o;
output wire [7:0]                  axi4_arlen_o;
output wire [2:0]                  axi4_arsize_o;
output wire [1:0]                  axi4_arburst_o;
output wire [0:0]                  axi4_arlock_o;
output wire [3:0]                  axi4_arcache_o;
output wire [2:0]                  axi4_arprot_o;
output wire [3:0]                  axi4_arqos_o;
output wire                        axi4_arvalid_o;
input  wire                        axi4_arready_i;

output reg                         axi4_rready_o;
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_rid_i;
input  wire [ARCHBITSZ -1 : 0]     axi4_rdata_i;
input  wire [1:0]                  axi4_rresp_i;
input  wire                        axi4_rlast_i;
input  wire                        axi4_rvalid_i;

assign axi4_awid_o = {AXI4_ID_WIDTH{1'b0}};
assign axi4_awlen_o = 0;
assign axi4_awsize_o = clog2(ARCHBITSZ);
assign axi4_awburst_o = 2'b01;
assign axi4_awlock_o = 0;
assign axi4_awcache_o = 4'b0000;
assign axi4_awprot_o = 3'b000;
assign axi4_awqos_o = 4'b0000;
assign axi4_arid_o = {AXI4_ID_WIDTH{1'b0}};
assign axi4_arlen_o = 0;
assign axi4_arsize_o = clog2(ARCHBITSZ);
assign axi4_arburst_o = 2'b01;
assign axi4_arlock_o = 0;
assign axi4_arcache_o = 4'b0000;
assign axi4_arprot_o = 3'b000;
assign axi4_arqos_o = 4'b0000;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg wrpending;

reg [2 -1 : 0]         pi1_op_i_hold;
reg [ARCHBITSZ -1 : 0] axi4_rdata_hold;

reg we;

wire ack = (we ? axi4_bvalid_i : axi4_rvalid_i);

wire not_wrpending_and_ack = (!wrpending && ack);

assign pi1_data_o = not_wrpending_and_ack ?
	((pi1_op_i_hold == PIRWOP) ? axi4_rdata_hold : axi4_rdata_i) :
	{ARCHBITSZ{1'b0}};

reg cyc;

assign pi1_rdy_o = (!rst_i && (!cyc || not_wrpending_and_ack));

wire [(256/8) -1 : 0] _pi1_sel_i = pi1_sel_i;
reg [ARCHBITSZ -1 : 0] axi4_axaddr_w;
always @* begin
	if (ARCHBITSZ == 16)
		axi4_axaddr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 1'b0 :
			_pi1_sel_i[1] ? 1'b1 : 1'b0 }};
	else if (ARCHBITSZ == 32)
		axi4_axaddr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 2'b00 :
			_pi1_sel_i[1] ? 2'b01 :
			_pi1_sel_i[2] ? 2'b10 :
			_pi1_sel_i[3] ? 2'b11 : 2'b00 }};
	else if (ARCHBITSZ == 64)
		axi4_axaddr_w = {pi1_addr_i, {
			_pi1_sel_i[0] ? 3'b000 :
			_pi1_sel_i[1] ? 3'b001 :
			_pi1_sel_i[2] ? 3'b010 :
			_pi1_sel_i[3] ? 3'b011 :
			_pi1_sel_i[4] ? 3'b100 :
			_pi1_sel_i[5] ? 3'b101 :
			_pi1_sel_i[6] ? 3'b110 :
			_pi1_sel_i[7] ? 3'b111 : 3'b000 }};
	else if (ARCHBITSZ == 128)
		axi4_axaddr_w = {pi1_addr_i, {
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
	else if (ARCHBITSZ == 256)
		axi4_axaddr_w = {pi1_addr_i, {
			_pi1_sel_i[0]  ? 5'b00000 :
			_pi1_sel_i[1]  ? 5'b00001 :
			_pi1_sel_i[2]  ? 5'b00010 :
			_pi1_sel_i[3]  ? 5'b00011 :
			_pi1_sel_i[4]  ? 5'b00100 :
			_pi1_sel_i[5]  ? 5'b00101 :
			_pi1_sel_i[6]  ? 5'b00110 :
			_pi1_sel_i[7]  ? 5'b00111 :
			_pi1_sel_i[8]  ? 5'b01000 :
			_pi1_sel_i[9]  ? 5'b01001 :
			_pi1_sel_i[10] ? 5'b01010 :
			_pi1_sel_i[11] ? 5'b01011 :
			_pi1_sel_i[12] ? 5'b01100 :
			_pi1_sel_i[13] ? 5'b01101 :
			_pi1_sel_i[14] ? 5'b01110 :
			_pi1_sel_i[15] ? 5'b01111 :
			_pi1_sel_i[16] ? 5'b10000 :
			_pi1_sel_i[17] ? 5'b10001 :
			_pi1_sel_i[18] ? 5'b10010 :
			_pi1_sel_i[19] ? 5'b10011 :
			_pi1_sel_i[20] ? 5'b10100 :
			_pi1_sel_i[21] ? 5'b10101 :
			_pi1_sel_i[22] ? 5'b10110 :
			_pi1_sel_i[23] ? 5'b10111 :
			_pi1_sel_i[24] ? 5'b11000 :
			_pi1_sel_i[25] ? 5'b11001 :
			_pi1_sel_i[26] ? 5'b11010 :
			_pi1_sel_i[27] ? 5'b11011 :
			_pi1_sel_i[28] ? 5'b11100 :
			_pi1_sel_i[29] ? 5'b11101 :
			_pi1_sel_i[30] ? 5'b11110 :
			_pi1_sel_i[31] ? 5'b11111 : 5'b00000 }};
	else
		axi4_axaddr_w = {ARCHBITSZ{1'b0}};
end

wire stall_n = (we ? (axi4_awready_i & axi4_wready_i) : axi4_arready_i);

reg axi4_awvalid_o_;
assign axi4_awvalid_o = (stall_n && axi4_awvalid_o_);

reg axi4_wvalid_o_;
assign axi4_wvalid_o = (stall_n && axi4_wvalid_o_);
assign axi4_wlast_o = axi4_wvalid_o_;

reg axi4_arvalid_o_;
assign axi4_arvalid_o = (stall_n && axi4_arvalid_o_);

always @ (posedge clk_i) begin

	if (rst_i) begin

		cyc <= 0;
		wrpending <= 0;
		axi4_awvalid_o_ <= 0;
		axi4_wvalid_o_ <= 0;
		axi4_arvalid_o_ <= 0;
		axi4_bready_o <= 0;
		axi4_rready_o <= 0;

	end else if (pi1_rdy_o) begin

		pi1_op_i_hold <= pi1_op_i;
		axi4_wdata_o <= pi1_data_i;
		axi4_wstrb_o <= _pi1_sel_i;

		if (pi1_op_i == PIRDOP) begin

			cyc <= 1;
			we <= 0;
			axi4_araddr_o <= axi4_axaddr_w;
			axi4_arvalid_o_ <= 1;
			axi4_rready_o <= 1;

		end else if (pi1_op_i == PIWROP) begin

			cyc <= 1;
			we <= 1;
			axi4_awaddr_o <= axi4_axaddr_w;
			axi4_awvalid_o_ <= 1;
			axi4_wvalid_o_ <= 1;
			axi4_bready_o <= 1;

		end else if (pi1_op_i == PIRWOP) begin

			cyc <= 1;
			we <= 0;
			wrpending <= 1;
			axi4_araddr_o <= axi4_axaddr_w;
			axi4_arvalid_o_ <= 1;
			axi4_rready_o <= 1;

		end else begin

			cyc <= 0;
			we <= 0;
			axi4_bready_o <= 0;
		end

	end else if (wrpending && ack) begin

		axi4_rdata_hold <= axi4_rdata_i;

		we <= 1;
		wrpending <= 0;
		axi4_awaddr_o <= axi4_araddr_o;
		axi4_awvalid_o_ <= 1;
		axi4_wvalid_o_ <= 1;
		axi4_bready_o <= 1;

	end else if (stall_n) begin

		axi4_awvalid_o_ <= 0;
		axi4_wvalid_o_ <= 0;
		axi4_arvalid_o_ <= 0;
		axi4_rready_o <= 0;
	end
end

initial begin
	cyc = 0;
	we = 0;
	axi4_awaddr_o = 0;
	axi4_awvalid_o_ = 0;
	axi4_wdata_o = 0;
	axi4_wstrb_o = 0;
	axi4_wvalid_o_ = 0;
	axi4_bready_o = 0;
	axi4_araddr_o = 0;
	axi4_arvalid_o_ = 0;
	axi4_rready_o = 0;
	axi4_rdata_hold = 0;
	pi1_op_i_hold = 0;
	wrpending = 0;
end

endmodule

`endif
