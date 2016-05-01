// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_TX_PHY_V
`define UART_TX_PHY_V

// Module implementing UART transmitter PHY.
// It follows RS232 standard signalling with the following properties:
// - Expect to send 8 data bits;
// 	no parity bits.
// - Send least significant bit first.
// - Transmit 2 stop bits.
// An 8 bits data transmission begins with a start bit
// which is a logic low state of the tx_o line, followed
// by the 8 bits to transmit and terminated by 1 or more
// stop bits which are logic high states of the tx_o line.

// Parameters:
//
// CLOCKCYCLESPERBITLIMIT
// 	Limit below which the input "clockcyclesperbit_i" can be set.
// 	It must be non-null. ie: 905; with the previous example,
// 	the max value that can be set on "clockcyclesperbit_i" is 904.

// Ports:
//
// rst_i
// 	This input reset the module.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// clockcyclesperbit_i
// 	This input is used to configure the bitrate used for transmission.
// 	Given the bitrate and frequency of the clock input "clk_i", the value
// 	of this input is calculated using the following formula: (clkfreq/bitrate);
// 	The result of the above formula should be rounded-down, because
// 	it is better to have a slightly lower estimation of the duration
// 	of a bit, this way a receiver is guarantied to always sample
// 	past the beginning of each bit, and not fall short by sampling
// 	the same bit twice. ie: For a clkfreq of 100 Mhz and a bitrate
// 	of 115200 bps, the above formula yield 866.056;
// 	the value of this input is then picked as: 866.
//
// stb_i
// 	This signal is to be set high to transmit "data_i" if "rdy_o" is high.
//
// data_i
// 	Byte value to transmit through "tx_o" when (stb_i && rdy_o) is true.
//
// rdy_o
// 	This signal is high when ready to transmit "data_i".
//
// tx_o
// 	Outgoing serial line.
//
// To flush unknown states through "tx_o" after poweron,
// this module must be run for a clock cycle count of at least
// (10 * CLOCKCYCLESPERBITLIMIT), with "stb_i" low.

module uart_tx_phy (

	 rst_i

	,clk_i

	,clockcyclesperbit_i

	,stb_i
	,data_i
	,rdy_o
	,tx_o
);

`include "lib/clog2.v"

parameter CLOCKCYCLESPERBITLIMIT       = 2;
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

input wire clk_i;

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire            stb_i;
input  wire [8 -1 : 0] data_i;
output wire            rdy_o;
output reg             tx_o = 1'b1;

// Transmitter is either sending stop bits,
// or waiting for the input "stb_i" to become high
// to begin transmitting the byte on the input data_i.
localparam TXIDLE = 0;

// Transmitter is transmitting data.
localparam TXSEND = 1;

reg txstate = TXIDLE; // Register which hold the state of the transmitter.

// Register holding bits to transmit captured from "data_i".
reg [8 -1 : 0] data = 0;

// Register which is used to keep track of the number of bit left to send.
reg [3 -1 : 0] bitcnt = 0;

// Register which is used to prevent garbaged transmission
// if changing the speed while a byte is transmitting.
reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit = 0;

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] cntr = 0;
wire                                     txen = (cntr >= clockcyclesperbit);

wire bsy = (txstate != TXIDLE || bitcnt);

assign rdy_o = !bsy;

always @ (posedge clk_i) begin

	if (rst_i) begin

		txstate <= TXIDLE;
		bitcnt <= 0;
		cntr <= 0;
		tx_o <= 1'b1;

	end else if ((stb_i && !bsy) || (txen && bsy)) begin

		if (txstate == TXIDLE) begin
			// The transmitter remains in this state until
			// "stb_i" becomes high to begin transmitting.

			// If bitcnt is true, stop bits are sent for the amount in bitcnt.
			if (bitcnt) begin
				bitcnt <= bitcnt - 1'b1;
				tx_o <= 1; // Stop bit.
			end else if (stb_i) begin
				txstate <= TXSEND;
				data <= data_i;
				tx_o <= 0; // Start bit.
				bitcnt <= 7;
				clockcyclesperbit <= clockcyclesperbit_i;
			end

		end else begin

			tx_o <= data[0];

			if (bitcnt) begin
				bitcnt <= bitcnt - 1'b1;
				data <= data >> 1'b1;
			end else begin
				txstate <= TXIDLE;
				bitcnt <= 2; // 2 stop bits to send.
			end
		end

		cntr <= 0;

	end else if (!txen)
		cntr <= cntr + 1'b1;
end

endmodule

`endif /* UART_TX_PHY_V */
