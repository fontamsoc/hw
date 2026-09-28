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
// 	it must be greater than 3, as a control
// 	data uses its four least significant bits.
//
// SCLKDIVLIMIT:
// 	Limit below which the input "sclkdiv_i" must be set.
//
// CPOL:
// 	SPI clock polarity.
//
// SYNCTIMEOUT:
// 	Number of clock cycles of "clk_phy_i" after which waiting for a null
// 	bit is given up, as described with the transmit buffer interface;
// 	a null value disables giving up.

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
// close_i
// 	Fifo interface to buffer the data to transmit.
// 	A transmission lasts until it is closed using the input "close_i";
// 	when the transmit buffer runs empty before, the transmission pauses:
// 	"sclk_o" remains at its idle level, "cs_o" keeps its level and nothing
// 	is clocked, until the next data buffered resumes it. Hence the data of
// 	a transmission can be buffered at any pace, and no data can begin a
// 	new transmission before the previous one was closed.
//
// 	The input "close_i", when high on a posedge of "clk_i", requests the
// 	end of the transmission, which happens once every data buffered before
// 	it has been transmitted, "cs_o" becoming high. The request remains
// 	pending until then; a data buffered meanwhile continues the
// 	transmission instead of beginning the next one, hence the next
// 	transmission is to be buffered once "usage_tx_o" is null. A request
// 	while no transmission is in progress does nothing, other than ending
// 	the discarding described below.
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
// 	transmission once the previous transmission has ended, is a control
// 	data: it configures that transmission instead of being transmitted,
// 	and {DATABITSZ{1'b1}} is transmitted in its place. The data which
// 	follow it within that transmission are transmitted as usual.
//
// 	The inverse of the least significant bit of a control data enables
// 	waiting for a null bit sampled from the input "miso_i" before
// 	counting the bits transmitted; until then, "sclk_o" keeps toggling,
// 	and "mosi_o" remains high, since {DATABITSZ{1'b1}} is what gets
// 	transmitted in place of a control data. It is used with a slave
// 	which signals the beginning of its response using a null bit, such
// 	as the start-bit of an SD card in SPI mode. Once synchronized, it
// 	remains so until the transmission ends, pauses included; hence the
// 	data that follow are retrieved without waiting for a null bit again.
//
// 	The inverse of the 2nd least significant bit of a control data
// 	discards that null bit, so that the DATABITSZ bits which follow it
// 	become the data pushed in the receive buffer; when null, that null
// 	bit becomes the most significant bit of that data. It is ignored
// 	unless waiting for a null bit was enabled.
//
// 	The inverse of the 3rd least significant bit of a control data keeps
// 	the output "cs_o" high for the whole transmission, while "sclk_o"
// 	and "mosi_o" behave as usual; hence the slave is sent clock cycles
// 	without being selected, such as the 74 clock cycles at least, with
// 	"cs_o" and "mosi_o" high, which an SD card needs before its first
// 	command. The bits of a control data are independent: waiting for a
// 	null bit while "cs_o" is kept high waits on a slave which is not
// 	selected, until given up.
//
// 	The inverse of the 4th least significant bit of a control data enables
// 	receive flow control: while the receive buffer holds BUFSZ-1 data or
// 	more, the transmission pauses instead of taking the next data, hence
// 	no data received gets dropped; the control data itself waits for room
// 	before the transmission begins. As the room left is for the data taken
// 	and for the one whose reception is completing, the receive buffer
// 	usage stops at BUFSZ-1, or at BUFSZ when the next data was already
// 	waiting as the previous one completed.
//
// 	The remaining bits of a control data are reserved and expected 1'b1;
// 	hence a control data of {DATABITSZ{1'b1}} configures a transmission
// 	which neither waits for a null bit nor discards one, with "cs_o" low,
// 	and without receive flow control.
//
// 	Note that the transmission substituted for a control data also
// 	yields a data in the receive buffer, which is where the response of
// 	a slave signaling using a null bit gets retrieved.
//
// 	Waiting for a null bit is given up after SYNCTIMEOUT clock cycles of
// 	"clk_phy_i", on the next trailing edge of "sclk_o", unless the null
// 	bit was sampled on the leading edge before it: the transmission is
// 	aborted, ending with the output "cs_o" high and without a data
// 	received in place of the control data. The data in the transmit
// 	buffer are then discarded, and so are the data buffered afterwards,
// 	until the transmission is closed using "close_i", which a caller must
// 	do before buffering the next transmission, as for any other; a close
// 	already requested ends the discarding once the transmit buffer is
// 	empty. Hence a data meant to continue the transmission after it was
// 	aborted is never taken for the control data of a new one.
// 	The output "usage_tx_o" becomes null once the transmit buffer is
// 	empty, whereas it is never null while a transmission is in progress;
// 	hence a caller detects that waiting was given up from "usage_tx_o"
// 	becoming null before it closed the transmission.
//
// 	The output "near_full_o" is high when the transmit buffer is full
// 	or one data away from full.
//
// 	The output "usage_tx_o" is the count of the data not yet transmitted:
// 	those in the transmit buffer, the one read out of it and held until
// 	the phy takes it, and the one being transmitted; one more is counted
// 	while the transmission is paused, and one more while a close is
// 	pending. Hence it reaches BUFSZ+3 at most, and it is null only when
// 	no transmission is in progress and no close is pending, so that a data
// 	buffered while it is null begins a new transmission, becoming its
// 	control data. The data being discarded after waiting for a null bit
// 	was given up are counted only while in the transmit buffer.
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
	close_i,
	read_i, data_o, empty_o, usage_rx_o
);

`include "lib/clog2.sv"

parameter BUFSZ        = 2;
parameter DATABITSZ    = 4;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;
parameter SYNCTIMEOUT  = 0;

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
input  wire                          close_i;

input  wire                          read_i;
output wire [DATABITSZ -1 : 0]       data_o;
output wire                          empty_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_rx_o;

wire phy_rdy_w;
wire phy_rcvd_w;
wire phy_syncTimeout_w;
wire phy_idle_w;
wire phy_hold_w;

wire [DATABITSZ -1 : 0] phy_data_w0;
wire [DATABITSZ -1 : 0] phy_data_w1;

wire [DATABITSZ -1 : 0] fifo_tx_data_w;

reg phy_stb_r;

// The data held, presented to the phy unless receive flow control holds it.
wire phy_stb_w;

// High from the phy giving up waiting for a null bit until the transmission
// is closed, while every data read out of the transmit buffer is discarded.
reg aborted_r;

// High while a close requested through "close_i" is pending.
reg close_r;

// Configuration latched from a control data; the phy samples those inputs
// at each bit transmitted, hence they must remain valid for the whole
// transmission, which they do until the next control data.
reg phy_misoSync_r;
reg phy_misoSkipSyncBit_r;
reg phy_rxFlowCtrl_r;

wire fifo_rx_near_full_w;

spi_master_phy #(
	 .SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.DATABITSZ    (DATABITSZ)
	,.CPOL         (CPOL)
	,.SYNCTIMEOUT  (SYNCTIMEOUT)
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

	,.misoSync_i        (phy_misoSync_r)
	,.misoSkipSyncBit_i (phy_misoSkipSyncBit_r)

	,.syncTimeout_o (phy_syncTimeout_w)

	,.idle_o       (phy_idle_w)
	,.hold_i       (phy_hold_w)
	,.csKeepHigh_i (!fifo_tx_data_w[2])
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
	,.near_full_o (fifo_rx_near_full_w)
);

reg phy_rdy_w_r;
always_ff @(posedge clk_phy_i)
	phy_rdy_w_r <= phy_rdy_w;
wire phy_rdy_w_negedge = (!phy_rdy_w && phy_rdy_w_r);

wire fifo_tx_empty_w;

wire [(CLOG2BUFSZ +1) -1 : 0] fifo_tx_usage_w;

// Once the phy gave up waiting for a null bit, the data held on its input
// "data_i" is discarded, and so is every data read out of the transmit
// buffer, a data per clock cycle, until the transmission is closed; that
// includes any data buffered meanwhile.
wire fifo_tx_read_w = (!fifo_tx_empty_w && (!phy_stb_r || phy_rdy_w_negedge));
always_ff @(posedge clk_phy_i) begin
	if (rst_i || phy_syncTimeout_w)
		phy_stb_r <= 1'b0;
	else if (fifo_tx_read_w && !aborted_r)
		phy_stb_r <= 1'b1;
	else if (phy_rdy_w_negedge)
		phy_stb_r <= 1'b0;
end

// A close takes effect only while the transmit buffer is empty, so that
// the data buffered before it are transmitted first: a data buffered just
// before it, and not yet read out of the transmit buffer at the end of the
// data transmitted, makes the transmission pause instead of ending, and
// then resume with that data.
wire closing_w = (close_r && fifo_tx_empty_w);

always_ff @(posedge clk_phy_i) begin
	if (rst_i)
		aborted_r <= 1'b0;
	else if (phy_syncTimeout_w)
		aborted_r <= 1'b1;
	else if (closing_w)
		aborted_r <= 1'b0;
end

// Under receive flow control, the data held is not presented to the phy
// while the receive buffer lacks room for two data: the one the phy would
// take, and the one whose reception it is completing, which it pushes in
// the receive buffer in the clock cycle after it takes the next data.
// While idle, the phy is to take a control data, whose own bit decides.
wire phy_rxFlowCtrl_w = (phy_idle_w ? !fifo_tx_data_w[3] : phy_rxFlowCtrl_r);
assign phy_stb_w = (phy_stb_r && !(phy_rxFlowCtrl_w && fifo_rx_near_full_w));
wire phy_flowWait_w = (phy_stb_r && !phy_stb_w);

// A transmission pauses instead of ending, unless a close takes effect;
// and it pauses while a data held waits for room in the receive buffer,
// a close notwithstanding, as that data was buffered before the close.
assign phy_hold_w = ((!phy_idle_w && !closing_w) || phy_flowWait_w);

// A close is a level, pending until the transmission has ended, the
// transmit buffer is empty, no data is held for the phy, and discarding
// has ended; hence a phy clocked slower or faster than "clk_i" cannot miss
// it, and it cannot clear early: until the transmission it closes has
// ended, the transmit buffer is not empty, a data is held for the phy, or
// the phy is not idle. It ends discarding through "aborted_r" being cleared
// first, so that "usage_tx_o", which counts it, becomes null only once a
// data buffered would not be discarded.
always_ff @(posedge clk_i) begin
	if (rst_i)
		close_r <= 1'b0;
	else if (close_i)
		close_r <= 1'b1;
	else if (phy_idle_w && fifo_tx_empty_w && !phy_stb_r && !aborted_r)
		close_r <= 1'b0;
end

// The phy takes a data either while idle, with its output "idle_o" high,
// which begins a transmission, or at the end of the data transmitted,
// with "idle_o" low, which continues it; hence whether a data is a control
// data is decided from "idle_o" in the clock cycle the phy takes it.
// It cannot be decided when the data is read from the transmit buffer,
// as the phy may become idle at that very clock edge, the buffer having
// run empty until then, and that data would begin a transmission while
// having been read as one continuing it.
// {DATABITSZ{1'b1}} gets transmitted in place of a control data, which also
// keeps "mosi_o" high while waiting for a null bit from the input "miso_i".
assign phy_data_w1 = (phy_idle_w ? {DATABITSZ{1'b1}} : fifo_tx_data_w);

// The configuration is latched from a control data in the clock cycle the
// phy takes it, the only one where "phy_stb_w" is high while the phy output
// "idle_o" is high, "phy_stb_r" possibly having been high before while the
// control data waited for room in the receive buffer; the transmit buffer
// is not read in that clock cycle, the phy output "rdy_o" remaining high
// until then, and the phy first uses the configuration at the end of the
// first bit transmitted. The phy latches its input "csKeepHigh_i" in that
// same clock cycle.
// Discarding the null bit is allowed only when waiting for it is enabled,
// as the phy would otherwise transmit one bit too many.
always_ff @(posedge clk_phy_i) begin
	if (rst_i) begin
		phy_misoSync_r <= 1'b0;
		phy_misoSkipSyncBit_r <= 1'b0;
		phy_rxFlowCtrl_r <= 1'b0;
	end else if (phy_idle_w && phy_stb_w) begin
		phy_misoSync_r <= !fifo_tx_data_w[0];
		phy_misoSkipSyncBit_r <= (!fifo_tx_data_w[1] && !fifo_tx_data_w[0]);
		phy_rxFlowCtrl_r <= !fifo_tx_data_w[3];
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
// the one being transmitted. The phy output "idle_o" remaining low while
// the transmission is paused, one more is counted meanwhile, and one more
// while a close is pending, so that the count becomes null only once the
// transmission has ended, and a data buffered would begin a new one.
assign usage_tx_o = (fifo_tx_usage_w + (phy_stb_r && !phy_rdy_w_negedge) + !phy_idle_w + close_r);

endmodule

`endif /* SPI_MASTER_V */
