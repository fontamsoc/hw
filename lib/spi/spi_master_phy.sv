// SPDX-License-Identifier: GPL-2.0-only
// 20260923 (c) William Fonkou Tambe

`ifndef SPI_MASTER_PHY_V
`define SPI_MASTER_PHY_V

// Module implementing SPI master PHY, with CPHA == 0.

// Parameters.
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
//
// SYNCTIMEOUT:
// 	Number of clock cycles after which waiting for a null bit, which
// 	the input "misoSync_i" enables, is given up; a null value disables
// 	giving up.

// Ports.
//
// clk_i
// 	Clock signal.
// 	Its frequency determine the transmission bitrate
// 	which is computed as follow: (CLKFREQ/(2*(sclkdiv_i+1))).
// 	For a CLKFREQ of 100 Mhz and a value of 1 on the input "sclkdiv_i",
// 	it results in a bitrate of 25 Mbps.
//
// sclk_o
// mosi_o
// miso_i
// cs_o
// 	SPI master signals.
// 	The output "cs_o" is low while a transmission is in progress,
// 	unless the input "csKeepHigh_i" was high when it began.
//
// sclkdiv_i
// 	This input is used to adjust the bitrate; it is the number of clock
// 	cycles per half-period of the output "sclk_o", less one, and a null
// 	value is valid.
// 	The resulting bitrate is computed as follow: (CLKFREQ/(2*(sclkdiv_i+1))).
// 	For a CLKFREQ of 100 Mhz and a value of 1 on the input "sclkdiv_i",
// 	it results in a bitrate of 25 Mbps.
// 	Each half-period of "sclk_o" lasts (sclkdiv_i+1) clock cycles, hence
// 	its duty cycle is 50% for every value of this input; note that only
// 	even divisions of CLKFREQ are reachable, which are precisely those
// 	that a 50% duty cycle allows.
//
// stb_i
// 	This signal is set high to begin transmitting the data value on
// 	the input "data_i" and receiving a data value on the output "data_o".
// 	It must be held high until transmission begins (ie: signal "rdy_o" negedge).
// 	To prevent the transmission from ending between each data transmitted,
// 	this signal must be set high as soon as the signal "rdy_o" posedge.
//
// rdy_o
// 	This signal is high when ready to transmit "data_i".
//
// rcvd_o
// 	This signal is high for a single clock cycle
// 	when data is ready to be sampled on "data_o".
//
// data_o
// 	Data received which is valid only while "rcvd_o" is high.
//
// data_i
// 	Data value to transmit through "mosi_o".
//
// misoSync_i
// 	When this signal is high, the shifting of "mosi_o" and the counting
// 	of the bits transmitted do not begin until a null bit has been
// 	sampled from the input "miso_i"; until then, "sclk_o" keeps toggling,
// 	and "mosi_o" keeps presenting the most significant bit of "data_i",
// 	which must be 1'b1 in order for "mosi_o" to remain high while waiting.
// 	It is used with a slave which signals the beginning of its response
// 	using a null bit, such as the start-bit of an SD card in SPI mode.
// 	Once synchronized, it remains so until the transmission ends.
// 	Waiting is given up after SYNCTIMEOUT clock cycles, as described
// 	with the output "syncTimeout_o".
//
// misoSkipSyncBit_i
// 	This signal must be asserted only when the input "misoSync_i" is
// 	true, and must be null otherwise, as it would corrupt the first
// 	data of the transmission.
// 	When high, the null bit that synchronized the transmission is
// 	discarded, and the DATABITSZ bits that follow it become "data_o";
// 	when low, that null bit becomes the most significant bit of "data_o".
//
// syncTimeout_o
// 	This signal is high in the clock cycle at the end of which waiting
// 	for a null bit is given up, having lasted SYNCTIMEOUT clock cycles;
// 	it happens on the first trailing edge of "sclk_o" after that, unless
// 	the null bit was sampled on the leading edge before it.
// 	The transmission is then aborted: the outputs "idle_o", "cs_o" and
// 	"rdy_o" become high, while "rcvd_o" does not become high for the
// 	data given up. The phy being idle from that clock edge, "stb_i" must
// 	be lowered at that same edge, unless its data is to begin a new
// 	transmission.
//
// idle_o
// 	This signal is high while no transmission is in progress; the data
// 	taken while it is high begins a transmission, which ends when no
// 	data is presented through "stb_i" at the end of the data transmitted,
// 	or when waiting for a null bit is given up.
//
// csKeepHigh_i
// 	This signal is sampled when the phy takes a data while "idle_o" is
// 	high; when high, the output "cs_o" remains high for the whole
// 	transmission which that data begins, while "sclk_o" and "mosi_o"
// 	behave as usual, hence the slave is sent clock cycles without being
// 	selected.

module spi_master_phy (
	rst_i, clk_i,
	sclk_o, mosi_o, miso_i, cs_o,
	stb_i, rdy_o, rcvd_o, sclkdiv_i,
	data_o, data_i,
	misoSync_i, misoSkipSyncBit_i,
	syncTimeout_o,
	idle_o, csKeepHigh_i
);

`include "lib/clog2.sv"

parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;
parameter SYNCTIMEOUT  = 0;

localparam CLOG2DATABITSZ    = clog2(DATABITSZ);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);
localparam CLOG2SYNCTIMEOUT  = clog2(SYNCTIMEOUT+1);

input wire rst_i;

input wire clk_i;

// The registers driving the pins, "mosibits" below included, are
// initialized at declaration, as the clock may not run until a pll
// locks: the slave must see inactive levels from configuration on.
output reg  sclk_o = (|CPOL);
output wire mosi_o;
input  wire miso_i;
output reg  cs_o = 1'b1;

input  wire stb_i;
output reg  rdy_o;
output reg  rcvd_o;

input wire [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv_i;

output reg  [DATABITSZ -1 : 0] data_o;
input  wire [DATABITSZ -1 : 0] data_i;

input wire misoSync_i;
input wire misoSkipSyncBit_i;

output wire syncTimeout_o;

output reg  idle_o;
input  wire csKeepHigh_i;

wire misoIsLow = !data_o[0];

reg inSync; // Relevant only if misoSync_i is true.

// Latched from "csKeepHigh_i" when a transmission begins.
reg csKeepHigh;

reg  [DATABITSZ -1 : 0] mosibits = {DATABITSZ{1'b1}};
assign mosi_o = mosibits[DATABITSZ-1];

// Keep track of the number of bits left to transmit.
reg [CLOG2DATABITSZ -1 : 0] bitcnt;
wire bitcntNull = !bitcnt;
wire bitcntNull_and_stbNull = (bitcntNull && !stb_i);

// Keep track of the number of clock cycles within the current half-period.
reg [CLOG2SCLKDIVLIMIT -1 : 0] cntr;
wire cntrDone = (cntr == sclkdiv_i);

// The level of "sclk_o" doubles as the half-period phase.
wire sclkIsIdle = (sclk_o == (|CPOL));

// High while waiting for a null bit, which can only be in place of the
// first data of a transmission, since once synchronized it remains so.
wire syncWaiting = (misoSync_i && !inSync && !bitcntNull);

// Keep track of the number of clock cycles spent waiting for a null bit;
// it needs no reset, as it clears itself while not waiting, which a reset
// insures.
reg [CLOG2SYNCTIMEOUT -1 : 0] syncTimeoutCntr;
wire syncTimeoutDone = ((SYNCTIMEOUT != 0) &&
	(syncTimeoutCntr == SYNCTIMEOUT[CLOG2SYNCTIMEOUT -1 : 0]));
always_ff @(posedge clk_i) begin
	if (!syncWaiting)
		syncTimeoutCntr <= 0;
	else if (!syncTimeoutDone)
		syncTimeoutCntr <= (syncTimeoutCntr + 1'b1);
end

// Waiting is given up on a trailing edge of "sclk_o", unless the null bit
// was sampled on the leading edge which preceded it.
assign syncTimeout_o = (syncTimeoutDone && syncWaiting && !misoIsLow && cntrDone && !sclkIsIdle);

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		sclk_o <= (|CPOL);
		cs_o <= 1'b1;
		idle_o <= 1'b1;
		csKeepHigh <= 1'b0;
		rdy_o <= 1'b1;
		rcvd_o <= 1'b0;
		inSync <= 1'b0;
		mosibits <= {DATABITSZ{1'b1}};
		bitcnt <= 0;
	end else if (idle_o || (cntrDone && !sclkIsIdle)) begin
		sclk_o <= (|CPOL);
		if (bitcnt) begin
			if (!misoSync_i || inSync || misoIsLow) begin
				if (!misoSkipSyncBit_i || inSync)
					bitcnt <= (bitcnt - 1'b1);
				mosibits <= {mosibits[(DATABITSZ-1)-1:0], 1'b1};
				inSync <= 1'b1;
			end else if (syncTimeout_o)
				bitcnt <= 0;
		end else if (stb_i) begin
			bitcnt <= (DATABITSZ-1);
			mosibits <= data_i;
			if (idle_o)
				csKeepHigh <= csKeepHigh_i;
		end else
			inSync <= 1'b0;
		idle_o <= bitcntNull_and_stbNull;
		// A single register drives "cs_o", so that it cannot glitch;
		// when a transmission begins, "csKeepHigh" is not latched yet.
		cs_o <= (bitcntNull_and_stbNull || (idle_o ? csKeepHigh_i : csKeepHigh));
		rdy_o <= (bitcntNull_and_stbNull || (bitcnt == 1));
		rcvd_o <= (bitcntNull && !idle_o);
		cntr <= 0;
		// Giving up waiting for a null bit ends the transmission;
		// "rcvd_o" remains low, as "bitcnt" is non-null.
		if (syncTimeout_o) begin
			idle_o <= 1'b1;
			cs_o <= 1'b1;
			rdy_o <= 1'b1;
		end
	end else if (cntrDone) begin
		sclk_o <= ~(|CPOL);
		data_o <= {data_o[(DATABITSZ-1)-1:0], miso_i};
		rcvd_o <= 1'b0;
		cntr <= 0;
	end else begin
		rcvd_o <= 1'b0;
		cntr <= (cntr + 1'b1);
	end
end

endmodule

`endif /* SPI_MASTER_PHY_V */
