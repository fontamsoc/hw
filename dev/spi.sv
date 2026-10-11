// SPDX-License-Identifier: GPL-2.0-only
// 20260926 (c) William Fonkou Tambe

// SPI peripheral.
//
// The device is a SPI master with CPHA 0, the clock polarity being the
// parameter CPOL, and it transfers data a word at a time, most significant
// bit of least significant byte first, ie: the bytes of a word from the
// least significant one, each most significant bit first. It transfers
// full duplex: while a word is transmitted through "mosi_o", a word is
// received through "miso_i", and pushed in the receive buffer, the first
// byte received becoming its least significant byte. Hence the bytes of a
// buffer in a little-endian memory are transmitted, and the bytes received
// are stored, in the order of their addresses.
// The first word of the device memory mapping is used to send/receive
// words while the second word is used to send commands to the device.
// An access to the first word transfers a whole word, as "wb_sel_i" is
// ignored: a write of fewer bytes than a word buffers a whole word for
// transmission, its other bytes being whatever the memory interface
// carries, and a read of fewer bytes than a word takes a whole word out of
// the receive buffer.
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
// 	the count of the bytes of the words not yet transmitted; it includes
// 	up to two words taken out of the transmit buffer, one while a
// 	transmission is paused in place of the word being transmitted, and
// 	one while a close is pending, hence it is capped to the size in bytes
// 	of the buffer, and it is null only when no transmission is in
// 	progress and no close is pending.
// 	"resp" in the result gets set to the usage in number of bytes, which
// 	is a multiple of (WORDBITSZ/8), as the buffers hold whole words.
// 	CMDSETINTERRUPT: enable/disable interrupt.
// 	"arg" value when 0 disables interrupt, and when non-null, enables
// 	interrupt and sets the minimum receive buffer usage in bytes that
// 	would trigger an interrupt; the usage being a multiple of
// 	(WORDBITSZ/8), a threshold between two multiples is reached at the
// 	greater one. When the whole "arg" is 0, it also closes the
// 	transmission in progress, as described below.
// 	"resp" in the result gets set to the size in bytes of the transmit
// 	and receive buffer, which is (BUFSZ*(WORDBITSZ/8)).
// 	CMDSETSPEED: Set the bitrate used when sending and receiving words.
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
// A word written while the transmit buffer usage is null begins a new
// transmission, which lasts until it is closed using CMDSETINTERRUPT with
// a null "arg": it then ends once every word written before that command
// has been transmitted, "cs_o" becoming high. When the transmit buffer
// runs empty before, the transmission pauses: "sclk_o" remains at its idle
// level, "cs_o" keeps its level and nothing is clocked, until the next
// word written resumes it. Hence the words of a transmission can be written
// at any pace, preemption included, and a word written within a
// transmission never begins a new one.
// The word which begins a transmission is a control word, which configures
// the transmission instead of being transmitted, ones being transmitted in
// its place, while the word received in its place gets pushed in the
// receive buffer as any other. The bits 0 to 3 of its least significant
// byte, ie: its first byte in transmission order, are its control bits,
// and its other bits are reserved and expected 1; they are as follow:
// 	bit 0: when null, waiting for a null bit on "miso_i" before counting
// 	the bits transmitted is enabled, "sclk_o" toggling meanwhile with
// 	"mosi_o" high; it is used with a slave which signals the beginning
// 	of its response using a null bit, such as the start-bit of an SD
// 	card in SPI mode, and the transmission remains synchronized to that
// 	null bit until it ends.
// 	bit 1: when null, and waiting for a null bit is enabled, that null
// 	bit is discarded, the WORDBITSZ bits which follow it becoming the word
// 	received in place of the control word; otherwise, that null bit
// 	becomes the most significant bit of the least significant byte of
// 	that word.
// 	bit 2: when null, "cs_o" remains high for the whole transmission,
// 	while "sclk_o" and "mosi_o" behave as usual; ie: For a WORDBITSZ of
// 	32, a control word of 0xfffffffb followed by two words 0xffffffff,
// 	then the close, sends 96 clock cycles with "cs_o" and "mosi_o" high,
// 	which covers the 74 at least that an SD card needs before its first
// 	command. The bits are independent: waiting for a null bit while
// 	"cs_o" is kept high waits on a slave which is not selected, until
// 	given up.
// 	bit 3: when null, receive flow control is enabled: while the receive
// 	buffer holds BUFSZ-1 words or more, the transmission pauses instead
// 	of taking the next word, hence no word received gets dropped, and the
// 	reader can be preempted as the writer can; the control word itself
// 	waits for room in the receive buffer before the transmission begins.
// 	The receive buffer usage then stops at BUFSZ-1 words, or at BUFSZ
// 	words when the next word was already waiting as the previous one
// 	completed, hence an interrupt threshold of at most
// 	((BUFSZ-1)*(WORDBITSZ/8)) bytes is to be used with it.
// Hence, for a WORDBITSZ of 32, a control word of 0xffffffff begins a
// transmission which neither waits for a null bit, keeps "cs_o" high, nor
// pauses for room in the receive buffer; 0xfffffffe waits for a null bit,
// 0xfffffffc also discarding it, 0xfffffffb keeps "cs_o" high, and
// 0xfffffff7 enables receive flow control. Since a write of fewer bytes
// than a word buffers a whole word, a byte which begins a transmission,
// written at the address of the first word, makes a control word whose
// least significant byte is that byte.
// When the parameter CTRLCSHIGH is non-null, "cs_o" is high while ones are
// transmitted in place of the control word, and becomes low, unless bit 2
// is null, or unless the transmission ends there, a clock cycle of
// "clk_phy_i" after their last trailing edge of "sclk_o", a full half-period
// before the leading edge which follows, the transmission pausing there at
// least that clock cycle, the one pause where "cs_o" changes; and
// the second byte of the control word in transmission order, ie: its bits
// 8 to 15, is the count of bytes, transmitted after it, during which "cs_o"
// is low: "cs_o" becomes high on the trailing edge of "sclk_o" which ends
// the last of them, and remains high until the transmission ends, while
// "sclk_o" and "mosi_o" behave as usual. A null count keeps "cs_o" high as
// a null bit 2 does, and a count of 0xff, the value expected of a reserved
// byte, keeps it low until the transmission ends. Hence a SPI flash, which takes the first
// byte after the fall of its chip select for a command, is sent nothing
// before it; and a command of a byte which it executes only when its chip
// select rises right after its eighth bit, such as its write enable, is
// transmitted, for a WORDBITSZ of 32, using the control word 0xffff01ff
// followed by a word whose least significant byte is that command, ie:
// 0xffffff06. When the
// parameter CTRLCSHIGH is null, the second byte is reserved.
//
// A close remains pending until the transmission has ended, and is counted
// in the transmit buffer usage meanwhile; a word written while it is pending
// continues the transmission instead of beginning the next one, hence the
// next transmission is to be written once the transmit buffer usage is null.
// A close while no transmission is in progress does nothing, other than
// ending the discarding described below; hence the CMDSETINTERRUPT which
// ends hwdrvchar_init() is harmless.
// Using hwdrvchar.h, HWDRVCHAR_DATATYPE being defined to a type of WORDBITSZ
// bits, ie: uintptr_t, so that hwdrvchar_read() and hwdrvchar_write() access
// the first word a word at a time, a transmission is performed as follow:
// 	uintptr_t junk[16], c;
// 	// End what may have been left open, drop stale words, wait until idle.
// 	hwdrvchar_interrupt(dev, 0);
// 	do hwdrvchar_read(dev, junk, sizeof(junk));
// 	while (hwdrvchar_writable(dev) != dev->bufsz);
// 	while (hwdrvchar_read(dev, junk, sizeof(junk)));
// 	c = -1; // The control word; ie: ~8 for receive flow control.
// 	hwdrvchar_write(dev, &c, sizeof(c));
// 	// hwdrvchar_write() and hwdrvchar_read() at any pace, reading every
// 	// word expected; ie: for an SD card, the command, polling its response
// 	// using bytes 0xff, polling the data token, then the block and its CRC.
// 	hwdrvchar_interrupt(dev, 0); // The close.
// 	while (hwdrvchar_writable(dev) != dev->bufsz); // Ended.
// Its first lines insure that a transmission left open, ie: by a context
// which did not complete it, does not take the words written as its own.
// With a HWDRVCHAR_DATATYPE of a byte, each access of hwdrvchar_read() or
// hwdrvchar_write() to the first word would transfer a whole word, and the
// reads beyond the words received would stall the memory interface, as
// described below.
//
// Waiting for a null bit is given up after SYNCTIMEOUT clock cycles of
// "clk_phy_i": the transmission is aborted, without a word received in
// place of the control word, "cs_o" becoming high, and no interrupt is
// raised. The words in the transmit buffer are then discarded, and so are
// the words written afterwards, until the transmission is closed, which
// must be done before writing the next transmission as for any other; a
// close already requested ends the discarding once the transmit buffer is
// empty. Hence a word meant to continue the transmission after it was
// aborted is never taken for the control word of a new one. Software
// detects the abort from the transmit buffer usage becoming null before it
// closed the transmission, whereas it is never null while a transmission
// is in progress; the words received before the abort remain in the
// receive buffer.
// A transmission paused for PAUSETIMEOUT clock cycles of "clk_phy_i",
// whether waiting for a word to be written or for room in the receive
// buffer, is aborted likewise, "cs_o" becoming high; so is a control word
// waiting for room in the receive buffer as long, which is dropped. The
// discarding follows until the close, as above. Hence a transmission left
// open ends by itself, and hwdrvchar_init() alone returns the transmit
// side to idle, taking the time to transmit the words buffered, up to
// BUFSZ+2 word-times, then PAUSETIMEOUT+1 clock cycles of "clk_phy_i",
// its final CMDSETINTERRUPT ending the discarding; the words received
// meanwhile remain to be read.
//
// For every word written, a word is received, and the receive buffer drops
// the words received while it is full; hence, unless receive flow control
// is enabled, the count of words written less the count of words read
// must not exceed BUFSZ.
//
// A read while the receive buffer is empty, or a write while the transmit
// buffer is full or one word away from full, stalls the memory interface
// until a word is received, or until room is made by a word transmitted;
// hence such a read stalls it for good when no word written remains to be
// received.
// Under receive flow control, such a write while the transmission waits for
// room in the receive buffer stalls it until the transmission is aborted,
// or for good if PAUSETIMEOUT is null, as the reader cannot run meanwhile;
// hence no more bytes than hwdrvchar_writable() returns are to be written.
//
// The transmissions of different software contexts must not interleave,
// hence the accesses to the device must be serialized, ie: using a lock.
//
// On reset, interrupt is disabled, and must be explicitly enabled.
// It prevents an unwanted interrupt after reset.
// When enabled, an interrupt request is raised if the receive buffer
// usage interrupt threshold is reached; interrupt gets disabled when
// the raised interrupt gets acknowledged.
// CMDSETINTERRUPT with a null "arg" closing the transmission in progress,
// interrupt is to be enabled again after the close if it is used, and
// is to be disabled within a transmission using a threshold of
// ((BUFSZ*(WORDBITSZ/8))+1) bytes, which the receive buffer usage never
// reaches.

// Parameters:
//
// WORDBITSZ
// 	Must be 32 or 64.
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
//
// DEFAULTBITRATE
// 	Bitrate at reset, set as CMDSETSPEED sets it; ie: 400000, the highest
// 	bitrate at which an SD card may be initialized.
//
// BUFSZ
// 	Size in words of the receive and transmit buffer.
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
//
// PAUSETIMEOUT
// 	Number of clock cycles of "clk_phy_i" after which a paused
// 	transmission, or a control word waiting for room in the receive
// 	buffer, is given up; a null value disables giving up, as happens at
// 	the default PHYCLKFREQ. Its default of (PHYCLKFREQ/10) is 100 ms,
// 	twice the 50 ms within which underLineOS resumes a preempted thread;
// 	equal to SYNCTIMEOUT, it adds no counter bits.
//
// CTRLCSHIGH
// 	When non-null, "cs_o" is high while ones are transmitted in place of
// 	the control word, and the second byte of the control word is the count
// 	of bytes after it during which "cs_o" is low, as described above; ie:
// 	for a SPI flash. It is not to be used with bit 0 of the control word,
// 	which would wait for a null bit from a slave which is not selected.
//
// LATESAMPLE
// 	When non-null, "miso_i" is sampled on the trailing edge of "sclk_o"
// 	which ends each bit, instead of the leading edge which begins it; hence
// 	a slave which changes "miso_i" on the trailing edges, such as a SPI
// 	flash in mode 0, which does on the falling edge, has a full period of
// 	"sclk_o" for its output to reach the pin instead of half of it, which
// 	the delays of the pads and of the slave exceed above about 25 Mbps. It
// 	is not to be set for a slave which changes "miso_i" on the leading
// 	edges, such as an SD card in high speed mode, as the next bit would
// 	get sampled; nor used with bit 0 of the control word, which expects a
// 	null bit sampled on a leading edge.

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
parameter PAUSETIMEOUT   = (PHYCLKFREQ/10);
parameter CTRLCSHIGH     = 0;
parameter LATESAMPLE     = 0;

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (2*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

// Size in bytes of the receive and transmit buffer, in which software
// counts the buffer usages and the interrupt threshold.
localparam BUFBYTESZ = (BUFSZ*(WORDBITSZ/8));
localparam CLOG2BUFBYTESZ = clog2(BUFBYTESZ);

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

// CMDSETINTERRUPT with a null "arg" closes the transmission in progress;
// the whole "arg" is decoded, as "intrqstthresh" keeps its
// (CLOG2BUFBYTESZ+1) lsb only, and a non-null "arg" which truncates to a
// null threshold only disables interrupt.
wire cmdclose = (cmdsetint && !(|wb_dat_r[WORDBITSZ-1:2]));

wire devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);
wire devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] && prevcmdisdevrdy);

wire                    rx_read_w = devrd;
wire [WORDBITSZ -1 : 0] rx_data_w0_;
wire [WORDBITSZ -1 : 0] rx_data_w0;

wire                    tx_write_w = devwr;
wire [WORDBITSZ -1 : 0] tx_data_w1;

// A word is transmitted from its least significant byte, while spi_master
// transmits a data from its most significant bit: the bytes of the word
// written are reversed into the data to transmit, its least significant
// byte becoming the 8 most significant bits of that data; likewise, the
// bytes of the data received are reversed into the word read, the first
// byte received becoming its least significant byte.
genvar gen_data_byte_idx;
generate for (
	gen_data_byte_idx = 0;
	gen_data_byte_idx < (WORDBITSZ/8);
	gen_data_byte_idx = gen_data_byte_idx + 1) begin :gen_data_byte
	assign tx_data_w1[((WORDBITSZ-8)-(gen_data_byte_idx*8)) +: 8] = wb_dat_r[(gen_data_byte_idx*8) +: 8];
	assign rx_data_w0[(gen_data_byte_idx*8) +: 8] = rx_data_w0_[((WORDBITSZ-8)-(gen_data_byte_idx*8)) +: 8];
end endgenerate

// The buffer usages, which spi_master counts in words, are reported in
// bytes, as BUFBYTESZ is.
wire [(CLOG2BUFSZ +1) -1 : 0]     rx_usage_w_;
wire [(CLOG2BUFSZ +2) -1 : 0]     tx_usage_w_;
wire [(CLOG2BUFBYTESZ +1) -1 : 0] rx_usage_w = {rx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};
wire [(CLOG2BUFBYTESZ +2) -1 : 0] tx_usage_w = {tx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};

wire tx_near_full_w;

assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_we_i ? tx_near_full_w : (rx_usage_w == 0)));

// The interrupt threshold in bytes, wide enough to hold BUFBYTESZ+1, which
// the receive buffer usage never reaches; a threshold between two multiples
// of (WORDBITSZ/8) is reached at the greater one.
reg [(CLOG2BUFBYTESZ +1) -1 : 0] intrqstthresh;

assign irq_stb_o = (|intrqstthresh && (rx_usage_w >= intrqstthresh) &&
	// Raise intrqst only when the device is ready for the next command,
	// otherwise an interrupt would cause software to send the device a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

reg rx_read_w_sampled;

assign wb_dat_o = (rx_read_w_sampled ? rx_data_w0 : wb_dat_o_);

// The transmit buffer usage counts up to two words taken out of the
// transmit buffer, hence it is capped to BUFBYTESZ, so that software which
// computes the room in the transmit buffer as BUFBYTESZ less that usage
// never computes a negative value.
wire [(CLOG2BUFBYTESZ +1) -1 : 0] _tx_usage_w = ((tx_usage_w > BUFBYTESZ) ? BUFBYTESZ : tx_usage_w);

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

// The constants which the results of commands hold, sized to "resp": a
// part-select of BUFBYTESZ or PHYCLKFREQ, integers of 32 bits, would yield
// undefined bits beyond their 32 bits for a WORDBITSZ of 64.
localparam [(WORDBITSZ-2) -1 : 0] RESPBUFBYTESZ  = BUFBYTESZ;
localparam [(WORDBITSZ-2) -1 : 0] RESPPHYCLKFREQ = PHYCLKFREQ;

always_ff @(posedge clk_i) begin
	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {RESPBUFBYTESZ, wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2BUFBYTESZ+1)){1'b0}},
			(wb_dat_r[2] ? _tx_usage_w : rx_usage_w),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {RESPPHYCLKFREQ, wb_dat_r[1:0]};
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
	,.DATABITSZ    (WORDBITSZ)
	,.SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.CPOL         (CPOL)
	,.SYNCTIMEOUT  (SYNCTIMEOUT)
	,.PAUSETIMEOUT (PAUSETIMEOUT)
	,.CTRLCSHIGH   (CTRLCSHIGH)
	,.LATESAMPLE   (LATESAMPLE)

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
	,.usage_tx_o  (tx_usage_w_)
	,.close_i     (cmdclose)

	,.read_i     (rx_read_w)
	,.data_o     (rx_data_w0_)
	,.empty_o    ()
	,.usage_rx_o (rx_usage_w_)
);

endmodule
