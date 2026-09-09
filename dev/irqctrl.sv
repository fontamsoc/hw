// SPDX-License-Identifier: GPL-2.0-only
// 20260802 (c) William Fonkou Tambe

// Interrupt controller peripheral.
// It dispatches an interrupt to a destination for which
// its irq_rdy_o is high, iterating in a round-robin fashion
// through each destination.
// Preference is given to destination with irq_dst_pri_i high.
//
// Commands are sent to the controller writing to it with the
// following expected format | arg: (WORDBITSZ-2) bits | cmd: 2 bit |
// where the field "cmd" values are CMDDEVRDY(2'b00), CMDACKIRQ(2'b01),
// CMDINTDST(2'b10) and CMDENAIRQ(2'b11). The result of a previously
// sent command is retrieved from the controller reading from it and
// has the following format
// | resp: (WORDBITSZ-3) bits | rsvd: 1 bit | cmd: 2 bit |, where the fields
// "cmd" and "resp" are the command and its result, while the field "rsvd"
// is reserved and null.
// Two memory operations, a write followed by a read are needed to send
// a command to the controller and retrieve its result.
// The controller has accepted a command only if "cmd" in its result
// is CMDDEVRDY, otherwise sending the command CMDDEVRDY is needed.
//
// The description of commands is as follow:
// 	CMDDEVRDY: Ready the controller to accept a new command.
// 	"resp" in the result gets set to 0.
// 	CMDACKIRQ: Acknowledges an interrupt source; field "arg" is expected
// 	to have following format | idx: (WORDBITSZ-3) bits | en: 1 bit |
// 	where "idx" is the interrupt destination index, "en" enables/disables
// 	further interrupt delivery to the interrupt destination "idx".
// 	"resp" in the result gets set to the interrupt source index, or -2
// 	if there are no pending interrupts for the destination "idx", or -1
// 	for an interrupt triggered by CMDINTDST.
// 	CMDINTDST: Triggers an interrupt targeting a specific destination;
// 	field "arg" is expected to have following format
// 	| idx: (WORDBITSZ-3) bits | rsvd: 1 bit | where "idx" is the interrupt
// 	destination index to target, "rsvd" is reserved and ignored.
// 	"resp" in the result gets set to the interrupt destination index
// 	if valid, -2 if not ready due to an interrupt pending ack, or -1 if invalid.
// 	The destination -1 (all ones) requests a system reset, which the
// 	controller signals through rst_rqst_o; "resp" gets set to -1 as for
// 	an invalid destination, the four command codes being all taken.
// 	CMDENAIRQ: Enable/Disable an interrupt source; field "arg" is expected
// 	to have following format | idx: (WORDBITSZ-3) bits | en: 1 bit |
// 	where "idx" is the interrupt source index, "en" enables/disables
// 	interrupts from the interrupt source "idx".
// 	"resp" in the result gets set to the interrupt source index, or -1
// 	if invalid.
//
// The controller silently drops any command, other than CMDDEVRDY,
// written while the previous command isn't CMDDEVRDY (in other words
// while processing a transaction); CMDDEVRDY is always accepted and
// discards any result not yet retrieved.
// Hence a non-CMDDEVRDY command is the start of a transaction,
// and to insure threadsafety, an atomic read-write must be used to send
// a command to the controller until CMDDEVRDY is returned, then another
// atomic read-write sending CMDDEVRDY must be used to retrieve the
// result while making the controller ready for the next command.
//
// An interrupt must be acknowledged as soon as possible using CMDACKIRQ
// (which drives irq_src_rdy_o low and returns its index) so that
// the controller can dispatch another interrupt, because the controller
// does not buffer requests.

// Parameters:
//
// IRQDSTCOUNT
// 	Number of interrupt destinations.
// 	It must be non-null and less than ((1<<(WORDBITSZ-4))-2).
//
// IRQSRCCOUNT
// 	Number of interrupt sources.
// 	It must be non-null and less than ((1<<(WORDBITSZ-4))-2).

// Ports:
//
// rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module resets.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
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
// irq_dst_stb_o
// irq_dst_stb_i
// irq_dst_rdy_i
// irq_dst_pri_i
// 	Destination interrupt signals.
// 	irq_dst_stb_o is raised to request an interrupt from the destination.
// 	irq_dst_stb_i is raised when the interrupt request is now being
// 	considered by the destination.
// 	When the destination drives irq_dst_rdy_i low while irq_dst_stb_i
// 	is high, it is assumed that it has taken on the requested interrupt.
// 	The destination keeps irq_dst_pri_i low when it wouldn't be
// 	the best choice to service the interrupt; irq_dst_pri_i is used
// 	in a multi-PU system where it is driven by PUs "halted_o" in order
// 	to give a preference to PUs that are halted.
// 	The destination with the lowest index is always preferred.
//
// irq_src_stb_i
// irq_src_rdy_o
// 	Source interrupt signals.
// 	irq_src_stb_i is high to request an interrupt, and irq_src_rdy_o
// 	gets driven low when the requested interrupt has been acknowledged.
// 	The source device must drive irq_src_stb_i low as soon as a falling edge
// 	of irq_src_rdy_o occurs, otherwise another interrupt request will occur
// 	when irq_src_rdy_o has become high and irq_src_stb_i is still high.
//
// rst_rqst_o
// 	Raised for a clock cycle when an accepted CMDINTDST targets the
// 	destination -1 (all ones), requesting a system reset; it is meant
// 	for the reset controller, which stretches it into a reset pulse.

module irqctrl (

	 rst_i

	,clk_i

	,wb_stb_i
	,wb_we_i
	//,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,irq_dst_stb_o
	,irq_dst_stb_i
	,irq_dst_rdy_i
	,irq_dst_pri_i

	,irq_src_stb_i
	,irq_src_rdy_o

	,rst_rqst_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter IRQSRCCOUNT = 0;
parameter IRQDSTCOUNT = 0;

localparam CLOG2IRQSRCCOUNT = clog2(IRQSRCCOUNT);
localparam CLOG2IRQDSTCOUNT = clog2(IRQDSTCOUNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (WORDBITSZ/8);

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
//input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            wb_dat_o;

output wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_o;
input  wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_i;
input  wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_i;
input  wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_i;

input  wire [IRQSRCCOUNT -1 : 0] irq_src_stb_i;
output wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_o;

output reg rst_rqst_o;

assign wb_bsy_o = 1'b0;

reg                    wb_stb_r;
reg                    wb_we_r;
reg [WORDBITSZ -1 : 0] wb_dat_r;

always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_i;
	if (wb_stb_i) begin
		wb_we_r <= wb_we_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

// Registers used to index respectively the source and destination of an interrupt.
reg [CLOG2IRQSRCCOUNT -1 : 0] srcidx;
reg [CLOG2IRQDSTCOUNT -1 : 0] dstidx;

localparam CMDDEVRDY = 2'b00;
localparam CMDACKIRQ = 2'b01;
localparam CMDINTDST = 2'b10;
localparam CMDENAIRQ = 2'b11;

wire prevcmdisdevrdy = (wb_dat_o[1:0] == CMDDEVRDY);

wire prevcmddone = (wb_stb_r && wb_we_r && prevcmdisdevrdy);

wire cmddevrdy = (wb_stb_r && wb_we_r && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdackirq = (prevcmddone && wb_dat_r[1:0] == CMDACKIRQ);
wire cmdintdst = (prevcmddone && wb_dat_r[1:0] == CMDINTDST);
wire cmdenairq = (prevcmddone && wb_dat_r[1:0] == CMDENAIRQ);

// Registered one-cycle pulse requesting a system reset: an accepted
// CMDINTDST targeting the destination -1 (all ones); cmdintdst carries
// the prevcmddone gate, hence only an accepted command pulses and a
// retried request cannot pulse twice; the pulse getting cleared by the
// reset it requests is harmless, the reset controller having latched it.
always_ff @(posedge clk_i) begin
	if (rst_i)
		rst_rqst_o <= 1'b0;
	else
		rst_rqst_o <= (cmdintdst && (&wb_dat_r[WORDBITSZ -1 : 3]));
end

reg [WORDBITSZ -1 : 0] irqdstdat;
wire irqdstseek = (
	irqdstdat[1:0] == CMDINTDST &&
	dstidx != irqdstdat[(CLOG2IRQDSTCOUNT +3) -1 : 3]);

reg irqpending; /* set to 1 when an interrupt request is waiting to be acknowledged */

reg [IRQDSTCOUNT -1 : 0] irq_dst_rdy_i_and_not_irq_dst_stb_i_r;
always_ff @(posedge clk_i)
	irq_dst_rdy_i_and_not_irq_dst_stb_i_r <= (irq_dst_rdy_i & ~irq_dst_stb_i);
wire [IRQDSTCOUNT -1 : 0] irqpending_abort = (~irq_dst_rdy_i & irq_dst_rdy_i_and_not_irq_dst_stb_i_r);

wire irqpending_abort_dstidx = irqpending_abort[dstidx];

// An acknowledgement hits only when an interrupt is pending, routed to the
// acknowledging destination, and not being aborted; any other acknowledgement
// reports no pending interrupts and must not signal irq_src_rdy_o, otherwise
// an interrupt source which is not being serviced would silently drop its
// request; ie: an acknowledgement sent while nothing is routed to the
// acknowledging destination would otherwise report, and fake-service, the
// interrupt source that the round-robin scan happens to be indexing.
genvar gen_irq_src_rdy_o_idx;
generate for (
	gen_irq_src_rdy_o_idx = 0;
	gen_irq_src_rdy_o_idx < IRQSRCCOUNT;
	gen_irq_src_rdy_o_idx = gen_irq_src_rdy_o_idx + 1) begin :gen_irq_src_rdy_o
	assign irq_src_rdy_o[gen_irq_src_rdy_o_idx] = (
		srcidx != gen_irq_src_rdy_o_idx || irqdstdat[1:0] == CMDINTDST ||
			!(cmdackirq && irqpending && !irqpending_abort_dstidx &&
				wb_dat_r[WORDBITSZ -1 : 3] == dstidx));
end endgenerate

genvar gen_irq_dst_stb_o_idx;
generate for (
	gen_irq_dst_stb_o_idx = 0;
	gen_irq_dst_stb_o_idx < IRQDSTCOUNT;
	gen_irq_dst_stb_o_idx = gen_irq_dst_stb_o_idx + 1) begin :gen_irq_dst_stb_o
	assign irq_dst_stb_o[gen_irq_dst_stb_o_idx] = (
		dstidx == gen_irq_dst_stb_o_idx && irqpending && !irqdstseek &&
		// Raise irq_dst_stb_o only when the controller is ready for the next command,
		// otherwise an interrupt would cause software to send the controller a new
		// command while it is not ready, waiting indefinitely for it to be ready.
		prevcmdisdevrdy);
end endgenerate

wire [CLOG2IRQSRCCOUNT -1 : 0] nextsrcidx =
	((srcidx < (IRQSRCCOUNT-1)) ? (srcidx + 1'b1) : {CLOG2IRQSRCCOUNT{1'b0}});
wire [CLOG2IRQDSTCOUNT -1 : 0] nextdstidx =
	((dstidx < (IRQDSTCOUNT-1)) ? (dstidx + 1'b1) : {CLOG2IRQDSTCOUNT{1'b0}});

reg [IRQSRCCOUNT -1 : 0] irqsrcen;
reg [IRQDSTCOUNT -1 : 0] irqdsten;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		wb_dat_o <= {WORDBITSZ{1'b0}};
		srcidx <= {CLOG2IRQSRCCOUNT{1'b0}};
		dstidx <= {CLOG2IRQDSTCOUNT{1'b0}};
		irqpending <= 1'b0;
		irqdstdat <= {WORDBITSZ{1'b0}};
		irqsrcen <= {IRQSRCCOUNT{1'b0}};
		irqdsten <= {IRQDSTCOUNT{1'b0}};
	end else if (cmddevrdy) begin
		wb_dat_o <= {WORDBITSZ{1'b0}};
	end else if (cmdenairq) begin
		if (wb_dat_r[WORDBITSZ -1 : 3] < IRQSRCCOUNT) begin
			irqsrcen[wb_dat_r[(CLOG2IRQSRCCOUNT +3) -1 : 3]] <= wb_dat_r[2];
			wb_dat_o <= {
				{((WORDBITSZ-3)-CLOG2IRQSRCCOUNT){1'b0}},
				wb_dat_r[(CLOG2IRQSRCCOUNT +3) -1 : 3],
				1'b0,
				wb_dat_r[1:0]};
		end else
			wb_dat_o <= {{(WORDBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
	end else if (cmdintdst) begin
		if (wb_dat_r[WORDBITSZ -1 : 3] < IRQDSTCOUNT) begin
			if (irqpending) begin
				wb_dat_o <= {{(WORDBITSZ-4){1'b1}}, 1'b0, 1'b0, wb_dat_r[1:0]};
			end else begin
				wb_dat_o <= {
					{((WORDBITSZ-3)-CLOG2IRQDSTCOUNT){1'b0}},
					wb_dat_r[(CLOG2IRQDSTCOUNT +3) -1 : 3],
					1'b0,
					wb_dat_r[1:0]};
				irqpending <= 1'b1;
				irqdstdat <= wb_dat_r;
			end
		end else
			wb_dat_o <= {{(WORDBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
	end else if (irqdstseek) begin
		// Keep incrementing dstidx until the targeted interrupt destination is indexed.
		dstidx <= nextdstidx;
	end else if (irqpending || cmdackirq) begin
		if (irqpending_abort_dstidx)
			irqpending <= 1'b0;
		if (cmdackirq) begin // Logic that acknowledges a triggered interrupt.
			if (irqpending && !irqpending_abort_dstidx &&
				wb_dat_r[WORDBITSZ -1 : 3] == dstidx) begin
				wb_dat_o <= ((irqdstdat[1:0] == CMDINTDST) ?
					{{(WORDBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]} :
					{{((WORDBITSZ-3)-CLOG2IRQSRCCOUNT){1'b0}}, srcidx, 1'b0, wb_dat_r[1:0]});
				irqpending <= 1'b0;
				irqdstdat <= {WORDBITSZ{1'b0}};
				// The destination with the lowest index is always preferred.
				dstidx <= {CLOG2IRQDSTCOUNT{1'b0}};
				srcidx <= nextsrcidx;
			end else begin
				// No pending interrupt is routed to the acknowledging destination;
				// this also responds to an acknowledgement which lost against
				// irqpending_abort_dstidx, which would otherwise leave the ready
				// result in place and get read back as interrupt source 0.
				wb_dat_o <= {{(WORDBITSZ-4){1'b1}}, 1'b0, 1'b0, wb_dat_r[1:0]};
			end
			if (wb_dat_r[WORDBITSZ -1 : 3] < IRQDSTCOUNT)
				irqdsten[wb_dat_r[(CLOG2IRQDSTCOUNT +3) -1 : 3]] <= wb_dat_r[2];
		end
	end else if (irqsrcen[srcidx] && irq_src_stb_i[srcidx]) begin
		// If there is no preferred interrupt destination available
		// and the indexed destination for the interrupt is not
		// ready, I try the next one.
		// If there is a preferred interrupt destination available,
		// dstidx keeps incrementing until the preferred interrupt
		// destination is indexed.
		if (irqdsten[dstidx] && irq_dst_rdy_i[dstidx] &&
			(!(irq_dst_pri_i & irqdsten) || irq_dst_pri_i[dstidx])) begin
			// Only when the controller is ready for the next command,
			// since irq_dst_stb_o is raised only then.
			if (prevcmdisdevrdy)
				irqpending <= 1'b1;
		end else
			dstidx <= nextdstidx;
	// I check the next interrupt source if there is no request on the current interrupt source.
	end else
		srcidx <= nextsrcidx;
end

`ifdef SIMULATION_MONITOR
// Report an acknowledgement which does not hit, since software is expected
// to acknowledge an interrupt only from the destination it was dispatched
// to; each of these corners used to be mishandled before the hardening
// which made every acknowledgement miss report no pending interrupts:
// a blind acknowledgement, or one from a destination other than the routed
// one, used to fake-service the interrupt source that the round-robin scan
// happened to be indexing, while one colliding with an interrupt abort used
// to leave the ready result in place to be read back as interrupt source 0.
// An acknowledgement miss from a destination with interrupt delivery
// disabled is not reported, as it is the documented way for software to
// enable interrupt delivery to a destination; ie: the _OS (UnderLineOS)
// cpu bring-up deliberately acknowledges with nothing pending just for
// the enable side effect.
always_ff @(posedge clk_i) begin
	if (!rst_i && cmdackirq && !irqdstseek &&
		(wb_dat_r[WORDBITSZ -1 : 3] >= IRQDSTCOUNT ||
			irqdsten[wb_dat_r[(CLOG2IRQDSTCOUNT +3) -1 : 3]])) begin
		if (!irqpending) begin
			$display("irqctrl: error: acknowledgement from destination %0d with no interrupt pending",
				wb_dat_r[WORDBITSZ -1 : 3]);
			$fflush();
		end else if (wb_dat_r[WORDBITSZ -1 : 3] != dstidx) begin
			$display("irqctrl: error: acknowledgement from destination %0d while the pending interrupt is routed to destination %0d",
				wb_dat_r[WORDBITSZ -1 : 3], dstidx);
			$fflush();
		end else if (irqpending_abort_dstidx) begin
			$display("irqctrl: error: acknowledgement from destination %0d colliding with the abort of its routed interrupt",
				wb_dat_r[WORDBITSZ -1 : 3]);
			$fflush();
		end
	end
end
`endif

endmodule
