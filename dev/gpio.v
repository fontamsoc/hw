// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/dbncr.v"

module gpio (

	rst_i,

	clk_i,

	pi1_op_i,
	pi1_addr_i,
	pi1_data_i,
	pi1_data_o,
	pi1_sel_i,
	pi1_rdy_o,
	pi1_mapsz_o,

	intrqst_o,
	intrdy_i,

	i, o, t
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;
parameter CLKFREQ   = 0;
parameter IOCOUNT   = 0;

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
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire intrqst_o;
input  wire intrdy_i;

input  wire [IOCOUNT -1 : 0] i;
output reg  [IOCOUNT -1 : 0] o;
output reg  [IOCOUNT -1 : 0] t;

assign pi1_rdy_o = 1;

assign pi1_mapsz_o = ((ARCHBITSZ<64)?(64/ARCHBITSZ):1);

wire [IOCOUNT -1 : 0] _i;

reg [(ARCHBITSZ -1) -1 : 0] debounce;

genvar genlowpass_idx;
generate for (genlowpass_idx = 0; genlowpass_idx < IOCOUNT; genlowpass_idx = genlowpass_idx + 1) begin: genlowpass
dbncr  #(
	 .THRESBITSZ (ARCHBITSZ -1)
	,.INIT       (1'b0)
) dbncr (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.i        (i[genlowpass_idx])
	,.o        (_i[genlowpass_idx])
	,.thresh_i (debounce)
);
end endgenerate

wire [IOCOUNT -1 : 0] ival = (_i & ~t);

reg [IOCOUNT -1 : 0] ivalsampled;

wire [IOCOUNT -1 : 0] ivalchanged = (ival ^ ivalsampled);

reg [IOCOUNT -1 : 0] ivalchange;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDCONFIGUREIO = 0;
localparam CMDSETDEBOUNCE = 1;

assign intrqst_o = |ivalchange;

reg intrdy_i_sampled;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_sampled);

always @(posedge clk_i) begin

	if (rst_i)
		t <= 0;
	else if (pi1_op_i == PIRWOP && pi1_data_i[ARCHBITSZ-1] == CMDCONFIGUREIO)
		t <= pi1_data_i[ARCHBITSZ-2:0];

	if (rst_i)
		o <= 0;
	else if (pi1_op_i == PIWROP)
		o <= pi1_data_i[ARCHBITSZ-2:0];

	if (intrdy_i_negedge)
		ivalchange <= 0;
	else
		ivalchange <= (ivalchange | ivalchanged);

	if (pi1_op_i == PIRWOP && pi1_data_i[ARCHBITSZ-1] == CMDSETDEBOUNCE)
		debounce <= pi1_data_i[ARCHBITSZ-2:0];

	if (pi1_op_i == PIRDOP) begin
		pi1_data_o <= ival;
	end else if (pi1_op_i == PIRWOP) begin
		if (pi1_data_i[ARCHBITSZ-1] == CMDCONFIGUREIO)
			pi1_data_o <= IOCOUNT;
		else if (pi1_data_i[ARCHBITSZ-1] == CMDSETDEBOUNCE)
			pi1_data_o <= CLKFREQ;
	end

	ivalsampled <= ival;

	intrdy_i_sampled <= intrdy_i;
end

endmodule
