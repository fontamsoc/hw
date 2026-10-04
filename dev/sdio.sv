// SPDX-License-Identifier: GPL-2.0-only
// 20261003 (c) William Fonkou Tambe

// SD host peripheral, driving an SD card in SD mode on a bus 4 bits wide.
//
// The device drives the SD bus using five SPI masters, or lanes, sharing the
// bus clock "sdclk_o": a lane transfers on the CMD line, through "sdcmd_o",
// "sdcmd_i" and "sdcmd_e", and four lanes transfer on the lines DAT0 to
// DAT3, through "sddat_o", "sddat_i" and "sddat_e", the lane i on DATi. Each
// lane works as the SPI master of dev/spi.sv does, with CPHA 0 and CPOL 0:
// its output changes on a falling edge of "sdclk_o", and its input is
// sampled on a rising edge, "sdclk_o" being low while not clocked; the "cs"
// of a lane, which dev/spi.sv drives on "cs_o", is the inverse of the output
// enable of its line: "sdcmd_e", or the bit i of "sddat_e", is high while
// its line is driven, from the beginning of a transmission driving it, which
// happens while "sdclk_o" is low, a half-period at least before its first
// rising edge, until the falling edge of "sdclk_o" which follows its last
// bit, or, when it pauses after its last bit, until its close releases it,
// "sdclk_o" being stopped meanwhile, and is low otherwise, the line being
// then released to the card and to its pull-up.
//
// The memory mapping of the device is made of two interfaces of two words
// each: the CMD interface, which is the first two words, and the DAT
// interface, which is the last two words. Each interface is the interface of
// dev/spi.sv, to be driven likewise using hwdrvchar.h: its first word is
// used to send/receive words, and its second word to send commands, with the
// same commands, results and transmissions, which dev/spi.sv describes; the
// differences are described below.
//
// The CMD interface transfers a word on the CMD line as dev/spi.sv does:
// most significant bit of least significant byte first, ie: the bytes of a
// word from the least significant one, each most significant bit first,
// which is the order of the bits of the commands and responses of the SD
// bus; hence the bytes of a command in a little-endian memory are
// transmitted, and the bytes of a response are stored, in the order of
// their addresses.
// The DAT interface transfers a word on the four DAT lines, a nibble per
// clock, as the SD bus transfers the data of a block (Figure 3-9 of the SD
// Physical Layer Specification): the bytes from the least significant one,
// each as its most significant nibble then its least significant nibble,
// the bit (4+i) then the bit i of each byte being on DATi; hence a word
// lasts (WORDBITSZ/4) clocks, each DAT lane transferring (WORDBITSZ/4) bits
// of it, and the bytes of a data block in a little-endian memory are
// transmitted, and the bytes received are stored, in the order of their
// addresses, as are the four CRC16 of a block.
//
// The commands of each interface are those of dev/spi.sv, and are as follow:
// 	CMDDEVRDY: Make the interface accept a new command.
// 	CMDGETBUFFERUSAGE: Get the receive/transmit buffer usage of the
// 	interface, in bytes. The usages of the DAT interface are those of
// 	the lane which received the fewest words and of the lane which
// 	transmitted the fewest, as they are made of the words of every lane;
// 	the lanes progress identically unless, as described below, their
// 	control bits differ, or a wait for a null bit gets given up on some
// 	lanes only.
// 	CMDSETINTERRUPT: Enable/disable the interrupt of the interface, as
// 	described below; with a null "arg", it also closes the transmission
// 	in progress on that interface. "resp" in the result gets set to the
// 	size in bytes of the transmit and receive buffer of the interface,
// 	which is (CMDBUFSZ*(WORDBITSZ/8)) for the CMD interface, and
// 	(DATBUFSZ*(WORDBITSZ/8)) for the DAT interface.
// 	CMDSETSPEED: Set the bitrate of the bus, as dev/spi.sv computes it,
// 	which is one for both interfaces, being the frequency of "sdclk_o";
// 	hence it is to be changed while the transmit buffer usages of both
// 	interfaces are null. "resp" in the result gets set to PHYCLKFREQ.
// Each interface drops a command written while its previous command isn't
// CMDDEVRDY, and is to be accessed using atomic read-writes, as described in
// dev/spi.sv; both interfaces may be used by different software contexts,
// each serializing the accesses to its own interface.
//
// Each interface performs transmissions as dev/spi.sv does: the word written
// while its transmit buffer usage is null begins a new transmission, being
// its control word, which configures it instead of being transmitted, ones
// being transmitted in its place, the word received in its place being
// pushed in the receive buffer as any other; the transmission lasts until it
// is closed using CMDSETINTERRUPT with a null "arg" on that interface; it
// pauses while the transmit buffer runs empty before, and it is aborted when
// a wait is given up, which discards the words written until the close. The
// transmissions of both interfaces are independent, and can overlap, ie: a
// command sent while data are transferred.
//
// The lanes share one clock, as the lines of an SD bus do, the card shifting
// every line at every clock; they are kept in lockstep as follow:
// "sdclk_o" toggles while a lane of either interface is in a transmission,
// and every lane in a transmission transfers its next bit at each clock;
// a transmission begins either while "sdclk_o" is not clocked, or with a
// falling edge of "sdclk_o"; and while a lane pauses, whether its transmit
// buffer is empty or it waits for room in its receive buffer, "sdclk_o"
// stops, low, every lane being frozen between two bits, until the lane
// resumes, the next bit getting then a full half-period before its rising
// edge. The SD card allows its clock to be stopped at any time, the data it
// transfers resuming with the clock, with the exceptions which 4.4 of the
// SD Physical Layer Specification lists: the card needs 8 clocks after the
// end of the last transaction before its clock stops for long, which the
// recipes below give, and the commands ACMD41 which initialize it are to be
// less than 50 ms apart when its clock stops between them; hence any
// transmission can pause, preemption included.
// A lane waiting for a null bit keeps counting its timeout while frozen; it
// gives it up on the first falling edge of "sdclk_o" after the freeze.
// "sdclk_o" is driven by a register of its own, which takes at every clock
// cycle of "clk_phy_i" the level which the clocks of the lanes take, from
// their edges and their levels and not from its own, so that no logic feeds
// it back to itself, which could keep it out of the I/O tile of its pin;
// hence it equals at every clock cycle the OR of those clocks, which are
// simultaneous, with no logic between that register and the pin; likewise,
// "sdcmd_o" and "sddat_o" are driven by registers of the lanes, "sdcmd_e"
// and "sddat_e" are the inverse of the "cs" registers of the lanes, which a
// pin driven as (e ? o : 1'bz) takes back as its tristate control, and each
// bit of "sdcmd_i" and "sddat_i" is sampled by a single register of its
// lane; hence each of those registers can be placed in the I/O tile of its
// pin, which keeps the delays of the pins short.
//
// The control bits of a control word are as described in dev/spi.sv, in the
// first byte transmitted by each lane, with the following bit 4:
// 	bit 4: when null, the transmission is chained to the next one of
// 	the same interface: once the transmission has ended, its lines being
// 	released if it drove them, "sdclk_o" remains stopped, every lane
// 	being frozen, until the next transmission of that interface begins,
// 	which it does then with no clock in between; hence a response sent
// 	by the card a few clocks after the end of a command is not clocked
// 	until the transmission which receives it has begun, even when DAT
// 	lanes keep "sdclk_o" toggling. The wait for the next transmission is
// 	given up after PAUSETIMEOUT clock cycles of "clk_phy_i", as a pause
// 	is, which discards the next transmission until its close; hence the
// 	next transmission is to be written as soon as the transmit buffer
// 	usage is null, and nothing other than it is to be waited for, as no
// 	transmission of the other interface progresses meanwhile.
//
// The control bits of a CMD control word are in its first byte, as in
// dev/spi.sv: they are its bits 0 to 4, its other bits being reserved and
// expected 1. Hence, for a WORDBITSZ of 32, a control word of 0xffffffff
// begins a transmission which drives the CMD line, 0xffffffef a chained one,
// 0xfffffffb one which keeps the CMD line released ("cs" high), to receive,
// 0xfffffffa one which keeps it released and waits for a null bit, keeping
// it as the bit 7 of the first byte received, ie: the start bit of a
// response, and 0xfffffff8 one which discards it.
// The control bits of a DAT control word are the bits of each lane: the
// first byte transmitted by the lane i is made of the bits (4+i) and i of
// the bytes 0 to 3 of the control word, its bit 7 being the bit (4+i) of
// its byte 0, hence its control bits are as follow, whatever WORDBITSZ:
// 	bit 0: the bit i of the byte 3.
// 	bit 1: the bit (4+i) of the byte 3.
// 	bit 2: the bit i of the byte 2.
// 	bit 3: the bit (4+i) of the byte 2.
// 	bit 4: the bit i of the byte 1.
// The other bits of the control word are reserved and expected 1. Hence,
// for a WORDBITSZ of 32, a DAT control word of 0xffffffff begins a
// transmission which drives every DAT line, 0xfffff0ff a chained one,
// 0xfff0ffff one which keeps every DAT line released, to receive, ie: the
// CRC status which follows a data block written, the busy, or clocks,
// 0x0000ffff one which also waits for a null bit on each line, the start
// bit of a data block, discarding it, and enables receive flow control,
// hence the data block lands word aligned, its first word being received
// in place of the control word, and 0xfef0ffff one which waits for a null
// bit on DAT0 only, keeping it.
// The DAT lanes take the same words, hence they progress identically, unless
// their control bits 0, 1 or 3 differ, or, waiting for a null bit, the card
// drives one on some lines only; such a transmission is to be closed before
// its words are waited for, its lanes ending each after its own words, as a
// lane would otherwise pause ahead of the others, freezing them, until that
// pause gets given up.
//
// Every DAT lane transmits each of its bits (WORDBITSZ/4)-1 clocks later
// than its place in the words written: the bits which follow a control
// word are delayed by (WORDBITSZ/4)-1 bits within each lane, ones being
// transmitted in place of the bits before the first one, and the last
// ((WORDBITSZ/4)-1) bits of each lane of the last word written never being
// transmitted; the control word is not delayed. Hence a data block written
// as follow ends its transmission right after its end bit, and the DAT
// lines are released on the falling edge of "sdclk_o" which follows it,
// before the card drives the CRC status on DAT0, 2 clocks later:
// a control word of ones; a word of ones but its last nibble transmitted,
// the start bit, ie: the most significant nibble of its most significant
// byte being 0xf and its least significant nibble 0, which is 0xf0ffffff
// for a WORDBITSZ of 32; the data block, whose 512 bytes are 1024 clocks;
// its four CRC16, 16 clocks, the CRC16 of each DAT line in the bits of that
// line, most significant bit first; then a word whose first nibble
// transmitted is the end bit, ie: of ones, followed by the close.
// The bits received are not delayed, nor are the bits transmitted on the
// CMD line, a command being transmitted whole within whole words, ie: as
// 2 bytes 0xff followed by the 6 bytes of the command, which ends its
// transmission right after its end bit, releasing the CMD line on the
// falling edge of "sdclk_o" which follows it.
//
// Using hwdrvchar.h, HWDRVCHAR_DATATYPE being defined to uintptr_t, a
// hwdrvchar_t for each interface, and the prologue of the recipe of
// dev/spi.sv on an interface before each of its transmissions, ie: its
// close, then reading until idle, a command expecting a response is sent as
// follow, for a WORDBITSZ of 32:
// 	the control word 0xffffffef, chained, then the 2 words of the bytes
// 	0xff, 0xff and the 6 bytes of the command, then the close, on the
// 	CMD interface;
// 	waiting until its transmit buffer usage is null, the bus being then
// 	stopped, the command having ended, and reading the words received
// 	meanwhile, which are the command itself, as a word is received for
// 	every word written;
// 	if the command reads a data block, ie: CMD17, the control word
// 	0x0000ffff, then ((L/4)+3) words of ones, L being the size in bytes
// 	of the block, followed by the close, on the DAT interface, its words
// 	being the data block, its CRC16s, then 2 words of the end bit and of
// 	the 8 clocks which the card needs after it (4.4 of the SD Physical
// 	Layer Specification), the DAT lanes waiting for the start bit from
// 	the clock which follows the end of the command, as the CMD lane does;
// 	the control word 0xfffffffa, then a word of ones for a response of 48
// 	bits, or 4 words of ones for a response of 136 bits, followed by the
// 	close, on the CMD interface; the response is then the first bytes
// 	received, its start bit being the bit 7 of its first byte, the bits
// 	which follow it giving the card the 8 clocks it needs after it.
// A command expecting no response, ie: CMD0, is sent likewise, unchained,
// followed in its transmission by a word of ones, the 8 clocks which the
// card needs after it.
// A data block is written, as described above, once the response of its
// command was received; a transmission whose control word is 0xfff0ffff,
// followed by 3 words of ones then the close, then receives on DAT0, in the
// bits 4 and 0 of the bytes received, the CRC status, which begins 2 clocks
// after the end bit, and the busy which follows it, which gets polled using
// such transmissions until DAT0 is high. The transmission of the data block
// can be chained, with the control word 0xfffff0ff, so that "sdclk_o" has no
// edge between its end bit and the transmission which receives the CRC
// status, even while a transmission of the CMD interface is in progress.
// Waiting for a null bit on the CMD line is given up after SYNCTIMEOUT
// clock cycles of "clk_phy_i", and on the DAT lines after DATSYNCTIMEOUT,
// counted from the beginning of the wait, frozen time included; hence the
// wait for a data block, which begins while the chained command keeps the
// bus stopped, also covers the time until the transmission which receives
// the response begins.
//
// Aborts are as described in dev/spi.sv, for each lane; after an abort
// which happens on some DAT lanes only, the other lanes progressing, the
// DAT interface reads as aborted, its transmit buffer usage being null
// before its close, once every lane has ended its transmission or given it
// up, the words of the lanes which gave up missing from its receive buffer;
// the words which the other lanes received beyond those remain in their
// receive buffers, ahead of the words which they receive next, as no close
// empties a receive buffer, until the lanes get realigned as follow: a
// transmission of the DAT interface without receive flow control, ie: whose
// control word is 0xfff0ffff for a WORDBITSZ of 32, of at least DATBUFSZ
// words, its control word included, fills the receive buffer of every lane,
// which drops the words received while it is full; once it has ended,
// reading the first word of the DAT interface until its receive buffer
// usage is null empties every lane alike. A reset realigns them as well.
//
// A read of the first word of an interface while its receive buffer is
// empty, which for the DAT interface is while the receive buffer of any
// lane is empty, or a write while its transmit buffer is full or one word
// away from full, which for the DAT interface is while the transmit buffer
// of any lane is, stalls the memory interface, as described in dev/spi.sv.
//
// On reset, interrupt is disabled on both interfaces, and must be explicitly
// enabled. The device raises one interrupt request, when enabled on either
// interface and the receive buffer usage of that interface reaches its
// interrupt threshold, set by CMDSETINTERRUPT on that interface; it is
// raised only while both interfaces are ready for the next command, as an
// interrupt would otherwise cause software to send a command to an interface
// which is not ready, waiting indefinitely for it. Interrupt gets disabled on
// both interfaces when the raised interrupt gets acknowledged; as a close
// disables it on its interface, it is to be enabled again after the close if
// it is used.

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
// CMDBUFSZ
// DATBUFSZ
// 	Size in words of the receive and transmit buffer of the CMD interface
// 	and of the DAT interface; each DAT lane buffers a quarter of each
// 	word, in buffers of DATBUFSZ entries of (WORDBITSZ/4) bits.
// 	They must be at least 2 and powers of 2.
//
// SYNCTIMEOUT
// DATSYNCTIMEOUT
// 	Number of clock cycles of "clk_phy_i" after which waiting for a null
// 	bit is given up, on the CMD line and on the DAT lines; a null value
// 	disables giving up.
// 	The default of SYNCTIMEOUT, (PHYCLKFREQ/500), is 2 ms, which covers the
// 	64 clocks within which an SD card begins a response, ie: 640 us at the
// 	lowest bitrate of about 100 kbps; it is that short as a command whose
// 	response never comes waits for it that long, ie: CMD8, which a card of
// 	the version 1.x of the SD Physical Layer Specification does not answer,
// 	and as that wait is not otherwise lengthened: it begins with the
// 	transmission which receives the response, the command being chained
// 	to it, and the DAT lanes are not to pause meanwhile, as they would stop
// 	"sdclk_o" while the wait is counted.
// 	The default of DATSYNCTIMEOUT, (PHYCLKFREQ/4), is 250 ms, covering the
// 	100 ms within which an SD card begins sending a data block read, and
// 	the time from the beginning of the wait until the transmission which
// 	receives the response of the command begins, a thread preemption
// 	included, which the chain bounds to PAUSETIMEOUT, 100 ms by default.
//
// PAUSETIMEOUT
// 	Number of clock cycles of "clk_phy_i" after which a paused
// 	transmission, a control word waiting for room in the receive buffer,
// 	or the wait for the transmission which follows a chained one, is given
// 	up; a null value disables giving up. Its default of (PHYCLKFREQ/10) is
// 	100 ms, twice the 50 ms within which underLineOS resumes a preempted
// 	thread.

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
// 	Clock input used by the lanes which transmit and receive bits; its
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
// sdclk_o
// 	Clock of the SD bus, low while not clocked.
//
// sdcmd_i
// sdcmd_o
// sdcmd_e
// 	CMD line of the SD bus: its input, its output, and the enable of its
// 	output, active high, ie: the line is driven with "sdcmd_o" while
// 	"sdcmd_e" is high, and released otherwise.
//
// sddat_i
// sddat_o
// sddat_e
// 	Lines DAT0 to DAT3 of the SD bus, the bit i of each port being DATi:
// 	their input, their output, and the enable of their output, active
// 	high, as for the CMD line.

`include "lib/spi/spi_master.sv"

module sdio (

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

	,sdclk_o
	,sdcmd_i
	,sdcmd_o
	,sdcmd_e
	,sddat_i
	,sddat_o
	,sddat_e
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter PHYCLKFREQ     = 1;
parameter DEFAULTBITRATE = 1;
parameter CMDBUFSZ       = 2;
parameter DATBUFSZ       = 2;
parameter SYNCTIMEOUT    = (PHYCLKFREQ/500);
parameter DATSYNCTIMEOUT = (PHYCLKFREQ/4);
parameter PAUSETIMEOUT   = (PHYCLKFREQ/10);

localparam CLOG2CMDBUFSZ = clog2(CMDBUFSZ);
localparam CLOG2DATBUFSZ = clog2(DATBUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (4*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

// Size in bytes of the receive and transmit buffer of each interface, in
// which software counts the buffer usages and the interrupt threshold.
localparam CMDBUFBYTESZ = (CMDBUFSZ*(WORDBITSZ/8));
localparam CLOG2CMDBUFBYTESZ = clog2(CMDBUFBYTESZ);
localparam DATBUFBYTESZ = (DATBUFSZ*(WORDBITSZ/8));
localparam CLOG2DATBUFBYTESZ = clog2(DATBUFBYTESZ);

// Count of the bits of a word which a DAT lane transfers, a nibble of the
// word being transferred per clock.
localparam LANEBITSZ = (WORDBITSZ/4);

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

// Initialized at declaration, as are the registers of the lanes which drive
// the pins: the card must see the clock low from configuration on.
output reg             sdclk_o = 1'b0;
input  wire            sdcmd_i;
output wire            sdcmd_o;
output wire            sdcmd_e;
input  wire [4 -1 : 0] sddat_i;
output wire [4 -1 : 0] sddat_o;
output wire [4 -1 : 0] sddat_e;

// The first word of each interface is used to send/receive data, while
// the second word is used to issue commands; the first two words are the
// CMD interface, while the last two words are the DAT interface.
localparam ISCMDBIT = 0;
localparam ISDATBIT = 1;

reg                               wb_stb_r;
reg                               wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;

// The interface accessed, sampled for the clock cycle where "wb_ack_o"
// returns the result of its previous command.
reg wb_isdat_r;

wire wb_stb_r_ = (wb_stb_i && !wb_bsy_o);

always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_r_;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
	wb_isdat_r <= wb_addr_r[ISDATBIT];
end

localparam CMDDEVRDY         = 0;
localparam CMDGETBUFFERUSAGE = 1;
localparam CMDSETINTERRUPT   = 2;
localparam CMDSETSPEED       = 3;

// The result of the previous command of each interface.
reg [WORDBITSZ -1 : 0] cmd_wb_dat_o_;
reg [WORDBITSZ -1 : 0] dat_wb_dat_o_;

wire cmd_iscmd = (wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT] && !wb_addr_r[ISDATBIT]);
wire dat_iscmd = (wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT] &&  wb_addr_r[ISDATBIT]);

wire cmd_prevcmdisdevrdy = (cmd_wb_dat_o_[1:0] == CMDDEVRDY);
wire dat_prevcmdisdevrdy = (dat_wb_dat_o_[1:0] == CMDDEVRDY);

wire cmd_prevcmddone = (cmd_iscmd && cmd_prevcmdisdevrdy);
wire dat_prevcmddone = (dat_iscmd && dat_prevcmdisdevrdy);

wire cmd_cmddevrdy = (cmd_iscmd       && wb_dat_r[1:0] == CMDDEVRDY);
wire cmd_cmdgetbuf = (cmd_prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmd_cmdsetint = (cmd_prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmd_cmdsetspd = (cmd_prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire dat_cmddevrdy = (dat_iscmd       && wb_dat_r[1:0] == CMDDEVRDY);
wire dat_cmdgetbuf = (dat_prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire dat_cmdsetint = (dat_prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire dat_cmdsetspd = (dat_prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

// CMDSETINTERRUPT with a null "arg" closes the transmission in progress on
// its interface; the whole "arg" is decoded, as dev/spi.sv does.
wire cmd_cmdclose = (cmd_cmdsetint && !(|wb_dat_r[WORDBITSZ-1:2]));
wire dat_cmdclose = (dat_cmdsetint && !(|wb_dat_r[WORDBITSZ-1:2]));

wire cmd_devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] && !wb_addr_r[ISDATBIT] && cmd_prevcmdisdevrdy);
wire cmd_devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] && !wb_addr_r[ISDATBIT] && cmd_prevcmdisdevrdy);
wire dat_devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] &&  wb_addr_r[ISDATBIT] && dat_prevcmdisdevrdy);
wire dat_devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] &&  wb_addr_r[ISDATBIT] && dat_prevcmdisdevrdy);

wire                    cmd_rx_read_w = cmd_devrd;
wire [WORDBITSZ -1 : 0] cmd_rx_data_w0_;
wire [WORDBITSZ -1 : 0] cmd_rx_data_w0;

wire                    cmd_tx_write_w = cmd_devwr;
wire [WORDBITSZ -1 : 0] cmd_tx_data_w1;

wire                    dat_rx_read_w = dat_devrd;
wire [WORDBITSZ -1 : 0] dat_rx_data_w0;

wire                    dat_tx_write_w = dat_devwr;

// A word is transmitted on the CMD line from its least significant byte,
// while spi_master transmits a data from its most significant bit: the
// bytes of the word written are reversed into the data to transmit, as
// dev/spi.sv does, and so are the bytes of the data received.
genvar gen_data_byte_idx;
generate for (
	gen_data_byte_idx = 0;
	gen_data_byte_idx < (WORDBITSZ/8);
	gen_data_byte_idx = gen_data_byte_idx + 1) begin :gen_data_byte
	assign cmd_tx_data_w1[((WORDBITSZ-8)-(gen_data_byte_idx*8)) +: 8] = wb_dat_r[(gen_data_byte_idx*8) +: 8];
	assign cmd_rx_data_w0[(gen_data_byte_idx*8) +: 8] = cmd_rx_data_w0_[((WORDBITSZ-8)-(gen_data_byte_idx*8)) +: 8];
end endgenerate

// The buffer usages, which spi_master counts in words, are reported in
// bytes; those of the DAT interface are computed below from its lanes.
wire [(CLOG2CMDBUFSZ +1) -1 : 0]     cmd_rx_usage_w_;
wire [(CLOG2CMDBUFSZ +2) -1 : 0]     cmd_tx_usage_w_;
wire [(CLOG2CMDBUFBYTESZ +1) -1 : 0] cmd_rx_usage_w = {cmd_rx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};
wire [(CLOG2CMDBUFBYTESZ +2) -1 : 0] cmd_tx_usage_w = {cmd_tx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};

wire [(CLOG2DATBUFSZ +1) -1 : 0]     dat_rx_usage_w_;
wire [(CLOG2DATBUFSZ +2) -1 : 0]     dat_tx_usage_w_;
wire [(CLOG2DATBUFBYTESZ +1) -1 : 0] dat_rx_usage_w = {dat_rx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};
wire [(CLOG2DATBUFBYTESZ +2) -1 : 0] dat_tx_usage_w = {dat_tx_usage_w_, {CLOG2WORDBITSZBY8{1'b0}}};

wire cmd_tx_near_full_w;
wire dat_tx_near_full_w;
wire dat_rx_empty_w;

assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_addr_i[ISDATBIT] ?
	(wb_we_i ? dat_tx_near_full_w : dat_rx_empty_w) :
	(wb_we_i ? cmd_tx_near_full_w : (cmd_rx_usage_w == 0))));

// The interrupt threshold in bytes of each interface, wide enough to hold
// the size in bytes of its buffer plus one, which its receive buffer usage
// never reaches; a threshold between two multiples of (WORDBITSZ/8) is
// reached at the greater one.
reg [(CLOG2CMDBUFBYTESZ +1) -1 : 0] cmd_intrqstthresh;
reg [(CLOG2DATBUFBYTESZ +1) -1 : 0] dat_intrqstthresh;

assign irq_stb_o = (
	((|cmd_intrqstthresh && (cmd_rx_usage_w >= cmd_intrqstthresh)) ||
	 (|dat_intrqstthresh && (dat_rx_usage_w >= dat_intrqstthresh))) &&
	// Raise intrqst only when both interfaces are ready for the next command,
	// otherwise an interrupt would cause software to send an interface a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	cmd_prevcmdisdevrdy && dat_prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

reg cmd_rx_read_w_sampled;
reg dat_rx_read_w_sampled;

assign wb_dat_o = (
	cmd_rx_read_w_sampled ? cmd_rx_data_w0 :
	dat_rx_read_w_sampled ? dat_rx_data_w0 :
	wb_isdat_r ? dat_wb_dat_o_ : cmd_wb_dat_o_);

// The transmit buffer usages count up to two words taken out of the
// transmit buffer, hence each is capped to the size in bytes of its buffer,
// as dev/spi.sv does.
wire [(CLOG2CMDBUFBYTESZ +1) -1 : 0] _cmd_tx_usage_w = ((cmd_tx_usage_w > CMDBUFBYTESZ) ? CMDBUFBYTESZ : cmd_tx_usage_w);
wire [(CLOG2DATBUFBYTESZ +1) -1 : 0] _dat_tx_usage_w = ((dat_tx_usage_w > DATBUFBYTESZ) ? DATBUFBYTESZ : dat_tx_usage_w);

localparam SCLKDIVLIMIT = ((PHYCLKFREQ/200000)+1); // 100 kbps is the minimum bitrate.
localparam CLOG2SCLKDIVLIMIT = clog2(SCLKDIVLIMIT);

// The divider of the bus clock, shared by every lane.
reg [CLOG2SCLKDIVLIMIT -1 : 0] sclkdiv;

// Compute the value of "sclkdiv" from the "arg" of CMDSETSPEED, as
// dev/spi.sv does.
function automatic [CLOG2SCLKDIVLIMIT -1 : 0] sclkdivof;
	input [(WORDBITSZ-2) -1 : 0] arg;
	reg [(WORDBITSZ-2) -1 : 0] v;
	v = ((arg - 1'b1) >> 1);
	sclkdivof = ((v > (SCLKDIVLIMIT-1)) ? (SCLKDIVLIMIT-1) : v);
endfunction

always_ff @(posedge clk_i) begin
	// Logic enabling/disabling interrupt of the CMD interface.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitly enabled.
		// It prevents unwanted interrupt after reset.
		cmd_intrqstthresh <= 0;
	end else if (cmd_cmdsetint) begin
		cmd_intrqstthresh <= wb_dat_r[WORDBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		cmd_intrqstthresh <= 0;
	end
end

always_ff @(posedge clk_i) begin
	// Logic enabling/disabling interrupt of the DAT interface.
	if (rst_i) begin
		dat_intrqstthresh <= 0;
	end else if (dat_cmdsetint) begin
		dat_intrqstthresh <= wb_dat_r[WORDBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		dat_intrqstthresh <= 0;
	end
end

// The constants which the results of commands hold, sized to "resp", as
// dev/spi.sv does.
localparam [(WORDBITSZ-2) -1 : 0] RESPCMDBUFBYTESZ = CMDBUFBYTESZ;
localparam [(WORDBITSZ-2) -1 : 0] RESPDATBUFBYTESZ = DATBUFBYTESZ;
localparam [(WORDBITSZ-2) -1 : 0] RESPPHYCLKFREQ   = PHYCLKFREQ;

always_ff @(posedge clk_i) begin
	if (rst_i || cmd_cmddevrdy) begin
		cmd_wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (cmd_cmdsetint) begin
		cmd_wb_dat_o_ <= {RESPCMDBUFBYTESZ, wb_dat_r[1:0]};
	end else if (cmd_cmdgetbuf) begin
		cmd_wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2CMDBUFBYTESZ+1)){1'b0}},
			(wb_dat_r[2] ? _cmd_tx_usage_w : cmd_rx_usage_w),
			wb_dat_r[1:0]};
	end else if (cmd_cmdsetspd) begin
		cmd_wb_dat_o_ <= {RESPPHYCLKFREQ, wb_dat_r[1:0]};
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i || dat_cmddevrdy) begin
		dat_wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (dat_cmdsetint) begin
		dat_wb_dat_o_ <= {RESPDATBUFBYTESZ, wb_dat_r[1:0]};
	end else if (dat_cmdgetbuf) begin
		dat_wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2DATBUFBYTESZ+1)){1'b0}},
			(wb_dat_r[2] ? _dat_tx_usage_w : dat_rx_usage_w),
			wb_dat_r[1:0]};
	end else if (dat_cmdsetspd) begin
		dat_wb_dat_o_ <= {RESPPHYCLKFREQ, wb_dat_r[1:0]};
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		sclkdiv <= sclkdivof(PHYCLKFREQ/DEFAULTBITRATE);
	else if (cmd_cmdsetspd || dat_cmdsetspd)
		sclkdiv <= sclkdivof(wb_dat_r[WORDBITSZ-1:2]);
end

always_ff @(posedge clk_i) begin
	cmd_rx_read_w_sampled <= cmd_rx_read_w;
	dat_rx_read_w_sampled <= dat_rx_read_w;
	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

// The gang of the lanes: the bus clock is frozen while any lane requests it,
// and a lane begins a transmission only while the bus clock is frozen, or
// when every lane in a transmission has a trailing edge of its clock at the
// end of the clock cycle.
wire            cmd_sclk_w;
wire            cmd_cs_w;
wire            cmd_freeze_w;
wire            cmd_startok_w;
wire            cmd_leading_w;
wire            cmd_trailing_w;
wire [4 -1 : 0] dat_sclk_w;
wire [4 -1 : 0] dat_cs_w;
wire [4 -1 : 0] dat_freeze_w;
wire [4 -1 : 0] dat_startok_w;
wire [4 -1 : 0] dat_leading_w;
wire [4 -1 : 0] dat_trailing_w;

wire gang_freeze_w = (cmd_freeze_w || (|dat_freeze_w));
wire gang_start_w  = (gang_freeze_w || (cmd_startok_w && (&dat_startok_w)));

// The bus clock, from a register of its own, which takes at every clock cycle
// the level which the clocks of the lanes take: high when a lane has a
// leading edge, or when the clock of a lane is high without a trailing edge;
// hence equal to the OR of those clocks at every clock cycle, with no
// dependence on its own level, which could keep it out of the I/O tile.
always_ff @(posedge clk_phy_i) begin
	if (rst_i)
		sdclk_o <= 1'b0;
	else
		sdclk_o <= (cmd_leading_w || (|dat_leading_w) ||
			(cmd_sclk_w && !cmd_trailing_w) || (|(dat_sclk_w & ~dat_trailing_w)));
end

// A lane drives its line while its "cs" is low.
assign sdcmd_e = !cmd_cs_w;
assign sddat_e = ~dat_cs_w;

spi_master #(

	 .BUFSZ        (CMDBUFSZ)
	,.DATABITSZ    (WORDBITSZ)
	,.SCLKDIVLIMIT (SCLKDIVLIMIT)
	,.CPOL         (0)
	,.SYNCTIMEOUT  (SYNCTIMEOUT)
	,.PAUSETIMEOUT (PAUSETIMEOUT)
	,.GANG         (1)

) sdcmd (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (cmd_sclk_w)
	,.mosi_o (sdcmd_o)
	,.miso_i (sdcmd_i)
	,.cs_o   (cmd_cs_w)

	,.sclkdiv_i (sclkdiv)

	,.write_i     (cmd_tx_write_w)
	,.data_i      (cmd_tx_data_w1)
	,.near_full_o (cmd_tx_near_full_w)
	,.full_o      ()
	,.usage_tx_o  (cmd_tx_usage_w_)
	,.close_i     (cmd_cmdclose)

	,.read_i     (cmd_rx_read_w)
	,.data_o     (cmd_rx_data_w0_)
	,.empty_o    ()
	,.usage_rx_o (cmd_rx_usage_w_)

	,.freeze_i   (gang_freeze_w)
	,.start_i    (gang_start_w)
	,.freeze_o   (cmd_freeze_w)
	,.startok_o  (cmd_startok_w)
	,.leading_o  (cmd_leading_w)
	,.trailing_o (cmd_trailing_w)
);

// The usages of each DAT lane, in words.
wire [(4*(CLOG2DATBUFSZ+1)) -1 : 0] dat_rx_usages_w;
wire [(4*(CLOG2DATBUFSZ+2)) -1 : 0] dat_tx_usages_w;

wire [4 -1 : 0] dat_tx_near_fulls_w;
wire [4 -1 : 0] dat_rx_empties_w;

assign dat_tx_near_full_w = (|dat_tx_near_fulls_w);
assign dat_rx_empty_w = (|dat_rx_empties_w);

// A word written to the DAT interface while its transmit buffer usage is
// null is a control word, which every lane takes as the control data of its
// transmission, as spi_master decides it from the same usage.
wire dat_tx_isctrl_w = !(|dat_tx_usages_w);

genvar gen_sddat_idx;
genvar gen_lanebit_idx;
generate for (
	gen_sddat_idx = 0;
	gen_sddat_idx < 4;
	gen_sddat_idx = gen_sddat_idx + 1) begin :gen_sddat

	// The bits of the lane in the word written, and in the data received,
	// in transmission order from the most significant bit: the clock k of a
	// word, counted from 0, carries the bit (4+i) of its byte (k/2) when k
	// is even, otherwise its bit i, for the lane i.
	wire [LANEBITSZ -1 : 0] tx_data_w;
	wire [LANEBITSZ -1 : 0] rx_data_w;

	for (
		gen_lanebit_idx = 0;
		gen_lanebit_idx < LANEBITSZ;
		gen_lanebit_idx = gen_lanebit_idx + 1) begin :gen_lanebit
		assign tx_data_w[gen_lanebit_idx] = wb_dat_r[
			(((LANEBITSZ-1-gen_lanebit_idx)/2)*8) +
			((((LANEBITSZ-1-gen_lanebit_idx)%2) == 0) ? 4 : 0) + gen_sddat_idx];
		assign dat_rx_data_w0[
			(((LANEBITSZ-1-gen_lanebit_idx)/2)*8) +
			((((LANEBITSZ-1-gen_lanebit_idx)%2) == 0) ? 4 : 0) + gen_sddat_idx] = rx_data_w[gen_lanebit_idx];
	end

	// The bits of the lane which follow a control word are transmitted
	// (LANEBITSZ-1) clocks late: each data transmitted is made of the
	// (LANEBITSZ-1) last bits of the lane in the previous word written,
	// ones after a control word, followed by the first bit of the lane in
	// the word written; hence the transmission ends (LANEBITSZ-1) clocks
	// after the first bit of the last word written, which is the end bit
	// of a data block, the bits of that word which follow it being never
	// transmitted.
	reg [(LANEBITSZ-1) -1 : 0] txdly_r;
	always_ff @(posedge clk_i) begin
		if (dat_tx_write_w)
			txdly_r <= (dat_tx_isctrl_w ? {(LANEBITSZ-1){1'b1}} : tx_data_w[(LANEBITSZ-1)-1:0]);
	end
	wire [LANEBITSZ -1 : 0] tx_data_w1 = (dat_tx_isctrl_w ? tx_data_w : {txdly_r, tx_data_w[LANEBITSZ-1]});

	spi_master #(

		 .BUFSZ        (DATBUFSZ)
		,.DATABITSZ    (LANEBITSZ)
		,.SCLKDIVLIMIT (SCLKDIVLIMIT)
		,.CPOL         (0)
		,.SYNCTIMEOUT  (DATSYNCTIMEOUT)
		,.PAUSETIMEOUT (PAUSETIMEOUT)
		,.GANG         (1)

	) sddat (

		 .rst_i (rst_i)

		,.clk_i     (clk_i)
		,.clk_phy_i (clk_phy_i)

		,.sclk_o (dat_sclk_w[gen_sddat_idx])
		,.mosi_o (sddat_o[gen_sddat_idx])
		,.miso_i (sddat_i[gen_sddat_idx])
		,.cs_o   (dat_cs_w[gen_sddat_idx])

		,.sclkdiv_i (sclkdiv)

		,.write_i     (dat_tx_write_w)
		,.data_i      (tx_data_w1)
		,.near_full_o (dat_tx_near_fulls_w[gen_sddat_idx])
		,.full_o      ()
		,.usage_tx_o  (dat_tx_usages_w[(gen_sddat_idx*(CLOG2DATBUFSZ+2)) +: (CLOG2DATBUFSZ+2)])
		,.close_i     (dat_cmdclose)

		,.read_i     (dat_rx_read_w)
		,.data_o     (rx_data_w)
		,.empty_o    (dat_rx_empties_w[gen_sddat_idx])
		,.usage_rx_o (dat_rx_usages_w[(gen_sddat_idx*(CLOG2DATBUFSZ+1)) +: (CLOG2DATBUFSZ+1)])

		,.freeze_i   (gang_freeze_w)
		,.start_i    (gang_start_w)
		,.freeze_o   (dat_freeze_w[gen_sddat_idx])
		,.startok_o  (dat_startok_w[gen_sddat_idx])
		,.leading_o  (dat_leading_w[gen_sddat_idx])
		,.trailing_o (dat_trailing_w[gen_sddat_idx])
	);

end endgenerate

// The receive buffer usage of the DAT interface is the lowest of its lanes,
// and its transmit buffer usage the highest.
localparam DATRXUSAGESZ = (CLOG2DATBUFSZ+1);
localparam DATTXUSAGESZ = (CLOG2DATBUFSZ+2);
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage0_w = dat_rx_usages_w[(0*DATRXUSAGESZ) +: DATRXUSAGESZ];
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage1_w = dat_rx_usages_w[(1*DATRXUSAGESZ) +: DATRXUSAGESZ];
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage2_w = dat_rx_usages_w[(2*DATRXUSAGESZ) +: DATRXUSAGESZ];
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage3_w = dat_rx_usages_w[(3*DATRXUSAGESZ) +: DATRXUSAGESZ];
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage01_w = ((dat_rx_usage0_w < dat_rx_usage1_w) ? dat_rx_usage0_w : dat_rx_usage1_w);
wire [DATRXUSAGESZ -1 : 0] dat_rx_usage23_w = ((dat_rx_usage2_w < dat_rx_usage3_w) ? dat_rx_usage2_w : dat_rx_usage3_w);
assign dat_rx_usage_w_ = ((dat_rx_usage01_w < dat_rx_usage23_w) ? dat_rx_usage01_w : dat_rx_usage23_w);
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage0_w = dat_tx_usages_w[(0*DATTXUSAGESZ) +: DATTXUSAGESZ];
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage1_w = dat_tx_usages_w[(1*DATTXUSAGESZ) +: DATTXUSAGESZ];
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage2_w = dat_tx_usages_w[(2*DATTXUSAGESZ) +: DATTXUSAGESZ];
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage3_w = dat_tx_usages_w[(3*DATTXUSAGESZ) +: DATTXUSAGESZ];
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage01_w = ((dat_tx_usage0_w > dat_tx_usage1_w) ? dat_tx_usage0_w : dat_tx_usage1_w);
wire [DATTXUSAGESZ -1 : 0] dat_tx_usage23_w = ((dat_tx_usage2_w > dat_tx_usage3_w) ? dat_tx_usage2_w : dat_tx_usage3_w);
assign dat_tx_usage_w_ = ((dat_tx_usage01_w > dat_tx_usage23_w) ? dat_tx_usage01_w : dat_tx_usage23_w);

`ifdef SIMULATION_MONITOR
// Run-time checks of the lockstep of the lanes; they read the internals of
// the lanes, which nothing synthesized does: this block is never
// synthesized. Out of reset, at every clock cycle of "clk_phy_i":
// L1: the lanes in a transmission have their clock at the same level and
// the same count within the half-period, and the idle lanes have their
// clock low;
// L2: while the gang is frozen, no lane has a leading edge, and "sdclk_o"
// is low;
// L3: when a lane has a leading edge, so does every lane in a transmission
// which is not paused;
// L4: "sdclk_o" equals the OR of the clocks of the lanes, and its high
// phases last (sclkdiv+1) clock cycles, its low phases (sclkdiv+1) at
// least, unless "sclkdiv" changed during the phase.
// The first 32 clock cycles with a violation are reported.
localparam MONCNTRSZ = CLOG2SCLKDIVLIMIT;
wire [5 -1 : 0] mon_idle_w = {
	gen_sddat[3].sddat.spi_phy.idle_o, gen_sddat[2].sddat.spi_phy.idle_o,
	gen_sddat[1].sddat.spi_phy.idle_o, gen_sddat[0].sddat.spi_phy.idle_o,
	sdcmd.spi_phy.idle_o};
wire [5 -1 : 0] mon_paused_w = {
	gen_sddat[3].sddat.spi_phy.paused, gen_sddat[2].sddat.spi_phy.paused,
	gen_sddat[1].sddat.spi_phy.paused, gen_sddat[0].sddat.spi_phy.paused,
	sdcmd.spi_phy.paused};
wire [5 -1 : 0] mon_sclk_w = {
	gen_sddat[3].sddat.spi_phy.sclk_o, gen_sddat[2].sddat.spi_phy.sclk_o,
	gen_sddat[1].sddat.spi_phy.sclk_o, gen_sddat[0].sddat.spi_phy.sclk_o,
	sdcmd.spi_phy.sclk_o};
wire [(5*MONCNTRSZ) -1 : 0] mon_cntr_w = {
	gen_sddat[3].sddat.spi_phy.cntr, gen_sddat[2].sddat.spi_phy.cntr,
	gen_sddat[1].sddat.spi_phy.cntr, gen_sddat[0].sddat.spi_phy.cntr,
	sdcmd.spi_phy.cntr};
wire [5 -1 : 0] mon_leading_w = {dat_leading_w, cmd_leading_w};
wire [(5*5) -1 : 0] mon_l1pairs_w;
genvar gen_mon_idx;
genvar gen_mon_jdx;
generate for (
	gen_mon_idx = 0;
	gen_mon_idx < 5;
	gen_mon_idx = gen_mon_idx + 1) begin :gen_mon_i
	for (
		gen_mon_jdx = 0;
		gen_mon_jdx < 5;
		gen_mon_jdx = gen_mon_jdx + 1) begin :gen_mon_j
		assign mon_l1pairs_w[(gen_mon_idx*5)+gen_mon_jdx] = (
			!mon_idle_w[gen_mon_idx] && !mon_idle_w[gen_mon_jdx] &&
			((mon_sclk_w[gen_mon_idx] != mon_sclk_w[gen_mon_jdx]) ||
			 (mon_cntr_w[(gen_mon_idx*MONCNTRSZ) +: MONCNTRSZ] !=
			  mon_cntr_w[(gen_mon_jdx*MONCNTRSZ) +: MONCNTRSZ])));
	end
end endgenerate
reg                    mon_sdclk_r;
reg [32 -1 : 0]        mon_phase_r;
reg                    mon_divchg_r;
reg [MONCNTRSZ -1 : 0] mon_sclkdiv_r;
reg [32 -1 : 0]        mon_errcnt_r;
wire [32 -1 : 0]       mon_halfper_w = ({{(32-MONCNTRSZ){1'b0}}, mon_sclkdiv_r} + 32'd1);
wire mon_l1_w = ((|mon_l1pairs_w) || (|(mon_idle_w & mon_sclk_w)));
wire mon_l2_w = (gang_freeze_w && ((|mon_leading_w) || sdclk_o));
wire mon_l3_w = ((|mon_leading_w) && (mon_leading_w != (~mon_idle_w & ~mon_paused_w)));
wire mon_l4_w = ((sdclk_o != (|mon_sclk_w)) || ((sdclk_o != mon_sdclk_r) && !mon_divchg_r &&
	(mon_sdclk_r ? (mon_phase_r != mon_halfper_w) : (mon_phase_r < mon_halfper_w))));
always_ff @(posedge clk_phy_i) begin
	mon_sdclk_r <= sdclk_o;
	mon_sclkdiv_r <= sclkdiv;
	if (rst_i) begin
		mon_phase_r <= 1;
		mon_divchg_r <= 1'b1;
		mon_errcnt_r <= 0;
	end else begin
		if (sdclk_o == mon_sdclk_r) begin
			mon_phase_r <= (mon_phase_r + 1);
			mon_divchg_r <= (mon_divchg_r || (sclkdiv != mon_sclkdiv_r));
		end else begin
			mon_phase_r <= 1;
			mon_divchg_r <= 1'b0;
		end
		if (mon_l1_w || mon_l2_w || mon_l3_w || mon_l4_w) begin
			if (mon_errcnt_r < 32) begin
				$display("sdio: error: lockstep: L1 %b L2 %b L3 %b L4 %b at %0t: idle %b paused %b sclk %b leading %b freeze %b sdclk_o %b phase %0d sclkdiv %0d",
					mon_l1_w, mon_l2_w, mon_l3_w, mon_l4_w, $time, mon_idle_w, mon_paused_w,
					mon_sclk_w, mon_leading_w, gang_freeze_w, sdclk_o, mon_phase_r, mon_sclkdiv_r);
				$fflush();
			end
			mon_errcnt_r <= (mon_errcnt_r + 1);
		end
	end
end
`endif

endmodule
