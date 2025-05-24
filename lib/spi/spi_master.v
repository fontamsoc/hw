// SPDX-License-Identifier: GPL-2.0-only
// 20250519 (c) William Fonkou Tambe

`ifndef SPI_MASTER_V
`define SPI_MASTER_V

// Module implementing SPI master.

// Parameters.
//
// BUFSZ:
// 	Size of the receive and transmit buffers which
// 	store the data received and the data to transmit.
// 	It must be greater than 1 and a power of 2.
//
// DATABITSZ:
// 	Number of bits per data to transmit;
// 	it must be greater than 1.
//
// SCLKDIVLIMIT:
// 	Limit below which the input "sclkdiv_i" must be set.
//
// CPOL:
// 	SPI clock polarity.

// Ports.
//
// rst_i
// 	This input reset empty the receive and transmit buffer.
//
// clk_i
// 	Clock input used by the reset signal, and used to write data
// 	in the transmit buffer, and read data from the receive buffer.
//
// clk_phy_i
// 	Clock input used by the phy device which transmit/receive.
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
// write_i
// data_i
// full_o
// 	Fifo interface to buffer the data to transmit.
// 	The output "cs_o" becomes high when there is no data
// 	in the transmit buffer to send after the last data
// 	has been transmitted.
//
// read_i
// data_o
// empty_o
// 	Fifo interface to retrieve the data received.

`include "lib/fifo.v"
`include "lib/fifo_fwft.v"

`include "./spi_master_phy.v"

module spi_master (
	rst_i,
	clk_i, clk_phy_i,
	sclk_o, mosi_o, miso_i, cs_o,
	sclkdiv_i,
	push_i, data_i, full_o,
	read_i, data_o, empty_o
);

`include "lib/clog2.v"

parameter BUFSZ        = 2;
parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;

localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

output wire sclk_o;
output wire mosi_o;
input  wire miso_i;
output wire cs_o;

input wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_i;

input  wire                    push_i;
input  wire [DATABITSZ -1 : 0] data_i;
output wire                    full_o;

input  wire                    read_i;
output wire [DATABITSZ -1 : 0] data_o;
output wire                    empty_o;

wire fifo_tx_empty_w;

wire phy_rdy_w;
wire phy_rcvd_w;

wire [DATABITSZ -1 : 0] phy_data_w0;
wire [DATABITSZ -1 : 0] phy_data_w1;

spi_master_phy #(
	 .SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.DATABITSZ    (DATABITSZ)
	,.CPOL         (CPOL)
) spi_phy (
	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.mosi_o (mosi_o)
	,.miso_i (miso_i)
	,.cs_o   (cs_o)

	,.stb_i     (!fifo_tx_empty_w)
	,.rdy_o     (phy_rdy_w)
	,.rcvd_o    (phy_rcvd_w)
	,.sclkdiv_i (sclkdiv_i)

	,.data_o (phy_data_w0)
	,.data_i (phy_data_w1)
);

fifo #( // fifo for storing data received.
	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)
) fifo_rx (

	 .rst_i (rst_i)

	,.clk_read_i (clk_i)
	,.read_i     (read_i)
	,.data_o     (data_o)
	,.empty_o    (empty_o)

	// Note that "phy_rcvd_w" is high only
	// for a single clock cycle of "clk_phy_i".
	,.clk_write_i (clk_phy_i)
	,.write_i     (phy_rcvd_w)
	,.data_i      (phy_data_w0)
);

reg phy_rdy_w_sampled = 0;
always @ (posedge clk_phy_i)
		phy_rdy_w_sampled <= phy_rdy_w;
wire phy_rdy_w_negedge = (!phy_rdy_w && phy_rdy_w_sampled);

fifo_fwft #( // fifo for buffering data to transmit.
	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)
) fifo_tx (

	 .rst_i (rst_i)

	,.clk_pop_i (clk_phy_i)
	,.pop_i     (phy_rdy_w_negedge)
	,.data_o    (phy_data_w1)
	,.empty_o   (fifo_tx_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (push_i)
	,.data_i     (data_i)
	,.full_o     (full_o)
);

endmodule

`endif /* SPI_MASTER_V */
