// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SPI_MASTER_PHY_V
`define SPI_MASTER_PHY_V

// Module implementing SPI master PHY.

// Parameters.
//
// DATABITSZ:
// 	Number of bits per data to transmit;
//  it must be greater than 1.
//
// SCLKDIVLIMIT:
// 	Limit below which the input "sclkdiv_i" must be set.

// Ports.
//
// clk_i
// 	Clock signal.
// 	Its frequency determine the transmission bitrate
// 	which is computed as follow: (CLKFREQ / (1 << sclkdiv_i)).
// 	For a CLKFREQ of 100 Mhz and a value of 0 on the input
// 	"sclkdiv_i", it results in a bitrate of 100 Mbps.
//
// sclk_o
// mosi_o
// miso_i
// cs_o
// 	SPI master signals.
//
// sclkdiv_i
// 	This input is used to adjust the bitrate.
// 	The resulting bitrate is computed as follow: (CLKFREQ / (1 << sclkdiv_i)).
// 	For a CLKFREQ of 100 Mhz and a value of 0 on the input
// 	"sclkdiv_i", it results in a bitrate of 100 Mbps.
//
// stb_i
// 	This signal is set high to begin transmitting the data value on
// 	the input "data_i" and receiving a data value on the output "data_o".
// 	When the output "rdy_o" is high, transmission begins
// 	on the next active edge of the clock input "clk_i".
// 	To prevent the output "cs_o" from becoming high between each
// 	data transmission, this signal must be set high as soon as
// 	the output "rdy_o" becomes high.
//
// rdy_o
// 	This signal is high when ready to transmit "data_i".
//
// rcvd_o
// 	This signal is high for a single clock cycle
//  when data is ready to be sampled on "data_o".
//
// data_o
// 	Data received which is valid only while "rcvd_o" is high.
//
// data_i
// 	Data value to transmit through "mosi_o" when (stb_i && rdy_o) is true.
//
// To flush unknown states on the outputs "mosi_o" and "cs_o"
// after poweron, this module must be run for a clock cycle count
// of at least (DATABITSZ * (1 << (SCLKDIVLIMIT-1))) with "stb_i" low.

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

// Register holding bits used to set the output "mosi_o".
reg [DATABITSZ -1 : 0] mosibits = {DATABITSZ{1'b1}};

// Register used to keep track of the number of clock cycles.
reg [SCLKDIVLIMIT : 0] cntr = 0;

// Register which is used to keep track
// of the number of bits left to transmit.
reg [CLOG2DATABITSZ -1 : 0] bitcnt = 0;

assign rdy_o = !bitcnt;

wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_w;
wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_w_minus_one = (sclkdiv_w-1);

assign sclkdiv_w = ((sclkdiv_i < 1) ? 1 : sclkdiv_i);
assign sclk_o = cntr[sclkdiv_w_minus_one];
assign mosi_o = mosibits[DATABITSZ -1];

// Register used to detect a falling edge on "rdy_o".
reg rdy_o_sampled = 1;

// This logic set the net rdy_o_negedge to 1
// when the falling edge of "rdy_o" occurs.
wire rdy_o_negedge = (rdy_o < rdy_o_sampled);

// Register used to detect a falling/rising edge on "cs_o".
reg cs_o_sampled = 1;

wire cs_o_negedge = (cs_o < cs_o_sampled);

wire cs_o_posedge = (cs_o > cs_o_sampled);

// Data has been received when either of the following condition occurs:
// - A falling edge on "rdy_o";
// 	in this condition, data has been received only if there was no
// 	falling edge on "cs_o", otherwise it means that the transmission
//  just started and data still has yet to be received.
// - A rising edge on "cs_o".
//
// "rcvd_o" is high only for a single clock cycle since
// rdy_o_sampled and cs_o_sampled are updated every clock cycles.
assign rcvd_o = ((rdy_o_negedge && !cs_o_negedge) || cs_o_posedge);

always @ (posedge clk_i) begin

	if (!cs_o && (cntr == (({{SCLKDIVLIMIT{1'b0}}, 1'b1} << sclkdiv_w_minus_one) -1)))
		data_o <= {data_o[DATABITSZ -2 : 0], miso_i};

	// When the output "cs_o" is low, this block executes only
	// after every clock cycle count of ((1 << sclkdiv_w) -1);
	// when the output "cs_o" is high, this block executes every clock cycle.
	// ">=" is used so that the register "cntr" gets correctly wrapped
	// around when "sclkdiv_w" is suddently set to a value that makes
	// the register "cntr" greater than or equal to ((1 << sclkdiv_w) -1).
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

	end else
		cntr <= cntr + 1'b1;

	rdy_o_sampled <= rdy_o;

	cs_o_sampled <= cs_o;
end

endmodule

`endif /* SPI_MASTER_PHY_V */
