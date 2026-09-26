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
// 	it must be greater than 1, also because
// 	a control data uses its two least significant bits.
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
// near_full_o
// full_o
// usage_tx_o
// 	Fifo interface to buffer the data to transmit.
// 	The output "cs_o" becomes high when there is no data
// 	in the transmit buffer to send after the last data
// 	has been transmitted.
//
// 	Note that a data read from the transmit buffer is held outside of it
// 	until it has been transmitted, hence the output "full_o" frees a slot
// 	one data ahead of the transmission, and the buffer holds one data more
// 	than BUFSZ. A caller must not rely on "full_o" to pace itself against
// 	the transmission; in particular, if it computes something per data
// 	buffered, such as a CRC over each data, it must pace itself against
// 	that computation explicitly, and not assume that "full_o" leaves it
// 	the time a transmission would.
//
// 	The data which begins a transmission, ie: the first data taken for
// 	transmission while the output "cs_o" is high, is a control data:
// 	it configures that transmission instead of being transmitted, and
// 	{DATABITSZ{1'b1}} is transmitted in its place. The data which follow
// 	it within that transmission are transmitted as usual.
//
// 	The inverse of the least significant bit of a control data enables
// 	waiting for a null bit sampled from the input "miso_i" before
// 	counting the bits transmitted; until then, "sclk_o" keeps toggling
// 	with the output "cs_o" held low, and "mosi_o" remains high, since
// 	{DATABITSZ{1'b1}} is what gets transmitted in place of a control
// 	data. It is used with a slave which signals the beginning of its
// 	response using a null bit, such as the start-bit of an SD card in
// 	SPI mode. Once synchronized, it remains so until the output "cs_o"
// 	becomes high, which happens when the transmit buffer runs empty;
// 	hence the data that follow in an uninterrupted transmission are
// 	retrieved without waiting for a null bit again.
//
// 	The inverse of the 2nd least significant bit of a control data
// 	discards that null bit, so that the DATABITSZ bits which follow it
// 	become the data pushed in the receive buffer; when null, that null
// 	bit becomes the most significant bit of that data. It is ignored
// 	unless waiting for a null bit was enabled.
//
// 	The remaining bits of a control data are reserved and expected 1'b1;
// 	hence a control data of {DATABITSZ{1'b1}} configures a transmission
// 	which neither waits for a null bit nor discards one.
//
// 	Note that the transmission substituted for a control data also
// 	yields a data in the receive buffer, which is where the response of
// 	a slave signaling using a null bit gets retrieved.
//
// 	Note also that the transmit buffer must not run empty before the
// 	last data of a transmission has been buffered, otherwise the output
// 	"cs_o" becomes high, and the next data buffered begins a new
// 	transmission, becoming its control data instead of being transmitted.
//
// 	The output "near_full_o" is high when the transmit buffer is full
// 	or one data away from full.
//
// 	The output "usage_tx_o" is the count of the data not yet transmitted:
// 	those in the transmit buffer, the one read out of it and held until
// 	the phy takes it, and the one being transmitted; hence it reaches
// 	BUFSZ+2 at most, and it is null only when the transmission has ended
// 	with nothing left to transmit, so that a data buffered while it is
// 	null begins a new transmission, becoming its control data.
//
// read_i
// data_o
// empty_o
// usage_rx_o
// 	Fifo interface to retrieve the data received.
// 	The output "usage_rx_o" is the count of the data in the receive buffer.
//
// 	The outputs "usage_tx_o" and "usage_rx_o" each span the clocks
// 	"clk_i" and "clk_phy_i": sampled using "clk_i", they are exact only
// 	when both clocks are related as the documentation of the output
// 	"usage_o" of lib/fifo.sv requires, and must otherwise be debounced
// 	as it describes.

`include "lib/fifo.sv"

`include "lib/spi/spi_master_phy.sv"

module spi_master (
	rst_i,
	clk_i, clk_phy_i,
	sclk_o, mosi_o, miso_i, cs_o,
	sclkdiv_i,
	write_i, data_i, near_full_o, full_o, usage_tx_o,
	read_i, data_o, empty_o, usage_rx_o
);

`include "lib/clog2.sv"

parameter BUFSZ        = 2;
parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;

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
output wire                          near_full_o;
output wire                          full_o;
output wire [(CLOG2BUFSZ +2) -1 : 0] usage_tx_o;

input  wire                          read_i;
output wire [DATABITSZ -1 : 0]       data_o;
output wire                          empty_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_rx_o;

wire phy_rdy_w;
wire phy_rcvd_w;

wire [DATABITSZ -1 : 0] phy_data_w0;
wire [DATABITSZ -1 : 0] phy_data_w1;

reg phy_stb_r;

// Configuration latched from a control data; the phy samples those inputs
// at each bit transmitted, hence they must remain valid for the whole
// transmission, which they do until the next control data.
reg phy_misoSync_r;
reg phy_misoSkipSyncBit_r;

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

	,.stb_i     (phy_stb_r)
	,.rdy_o     (phy_rdy_w)
	,.rcvd_o    (phy_rcvd_w)
	,.sclkdiv_i (sclkdiv_i)

	,.data_o (phy_data_w0)
	,.data_i (phy_data_w1)

	,.misoSync_i        (phy_misoSync_r)
	,.misoSkipSyncBit_i (phy_misoSkipSyncBit_r)
);

fifo #( // fifo for storing data received.
	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)
) fifo_rx (

	 .rst_i (rst_i)

	,.usage_o (usage_rx_o)

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

reg phy_rdy_w_r;
always_ff @(posedge clk_phy_i)
	phy_rdy_w_r <= phy_rdy_w;
wire phy_rdy_w_negedge = (!phy_rdy_w && phy_rdy_w_r);

wire fifo_tx_empty_w;

wire [(CLOG2BUFSZ +1) -1 : 0] fifo_tx_usage_w;

wire fifo_tx_read_w = (!fifo_tx_empty_w && (!phy_stb_r || phy_rdy_w_negedge));
always_ff @(posedge clk_phy_i) begin
	if (rst_i)
		phy_stb_r <= 1'b0;
	else if (fifo_tx_read_w)
		phy_stb_r <= 1'b1;
	else if (phy_rdy_w_negedge)
		phy_stb_r <= 1'b0;
end

wire [DATABITSZ -1 : 0] fifo_tx_data_w;

// The phy takes a data either while idle, with the output "cs_o" high,
// which begins a transmission, or at the end of the data transmitted,
// with "cs_o" low, which continues it; hence whether a data is a control
// data is decided from "cs_o" in the clock cycle the phy takes it.
// It cannot be decided when the data is read from the transmit buffer,
// as the phy may become idle at that very clock edge, the buffer having
// run empty until then, and that data would begin a transmission while
// having been read as one continuing it.
// {DATABITSZ{1'b1}} gets transmitted in place of a control data, which also
// keeps "mosi_o" high while waiting for a null bit from the input "miso_i".
assign phy_data_w1 = (cs_o ? {DATABITSZ{1'b1}} : fifo_tx_data_w);

// The configuration is latched from a control data in the clock cycle the
// phy takes it, the only one where "phy_stb_r" is high while the output
// "cs_o" is high; the transmit buffer is not read in that clock cycle, the
// phy output "rdy_o" remaining high until then, and the phy first uses
// the configuration at the end of the first bit transmitted.
// Discarding the null bit is allowed only when waiting for it is enabled,
// as the phy would otherwise transmit one bit too many.
always_ff @(posedge clk_phy_i) begin
	if (rst_i) begin
		phy_misoSync_r <= 1'b0;
		phy_misoSkipSyncBit_r <= 1'b0;
	end else if (cs_o && phy_stb_r) begin
		phy_misoSync_r <= !fifo_tx_data_w[0];
		phy_misoSkipSyncBit_r <= (!fifo_tx_data_w[1] && !fifo_tx_data_w[0]);
	end
end

// Note that this fifo is not first-word-fall-through, hence a data is read
// out of it before being transmitted, and its usage no longer counts that
// data; the output "full_o" therefore frees a slot one data ahead of the
// transmission, which the documentation of "full_o" above warns about.
fifo #( // fifo for buffering data to transmit.
	 .WIDTH (DATABITSZ)
	,.DEPTH (BUFSZ)
) fifo_tx (

	 .rst_i (rst_i)

	,.usage_o (fifo_tx_usage_w)

	,.clk_read_i (clk_phy_i)
	,.read_i     (fifo_tx_read_w)
	,.data_o     (fifo_tx_data_w)
	,.empty_o    (fifo_tx_empty_w)

	,.clk_write_i (clk_i)
	,.write_i     (write_i)
	,.data_i      (data_i)
	,.near_full_o (near_full_o)
	,.full_o      (full_o)
);

// The data not yet transmitted: those in the transmit buffer, the one
// held on the phy input "data_i" until the phy takes it, and the one the
// phy is transmitting. The data held stops being counted in the clock
// cycle where "phy_rdy_w_negedge" is high, the phy having taken it at the
// clock edge which began that clock cycle, from which it is counted as
// the one being transmitted.
assign usage_tx_o = (fifo_tx_usage_w + (phy_stb_r && !phy_rdy_w_negedge) + !cs_o);

endmodule

`endif /* SPI_MASTER_V */
