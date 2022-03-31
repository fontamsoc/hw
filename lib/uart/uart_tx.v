// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_TX_V
`define UART_TX_V

// Module implementing UART transmitter.

// Parameters:
//
// BUFSZ
// 	Size in bytes of the buffer storing bytes to transmit.
// 	It must be at least 2 and a power of 2.
//
// CLOCKCYCLESPERBITLIMIT
// 	Limit below which the input "clockcyclesperbit_i" can be set.
// 	It must be non-null. ie: 905; with the previous example,
// 	the max value that can be set on "clockcyclesperbit_i" is 904.

// Ports:
//
// rst_i
// 	This input reset the trasmit buffer empty.
//
// clk_i
// 	Clock input used to write data in the transmit buffer.
//
// clk_phy_i
// 	Clock input used by the PHY which transmits bits.
// 	"clockcyclesperbit_i" is to be set with respect
// 	to the frequency of this input.
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
// write_i
// data_i
// full_o
// usage_o
// 	FIFO interface to buffer the data to transmit.
//
// tx_o
// 	Outgoing serial line.

`include "lib/fifo.v"
`include "lib/uart/uart_tx_phy.v"

module uart_tx (

	 rst_i

	,clk_i
	,clk_phy_i

	,clockcyclesperbit_i

	,write_i
	,data_i
	,full_o
	,usage_o

	,tx_o
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

input  wire                          write_i;
input  wire [8 -1 : 0]               data_i;
output wire                          full_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_o;

output wire tx_o;

// This register is set to 1, when data was read from fifo.
reg tx_read_done = 0;

wire tx_read_stb = (usage_o && !tx_read_done);

wire            tx_empty_w;
wire [8 -1 : 0] tx_data_w;

fifo #(

	 .WIDTH (8)
	,.DEPTH (BUFSZ)

) tx (

	 .rst_i (rst_i)

	,.usage_o (usage_o)

	,.clk_read_i (clk_phy_i)
	,.read_i     (tx_read_stb)
	,.data_o     (tx_data_w)
	,.empty_o    (tx_empty_w)

	,.clk_write_i (clk_i)
	,.write_i     (write_i)
	,.data_i      (data_i)
	,.full_o      (full_o)
);

wire tx_phy_rdy_w;

uart_tx_phy #(

	.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) tx_phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.clockcyclesperbit_i (clockcyclesperbit_i)

	,.stb_i  (tx_phy_rdy_w && tx_read_done)
	,.data_i (tx_data_w)
	,.rdy_o  (tx_phy_rdy_w)
	,.tx_o   (tx_o)
);

// Register used to save the state of tx_phy_rdy_w
// in order to detect its falling edge.
reg tx_phy_rdy_w_sampled;

// Logic that set the net tx_phy_rdy_w_negedge
// when a falling edge of tx_phy_rdy_w occurs.
wire tx_phy_rdy_w_negedge = (tx_phy_rdy_w < tx_phy_rdy_w_sampled);

always @(posedge clk_phy_i) begin
	// Logic that update tx_read_done.
	if (rst_i || (tx_read_done && tx_phy_rdy_w_negedge))
		tx_read_done <= 0;
	else if (tx_read_stb)
		tx_read_done <= 1;

	// Save the current state of tx_phy_rdy_w;
	tx_phy_rdy_w_sampled <= tx_phy_rdy_w;
end

endmodule

`endif /* UART_TX_V */
