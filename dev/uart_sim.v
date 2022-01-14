// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

module uart_sim (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqst_o
	,intrdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter BUFSZ = 2;

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = 0;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire intrqst_o;
input  wire intrdy_i;

assign pi1_rdy_o = 1;

assign pi1_mapsz_o = ((ARCHBITSZ<64)?(64/ARCHBITSZ):1);

reg [(CLOG2BUFSZ +1) -1 : 0] rx_usage_r = 0;

reg [(ARCHBITSZ-2) -1 : 0] intrqstthresh = 0;

assign intrqst_o = (|intrqstthresh && (rx_usage_r >= intrqstthresh));

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg  intrdysampled = 0;
wire intrdynegedge = (!intrdy_i && intrdysampled);

localparam CMDGETBUFFERUSAGE = 0;
localparam CMDSETINTERRUPT   = 1;
localparam CMDSETSPEED       = 2;

reg [ARCHBITSZ -1 : 0] cntr = 0;

always @ (posedge clk_i) begin
	if (rst_i) begin
		intrqstthresh <= 0;
	end else if (pi1_op_i == PIRWOP && pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT) begin
		//intrqstthresh <= pi1_data_i[(ARCHBITSZ-2)-1:0]; /* ### Uncomment to generate interrupts */
	end else if (intrdynegedge)
		intrqstthresh <= 0;

	if (rst_i);
	else if (pi1_op_i == PIRDOP)
		pi1_data_o <= "\n";
	else if (pi1_op_i == PIWROP) begin
		$write("%c", pi1_data_i[7:0]); $fflush(1);
	end else if (pi1_op_i == PIRWOP) begin
		pi1_data_o <= (
			pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT ? BUFSZ :
			pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDGETBUFFERUSAGE ?
				(pi1_data_i[(ARCHBITSZ-2)-1:0] ? 0 : rx_usage_r) : 0);
	end

	intrdysampled <= intrdy_i;

	if (rst_i || cntr >= 100000000) begin
		cntr <= 0;
		rx_usage_r <= BUFSZ;
	end else if (rx_usage_r) begin
		if (pi1_op_i == PIRDOP)
			rx_usage_r <= rx_usage_r - 1'b1;
	end else
		cntr <= cntr + 1'b1;
end

endmodule
