// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Interrupt controller peripheral.
// It dispatches an interrupt to a destination for
// which the output intrdy is high, iterating in
// a round-robin fashion through each destination.
// Preference is given to destination driving
// intbest high.

// Parameters:
//
// INTDSTCOUNT
// 	Number of interrupt destination.
// 	It must be non-null and less than ((1<<(ARCHBITSZ-2))-2).
//
// INTSRCCOUNT
// 	Number of interrupt source.
// 	It must be non-null and less than ((1<<(ARCHBITSZ-2))-2).

// Ports:
//
// rst_i
// 	When held high at the rising edge
// 	of the clock signal, the module reset.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// pi1_op_i
// pi1_addr_i
// pi1_data_i
// pi1_data_o
// pi1_sel_i
// pi1_rdy_o
// pi1_mapsz_o
// 	PerInt slave memory interface.
//
// intrqstdst_o
// intrdydst_i
// intbestdst_i
// 	Destination interrupt signals.
// 	intrqst is raised to request an interrupt from the destination.
// 	The destination drives intrdy high when it is ready to take
// 	on a requested interrupt; it keeps intbest low when it wouldn't
// 	be the best choice to service the interrupt; intbest is used
// 	in a multipu system where it is driven by PUs output "halted"
// 	in order to give a preference to PUs that are halted when looking
// 	for an interrupt destination.
// 	The destination with the lowest index is always preferred.
//
// intrqstsrc_i
// intrdysrc_o
// 	Source interrupt signals.
// 	intrqst is high to request an interrupt, and intrdy is driven
// 	low when the requested interrupt is being acknowledged.
// 	The index of the interrupt being acknowledged is returned.
// 	The source device must drive intrqst low as soon as a falling edge
// 	of intrdy occur, otherwise another interrupt request will occur
// 	when intrdy has become high and intrqst is still high.
//
// PIRWOP is the only memory operation handled with following
// expected from pi1_data_i |arg: (ARCHBITSZ-2) bits|cmd: 2 bit|
// where the field "cmd" values are CMDACKINT(2'b00), CMDINTDST(2'b01) or CMDENAINT(2'b10).
// 	CMDACKINT: Acknowledges an interrupt source; field "arg" is expected
// 	to have following format |idx: (ARCHBITSZ-3) bits|en: 1 bit|
// 	where "idx" is the interrupt destination index, "en" enable/disable
// 	further interrupt delivery to the interrupt destination "idx".
// 	pi1_data_o get set to the interrupt source index, or -2 if
// 	there are no pending interrupt for the destination "idx",
// 	or -1 (for an interrupt triggered by CMDINTDST).
// 	CMDINTDST: Triggers an interrupt targeting a specific destination;
// 	the field "arg" from pi1_data_i is the index of the interrupt destination
// 	to target, while pi1_data_o get set to the interrupt destination index
// 	if valid, -2 if not ready due to an interrupt pending ack, or -1 if invalid.
// 	CMDENAINT: Enable/Disable an interrupt source; field "arg" is expected
// 	to have following format |idx: (ARCHBITSZ-3) bits|en: 1 bit|
// 	where "idx" is the interrupt source index, "en" enable/disable
// 	interrupts from the interrupt source "idx".
// 	pi1_data_o get set to the interrupt source index, or -1 if invalid.
// An interrupt must be acknowledged as soon as possible so
// that the intctrl can dispatch another interrupt request.

module intctrl (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i /* Not used */
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i  /* Not used */
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqstdst_o
	,intrdydst_i
	,intbestdst_i

	,intrqstsrc_i
	,intrdysrc_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter INTSRCCOUNT = 0;
parameter INTDSTCOUNT = 0;

localparam CLOG2INTSRCCOUNT = clog2(INTSRCCOUNT);
localparam CLOG2INTDSTCOUNT = clog2(INTDSTCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i; /* Not used */
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = {ARCHBITSZ{1'b0}};
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;  /* Not used */
output wire                        pi1_rdy_o;
output wire [ARCHBITSZ -1 : 0]     pi1_mapsz_o;

output wire [INTDSTCOUNT -1 : 0] intrqstdst_o;
input  wire [INTDSTCOUNT -1 : 0] intrdydst_i;
input  wire [INTDSTCOUNT -1 : 0] intbestdst_i;

input  wire [INTSRCCOUNT -1 : 0] intrqstsrc_i;
output wire [INTSRCCOUNT -1 : 0] intrdysrc_o;

assign pi1_rdy_o   = 1; // The output pi1_rdy_o is always 1 because all memory operations complete immediately.

// Actual mapsz is (1*(ARCHBITSZ/8)), but aligning to 64bits.
assign pi1_mapsz_o = (((ARCHBITSZ<64)?(64/ARCHBITSZ):1)*(ARCHBITSZ/8));

// Registers used to index respectively the source and destination of an interrupt.
reg [CLOG2INTSRCCOUNT -1 : 0] srcindex = {CLOG2INTSRCCOUNT{1'b0}};
reg [CLOG2INTDSTCOUNT -1 : 0] dstindex = {CLOG2INTDSTCOUNT{1'b0}};

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDACKINT = 2'b00;
localparam CMDINTDST = 2'b01;
localparam CMDENAINT = 2'b10;

wire ismemreadwriteop = (pi1_op_i == PIRWOP);

wire cmdackint = (ismemreadwriteop && pi1_data_i[1:0] == CMDACKINT);

wire cmdintdst = (ismemreadwriteop && pi1_data_i[1:0] == CMDINTDST);
reg [ARCHBITSZ -1 : 0] cmdintdstdata = {ARCHBITSZ{1'b0}};
wire cmdintdstseeking = (cmdintdstdata[1:0] == CMDINTDST && (dstindex != cmdintdstdata[(CLOG2INTDSTCOUNT +2) -1 : 2]));

wire cmdenaint = (ismemreadwriteop && pi1_data_i[1:0] == CMDENAINT);

// Register set to 1 when an interrupt request from a source is waiting to be acknowledged.
reg intrqstpending = 0;

genvar gen_intrdysrc_o_idx;
generate for (gen_intrdysrc_o_idx = 0; gen_intrdysrc_o_idx < INTSRCCOUNT; gen_intrdysrc_o_idx = gen_intrdysrc_o_idx + 1) begin :gen_intrdysrc_o
// Logic that drives the input intrdy of a source.
assign intrdysrc_o[gen_intrdysrc_o_idx] = !(srcindex == gen_intrdysrc_o_idx && intrqstpending && cmdintdstdata[1:0] != CMDINTDST);
end endgenerate

genvar gen_intrqstdst_o_idx;
generate for (gen_intrqstdst_o_idx = 0; gen_intrqstdst_o_idx < INTDSTCOUNT; gen_intrqstdst_o_idx = gen_intrqstdst_o_idx + 1) begin :gen_intrqstdst_o
// Logic that drives the input intrqst of a destination.
assign intrqstdst_o[gen_intrqstdst_o_idx] = (dstindex == gen_intrqstdst_o_idx && intrqstpending);
end endgenerate

wire [CLOG2INTSRCCOUNT -1 : 0] nextsrcindex =
	((srcindex < (INTSRCCOUNT-1)) ? (srcindex + 1'b1) : {CLOG2INTSRCCOUNT{1'b0}});
wire [CLOG2INTDSTCOUNT -1 : 0] nextdstindex =
	((dstindex < (INTDSTCOUNT-1)) ? (dstindex + 1'b1) : {CLOG2INTDSTCOUNT{1'b0}});

reg [INTSRCCOUNT -1 : 0] intsrcen = {INTSRCCOUNT{1'b0}};
reg [INTDSTCOUNT -1 : 0] intdsten = {INTDSTCOUNT{1'b0}};

always @ (posedge clk_i) begin
	if (rst_i) begin
		intrqstpending <= 1'b0;
		cmdintdstdata <= {ARCHBITSZ{1'b0}};
		intsrcen <= {INTSRCCOUNT{1'b0}};
		intdsten <= {INTDSTCOUNT{1'b0}};
	end else if (cmdenaint) begin
		if (pi1_data_i[ARCHBITSZ -1 : 3] < INTSRCCOUNT) begin
			intsrcen[pi1_data_i[(CLOG2INTSRCCOUNT +3) -1 : 3]] <= pi1_data_i[2];
			pi1_data_o <= {{(ARCHBITSZ-CLOG2INTSRCCOUNT){1'b0}}, pi1_data_i[(CLOG2INTSRCCOUNT +3) -1 : 3]};
		end else
			pi1_data_o <= {ARCHBITSZ{1'b1}};
	end else if (cmdintdst) begin
		if (pi1_data_i[ARCHBITSZ -1 : 2] < INTDSTCOUNT) begin
			if (intrqstpending) begin
				pi1_data_o <= {{(ARCHBITSZ-1){1'b1}}, 1'b0};
			end else begin
				pi1_data_o <= {{(ARCHBITSZ-CLOG2INTDSTCOUNT){1'b0}}, pi1_data_i[(CLOG2INTDSTCOUNT +2) -1 : 2]};
				intrqstpending <= 1'b1;
				cmdintdstdata <= pi1_data_i;
			end
		end else
			pi1_data_o <= {ARCHBITSZ{1'b1}};
	end else if (cmdintdstseeking) begin
		// Keep incrementing dstindex until the targeted interrupt destination is indexed.
		dstindex <= nextdstindex;
	end else if (intrqstpending || cmdackint) begin
		// Logic that acknowledges a triggered interrupt.
		if (cmdackint) begin
			if (pi1_data_i[ARCHBITSZ -1 : 3] == dstindex) begin
				pi1_data_o <= ((cmdintdstdata[1:0] == CMDINTDST) ? {ARCHBITSZ{1'b1}} :
					{{(ARCHBITSZ-CLOG2INTSRCCOUNT){1'b0}}, srcindex});
				intrqstpending <= 1'b0;
				cmdintdstdata <= {ARCHBITSZ{1'b0}};
				dstindex <= {CLOG2INTDSTCOUNT{1'b0}}; /* The destination with the lowest index is always preferred */
				srcindex <= nextsrcindex;
			end else begin
				pi1_data_o <= {{(ARCHBITSZ-1){1'b1}}, 1'b0};
			end
			if (pi1_data_i[ARCHBITSZ -1 : 3] < INTDSTCOUNT)
				intdsten[pi1_data_i[(CLOG2INTDSTCOUNT +3) -1 : 3]] <= pi1_data_i[2];
		end
	end else if (intsrcen[srcindex] && intrqstsrc_i[srcindex]) begin
		// If there is no preferred interrupt destination available
		// and the indexed destination for the interrupt is not
		// ready, I try the next one.
		// If there is a preferred interrupt destination available,
		// dstindex keep incrementing until the preferred interrupt
		// destination is indexed.
		if (intdsten[dstindex] && ((!(intbestdst_i & intdsten) && intrdydst_i[dstindex]) || intbestdst_i[dstindex]))
			intrqstpending <= 1'b1;
		else
			dstindex <= nextdstindex;
	// I check the next interrupt source if there is no request on the current interrupt source.
	end else
		srcindex <= nextsrcindex;
end

endmodule
