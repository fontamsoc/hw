// SPDX-License-Identifier: GPL-2.0-only
// 20260703 (c) William Fonkou Tambe

`ifndef SERIAL_JTAG_FIFO_PHY_V
`define SERIAL_JTAG_FIFO_PHY_V

// Module implementing JTAG serial FIFO-PHY.
//
// Unlike serial_usb_fifo_phy, the phy clock domain is the TAP clock
// which is unrelated to "clk_i" and not free-running, hence the
// asynchronous fifos are used, and only their gray-code-safe flags
// (full/near_full in the write clock domain, empty in the read clock
// domain) are used for flow control.
//
// The fifos are never reset, because their reset input must be
// sampled by a posedge in each clock domain to take effect, and the
// TAP clock has posedges only while the host is scanning; a reset
// through "rst_i" would desync the fifo indexes. Instead, on "rst_i",
// the receive fifo is drained empty from its read side (which "clk_i"
// owns), discarding stale host-to-device bytes; the transmit fifo is
// deliberately left untouched so that device-to-host bytes buffered
// across a reset get delivered once a host attaches.

// Parameters:
//
// DEPTH
// 	Max number of bytes that each fifo can contain.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	When high on "clk_i" posedge, draining the receive fifo empty
// 	begins; it must be low for normal operation.
//
// clk_i
// 	Clock used by both fifo interfaces below.
//
// rx_read_i
// rx_data_o
// rx_empty_o
// rx_usage_o
// 	FIFO interface to receive data.
// 	"rx_empty_o" is safe to use for flow control; "rx_usage_o" is
// 	debounced as per lib/fifo_async.sv and can lag JTAG activity by
// 	a few "clk_i" cycles, hence it must not be used for flow control.
//
// tx_write_i
// tx_data_i
// tx_near_full_o
// tx_full_o
// tx_usage_o
// 	FIFO interface to transmit data.
// 	"tx_near_full_o" and "tx_full_o" are safe to use for flow
// 	control; "tx_usage_o" is debounced just like "rx_usage_o".
//
// tap_tck_i
// tap_reset_i
// tap_sel_i
// tap_capture_i
// tap_shift_i
// tap_tdi_i
// tap_tdo_o
// 	TAP signals; see lib/serial_jtag_phy.sv .

`include "lib/fifo_async.sv"
`include "lib/fifo_fwft_async.sv"
`include "lib/serial_jtag_phy.sv"

module serial_jtag_fifo_phy (

	 rst_i

	,clk_i

	,rx_read_i
	,rx_data_o
	,rx_empty_o
	,rx_usage_o

	,tx_write_i
	,tx_data_i
	,tx_near_full_o
	,tx_full_o
	,tx_usage_o

	,tap_tck_i
	,tap_reset_i
	,tap_sel_i
	,tap_capture_i
	,tap_shift_i
	,tap_tdi_i
	,tap_tdo_o
);

`include "lib/clog2.sv"

parameter DEPTH = 2;

// Threaded to serial_jtag_phy; see its header (set when the TAP
// signals come through the lib/serial_jtag_jtagg.sv ecp5 adapter).
parameter TAPJTAGG        = 0;
parameter TAPJTAGGCAPDATA = 0;

localparam CLOG2DEPTH = clog2(DEPTH);

input wire rst_i;

input wire clk_i;

input  wire                          rx_read_i;
output wire [8 -1 : 0]               rx_data_o;
output wire                          rx_empty_o;
output wire [(CLOG2DEPTH +1) -1 : 0] rx_usage_o;

input  wire                          tx_write_i;
input  wire [8 -1 : 0]               tx_data_i;
output wire                          tx_near_full_o;
output wire                          tx_full_o;
output wire [(CLOG2DEPTH +1) -1 : 0] tx_usage_o;

input  wire tap_tck_i;
input  wire tap_reset_i;
input  wire tap_sel_i;
input  wire tap_capture_i;
input  wire tap_shift_i;
input  wire tap_tdi_i;
output wire tap_tdo_o;

// Register set high by rst_i and used to drain the receive fifo
// empty from its read side; while draining, rx_empty_o is masked
// high so that a racing read observes an empty fifo.
reg rx_flush_r = 1'b0;

wire                          rx_empty_w;
wire [(CLOG2DEPTH +1) -1 : 0] rx_usage_w;
wire                          rx_full_w;
wire                          rx_near_full_w;
wire [8 -1 : 0]               rx_data_w;
wire                          rx_push_w;

fifo_async #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) rx (

	 .rst_i (1'b0)

	,.clk_read_i (clk_i)
	,.read_i     (rx_flush_r ? !rx_empty_w : rx_read_i)
	,.data_o     (rx_data_o)
	,.empty_o    (rx_empty_w)
	,.usage_o    (rx_usage_w)

	,.clk_write_i (tap_tck_i)
	,.write_i     (rx_push_w)
	,.data_i      (rx_data_w)
	,.near_full_o (rx_near_full_w)
	,.full_o      (rx_full_w)
);

assign rx_empty_o = (rx_empty_w || rx_flush_r);

always_ff @(posedge clk_i) begin
	if (rst_i)
		rx_flush_r <= 1'b1;
	else if (rx_empty_w)
		rx_flush_r <= 1'b0;
end

wire                          tx_empty_w;
wire [(CLOG2DEPTH +1) -1 : 0] tx_usage_w;
wire [8 -1 : 0]               tx_data_w;
wire                          tx_pop_w;

fifo_fwft_async #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) tx (

	 .rst_i (1'b0)

	,.clk_pop_i (tap_tck_i)
	,.pop_i     (tx_pop_w)
	,.data_o    (tx_data_w)
	,.empty_o   (tx_empty_w)
	,.usage_o   (tx_usage_w)

	,.clk_push_i  (clk_i)
	,.push_i      (tx_write_i)
	,.data_i      (tx_data_i)
	,.near_full_o (tx_near_full_o)
	,.full_o      (tx_full_o)
);

serial_jtag_phy #(

	 .TAPJTAGG        (TAPJTAGG)
	,.TAPJTAGGCAPDATA (TAPJTAGGCAPDATA)

) phy (

	 .tap_tck_i     (tap_tck_i)
	,.tap_reset_i   (tap_reset_i)
	,.tap_sel_i     (tap_sel_i)
	,.tap_capture_i (tap_capture_i)
	,.tap_shift_i   (tap_shift_i)
	,.tap_tdi_i     (tap_tdi_i)
	,.tap_tdo_o     (tap_tdo_o)

	,.rx_push_o      (rx_push_w)
	,.rx_data_o      (rx_data_w)
	,.rx_full_i      (rx_full_w)
	,.rx_near_full_i (rx_near_full_w)

	,.tx_pop_o  (tx_pop_w)
	,.tx_data_i (tx_data_w)
	,.tx_empty_i (tx_empty_w)
);

// As documented in lib/fifo_async.sv, "usage_o" combines indexes from
// both clock domains and must be debounced for at least two stable
// samples when the clocks are unrelated; two consecutive equal samples
// cannot straddle two index transitions, because the TAP-side index
// moves at most once per 10 TAP clock cycles (once per frame), which
// is far apart relative to two "clk_i" cycles even at the fastest
// usual TAP clock, hence a torn sample is always discarded.
reg [(CLOG2DEPTH +1) -1 : 0] rx_usage_smp_r = 0;
reg [(CLOG2DEPTH +1) -1 : 0] rx_usage_r     = 0;
reg [(CLOG2DEPTH +1) -1 : 0] tx_usage_smp_r = 0;
reg [(CLOG2DEPTH +1) -1 : 0] tx_usage_r     = 0;

always_ff @(posedge clk_i) begin
	rx_usage_smp_r <= rx_usage_w;
	if (rx_usage_smp_r == rx_usage_w)
		rx_usage_r <= rx_usage_w;
	tx_usage_smp_r <= tx_usage_w;
	if (tx_usage_smp_r == tx_usage_w)
		tx_usage_r <= tx_usage_w;
end

assign rx_usage_o = rx_usage_r;
assign tx_usage_o = tx_usage_r;

endmodule

`endif /* SERIAL_JTAG_FIFO_PHY_V */
