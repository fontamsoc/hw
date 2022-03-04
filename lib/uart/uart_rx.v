// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_RX_V
`define UART_RX_V

// Module implementing UART receiver.

// Parameters:
//
// BUFSZ
// 	Size in bytes of the buffer storing bytes received.
// 	It must be at least 2 and a power of 2.
//
// CLOCKCYCLESPERBITLIMIT
// 	Limit below which the input "clockcyclesperbit_i" can be set.
// 	It must be non-null. ie: 905; with the previous example,
// 	the max value that can be set on "clockcyclesperbit_i" is 904.

// Ports:
//
// rst_i
// 	This input reset the receive buffer empty.
//
// clk_i
// 	Clock input used to read data from the receive buffer.
//
// clk_phy_i
// 	Clock input used by the PHY which receives bits.
// 	"clockcyclesperbit_i" is to be set with respect
// 	to the frequency of this input.
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
// pop_i
// data_o
// empty_o
// usage_o
// 	FIFO interface to retrieve the data received.
//
// input rx_i
// 	Incoming serial line.

`include "lib/fifo_fwft.v"
`include "lib/uart/uart_rx_phy.v"

module uart_rx (

	 rst_i

	,clk_i
	,clk_phy_i

	,clockcyclesperbit_i

	,pop_i
	,data_o
	,empty_o
	,usage_o

	,rx_i
);

`include "lib/clog2.v"

parameter BUFSZ                  = 2;
parameter CLOCKCYCLESPERBITLIMIT = 2;

localparam CLOG2BUFSZ                  = clog2(BUFSZ);
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire                          pop_i;
output wire [8 -1 : 0]               data_o;
output wire                          empty_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_o;

input wire rx_i;

wire [8 -1 : 0] rx_data_w;
wire            rx_push_w;

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (BUFSZ)

) rx (

	 .rst_i (rst_i)

	,.usage_o (usage_o)

	,.clk_pop_i (clk_i)
	,.pop_i     (pop_i)
	,.data_o    (data_o)
	,.empty_o   (empty_o)

	,.clk_push_i (clk_phy_i)
	,.push_i     (rx_push_w)
	,.data_i     (rx_data_w)
);

uart_rx_phy #(

	.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) rx_phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.clockcyclesperbit_i (clockcyclesperbit_i)

	,.rx_i   (rx_i)
	,.rcvd_o (rx_push_w)
	,.data_o (rx_data_w)
);

endmodule

`endif /* UART_RX_V */
