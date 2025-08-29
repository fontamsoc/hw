// SPDX-License-Identifier: GPL-2.0-only
// 20250519 (c) William Fonkou Tambe

`ifndef SPI_MASTER_PHY_V
`define SPI_MASTER_PHY_V

// Module implementing SPI master PHY, with CPHA == 0.

// Parameters.
//
// DATABITSZ:
// 	Number of bits per data to transmit;
//  it must be greater than 1.
//
// SCLKDIVLIMIT:
// 	Limit below which the input "sclkdiv_i" must be set.
//
// CPOL:
// 	SPI clock polarity.

// Ports.
//
// clk_i
// 	Clock signal.
// 	Its frequency determine the transmission bitrate
// 	which is computed as follow: (CLKFREQ / (1 << sclkdiv_i)).
// 	For a CLKFREQ of 100 Mhz and a value of 1 on the input "sclkdiv_i",
// 	it results in a bitrate of 50 Mbps.
//
// sclk_o
// mosi_o
// miso_i
// cs_o
// 	SPI master signals.
//
// sclkdiv_i
// 	This input is used to adjust the bitrate, and must be non-null.
// 	The resulting bitrate is computed as follow: (CLKFREQ/(sclkdiv_i+1)).
// 	For a CLKFREQ of 100 Mhz and a value of 1 on the input "sclkdiv_i",
// 	it results in a bitrate of 50 Mbps.
//
// stb_i
// 	This signal is set high to begin transmitting the data value on
// 	the input "data_i" and receiving a data value on the output "data_o".
// 	It must be held high until transmission begins (ie: signal "rdy_o" negedge).
// 	To prevent the output "cs_o" from becoming high between each data transmission,
// 	this signal must be set high as soon as the signal "rdy_o" posedge.
//
// rdy_o
// 	This signal is high when ready to transmit "data_i".
//
// rcvd_o
// 	This signal is high for a single clock cycle
// 	when data is ready to be sampled on "data_o".
//
// data_o
// 	Data received which is valid only while "rcvd_o" is high.
//
// data_i
// 	Data value to transmit through "mosi_o".

module spi_master_phy (
	rst_i, clk_i,
	sclk_o, mosi_o, miso_i, cs_o,
	stb_i, rdy_o, rcvd_o, sclkdiv_i,
	data_o, data_i,
	misoSync_i, misoSkipSyncBit_i
);

`include "lib/clog2.v"

parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;

localparam CLOG2DATABITSZ    = clog2(DATABITSZ);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

input wire rst_i;

input wire clk_i;

output reg  sclk_o = (|CPOL);
output wire mosi_o;
input  wire miso_i;
output reg  cs_o = 1'b1;

input  wire stb_i;
output reg  rdy_o = 1'b1;
output reg  rcvd_o = 1'b0;

input wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_i;

output reg  [DATABITSZ -1 : 0] data_o;
input  wire [DATABITSZ -1 : 0] data_i;

input wire misoSync_i;
input wire misoSkipSyncBit_i;

wire misoIsLow = !data_o[0];

reg inSync = 0; // Relevant only if misoSync_i is true.

reg  [DATABITSZ -1 : 0] mosibits = {DATABITSZ{1'b1}};
assign mosi_o = mosibits[DATABITSZ-1];

// Keep track of the number of bits left to transmit.
reg [CLOG2DATABITSZ -1 : 0] bitcnt = 0;
wire bitcntNull = !bitcnt;
wire bitcntNull_and_stbNull = (bitcntNull && !stb_i);

// Keep track of the number of clock cycles.
reg [CLOG2SCLKDIVLIMIT -1 : 0] cntr;

always @ (posedge clk_i) begin
	if (rst_i) begin
		sclk_o <= (|CPOL);
		cs_o <= 1'b1;
		rdy_o <= 1'b1;
		rcvd_o <= 1'b0;
		inSync <= 1'b0;
		mosibits <= {DATABITSZ{1'b1}};
		bitcnt <= 0;
	end else if (cs_o || (cntr == sclkdiv_i)) begin
		sclk_o <= (|CPOL);
		if (bitcnt) begin
			if (!misoSync_i || inSync || misoIsLow) begin
				if (!misoSkipSyncBit_i || inSync)
					bitcnt <= (bitcnt - 1'b1);
				mosibits <= {mosibits[(DATABITSZ-1)-1:0], 1'b1};
				inSync <= 1'b1;
			end
		end else if (stb_i) begin
			bitcnt <= (DATABITSZ-1);
			mosibits <= data_i;
		end else
			inSync <= 1'b0;
		cs_o <= bitcntNull_and_stbNull;
		rdy_o <= (bitcntNull_and_stbNull || (bitcnt == 1));
		rcvd_o <= (bitcntNull && !cs_o);
		cntr <= 0;
	end else begin
		if (cntr == {1'b0, sclkdiv_i[CLOG2SCLKDIVLIMIT-1:1]}) begin
			sclk_o <= ~(|CPOL);
			data_o <= {data_o[(DATABITSZ-1)-1:0], miso_i};
		end
		rcvd_o <= 1'b0;
		cntr <= (cntr + 1'b1);
	end
end

endmodule

`endif /* SPI_MASTER_PHY_V */
