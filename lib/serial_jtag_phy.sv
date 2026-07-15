// SPDX-License-Identifier: GPL-2.0-only
// 20260703 (c) William Fonkou Tambe

`ifndef SERIAL_JTAG_PHY_V
`define SERIAL_JTAG_PHY_V

// Module implementing the JTAG USER data-register engine used by the
// serial_jtag peripheral. It is entirely clocked by the TAP clock and
// exchanges bytes with the two fifos of serial_jtag_fifo_phy.
//
// The host transfers bytes by shifting the USER data-register with
// 10 bits frames, least-significant bit first, and a scan must be
// (10*N)+1 bits for N frames; the extra padding bit (for which the
// host shifts 0 and ignores the corresponding tdo bit) keeps every
// meaningful bit off the rising edge which leaves the Shift-DR state,
// for which the BSCANE2 "SHIFT" output timing is not reliable.
//
// Each frame shifted out to the host has the following format
// | rx_ready: 1 bit | tx_valid: 1 bit | tx_byte: 8 bits | where
// "tx_byte" is a device-to-host byte which is meaningful only when
// "tx_valid" is set, and "rx_ready" tells the host whether the device
// accepts the host-to-device byte sent in this same frame slot.
// Each frame shifted in from the host has the following format
// | reserved: 1 bit (shift 0) | rx_valid: 1 bit | rx_byte: 8 bits |
// where "rx_byte" is a host-to-device byte which is used only when
// "rx_valid" is set.
//
// A new frame is loaded on the Capture-DR rising edge and thereafter
// on every 10th shifting rising edge, which is also the edge at which
// the completed incoming frame is committed; an incoming byte is
// pushed in the receive fifo only when "rx_ready" was advertised in
// the same frame slot; once a valid incoming byte gets refused, all
// following incoming bytes of the scan are refused as well, so that
// the bytes accepted within a scan are always a prefix of the bytes
// sent, and the host preserves byte ordering by resending the refused
// suffix at the beginning of its next scan.
//
// A device-to-host byte is popped from the transmit fifo when loaded
// in a frame, and is retired only at that frame's own committing edge,
// since by that edge the host has sampled all 10 bits of the frame;
// a byte whose frame never completes (the scan ended, or the TAP was
// reset) is resent in the first frame of the next scan, hence no byte
// is ever lost or duplicated, and the host must ignore incomplete
// trailing frames.
//
// This module has no reset input; its registers rely on FPGA power-on
// initialization, and each scan reinitializes the framing at capture.
// A TAP Test-Logic-Reset only discards the partial frame state.

// Ports:
//
// tap_tck_i
// 	TAP clock from the BSCANE2 "TCK" output; it clocks every
// 	register in this module and it is not free-running.
//
// tap_reset_i
// 	High in the TAP Test-Logic-Reset state; BSCANE2 "RESET" output.
//
// tap_sel_i
// 	High when the USER instruction is the current TAP instruction;
// 	BSCANE2 "SEL" output. It qualifies tap_capture_i and tap_shift_i
// 	which pulse for every DR scan, USER-selected or not.
//
// tap_capture_i
// 	High in the TAP Capture-DR state; BSCANE2 "CAPTURE" output.
//
// tap_shift_i
// 	High in the TAP Shift-DR state; BSCANE2 "SHIFT" output.
//
// tap_tdi_i
// 	TAP data input; BSCANE2 "TDI" output.
//
// tap_tdo_o
// 	TAP data output, updated on "tap_tck_i" negedge as JTAG requires;
// 	to be connected to the BSCANE2 "TDO" input.
//
// rx_push_o
// rx_data_o
// rx_full_i
// rx_near_full_i
// 	Write interface of the receive (host-to-device) fifo, in the
// 	"tap_tck_i" clock domain; "rx_full_i" and "rx_near_full_i" must
// 	be valid in the write clock domain of that fifo.
//
// tx_pop_o
// tx_data_i
// tx_empty_i
// 	Read interface of the transmit (device-to-host) fifo, in the
// 	"tap_tck_i" clock domain; "tx_data_i" must fall-through (be valid
// 	before "tx_pop_o" is asserted) and "tx_empty_i" must be valid in
// 	the read clock domain of that fifo.

module serial_jtag_phy (

	 tap_tck_i
	,tap_reset_i
	,tap_sel_i
	,tap_capture_i
	,tap_shift_i
	,tap_tdi_i
	,tap_tdo_o

	,rx_push_o
	,rx_data_o
	,rx_full_i
	,rx_near_full_i

	,tx_pop_o
	,tx_data_i
	,tx_empty_i
);

localparam FRAMEBITSZ = 10;

input  wire tap_tck_i;
input  wire tap_reset_i;
input  wire tap_sel_i;
input  wire tap_capture_i;
input  wire tap_shift_i;
input  wire tap_tdi_i;
output wire tap_tdo_o;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;
input  wire            rx_full_i;
input  wire            rx_near_full_i;

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;
input  wire            tx_empty_i;

// There is no reset input; initial values matching the FPGA power-on
// initialization are used instead.
reg [FRAMEBITSZ -1 : 0] shift_r = 0; // Data-register shifter.
reg [4 -1 : 0]          bitcnt_r = 0; // Count of bits shifted in the current frame.
reg [8 -1 : 0]          hold_data_r = 0; // Byte loaded in the frame being shifted out.
reg                     hold_valid_r = 1'b0; // Whether hold_data_r is a byte not yet retired.
reg                     pend_accept_r = 1'b0; // "rx_ready" advertised in the frame being shifted out.
reg                     rx_reject_r = 1'b0; // Set once a valid incoming byte gets refused.
reg                     tdo_r = 1'b0;

wire capture_w = (tap_sel_i && tap_capture_i);
wire shift_w   = (tap_sel_i && tap_shift_i);
// The 10th shifting edge of a frame, at which the completed incoming
// frame is committed and the next outgoing frame is loaded.
wire commit_w  = (shift_w && bitcnt_r == (FRAMEBITSZ-1));

// Completed incoming frame as seen at the committing edge; its last
// bit is on tap_tdi_i while its 9 first bits are in shift_r[9:1].
wire [FRAMEBITSZ -1 : 0] inframe_w = {tap_tdi_i, shift_r[FRAMEBITSZ-1:1]};

assign rx_push_o = (commit_w && inframe_w[8] && pend_accept_r && !rx_reject_r && !rx_full_i);
assign rx_data_o = inframe_w[7:0];

// A valid incoming byte which could not be pushed makes rejection
// sticky until the next capture, so that the bytes accepted within
// a scan are always a prefix of the bytes sent and never reordered.
wire rx_reject_w = (capture_w ? 1'b0 : (rx_reject_r || (commit_w && inframe_w[8] && !rx_push_o)));

// "rx_ready" advertised by the frame loaded at this edge; when a push
// occurs at this same edge, "rx_near_full_i" (full or one write away
// from full) is what "rx_full_i" will be once the push takes effect.
wire accept_w = (!rx_reject_w && (rx_push_o ? !rx_near_full_i : !rx_full_i));

wire load_w = (capture_w || commit_w);
// At capture, a byte loaded in a frame which never reached its
// committing edge is resent instead of poping the transmit fifo;
// at a committing edge, the byte of the frame which just completed
// is retired, since the host has sampled all its bits by that edge.
wire resend_w = (capture_w && hold_valid_r);

assign tx_pop_o = (load_w && !resend_w && !tx_empty_i);

wire [8 -1 : 0]          load_data_w  = (resend_w ? hold_data_r : tx_data_i);
wire                     load_valid_w = (resend_w || tx_pop_o);
wire [FRAMEBITSZ -1 : 0] outframe_w   = {accept_w, load_valid_w, load_data_w};

always_ff @(posedge tap_tck_i) begin
	if (tap_reset_i) begin
		// Test-Logic-Reset discards the partial frame state;
		// hold_valid_r is preserved so that a byte in flight
		// survives a TAP reset and gets resent.
		bitcnt_r <= 0;
		rx_reject_r <= 1'b0;
	end else if (load_w) begin
		// The loaded frame's first bit is presented on tap_tdo_o at this
		// same edge (see the tap_tdo_o assignment), which the host captures
		// as this frame's leading bit; the shifter therefore holds the frame
		// pre-advanced by one so the following shifts emit bits 1..9.
		shift_r <= {1'b0, outframe_w[FRAMEBITSZ-1:1]};
		bitcnt_r <= 0;
		rx_reject_r <= rx_reject_w;
		pend_accept_r <= accept_w;
		hold_data_r <= load_data_w;
		hold_valid_r <= load_valid_w;
	end else if (shift_w) begin
		shift_r <= {tap_tdi_i, shift_r[FRAMEBITSZ-1:1]};
		bitcnt_r <= (bitcnt_r + 1'b1);
	end
end

// tdo transitions on the falling edge of the TAP clock so the host samples
// a stable value on the rising edge. JTAG requires each frame's bit 0 to be
// on tdo for its first shifting edge, but the phy loads on the Capture-DR
// exit edge, one edge too late for "shift_r[0]" alone; the shifter is loaded
// pre-advanced by one and bit 0 is presented separately.
//
// For every frame after the first, that separate bit 0 is registered on the
// falling edge preceding the committing edge (commit_w is asserted the cycle
// before it), and the remaining falling edges emit the pre-advanced shifter's
// bits 1..9.
//
// The first frame of a scan is loaded from Capture-DR, and the BSCANE2
// "CAPTURE" qualifier can reach this phy up to half a TAP period after the
// BUFG-delayed tap_tck (CAPTURE is aligned to the raw TCK while this phy runs
// on the buffered one), too late to register bit 0 on the falling edge that
// precedes the Capture-DR exit edge -- registering it there instead re-fires
// on the following falling edge and drops the frame's second bit. Drive bit 0
// combinationally while CAPTURE is asserted: "outframe_w[0]" is stable across
// Capture-DR (the transmit fifo is not popped until the exit edge, and the
// host samples it on that exit edge, its first shifting edge), after which
// CAPTURE deasserts and the registered shifter drives tdo as usual.
always_ff @(negedge tap_tck_i) begin
	tdo_r <= (commit_w ? outframe_w[0] : shift_r[0]);
end

assign tap_tdo_o = (capture_w ? outframe_w[0] : tdo_r);

endmodule

`endif /* SERIAL_JTAG_PHY_V */
