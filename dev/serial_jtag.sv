// SPDX-License-Identifier: GPL-2.0-only
// 20260703 (c) William Fonkou Tambe

// Serial peripheral through JTAG.
//
// The host side of this peripheral is the FPGA JTAG TAP, accessed
// through a USER instruction of the boundary-scan primitive (Xilinx
// BSCANE2, or Lattice ECP5 JTAGG through small glue deriving capture
// and select from its JCE output) which must be instantiated at the
// top-level and drive the tap_* ports; the wire protocol which the
// JTAG host must implement is documented in lib/serial_jtag_phy.sv .
//
// The device transfers data a byte at a time.
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
// 	when "arg" is 1, the transmit buffer usage is returned.
// 	"resp" in the result gets set to the usage in number of bytes.
// 	CMDSETINTERRUPT: enable/disable interrupt.
// 	"arg" value when 0 disables interrupt, and when non-null, enables
// 	interrupt and sets the minimum receive buffer usage that would
// 	trigger an interrupt.
// 	"resp" in the result gets set to the size in bytes of the transmit
// 	and receive buffer.
// 	CMDSETSPEED: "arg" is ignored, as the transfer rate is set by
// 	the JTAG host through its TAP clock frequency and scan sizing.
// 	"resp" in the result gets set to 0.
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
// On reset, interrupt is disabled, and must be explicitly enabled.
// It prevents an unwanted interrupt after reset.
// When enabled, an interrupt request is raised if the receive buffer
// usage interrupt threshold is reached; interrupt gets disabled when
// the raised interrupt gets acknowledged.
//
// On reset, the receive buffer is drained empty, discarding stale
// host-to-device bytes; the transmit buffer is left untouched so that
// bytes buffered across a reset get delivered once a JTAG host
// attaches. While no JTAG host drains the transmit buffer, a write
// to the device with the transmit buffer full stalls the memory
// interface until a JTAG host attaches; software which must not
// block should first check the usage through CMDGETBUFFERUSAGE.

// Parameters:
//
// WORDBITSZ
// 	Must be a power-of-2 and <= 64.
//
// BUFSZ
// 	Size in bytes of the receive and transmit buffer.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	This input resets this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock input used by the memory interface.
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
// tap_tck_i
// tap_reset_i
// tap_sel_i
// tap_capture_i
// tap_shift_i
// tap_tdi_i
// tap_tdo_o
// 	TAP signals; see lib/serial_jtag_phy.sv .

`include "lib/serial_jtag_fifo_phy.sv"

module serial_jtag (

	 rst_i

	,clk_i

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

	,tap_tck_i
	,tap_reset_i
	,tap_sel_i
	,tap_capture_i
	,tap_shift_i
	,tap_tdi_i
	,tap_tdo_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter BUFSZ = 2;

// Threaded to serial_jtag_phy; see its header (set when the TAP
// signals come through the lib/serial_jtag_jtagg.sv ecp5 adapter).
parameter TAPJTAGG        = 0;
parameter TAPJTAGGCAPDATA = 0;

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (2*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

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

input  wire tap_tck_i;
input  wire tap_reset_i;
input  wire tap_sel_i;
input  wire tap_capture_i;
input  wire tap_shift_i;
input  wire tap_tdi_i;
output wire tap_tdo_o;

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

wire rx_empty_w;

wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w;
wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_w;

wire tx_near_full_w;

// Unlike serial_usb, (rx_usage_w == 0) cannot be used here, because
// the usage is debounced and lags the fifo state; rx_empty_w is safe
// in the "clk_i" clock domain.
assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_we_i ? tx_near_full_w : rx_empty_w));

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

assign wb_dat_o = (rx_read_w_sampled ? rx_data_w0 : wb_dat_o_);

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
			(wb_dat_r[2] ? tx_usage_w : rx_usage_w),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {{(WORDBITSZ-2){1'b0}}, wb_dat_r[1:0]};
	end
end

always_ff @(posedge clk_i) begin
	rx_read_w_sampled <= rx_read_w;
	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

serial_jtag_fifo_phy #(

	 .DEPTH           (BUFSZ)
	,.TAPJTAGG        (TAPJTAGG)
	,.TAPJTAGGCAPDATA (TAPJTAGGCAPDATA)

) phy (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.rx_read_i  (rx_read_w)
	,.rx_data_o  (rx_data_w0)
	,.rx_empty_o (rx_empty_w)
	,.rx_usage_o (rx_usage_w)

	,.tx_write_i (tx_write_w)
	,.tx_data_i  (tx_data_w1)
	,.tx_usage_o (tx_usage_w)

	,.tx_near_full_o (tx_near_full_w)

	,.tap_tck_i     (tap_tck_i)
	,.tap_reset_i   (tap_reset_i)
	,.tap_sel_i     (tap_sel_i)
	,.tap_capture_i (tap_capture_i)
	,.tap_shift_i   (tap_shift_i)
	,.tap_tdi_i     (tap_tdi_i)
	,.tap_tdo_o     (tap_tdo_o)
);

endmodule
