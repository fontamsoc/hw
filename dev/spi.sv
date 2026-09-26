// SPDX-License-Identifier: GPL-2.0-only
// 20260926 (c) William Fonkou Tambe

// SPI peripheral.
//
// The device is a SPI master with CPHA 0, the clock polarity being the
// parameter CPOL, and it transfers data a byte at a time, most significant
// bit first, and full duplex: while a byte is transmitted through "mosi_o",
// a byte is received through "miso_i", and pushed in the receive buffer.
// The first word of the device memory mapping is used to send/receive
// bytes while the second word is used to send commands to the device.
//
// Commands sent to the device expect following format
// | arg: (WORDBITSZ-2) bits | cmd: 2 bit | where the field "cmd" values
// are CMDDEVRDY(2'b00), CMDGETBUFFERUSAGE(2'b01), CMDSETINTERRUPT(2'b10)
// and CMDSETSPEED(2'b11). The result of a previously sent command is
// retrieved from the device reading from it and has the following format
// | resp: (WORDBITSZ-2) bits | cmd: 2 bit | where the fields "cmd" and
// "resp" are the command and its result.
// Two memory operations, a write followed by a read are needed to send
// a command to the device and retrieve its result.
// The device has accepted a command only if "cmd" in its result
// is CMDDEVRDY, otherwise sending the command CMDDEVRDY is needed.
//
// The description of commands is as follow:
// 	CMDDEVRDY: Make the device accept a new command.
// 	"resp" in the result gets set to 0.
// 	CMDGETBUFFERUSAGE: Get receive/transmit buffer usage.
// 	"arg" value encodes which buffer should the usage be returned.
// 	When "arg" is 0, the receive buffer usage is returned;
// 	when "arg" is 1, the transmit buffer usage is returned, which is
// 	the count of bytes not yet transmitted; it includes up to two bytes
// 	taken out of the transmit buffer, hence it is capped to BUFSZ, and
// 	it is null only when no transmission is in progress.
// 	"resp" in the result gets set to the usage in number of bytes.
// 	CMDSETINTERRUPT: enable/disable interrupt.
// 	"arg" value when 0 disables interrupt, and when non-null, enables
// 	interrupt and sets the minimum receive buffer usage that would
// 	trigger an interrupt.
// 	"resp" in the result gets set to the size in bytes of the transmit
// 	and receive buffer.
// 	CMDSETSPEED: Set the bitrate used when sending and receiving bytes.
// 	"arg" value is the speed computed as follow: (PHYCLKFREQ/bitrate);
// 	the bitrate used is the highest of the form (PHYCLKFREQ/(2*n)), n
// 	being non-null, which does not exceed (PHYCLKFREQ/arg), and no lower
// 	than the lowest bitrate, (PHYCLKFREQ/(2*((PHYCLKFREQ/200000)+1))),
// 	which is about 100 kbps; an "arg" of 0 selects that lowest bitrate.
// 	ie: For a PHYCLKFREQ of 100 MHz and a bitrate of 25 Mbps,
// 	the above formula yields 4, hence 25 Mbps; for a bitrate of 30 Mbps,
// 	it yields 3, hence 25 Mbps as well.
// 	The new bitrate applies from the next edge of "sclk_o"; changing it
// 	while a transmission is in progress can stretch a half-period of
// 	"sclk_o", hence it is to be changed while the transmit buffer usage
// 	is null, as hwdrvchar_init() does.
// 	"resp" in the result gets set to PHYCLKFREQ.
//
// The device silently drops any command, other than CMDDEVRDY,
// written while the previous command isn't CMDDEVRDY (in other words
// while processing a transaction); CMDDEVRDY is always accepted and
// discards any result not yet retrieved.
// Hence a non-CMDDEVRDY command is the start of a transaction,
// and to insure threadsafety, an atomic read-write must be used to send
// a command to the device until CMDDEVRDY is returned, then another
// atomic read-write sending CMDDEVRDY must be used to retrieve the
// result while making the device ready for the next command.
//
// A transmission lasts as long as the transmit buffer does not run empty:
// it ends once the last byte buffered has been transmitted, "cs_o" being
// low meanwhile. Hence the bytes of a transmission which does not fit in
// the transmit buffer must be written without being preempted, with a
// BUFSZ and a bitrate which leave the time to refill it.
// A byte written while the transmit buffer usage is null begins a new
// transmission; that byte is a control byte, which configures the
// transmission instead of being transmitted, 0xff being transmitted in
// its place, while the byte received in its place gets pushed in the
// receive buffer as any other. The bits of a control byte are as follow:
// 	bit 0: when null, waiting for a null bit on "miso_i" before counting
// 	the bits transmitted is enabled, "sclk_o" toggling meanwhile with
// 	"mosi_o" high; it is used with a slave which signals the beginning
// 	of its response using a null bit, such as the start-bit of an SD
// 	card in SPI mode, and the transmission remains synchronized to that
// 	null bit until it ends.
// 	bit 1: when null, and waiting for a null bit is enabled, that null
// 	bit is discarded, the 8 bits which follow it becoming the byte
// 	received in place of the control byte; otherwise, that null bit
// 	becomes the most significant bit of that byte.
// 	bit 2: when null, "cs_o" remains high for the whole transmission,
// 	while "sclk_o" and "mosi_o" behave as usual; ie: A control byte of
// 	0xfb followed by nine bytes 0xff sends the 80 clock cycles with
// 	"cs_o" and "mosi_o" high which an SD card needs before its first
// 	command. The bits are independent: waiting for a null bit while
// 	"cs_o" is kept high waits on a slave which is not selected, until
// 	given up.
// 	bits 3 to 7: reserved and expected 1.
// Hence a control byte of 0xff begins a transmission which neither waits
// for a null bit nor keeps "cs_o" high.
//
// Waiting for a null bit is given up after SYNCTIMEOUT clock cycles of
// "clk_phy_i": the transmission is aborted, without a byte received in
// place of the control byte, and the transmit buffer is emptied, discarding
// the bytes it holds and those written until it is empty; no interrupt is
// raised. Software detects it from the transmit buffer usage becoming null
// while bytes it expects are missing from the receive buffer. Hence the
// control byte of a transmission which waits for a null bit is to be
// written along with the bytes which follow it, and no further byte is to
// be written until the first byte of the transmission has been received,
// as a byte written once the transmit buffer has been emptied would begin
// a new transmission.
//
// For every byte written, a byte is received, and the receive buffer drops
// the bytes received while it is full; hence the count of bytes written
// less the count of bytes read must not exceed BUFSZ.
//
// A read while the receive buffer is empty, or a write while the transmit
// buffer is full or one byte away from full, stalls the memory interface
// until a byte is received, or until room is made by a byte transmitted.
//
// The transmissions of different software contexts must not interleave,
// hence the accesses to the device must be serialized, ie: using a lock.
//
// On reset, interrupt is disabled, and must be explicitly enabled.
// It prevents an unwanted interrupt after reset.
// When enabled, an interrupt request is raised if the receive buffer
// usage interrupt threshold is reached; interrupt gets disabled when
// the raised interrupt gets acknowledged.

// Parameters:
//
// WORDBITSZ
// 	Must be a power-of-2 and <= 64.
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
//
// DEFAULTBITRATE
// 	Bitrate at reset, set as CMDSETSPEED sets it; ie: 400000, the highest
// 	bitrate at which an SD card may be initialized.
//
// BUFSZ
// 	Size in bytes of the receive and transmit buffer.
// 	It must be at least 2 and a power of 2.
//
// CPOL
// 	SPI clock polarity.
//
// SYNCTIMEOUT
// 	Number of clock cycles of "clk_phy_i" after which waiting for a null
// 	bit is given up; a null value disables giving up, as happens at the
// 	default PHYCLKFREQ. Its default of (PHYCLKFREQ/10) is 100 ms, the
// 	time within which an SD card answers a read.

// Ports:
//
// rst_i
// 	This input resets this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock input used by the memory interface.
//
// clk_phy_i
// 	Clock input used by the PHY which transmits and receives bits; its
// 	frequency must be at least twice the bitrate. The buffer usages being
// 	sampled using "clk_i", it must be "clk_i", or a clock related to it as
// 	the documentation of the output "usage_o" of lib/fifo.sv requires.
//
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.
//
// irq_stb_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised if enabled and the receive
// 	buffer usage interrupt threshold is reached.
//
// irq_rdy_i
// 	This signal becomes low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower irq_stb_o and disable interrupt.
//
// sclk_o
// mosi_o
// miso_i
// cs_o
// 	SPI master signals; "cs_o" is active low.

`include "lib/spi/spi_master.sv"

module spi (

	 rst_i

	,clk_i
	,clk_phy_i

	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,irq_stb_o
	,irq_rdy_i

	,sclk_o
	,mosi_o
	,miso_i
	,cs_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter PHYCLKFREQ     = 1;
parameter DEFAULTBITRATE = 1;
parameter BUFSZ          = 2;
parameter CPOL           = 0;
parameter SYNCTIMEOUT    = (PHYCLKFREQ/10);

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (2*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output wire [WORDBITSZ -1 : 0]            wb_dat_o;

output wire irq_stb_o;
input  wire irq_rdy_i;

output wire sclk_o;
output wire mosi_o;
input  wire miso_i;
output wire cs_o;

reg                               wb_stb_r;
reg                               wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;

wire wb_stb_r_ = (wb_stb_i && !wb_bsy_o);

always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_r_;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

localparam CMDDEVRDY         = 0;
localparam CMDGETBUFFERUSAGE = 1;
localparam CMDSETINTERRUPT   = 2;
localparam CMDSETSPEED       = 3;

reg [WORDBITSZ -1 : 0] wb_dat_o_;

// The first word is used to send/receive data,
// while the second word is used to issue commands.
localparam ISCMDBIT = 0;

wire iscmd = (wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT]);

wire prevcmdisdevrdy = (wb_dat_o_[1:0] == CMDDEVRDY);

wire prevcmddone = (iscmd && prevcmdisdevrdy);

wire cmddevrdy = (iscmd       && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdgetbuf = (prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmdsetint = (prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmdsetspd = (prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);
wire devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);

wire            rx_read_w = devrd;
wire [8 -1 : 0] rx_data_w0;

wire            tx_write_w = devwr;
wire [8 -1 : 0] tx_data_w1 = wb_dat_r[8 -1 : 0];

wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w;
wire [(CLOG2BUFSZ +2) -1 : 0] tx_usage_w;

wire tx_near_full_w;

assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_we_i ? tx_near_full_w : (rx_usage_w == 0)));

reg [(CLOG2BUFSZ +1) -1 : 0] intrqstthresh;

assign irq_stb_o = (|intrqstthresh && (rx_usage_w >= intrqstthresh) &&
	// Raise intrqst only when the device is ready for the next command,
	// otherwise an interrupt would cause software to send the device a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

reg rx_read_w_sampled;

assign wb_dat_o = (rx_read_w_sampled ? {{(WORDBITSZ-8){1'b0}}, rx_data_w0} : wb_dat_o_);

// The transmit buffer usage counts up to two bytes taken out of the
// transmit buffer, hence it is capped to BUFSZ, so that software which
// computes the room in the transmit buffer as BUFSZ less that usage
// never computes a negative value.
wire [(CLOG2BUFSZ +1) -1 : 0] _tx_usage_w = ((tx_usage_w > BUFSZ) ? BUFSZ : tx_usage_w);

localparam SCLKDIVLIMIT = ((PHYCLKFREQ/200000)+1); // 100 kbps is the minimum bitrate.
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

reg [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv;

// Compute the value of "sclkdiv" from the "arg" of CMDSETSPEED, which is
// (PHYCLKFREQ/bitrate); the bitrate resulting from "sclkdiv" being
// (PHYCLKFREQ/(2*(sclkdiv+1))), it does not exceed the bitrate requested
// when sclkdiv is (ceil(arg/2)-1), computed as ((arg-1)>>1), where an "arg"
// of 0 wraps to the largest value; the result is saturated at the lowest
// bitrate.
function automatic [CLOG2SCLKDIVLIMIT -1 : 0] sclkdivof;
	input [(WORDBITSZ-2) -1 : 0] arg;
	reg [(WORDBITSZ-2) -1 : 0] v;
	v = ((arg - 1'b1) >> 1);
	sclkdivof = ((v > (SCLKDIVLIMIT-1)) ? (SCLKDIVLIMIT-1) : v);
endfunction

always_ff @(posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitly enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (cmdsetint) begin
		intrqstthresh <= wb_dat_r[WORDBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		intrqstthresh <= 0;
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {BUFSZ[(WORDBITSZ-2)-1:0], wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2BUFSZ+1)){1'b0}},
			(wb_dat_r[2] ? _tx_usage_w : rx_usage_w),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {PHYCLKFREQ[(WORDBITSZ-2)-1:0], wb_dat_r[1:0]};
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		sclkdiv <= sclkdivof(PHYCLKFREQ/DEFAULTBITRATE);
	else if (cmdsetspd)
		sclkdiv <= sclkdivof(wb_dat_r[WORDBITSZ-1:2]);
end

always_ff @(posedge clk_i) begin
	rx_read_w_sampled <= rx_read_w;
	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

spi_master #(

	 .BUFSZ        (BUFSZ)
	,.DATABITSZ    (8)
	,.SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.CPOL         (CPOL)
	,.SYNCTIMEOUT  (SYNCTIMEOUT)

) spi_master (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.mosi_o (mosi_o)
	,.miso_i (miso_i)
	,.cs_o   (cs_o)

	,.sclkdiv_i (sclkdiv)

	,.write_i     (tx_write_w)
	,.data_i      (tx_data_w1)
	,.near_full_o (tx_near_full_w)
	,.full_o      ()
	,.usage_tx_o  (tx_usage_w)

	,.read_i     (rx_read_w)
	,.data_o     (rx_data_w0)
	,.empty_o    ()
	,.usage_rx_o (rx_usage_w)
);

endmodule
