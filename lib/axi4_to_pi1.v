// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef AXI4_TO_PI1_V
`define AXI4_TO_PI1_V

module axi4_to_pi1 (

	 clk_i

	// Write Address Ports
	,axi4_awid_i
	,axi4_awaddr_i
	,axi4_awlen_i
	,axi4_awsize_i
	,axi4_awburst_i
	,axi4_awlock_i
	,axi4_awcache_i
	,axi4_awprot_i
	,axi4_awqos_i
	,axi4_awvalid_i
	,axi4_awready_o
	// Write Data Ports
	,axi4_wdata_i
	,axi4_wstrb_i
	,axi4_wlast_i
	,axi4_wvalid_i
	,axi4_wready_o
	// Write Response Ports
	,axi4_bready_i
	,axi4_bid_o
	,axi4_bresp_o
	,axi4_bvalid_o
	// Read Address Ports
	,axi4_arid_i
	,axi4_araddr_i
	,axi4_arlen_i
	,axi4_arsize_i
	,axi4_arburst_i
	,axi4_arlock_i
	,axi4_arcache_i
	,axi4_arprot_i
	,axi4_arqos_i
	,axi4_arvalid_i
	,axi4_arready_o
	// Read Data Ports
	,axi4_rready_i
	,axi4_rid_o
	,axi4_rdata_o
	,axi4_rresp_o
	,axi4_rlast_o
	,axi4_rvalid_o

	,pi1_op_o
	,pi1_addr_o
	,pi1_data_o
	,pi1_data_i
	,pi1_sel_o
	,pi1_rdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter AXI4_ID_WIDTH = 4;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input clk_i;

localparam OKAY   = 2'b00;
localparam EXOKAY = 2'b01;

// Write Address Ports
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_awid_i;
input  wire [ARCHBITSZ -1 : 0]     axi4_awaddr_i;
input  wire [7:0]                  axi4_awlen_i;
input  wire [2:0]                  axi4_awsize_i;
input  wire [1:0]                  axi4_awburst_i;
input  wire [0:0]                  axi4_awlock_i;
input  wire [3:0]                  axi4_awcache_i;
input  wire [2:0]                  axi4_awprot_i;
input  wire [3:0]                  axi4_awqos_i;
input  wire                        axi4_awvalid_i;
output wire                        axi4_awready_o;
// Write Data Ports
input  wire [ARCHBITSZ -1 : 0]     axi4_wdata_i;
input  wire [(ARCHBITSZ/8) -1 : 0] axi4_wstrb_i;
input  wire                        axi4_wlast_i;
input  wire                        axi4_wvalid_i;
output wire                        axi4_wready_o;
// Write Response Ports
input  wire                        axi4_bready_i;
output wire [AXI4_ID_WIDTH -1 : 0] axi4_bid_o;
output reg  [1:0]                  axi4_bresp_o = OKAY;
output wire                        axi4_bvalid_o;
// Read Address Ports
input  wire [AXI4_ID_WIDTH -1 : 0] axi4_arid_i;
input  wire [ARCHBITSZ -1 : 0]     axi4_araddr_i;
input  wire [7:0]                  axi4_arlen_i;
input  wire [2:0]                  axi4_arsize_i;
input  wire [1:0]                  axi4_arburst_i;
input  wire [0:0]                  axi4_arlock_i;
input  wire [3:0]                  axi4_arcache_i;
input  wire [2:0]                  axi4_arprot_i;
input  wire [3:0]                  axi4_arqos_i;
input  wire                        axi4_arvalid_i;
output wire                        axi4_arready_o;
// Read Data Ports
input  wire                        axi4_rready_i;
output wire [AXI4_ID_WIDTH -1 : 0] axi4_rid_o;
output wire [ARCHBITSZ -1 : 0]     axi4_rdata_o;
output reg  [1:0]                  axi4_rresp_o = OKAY;
output wire                        axi4_rlast_o;
output wire                        axi4_rvalid_o;

output wire [2 -1 : 0]             pi1_op_o;
output wire [ADDRBITSZ -1 : 0]     pi1_addr_o;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_o;
input  wire                        pi1_rdy_i;

wire axi4_rdop = (axi4_arvalid_i & axi4_rready_i);
wire axi4_wrop = (axi4_awvalid_i & axi4_wvalid_i & axi4_bready_i);

// ### Net declared as reg so to be usable within always@block.
reg [(ARCHBITSZ/8) -1 : 0] rstrb = 0;
always @* begin
	if (ARCHBITSZ == 16) begin
		if (axi4_arsize_i == 3'b000) begin
			if (axi4_araddr_i[0] == 1'b0) rstrb = 2'b01;
			else                          rstrb = 2'b10;
		end else
			rstrb = 2'b11;
	end else if (ARCHBITSZ == 32) begin
		if (axi4_arsize_i == 3'b000) begin
			if      (axi4_araddr_i[1:0] == 2'b00) rstrb = 4'b0001;
			else if (axi4_araddr_i[1:0] == 2'b01) rstrb = 4'b0010;
			else if (axi4_araddr_i[1:0] == 2'b10) rstrb = 4'b0100;
			else                                  rstrb = 4'b1000;
		end else if (axi4_arsize_i == 3'b001) begin
			if (axi4_araddr_i[1] == 1'b0) rstrb = 4'b0011;
			else                          rstrb = 4'b1100;
		end else
			rstrb = 4'b1111;
	end else if (ARCHBITSZ == 64) begin
		if (axi4_arsize_i == 3'b000) begin
			if      (axi4_araddr_i[2:0] == 3'b000) rstrb = 8'b00000001;
			else if (axi4_araddr_i[2:0] == 3'b001) rstrb = 8'b00000010;
			else if (axi4_araddr_i[2:0] == 3'b010) rstrb = 8'b00000100;
			else if (axi4_araddr_i[2:0] == 3'b011) rstrb = 8'b00001000;
			else if (axi4_araddr_i[2:0] == 3'b100) rstrb = 8'b00010000;
			else if (axi4_araddr_i[2:0] == 3'b101) rstrb = 8'b00100000;
			else if (axi4_araddr_i[2:0] == 3'b110) rstrb = 8'b01000000;
			else                                   rstrb = 8'b10000000;
		end else if (axi4_arsize_i == 3'b001) begin
			if      (axi4_araddr_i[2:1] == 2'b00) rstrb = 8'b00000011;
			else if (axi4_araddr_i[2:1] == 2'b01) rstrb = 8'b00001100;
			else if (axi4_araddr_i[2:1] == 2'b10) rstrb = 8'b00110000;
			else                                  rstrb = 8'b11000000;
		end else if (axi4_arsize_i == 3'b010) begin
			if      (axi4_araddr_i[2] == 1'b0) rstrb = 8'b00001111;
			else                               rstrb = 8'b11110000;
		end else
			rstrb = 8'b11111111;
	end else if (ARCHBITSZ == 128) begin
		if (axi4_arsize_i == 3'b000) begin
			if      (axi4_araddr_i[3:0] == 4'b0000) rstrb = 16'b0000000000000001;
			else if (axi4_araddr_i[3:0] == 4'b0001) rstrb = 16'b0000000000000010;
			else if (axi4_araddr_i[3:0] == 4'b0010) rstrb = 16'b0000000000000100;
			else if (axi4_araddr_i[3:0] == 4'b0011) rstrb = 16'b0000000000001000;
			else if (axi4_araddr_i[3:0] == 4'b0100) rstrb = 16'b0000000000010000;
			else if (axi4_araddr_i[3:0] == 4'b0101) rstrb = 16'b0000000000100000;
			else if (axi4_araddr_i[3:0] == 4'b0110) rstrb = 16'b0000000001000000;
			else if (axi4_araddr_i[3:0] == 4'b0111) rstrb = 16'b0000000010000000;
			else if (axi4_araddr_i[3:0] == 4'b1000) rstrb = 16'b0000000100000000;
			else if (axi4_araddr_i[3:0] == 4'b1001) rstrb = 16'b0000001000000000;
			else if (axi4_araddr_i[3:0] == 4'b1010) rstrb = 16'b0000010000000000;
			else if (axi4_araddr_i[3:0] == 4'b1011) rstrb = 16'b0000100000000000;
			else if (axi4_araddr_i[3:0] == 4'b1100) rstrb = 16'b0001000000000000;
			else if (axi4_araddr_i[3:0] == 4'b1101) rstrb = 16'b0010000000000000;
			else if (axi4_araddr_i[3:0] == 4'b1110) rstrb = 16'b0100000000000000;
			else                                    rstrb = 16'b1000000000000000;
		end else if (axi4_arsize_i == 3'b001) begin
			if      (axi4_araddr_i[3:1] == 3'b000) rstrb = 16'b0000000000000011;
			else if (axi4_araddr_i[3:1] == 3'b001) rstrb = 16'b0000000000001100;
			else if (axi4_araddr_i[3:1] == 3'b010) rstrb = 16'b0000000000110000;
			else if (axi4_araddr_i[3:1] == 3'b011) rstrb = 16'b0000000011000000;
			else if (axi4_araddr_i[3:1] == 3'b100) rstrb = 16'b0000001100000000;
			else if (axi4_araddr_i[3:1] == 3'b101) rstrb = 16'b0000110000000000;
			else if (axi4_araddr_i[3:1] == 3'b110) rstrb = 16'b0011000000000000;
			else                                   rstrb = 16'b1100000000000000;
		end else if (axi4_arsize_i == 3'b010) begin
			if      (axi4_araddr_i[3:2] == 2'b00) rstrb = 16'b0000000000001111;
			else if (axi4_araddr_i[3:2] == 2'b01) rstrb = 16'b0000000011110000;
			else if (axi4_araddr_i[3:2] == 2'b10) rstrb = 16'b0000111100000000;
			else                                  rstrb = 16'b1111000000000000;
		end else if (axi4_arsize_i == 3'b011) begin
			if      (axi4_araddr_i[3] == 1'b0) rstrb = 16'b0000000011111111;
			else                               rstrb = 16'b1111111100000000;
		end else
			rstrb = 16'b1111111111111111;
	end
end

wire [ARCHBITSZ -1 : 0] axi4_axaddr_w = {axi4_arvalid_i ? axi4_araddr_i : axi4_awaddr_i};
assign pi1_addr_o = axi4_axaddr_w[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)];
assign pi1_data_o = axi4_wdata_i;
assign axi4_rdata_o = pi1_data_i;
assign pi1_sel_o = (axi4_arvalid_i ? rstrb : axi4_wstrb_i);

// ----------------- Logic Implementing exclusive access ----------------

reg [(ARCHBITSZ-clog2(ARCHBITSZ/8)) -1 : 0] axi4_exaccess_addr  [(1<<AXI4_ID_WIDTH) -1 : 0];
reg [(ARCHBITSZ/8) -1 : 0]                  axi4_exaccess_strb  [(1<<AXI4_ID_WIDTH) -1 : 0];
reg                                         axi4_exaccess_valid [(1<<AXI4_ID_WIDTH) -1 : 0];
integer init_axi4_exaccess_idx;
initial begin
	for (init_axi4_exaccess_idx = 0; init_axi4_exaccess_idx < (1<<AXI4_ID_WIDTH); init_axi4_exaccess_idx = init_axi4_exaccess_idx + 1) begin
		axi4_exaccess_addr[init_axi4_exaccess_idx] = 0;
		axi4_exaccess_strb[init_axi4_exaccess_idx] = 0;
		axi4_exaccess_valid[init_axi4_exaccess_idx] = 0;
	end
end

integer gen_axi4_exaccess_valid_idx;
always @(posedge clk_i) begin

	if (pi1_rdy_i) begin
		if (axi4_arlock_i) begin
			if (axi4_rdop) begin
				axi4_rresp_o <= EXOKAY;
				axi4_exaccess_addr[axi4_arid_i] <= axi4_araddr_i[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)];
				axi4_exaccess_strb[axi4_arid_i] <= rstrb;
				axi4_exaccess_valid[axi4_arid_i] <= 1;
			end else
				axi4_rresp_o <= OKAY;
		end else
			axi4_rresp_o <= OKAY;

		if (axi4_wrop) begin
			if (axi4_awlock_i) begin
				if (axi4_exaccess_addr[axi4_awid_i] == axi4_awaddr_i[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)] &&
					!(|(axi4_exaccess_strb[axi4_awid_i] ^ axi4_wstrb_i)) && axi4_exaccess_valid[axi4_awid_i])
					axi4_bresp_o <= EXOKAY;
				else
					axi4_bresp_o <= OKAY;
			end else begin
				for (gen_axi4_exaccess_valid_idx = 0; gen_axi4_exaccess_valid_idx < (1<<AXI4_ID_WIDTH); gen_axi4_exaccess_valid_idx = gen_axi4_exaccess_valid_idx + 1) begin
					axi4_exaccess_valid[gen_axi4_exaccess_valid_idx] <=
						!(axi4_exaccess_addr[gen_axi4_exaccess_valid_idx] == axi4_awaddr_i[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)] &&
							(|(axi4_exaccess_strb[gen_axi4_exaccess_valid_idx] & axi4_wstrb_i)));
				end
				axi4_bresp_o <= OKAY;
			end
		end else
			axi4_bresp_o <= OKAY;
	end
end

// ### Net declared as reg so to be usable within always@block.
reg axi4_exaccess_wvalid;
always @* begin
	if (axi4_awlock_i) begin
		axi4_exaccess_wvalid = (
			axi4_exaccess_addr[axi4_awid_i] == axi4_awaddr_i[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)] &&
			!(|(axi4_exaccess_strb[axi4_awid_i] ^ axi4_wstrb_i)) &&
			axi4_exaccess_valid[axi4_awid_i]);
	end else
		axi4_exaccess_wvalid = 1;
end

assign pi1_op_o = ({axi4_rdop, axi4_wrop & axi4_exaccess_wvalid});

// ----------------------------------------------------------------------

reg [AXI4_ID_WIDTH -1 : 0] axi4_arid_hold = 0;
reg [AXI4_ID_WIDTH -1 : 0] axi4_awid_hold = 0;
always @(posedge clk_i) begin
	if (pi1_rdy_i) begin
		if (axi4_rdop)
			axi4_arid_hold <= axi4_arid_i;
		if (axi4_wrop)
			axi4_awid_hold <= axi4_awid_i;
	end
end

reg therewasaread = 0;
always @(posedge clk_i) begin
	if (pi1_rdy_i)
		therewasaread <= axi4_rdop;
end

reg therewasawrite = 0;
always @(posedge clk_i) begin
	if (pi1_rdy_i)
		therewasawrite <= axi4_wrop;
end

assign axi4_arready_o = pi1_rdy_i;
assign axi4_rvalid_o = (therewasaread & pi1_rdy_i);
assign axi4_rid_o = axi4_arid_hold;
assign axi4_rlast_o = (therewasaread & pi1_rdy_i);
assign axi4_awready_o = pi1_rdy_i;
assign axi4_wready_o = pi1_rdy_i;
assign axi4_bvalid_o = (therewasawrite & pi1_rdy_i);
assign axi4_bid_o = axi4_awid_hold;

endmodule

`endif /* AXI4_TO_PI1_V */
