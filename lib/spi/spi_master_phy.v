// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SPI_MASTER_PHY_V
`define SPI_MASTER_PHY_V

module spi_master_phy (

	clk_i

	,sclk_o ,mosi_o ,miso_i ,cs_o

	,stb_i ,rdy_o ,rcvd_o ,sclkdiv_i

	,data_o ,data_i
);

`include "lib/clog2.v"

parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 1;

localparam CLOG2DATABITSZ    = clog2(DATABITSZ);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

input wire clk_i;

output wire sclk_o;
output wire mosi_o;
input  wire miso_i;
output reg  cs_o = 1'b1;

input  wire                            stb_i;
output wire                            rdy_o;
output wire                            rcvd_o;
input  wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_i;

output reg  [DATABITSZ -1 : 0] data_o;
input  wire [DATABITSZ -1 : 0] data_i;

reg [DATABITSZ -1 : 0] mosibits = {DATABITSZ{1'b1}};

reg [SCLKDIVLIMIT : 0] cntr = 0;

reg [CLOG2DATABITSZ -1 : 0] bitcnt = 0;

assign rdy_o = !bitcnt;

wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_w;

assign sclkdiv_w = ((sclkdiv_i == 0) ? (sclkdiv_i+1) : sclkdiv_i);
assign sclk_o = cntr[sclkdiv_w-1];
assign mosi_o = mosibits[DATABITSZ -1];

reg rdy_o_sampled = 1;

wire rdy_o_negedge = (rdy_o < rdy_o_sampled);

reg cs_o_sampled = 1;

wire cs_o_negedge = (cs_o < cs_o_sampled);

wire cs_o_posedge = (cs_o > cs_o_sampled);

assign rcvd_o = ((rdy_o_negedge && !cs_o_negedge) || cs_o_posedge);

always @ (posedge clk_i) begin

	if ((sclkdiv_w == 0) || (cntr == (({{SCLKDIVLIMIT{1'b0}}, 1'b1} << (sclkdiv_w-1)) -1))) begin
		data_o <= {data_o[DATABITSZ -2 : 0], miso_i};
	end

	if (cs_o || (cntr >= (({{SCLKDIVLIMIT{1'b0}}, 1'b1} << sclkdiv_w) -1))) begin

		if (bitcnt)
			mosibits <= (mosibits << 1);
		else
			mosibits <= data_i;

		if (bitcnt)
			bitcnt <= bitcnt - 1'b1;
		else if (stb_i)
			bitcnt <= (DATABITSZ -1);

		cs_o <= !(bitcnt || stb_i);

		cntr <= 0;

	end else cntr <= cntr + 1'b1;

	rdy_o_sampled <= rdy_o;

	cs_o_sampled <= cs_o;
end

endmodule

`endif
