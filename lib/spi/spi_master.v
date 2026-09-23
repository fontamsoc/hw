// SPDX-License-Identifier: GPL-2.0-only
// 20260923 (c) William Fonkou Tambe

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
// 	Its frequency, denoted CLKFREQ below, together with the input
// 	"sclkdiv_i", determine the transmission bitrate.
//
// sclk_o
// mosi_o
// miso_i
// cs_o
// 	SPI master signals.
//
// sclkdiv_i
// 	This input is used to adjust the bitrate; it is the number of clock
// 	cycles of "clk_phy_i" per half-period of the output "sclk_o", less
// 	one, and a null value is valid.
// 	The resulting bitrate is computed as follow: (CLKFREQ/(2*(sclkdiv_i+1))).
// 	For a CLKFREQ of 100 Mhz and a value of 1 on the input "sclkdiv_i",
// 	it results in a bitrate of 25 Mbps.
// 	Each half-period of "sclk_o" lasts (sclkdiv_i+1) clock cycles, hence
// 	its duty cycle is 50% for every value of this input.
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
//
// misoSync_i
// 	When this signal is high, the transmission does not begin until
// 	a null bit has been sampled from the input "miso_i"; until then,
// 	"sclk_o" keeps toggling with the output "cs_o" held low, and
// 	"mosi_o" keeps presenting the most significant bit of the data
// 	at the head of the transmit buffer, which must be 1'b1 in order
// 	for "mosi_o" to remain high while waiting.
// 	It is used with a slave which signals the beginning of its response
// 	using a null bit, such as the start-bit of an SD card in SPI mode.
// 	Once synchronized, it remains so until the output "cs_o" becomes
// 	high, which happens when the transmit buffer runs empty; hence
// 	the data that follow in an uninterrupted transmission are retrieved
// 	without waiting for a null bit again.
//
// misoSkipSyncBit_i
// 	This signal must be asserted only when the input "misoSync_i" is
// 	true, and must be null otherwise, as it would corrupt the first
// 	data transmitted after the output "cs_o" was high.
// 	When high, the null bit that synchronized the transmission is
// 	discarded, and the DATABITSZ bits that follow it become the data
// 	pushed in the receive buffer; when low, that null bit becomes the
// 	most significant bit of that data.

`include "lib/fifo.v"

`include "./spi_master_phy.v"

module spi_master (
	rst_i,
	clk_i, clk_phy_i,
	sclk_o, mosi_o, miso_i, cs_o,
	sclkdiv_i,
	write_i, data_i, full_o,
	read_i, data_o, empty_o,
	misoSync_i, misoSkipSyncBit_i
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

input  wire                    write_i;
input  wire [DATABITSZ -1 : 0] data_i;
output wire                    full_o;

input  wire                    read_i;
output wire [DATABITSZ -1 : 0] data_o;
output wire                    empty_o;

input wire misoSync_i;
input wire misoSkipSyncBit_i;

wire fifo_tx_empty_w;

wire phy_rdy_w;
wire phy_rcvd_w;

wire [DATABITSZ -1 : 0] phy_data_w0;
wire [DATABITSZ -1 : 0] phy_data_w1;

reg phy_stb_w = 0;

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

	,.stb_i     (phy_stb_w)
	,.rdy_o     (phy_rdy_w)
	,.rcvd_o    (phy_rcvd_w)
	,.sclkdiv_i (sclkdiv_i)

	,.data_o (phy_data_w0)
	,.data_i (phy_data_w1)

	,.misoSync_i        (misoSync_i)
	,.misoSkipSyncBit_i (misoSkipSyncBit_i)
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

wire fifo_tx_read_w = (!fifo_tx_empty_w && (!phy_stb_w || phy_rdy_w_negedge));
always @ (posedge clk_phy_i) begin
	if (rst_i)
		phy_stb_w <= 1'b0;
	else if (fifo_tx_read_w)
		phy_stb_w <= 1'b1;
	else if (phy_rdy_w_negedge)
		phy_stb_w <= 1'b0;
end

fifo #( // fifo for buffering data to transmit.
	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)
) fifo_tx (

	 .rst_i (rst_i)

	,.clk_read_i (clk_phy_i)
	,.read_i     (fifo_tx_read_w)
	,.data_o     (phy_data_w1)
	,.empty_o    (fifo_tx_empty_w)

	,.clk_write_i (clk_i)
	,.write_i     (write_i)
	,.data_i      (data_i)
	,.full_o      (full_o)
);

endmodule

`endif /* SPI_MASTER_V */
