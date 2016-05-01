// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

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

// Ports.
//
// rst_i
// 	This input reset empty the receive and transmit buffer.
// 	To prevent unwanted data in the receive buffer after reset,
// 	this input should be kept high for a clock cycle count of at
// 	least (DATABITSZ * (1 << (SCLKDIVLIMIT-1))) of the input "clk_phy_i".
//
// clk_i
// 	Clock input used by the reset signal, and used to write data
// 	in the transmit buffer, and read data from the receive buffer.
//
// clk_phy_i
// 	Clock input used by the physical device which transmit/receive.
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
// write_i
// data_i
// tx_usage_o
// full_o
// 	Fifo interface to buffer the data to transmit.
// 	The output "cs_o" become high when there is no data
// 	in the transmit buffer to send after the last data
// 	has been transmitted.
// 	A decrement of the output "tx_usage_o" indicates
// 	that a data was taken out of the transmit buffer
// 	and will be transmitted on the next active
// 	edge of the clock input "clk_phy_i".
// 	When the output "cs_o" is high, and data is added
// 	to the empty transmit buffer, transmission begins
// 	on the second active clock edge of "clk_phy_i".
//
// read_i
// data_o
// rx_usage_o
// empty_o
// 	Fifo interface to retrieve the data received.

`include "lib/fifo.v"

`include "./spi_master_phy.v"

module spi_master (

	 rst_i

	,clk_i ,clk_phy_i,

	,sclk_o ,mosi_o ,miso_i ,cs_o

	,sclkdiv_i

	,write_i ,data_i ,tx_usage_o ,full_o

	,read_i ,data_o ,rx_usage_o ,empty_o
);

`include "lib/clog2.v"

parameter BUFSZ        = 2;
parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 1;

localparam CLOG2BUFSZ        = clog2(BUFSZ);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

output wire sclk_o;
output wire mosi_o;
input  wire miso_i;
output wire cs_o;

input wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_i;

input  wire                          write_i;
input  wire [DATABITSZ -1 : 0]       data_i;
output wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_o;
output wire                          full_o;

input  wire                          read_i;
output wire [DATABITSZ -1 : 0]       data_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_o;
output wire                          empty_o;

reg fifo_tx_wasread = 0;

wire phy_rdy_w;
wire phy_rcvd_w;

wire [DATABITSZ -1 : 0] phy_data_w0;
wire [DATABITSZ -1 : 0] phy_data_w1;

spi_master_phy #(

	 .SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.DATABITSZ    (DATABITSZ)

) phy (

	 .clk_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.mosi_o (mosi_o)
	,.miso_i (miso_i)
	,.cs_o   (cs_o)

	,.stb_i     (fifo_tx_wasread)
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

	,.usage_o (rx_usage_o)

	,.clk_read_i (clk_i)
	,.read_i     (read_i)
	,.data_o     (data_o)
	,.empty_o    (empty_o)

	// Note that "phy_rcvd_w" is high only
	// for a single clock cycle of "clk_phy_i".
	,.clk_write_i (clk_phy_i)
	,.write_i     (phy_rcvd_w)
	,.data_i      (phy_data_w0)
	,.full_o      ()
);

wire fifo_tx_empty_w;

fifo #( // fifo for buffering data to transmit.

	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)

) fifo_tx (

	 .rst_i (rst_i)

	,.usage_o (tx_usage_o)

	,.clk_read_i (clk_phy_i)
	,.read_i     (!fifo_tx_wasread)
	,.data_o     (phy_data_w1)
	,.empty_o    (fifo_tx_empty_w)

	,.clk_write_i (clk_i)
	,.write_i     (write_i)
	,.data_i      (data_i)
	,.full_o      (full_o)
);

reg phy_rdy_w_sampled = 1;

wire phy_rdy_w_negedge = (phy_rdy_w < phy_rdy_w_sampled);

always @ (posedge clk_phy_i) begin

	if (rst_i || (fifo_tx_wasread && phy_rdy_w_negedge))
		fifo_tx_wasread <= 0;
	else if (!fifo_tx_empty_w && !fifo_tx_wasread)
		fifo_tx_wasread <= 1;

	phy_rdy_w_sampled <= phy_rdy_w;
end

endmodule

`endif /* SPI_MASTER_V */
