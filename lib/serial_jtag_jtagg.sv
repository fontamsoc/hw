// SPDX-License-Identifier: GPL-2.0-only
// 20260724 (c) William Fonkou Tambe

`ifndef SERIAL_JTAG_JTAGG_V
`define SERIAL_JTAG_JTAGG_V

// Module adapting the ecp5 JTAGG primitive to the BSCANE2-shaped TAP
// interface expected by serial_jtag_phy; it is the single owner of the
// ecp5 TAP-interface contract, and a serial_jtag fed through it must be
// instantiated with TAPJTAGG=1 so the phy compensates for the JTAGG
// behaviors described below; TAPJTAGG=1 without this adapter, or this
// adapter with TAPJTAGG=0, yields corrupted framing.
//
// The JTAGG primitive differs from the BSCANE2 in three ways which
// this pairing accounts for:
//
// - There are no separate CAPTURE/SEL decodes; JCE1/JCE2 are high in
//   the Capture-DR and Shift-DR states while respectively ER1 (0x32)
//   or ER2 (0x38) is the TAP instruction. Each capture strobe is
//   hence derived from the JCE rising edge.
//
// - JTDI is not the raw TDI pin; JTAGG registers it on the raw TCK
//   rising edge.
//
// - The one-TAP-state-early cadence which the phasing below engineers
//   emits each device-to-host bit one shifting edge before the host
//   samples it, hence the TDO path must be re-registered on a falling
//   edge; measurement showed the JTAGG passes JTDO1/JTDO2 to the TDO
//   pin combinationally (unlike some of its documentation), so this
//   adapter provides that register itself, on the delayed clock's
//   falling edge, making the pairing independent of the primitive's
//   undocumented TDO pipeline.
//
// The JTAGG decodes and its JTDI register are timed by the raw TCK,
// while the fabric is clocked by JTCK routed through this module's
// deliberate LUT4 delay chain (same technique as other production
// ecp5 JTAG cores); the added delay insures that every fabric rising
// edge samples the post-edge values of the JTAGG outputs: the state
// decodes appear one TAP state early and the registered JTDI appears
// on time. Without the chain, which side of the raw edge each fabric
// flip-flop samples would be decided by unconstrained routing races,
// re-rolled at each place-and-route. Under this engineered phasing
// the capture strobe fires at the Capture-DR entry rising edge (one
// earlier than the BSCANE2 CAPTURE) and the last frame bit reaches
// the phy one shifting edge past its commit; the TAPJTAGG=1 phy
// compensates for both, and the one-state-early cadence through this
// adapter's tdo register delivers the device-to-host stream on time.
//
// Limitation of the JCE-derived capture strobe: a JTAG host must not
// pass through the Pause-DR state within a scan, as resuming re-fires
// the JCE rising edge and corrupts the framing of that scan; hosts
// shifting each scan in one continuous pass (the bridge in
// tools/serial_jtag/) are unaffected.
//
// In simulation (`SIMULATION`) the LUT4 chain is bypassed, as the
// phasing it engineers is a hardware routing property; testbenches
// model the post-edge sampling at the signal level instead.

// Parameters:
//
// CHANNELCNT
// 	Count of serial_jtag channels, at most 2, as the ecp5 has only
// 	the two ER user data-registers.
//
// DELAYLUTCNT
// 	Count of LUT4 cells in the JTCK delay chain.

// Ports:
//
// jtck_i
// jtdi_i
// jshift_i
// jrstn_i
// jce_i
// 	JTAGG outputs "JTCK", "JTDI", "JSHIFT", "JRSTN" and
// 	"JCE1"/"JCE2".
//
// jtdo_o
// 	To be connected to the JTAGG inputs "JTDO1"/"JTDO2"; routed
// 	through this module so the pairing has a single connection
// 	point.
//
// tap_tck_o
// tap_reset_o
// tap_sel_o
// tap_capture_o
// tap_shift_o
// tap_tdi_o
// tap_tdo_i
// 	BSCANE2-shaped TAP bundle, one sel/capture per channel; see
// 	lib/serial_jtag_phy.sv for the individual signal contracts.

module serial_jtag_jtagg (

	 jtck_i
	,jtdi_i
	,jshift_i
	,jrstn_i
	,jce_i
	,jtdo_o

	,tap_tck_o
	,tap_reset_o
	,tap_sel_o
	,tap_capture_o
	,tap_shift_o
	,tap_tdi_o
	,tap_tdo_i
);

parameter CHANNELCNT  = 2;
parameter DELAYLUTCNT = 8;

input  wire                     jtck_i;
input  wire                     jtdi_i;
input  wire                     jshift_i;
input  wire                     jrstn_i;
input  wire [CHANNELCNT -1 : 0] jce_i;
output wire [CHANNELCNT -1 : 0] jtdo_o;

output wire                     tap_tck_o;
output wire                     tap_reset_o;
output wire [CHANNELCNT -1 : 0] tap_sel_o;
output wire [CHANNELCNT -1 : 0] tap_capture_o;
output wire                     tap_shift_o;
output wire                     tap_tdi_o;
input  wire [CHANNELCNT -1 : 0] tap_tdo_i;

`ifdef SIMULATION
assign tap_tck_o = jtck_i;
`else
// The chain must survive optimization, hence the keep attributes;
// each cell is a pass-through (INIT=2 makes Z follow A).
wire [DELAYLUTCNT : 0] dly_w;
assign dly_w[0] = jtck_i;
genvar gen_dly_idx;
generate for (
	gen_dly_idx = 0;
	gen_dly_idx < DELAYLUTCNT;
	gen_dly_idx = gen_dly_idx + 1) begin :gen_dly
(* keep *) LUT4 #(.INIT(16'd2)) dlylut (
	 .A (dly_w[gen_dly_idx])
	,.B (1'b0)
	,.C (1'b0)
	,.D (1'b0)
	,.Z (dly_w[gen_dly_idx+1])
);
end endgenerate
assign tap_tck_o = dly_w[DELAYLUTCNT];
`endif

// Registers used to detect a rising edge on JCE1/JCE2; clocked by the
// delayed TAP clock so the detector phase is part of the engineered
// contract above. There is no reset input; initial values matching
// the FPGA power-on initialization are used instead.
reg [CHANNELCNT -1 : 0] jce_r = 0;
always_ff @(posedge tap_tck_o) begin
	jce_r <= jce_i;
end

assign tap_reset_o   = !jrstn_i;
assign tap_sel_o     = jce_i;
assign tap_capture_o = (jce_i & ~jce_r);
assign tap_shift_o   = jshift_i;
assign tap_tdi_o     = jtdi_i;

// The falling-edge tdo register described in the header; it samples
// the phys' outputs before their own falling-edge updates land (a
// same-clock register pair), retiming the one-edge-early stream onto
// the host's sampling edges.
reg [CHANNELCNT -1 : 0] jtdo_r = 0;
always_ff @(negedge tap_tck_o) begin
	jtdo_r <= tap_tdo_i;
end

assign jtdo_o = jtdo_r;

endmodule

`endif /* SERIAL_JTAG_JTAGG_V */
