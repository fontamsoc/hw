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
//
// PAUSETIMEOUT:
// 	Number of clock cycles after which waiting for a data, which the
// 	input "hold_i" causes, is given up; a null value disables giving up.
// 	The waits for a null bit and for a data exclude each other, hence
// 	they share a counter, which only the greater of both timeouts sizes.
//
// GANG:
// 	When non-null, the phy can be ganged with others, as described with
// 	the input "freeze_i"; when null, that input is ignored, and the
// 	outputs "paused_o", "trailing_o" and "leading_o" are null.
//
// CTRLCSHIGH:
// 	When non-null, the first data of a transmission, ie: the data taken
// 	while "idle_o" is high, is transmitted with "cs_o" high, and a data
// 	presented at its end is not taken there, but makes the transmission
// 	pause, to be taken in the clock cycle which follows, at the earliest;
// 	"cs_o" becomes low in that clock cycle, unless the input "csKeepHigh_i"
// 	was high when the transmission began, or unless the transmission ends
// 	there, and the input "csLowCnt_i" sets for how long, as described with
// 	that input. Hence "cs_o" falls a clock cycle after a trailing edge of
// 	"sclk_o", and a full half-period before the leading edge which follows,
// 	as a slave which takes the first byte after the fall of its chip select
// 	for a command, such as a SPI flash, requires.
// 	It is not to be used with the parameter GANG, nor with the input
// 	"misoSync_i", which would wait for a null bit from a slave which is not
// 	selected, until given up; and DATABITSZ must be a multiple of 8.
//
// LATESAMPLE:
// 	When non-null, "miso_i" is sampled on the trailing edge of "sclk_o"
// 	which ends each bit, instead of the leading edge which begins it; hence
// 	a slave which changes "miso_i" on the trailing edges has a full period
// 	of "sclk_o", instead of half of it, for its output to settle, as a SPI
// 	flash needs at high bitrates in mode 0, where it changes its output on
// 	the falling edge. It is not to be set for a slave which changes "miso_i"
// 	on the leading edges, such as an SD card in high speed mode, as the next
// 	bit would get sampled; nor with the parameter GANG or the input
// 	"misoSync_i", which expect a null bit sampled on a leading edge.

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
// 	unless the input "csKeepHigh_i" was high when it began, and as
// 	described with the parameter CTRLCSHIGH.
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
// 	To prevent the transmission from pausing or ending between each data
// 	transmitted, this signal must be set high as soon as the signal "rdy_o"
// 	posedge; when the parameter CTRLCSHIGH is non-null, the transmission
// 	pauses after its first data regardless.
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
// 	with the output "timeout_o".
//
// misoSkipSyncBit_i
// 	This signal must be asserted only when the input "misoSync_i" is
// 	true, and must be null otherwise, as it would corrupt the first
// 	data of the transmission.
// 	When high, the null bit that synchronized the transmission is
// 	discarded, and the DATABITSZ bits that follow it become "data_o";
// 	when low, that null bit becomes the most significant bit of "data_o".
//
// timeout_o
// 	This signal is high in the clock cycle at the end of which a wait
// 	is given up.
// 	Waiting for a null bit is given up having lasted SYNCTIMEOUT clock
// 	cycles, on the first trailing edge of "sclk_o" after that, unless
// 	the null bit was sampled on the leading edge before it.
// 	Waiting for a data, while paused or while idle as described with
// 	the input "hold_i", is given up in the clock cycle where it has
// 	lasted PAUSETIMEOUT clock cycles, unless a data is presented through
// 	"stb_i", or "hold_i" is low, in that clock cycle.
// 	The transmission is then aborted: the outputs "idle_o", "cs_o" and
// 	"rdy_o" become high, while "rcvd_o" does not become high for the
// 	data given up. The phy being idle from that clock edge, "stb_i" must
// 	be lowered at that same edge, unless its data is to begin a new
// 	transmission; a data waiting while the phy was idle is expected
// 	dropped.
//
// idle_o
// 	This signal is high while no transmission is in progress; the data
// 	taken while it is high begins a transmission, which ends when no
// 	data is presented through "stb_i" at the end of the data transmitted
// 	while the input "hold_i" is low, or when a wait is given up; it
// 	remains low while the transmission is paused.
//
// hold_i
// 	This signal is sampled at the end of the data transmitted when no data
// 	is presented through "stb_i", and at each clock cycle of a pause; when
// 	high, the transmission pauses instead of ending, until a data presented
// 	through "stb_i" resumes it, or until this signal is low, which ends it.
// 	While paused, "sclk_o" remains at its idle level, "cs_o" keeps its
// 	level, but in the pause which follows the first data when the parameter
// 	CTRLCSHIGH is non-null, where it falls, "rdy_o" remains high, and the
// 	synchronization to a null bit is
// 	kept; the data which resumes the transmission continues it, and its
// 	first bit lasts a full half-period of "sclk_o" before its leading edge,
// 	as when a data begins a transmission.
// 	While "idle_o" is high, it reports a data waiting outside of the phy
// 	to begin a transmission, or such a data being awaited, as the phy is
// 	not presented it through "stb_i" meanwhile; that wait is then given up
// 	as a pause is.
//
// csKeepHigh_i
// 	This signal is sampled when the phy takes a data while "idle_o" is
// 	high; when high, the output "cs_o" remains high for the whole
// 	transmission which that data begins, while "sclk_o" and "mosi_o"
// 	behave as usual, hence the slave is sent clock cycles without being
// 	selected.
//
// csLowCnt_i
// 	Used when the parameter CTRLCSHIGH is non-null, and sampled as the
// 	input "csKeepHigh_i" is: the count of bytes, transmitted after the
// 	first data of the transmission, during which "cs_o" is low; "cs_o"
// 	becomes high on the trailing edge of "sclk_o" which ends the last of
// 	them, and remains high until the transmission ends, while "sclk_o" and
// 	"mosi_o" behave as usual. A null count keeps "cs_o" high for the whole
// 	transmission, and a count of 8'hff keeps it low until the transmission
// 	ends. A pause keeps "cs_o" at its level, but the one which follows the
// 	first data, where it falls.
//
// freeze_i
// paused_o
// trailing_o
// leading_o
// 	Used, when the parameter GANG is non-null, to gang phys which share
// 	one "sclk_o", as the lines of an SD bus do, by keeping their edges
// 	simultaneous.
// 	While "freeze_i" is high, a transmission in progress which is not
// 	paused is frozen between two bits: "sclk_o" remains at its idle
// 	level, its leading edge being withheld, nothing is shifted, and the
// 	half-period counter is held at its start, hence the next bit gets a
// 	full half-period before its leading edge once thawed, as when a data
// 	resumes a pause. It must rise only while "sclk_o" is at its idle
// 	level, as it does in a gang, rising in the clock cycle which follows
// 	a trailing edge, as "paused_o" does.
// 	A wait for a null bit keeps counting its timeout while frozen, and is
// 	given up on the first trailing edge after the freeze.
// 	The output "paused_o" is high while the transmission is paused.
// 	The outputs "trailing_o" and "leading_o" are high in the clock cycle
// 	at the end of which "sclk_o" has a trailing edge, and a leading edge,
// 	respectively; a return of "sclk_o" to its idle level which a reset
// 	causes is reported only when it coincides with a trailing edge.

module spi_master_phy (
	rst_i, clk_i,
	sclk_o, mosi_o, miso_i, cs_o,
	stb_i, rdy_o, rcvd_o, sclkdiv_i,
	data_o, data_i,
	misoSync_i, misoSkipSyncBit_i,
	timeout_o,
	idle_o, hold_i, csKeepHigh_i, csLowCnt_i,
	freeze_i, paused_o, trailing_o, leading_o
);

`include "lib/clog2.sv"

parameter DATABITSZ    = 2;
parameter SCLKDIVLIMIT = 2;
parameter CPOL         = 0;
parameter SYNCTIMEOUT  = 0;
parameter PAUSETIMEOUT = 0;
parameter GANG         = 0;
parameter CTRLCSHIGH   = 0;
parameter LATESAMPLE   = 0;

localparam CLOG2DATABITSZ    = clog2(DATABITSZ);
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);
localparam TIMEOUTMAX        = ((SYNCTIMEOUT > PAUSETIMEOUT) ? SYNCTIMEOUT : PAUSETIMEOUT);
localparam CLOG2TIMEOUT      = clog2(TIMEOUTMAX+1);

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

output wire timeout_o;

output reg  idle_o;
input  wire hold_i;
input  wire csKeepHigh_i;

input  wire [8 -1 : 0] csLowCnt_i;

input  wire freeze_i;
output wire paused_o;
output wire trailing_o;
output wire leading_o;

wire misoIsLow = !data_o[0];

reg inSync; // Relevant only if misoSync_i is true.

// Latched from "csKeepHigh_i" when a transmission begins.
reg csKeepHigh;

// Used when CTRLCSHIGH is non-null: high while the first data of the
// transmission is transmitted; and the count of bytes left to transmit
// with "cs_o" low, latched from "csLowCnt_i" when a transmission begins.
reg ctrlData;
reg [8 -1 : 0] csLowCnt;

// High while the transmission is paused at the end of a data,
// no data having been presented while "hold_i" was high.
reg paused;

reg  [DATABITSZ -1 : 0] mosibits = {DATABITSZ{1'b1}};
assign mosi_o = mosibits[DATABITSZ-1];

// Keep track of the number of bits left to transmit.
reg [CLOG2DATABITSZ -1 : 0] bitcnt;
wire bitcntNull = !bitcnt;

// When CTRLCSHIGH is non-null, the end of the first data of a transmission
// is a pause point: a data presented there is not taken, but makes the
// transmission pause instead of ending, and is taken in the clock cycle
// which follows, where "cs_o" becomes low; "stb" and "hold" are "stb_i" and
// "hold_i" as the logic below sees them.
wire ctrlEnd = ((CTRLCSHIGH != 0) && ctrlData && bitcntNull && !idle_o);
wire stb = (stb_i && !ctrlEnd);
wire hold = (hold_i || (stb_i && ctrlEnd));

wire bitcntNull_and_stbNull = (bitcntNull && !stb);

// At the end of a data, or while paused, the transmission ends when no
// data is presented, unless "hold_i" makes it pause.
wire ending = (bitcntNull_and_stbNull && (idle_o || !hold));

// Used when CTRLCSHIGH is non-null: high on a trailing edge of "sclk_o"
// which ends a byte transmitted after the first data of the transmission,
// and on the one which ends the last of the bytes which "csLowCnt" counts.
wire byteEnd = (!idle_o && !paused && !ctrlData && !(bitcnt & 3'd7));
wire csLowEnd = (byteEnd && (csLowCnt == 1));

// Keep track of the number of clock cycles within the current half-period.
reg [CLOG2SCLKDIVLIMIT -1 : 0] cntr;
wire cntrDone = (cntr == sclkdiv_i);

// The level of "sclk_o" doubles as the half-period phase.
wire sclkIsIdle = (sclk_o == (|CPOL));

// High while waiting for a null bit, which can only be in place of the
// first data of a transmission, since once synchronized it remains so.
wire syncWaiting = (misoSync_i && !inSync && !bitcntNull);

// High while waiting for a null bit, for a data while paused, or, while
// idle, for a data which "hold_i" reports waiting outside of the phy. A
// pause is at the end of a data, where waiting for a null bit is done,
// hence the waits exclude each other, and every wait begins from a clock
// cycle where none happens, which clears the counter they share.
wire waiting = (syncWaiting || paused || (idle_o && hold_i));

// Keep track of the number of clock cycles spent waiting; it needs no
// reset, as it clears itself while not waiting, which a reset insures.
reg [CLOG2TIMEOUT -1 : 0] timeoutCntr;
wire syncTimeoutDone = ((SYNCTIMEOUT != 0) &&
	(timeoutCntr == SYNCTIMEOUT[CLOG2TIMEOUT -1 : 0]));
wire pauseTimeoutDone = ((PAUSETIMEOUT != 0) &&
	(timeoutCntr == PAUSETIMEOUT[CLOG2TIMEOUT -1 : 0]));
always_ff @(posedge clk_i) begin
	if (!waiting)
		timeoutCntr <= 0;
	else if (!(syncWaiting && syncTimeoutDone))
		timeoutCntr <= (timeoutCntr + 1'b1);
end

// Waiting for a null bit is given up on a trailing edge of "sclk_o",
// unless the null bit was sampled on the leading edge which preceded it.
wire syncTimeout = (syncTimeoutDone && syncWaiting && !misoIsLow && cntrDone && !sclkIsIdle);

// Waiting for a data is given up in the clock cycle its count is reached,
// unless a data is presented, or "hold_i" is low, in that clock cycle.
wire pauseTimeout = (pauseTimeoutDone && (paused || idle_o) && !stb_i && hold_i);

assign timeout_o = (syncTimeout || pauseTimeout);

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		sclk_o <= (|CPOL);
		cs_o <= 1'b1;
		idle_o <= 1'b1;
		paused <= 1'b0;
		csKeepHigh <= 1'b0;
		ctrlData <= 1'b0;
		rdy_o <= 1'b1;
		rcvd_o <= 1'b0;
		inSync <= 1'b0;
		mosibits <= {DATABITSZ{1'b1}};
		bitcnt <= 0;
	end else if (idle_o || paused || (cntrDone && !sclkIsIdle)) begin
		sclk_o <= (|CPOL);
		if (bitcnt) begin
			if (!misoSync_i || inSync || misoIsLow) begin
				if (!misoSkipSyncBit_i || inSync)
					bitcnt <= (bitcnt - 1'b1);
				mosibits <= {mosibits[(DATABITSZ-1)-1:0], 1'b1};
				inSync <= 1'b1;
			end else if (timeout_o)
				bitcnt <= 0;
		end else if (stb) begin
			bitcnt <= (DATABITSZ-1);
			mosibits <= data_i;
			if (idle_o)
				csKeepHigh <= csKeepHigh_i;
		end else if (idle_o || !hold)
			inSync <= 1'b0; // A pause keeps the synchronization.
		// When CTRLCSHIGH is non-null, the first data is transmitted with
		// "cs_o" high, and the bytes which follow it with "cs_o" low until the
		// count latched from "csLowCnt_i" has elapsed, a null count keeping
		// "cs_o" high as "csKeepHigh_i" does; once elapsed, "cs_o" remains
		// high until the transmission ends.
		if (CTRLCSHIGH != 0) begin
			if (idle_o && stb) begin
				ctrlData <= 1'b1;
				csLowCnt <= csLowCnt_i;
				if (!csLowCnt_i)
					csKeepHigh <= 1'b1;
			end else if (ctrlEnd)
				ctrlData <= 1'b0;
			else if (byteEnd && (|csLowCnt) && !(&csLowCnt)) begin
				csLowCnt <= (csLowCnt - 1'b1);
				if (csLowEnd)
					csKeepHigh <= 1'b1;
			end
		end
		idle_o <= ending;
		paused <= (bitcntNull_and_stbNull && !idle_o && hold);
		// A single register drives "cs_o", so that it cannot glitch;
		// when a transmission begins, "csKeepHigh" is not latched yet.
		cs_o <= (ending || (idle_o ? ((CTRLCSHIGH != 0) || csKeepHigh_i) :
			(((CTRLCSHIGH != 0) && (ctrlData || csLowEnd)) || csKeepHigh)));
		rdy_o <= (bitcntNull_and_stbNull || (bitcnt == 1));
		// When LATESAMPLE is non-null, "miso_i" is sampled on the trailing
		// edges, which are the iterations of this branch neither idle nor
		// paused; the last bit of a data is thus sampled on the edge which
		// reports it received below.
		if ((LATESAMPLE != 0) && !idle_o && !paused)
			data_o <= {data_o[(DATABITSZ-1)-1:0], miso_i};
		// The data received is reported at the end of the data, and not
		// again at each clock cycle of the pause which may follow it.
		rcvd_o <= (bitcntNull && !idle_o && !paused);
		// Counting restarts at every clock cycle of a pause, so that the data
		// which resumes it gets a full half-period before its leading edge.
		cntr <= 0;
		// Giving up a wait ends the transmission; "rcvd_o" remains low, as
		// "bitcnt" is non-null while waiting for a null bit, and no data is
		// being received while paused or idle. The synchronization which a
		// pause kept is not passed on.
		if (timeout_o) begin
			idle_o <= 1'b1;
			paused <= 1'b0;
			cs_o <= 1'b1;
			rdy_o <= 1'b1;
			inSync <= 1'b0;
		end
	end else if ((GANG != 0) ? (cntrDone && !freeze_i) : cntrDone) begin
		sclk_o <= ~(|CPOL);
		if (LATESAMPLE == 0)
			data_o <= {data_o[(DATABITSZ-1)-1:0], miso_i};
		rcvd_o <= 1'b0;
		cntr <= 0;
	end else begin
		rcvd_o <= 1'b0;
		// While frozen, between two bits, the leading edge being withheld
		// above, the half-period counter is held at its start.
		cntr <= (((GANG != 0) ? freeze_i : 1'b0) ? {CLOG2SCLKDIVLIMIT{1'b0}} : (cntr + 1'b1));
	end
end

// The outputs of the gang interface. Out of reset, "sclk_o" has a trailing
// edge through the first branch above, which is taken while idle or paused
// with "sclk_o" at its idle level, and otherwise at the end of a half-period
// where "sclk_o" is not; and it has a leading edge through the next branch.
assign paused_o = ((GANG != 0) ? paused : 1'b0);
assign trailing_o = ((GANG != 0) ? (cntrDone && !sclkIsIdle) : 1'b0);
assign leading_o = ((GANG != 0) ? (!rst_i && !(idle_o || paused) && sclkIsIdle && cntrDone && !freeze_i) : 1'b0);

endmodule

`endif /* SPI_MASTER_PHY_V */
