// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_RX_PHY_V
`define UART_RX_PHY_V

// Module implementing UART receiver PHY.
// It follows RS232 standard signalling with the following properties:
// - Expect to receive 8 data bits;
// 	no parity bits.
// - Receive least significant bit first.
// - Expect to receive at least 1 stop bit;
// 	will not check or fail if there is
// 	more than 1 stop bit.
// An 8 bits data transmission begins with a start bit
// which is a logic low state of the rx_i line, followed
// by the 8 bits to transmit and terminated by 1 or more
// stop bits which are logic high states of the rx_i line.

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
// 	This input is used to adjust the transmission bitrate.
// 	Given the bitrate and frequency of the clock input clk_i,
// 	the value of this input is calculated using the following formula:
// 	((clkfreq/bitrate) + ((clkfreq/bitrate)/10/2)); where the expression
// 	((clkfreq/bitrate)/10/2) is the clock cycles amount that insures
// 	that the receiver will sample past the start of each bit.
// 	Note that, as the receiver goes through its idle state to start
// 	receiving the next byte, any accumulated skew from the beginning of
// 	a bit get discarded as the receiver detects the exact beginning of a bit.
// 	ie: For a clkfreq of 100 Mhz and a bitrate of 115200 bps, the above
// 	formula yield 909.458; the value of this input is then picked as: 909.
//
// rx_i
// 	Incoming serial line.
//
// rcvd_o
// 	This signal is high for one clock cycle when a byte has been received.
//
// data_o
// 	Byte received which is valid only when "rcvd_o" is high.
//
// To skip unknown states on the output "rcvd_o" after poweron,
// this module must be run for a clock cycle count of at least
// (10 * CLOCKCYCLESPERBITLIMIT), with "rx_i" set high.

module uart_rx_phy (

	 rst_i

	,clk_i

	,clockcyclesperbit_i

	,rx_i
	,rcvd_o
	,data_o
);

`include "lib/clog2.v"

parameter CLOCKCYCLESPERBITLIMIT       = 2;
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

input wire clk_i;

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire           rx_i;
output reg            rcvd_o = 0;
output reg [8 -1 : 0] data_o = 0;

// Receiver is waiting on a transmission.
localparam RXIDLE = 0;

// Receiver is receiving data.
localparam RXRCVD = 1;

// Receiver is checking for the end of a transmission.
localparam RXSTOP = 2;

reg [2 -1 : 0] rxstate = RXIDLE; // Register which hold the state of the receiver.

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] cntr = 0;

// Register which is used to keep track of the number of bits left to receive.
reg [3 -1 : 0] bitcnt = 0;

always @ (posedge clk_i) begin
	// Logic updating the register cntr.
	if (rst_i || rxstate == RXIDLE || cntr >= clockcyclesperbit_i)
		cntr <= 0;
	else cntr <= cntr + 1'b1;

	// Logic updating the register bitcnt and data_o.
	if (rxstate == RXRCVD) begin
		if (cntr >= clockcyclesperbit_i) begin
			// At the last bit to receive, "bitcnt" will be 0, and
			// will be automatically reset to 7 when decremented.
			bitcnt <= bitcnt - 1'b1;
			// Logic that stores each bit.
			data_o <= {rx_i, data_o[7:1]};
		end
	end else bitcnt <= 7;

	// Logic updating the registers rxstate and rcvd_o.
	if (rst_i)
		rxstate <= RXIDLE;
	else if (rxstate == RXIDLE) begin
		// I get here if the receiver is in an idle state.
		// I check for the start of a transmission.
		// A change of the incoming serial line state to low
		// indicates the start of a transmission.
		if (!rx_i)
			rxstate <= RXRCVD;

		rcvd_o <= 0;

	end else if (cntr >= clockcyclesperbit_i) begin

		if (rxstate == RXSTOP) begin
			// If I get here, I expect a stop bit which
			// corresponds to the incoming serial line being high.
			if (rx_i) rcvd_o <= 1;
			// If the expected stop bit is never found,
			// the rcvd_o bits are discarded since
			// the output "rcvd_o" never get set high.

			// I set the receiver state to iddle so
			// as to wait for the next transmission.
			rxstate <= RXIDLE;

		end else if (rxstate == RXRCVD) begin
			// At the last bit to receive, the receiver
			// state is set so as to expect a stop bit.
			if (!bitcnt)
				rxstate <= RXSTOP;

		end else
			rxstate <= RXIDLE;
	end
end

endmodule

`endif /* UART_RX_PHY_V */
