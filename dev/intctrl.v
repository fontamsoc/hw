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
// 	It must be non-null and less than ((1<<(ARCHBITSZ-5))-2).
//
// INTSRCCOUNT
// 	Number of interrupt source.
// 	It must be non-null and less than ((1<<(ARCHBITSZ-5))-2).

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
// wb_cyc_i
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
// mmapsz_o
// 	Memory map size in bytes.
//
// intrqstdst_o
// intrdydst_i
// intbestdst_i
// 	Destination interrupt signals.
// 	intrqst is raised to request an interrupt from the destination.
// 	The destination drives intrdy high when it is ready to take
// 	on a requested interrupt; it keeps intbest low when it wouldn't
// 	be the best choice to service the interrupt; intbest is used
// 	in a multi-pu system where it is driven by PUs output "halted_o"
// 	in order to give a preference to PUs that are halted when looking
// 	for an interrupt destination.
// 	The destination with the lowest index is always preferred.
//
// intrqstsrc_i
// intrdysrc_o
// 	Source interrupt signals.
// 	intrqst is high to request an interrupt, and intrdy is driven
// 	low when the requested interrupt is being acknowledged.
// 	The source device must drive intrqst low as soon as a falling edge
// 	of intrdy occurs, otherwise another interrupt request will occur
// 	when intrdy has become high and intrqst is still high.
//
// Commands are sent to the controller writing to it with the
// following expected format | arg: (ARCHBITSZ-2) bits | cmd: 2 bit |
// where the field "cmd" values are CMDDEVRDY(2'b00), CMDACKINT(2'b01),
// CMDINTDST(2'b10) and CMDENAINT(2'b11). The result of a previously
// sent command is retrieved from the controller reading from it and
// has the following format | resp: (ARCHBITSZ-2) bits | cmd: 2 bit |,
// where the fields "cmd" and "resp" are the command and its result.
// Two memory operations, a write followed by a read are needed to send
// a command to the controller and retrieve its result.
// The controller has accepted a command only if "cmd" in its result
// is CMDDEVRDY, otherwise sending the command CMDDEVRDY is needed.
//
// The description of commands is as follow:
// 	CMDDEVRDY: Make the controller accept a new command.
// 	"resp" in the result get set to 0.
// 	CMDACKINT: Acknowledges an interrupt source; field "arg" is expected
// 	to have following format | idx: (ARCHBITSZ-3) bits | en: 1 bit |
// 	where "idx" is the interrupt destination index, "en" enable/disable
// 	further interrupt delivery to the interrupt destination "idx".
// 	"resp" in the result get set to the interrupt source index, or -2
// 	if there are no pending interrupt for the destination "idx", or -1
// 	for an interrupt triggered by CMDINTDST.
// 	CMDINTDST: Triggers an interrupt targeting a specific destination;
// 	the field "arg" is the index of the interrupt destination to target,
// 	while "resp" in the result get set to the interrupt destination index
// 	if valid, -2 if not ready due to an interrupt pending ack, or -1 if invalid.
// 	CMDENAINT: Enable/Disable an interrupt source; field "arg" is expected
// 	to have following format | idx: (ARCHBITSZ-3) bits | en: 1 bit|
// 	where "idx" is the interrupt source index, "en" enable/disable
// 	interrupts from the interrupt source "idx".
// 	"resp" in the result get set to the interrupt source index, or -1
// 	if invalid.
//
// To be multi core proof, an atomic read-write must be used to send
// a command to the controller until CMDDEVRDY is returned, then another
// atomic read-write sending CMDDEVRDY must be used to retrieve the
// result while making the controller ready for the next command.
//
// An interrupt must be acknowledged as soon as possible so
// that the intctrl can dispatch another interrupt request.

module intctrl (

	 rst_i

	,clk_i

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,mmapsz_o

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

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output reg  [ARCHBITSZ -1 : 0]     wb_dat_o;

output wire [ARCHBITSZ -1 : 0] mmapsz_o;

output wire [INTDSTCOUNT -1 : 0] intrqstdst_o;
input  wire [INTDSTCOUNT -1 : 0] intrdydst_i;
input  wire [INTDSTCOUNT -1 : 0] intbestdst_i;

input  wire [INTSRCCOUNT -1 : 0] intrqstsrc_i;
output wire [INTSRCCOUNT -1 : 0] intrdysrc_o;

assign wb_bsy_o = 1'b0;

// Actual mmapsz is (1*(ARCHBITSZ/8)), but aligning to 64bits.
assign mmapsz_o = (((ARCHBITSZ<64)?(64/ARCHBITSZ):1)*(ARCHBITSZ/8));

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ARCHBITSZ -1 : 0] wb_dat_r;

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

// Registers used to index respectively the source and destination of an interrupt.
reg [CLOG2INTSRCCOUNT -1 : 0] srcidx;
reg [CLOG2INTDSTCOUNT -1 : 0] dstidx;

localparam CMDDEVRDY = 2'b00;
localparam CMDACKINT = 2'b01;
localparam CMDINTDST = 2'b10;
localparam CMDENAINT = 2'b11;

wire prevcmdisdevrdy = (wb_dat_o[1:0] == CMDDEVRDY);

wire prevcmddone = (!rst_i && wb_stb_r && wb_we_r && prevcmdisdevrdy);

wire cmddevrdy = (!rst_i && wb_stb_r && wb_we_r && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdackint = (prevcmddone && wb_dat_r[1:0] == CMDACKINT);
wire cmdintdst = (prevcmddone && wb_dat_r[1:0] == CMDINTDST);
wire cmdenaint = (prevcmddone && wb_dat_r[1:0] == CMDENAINT);

reg [ARCHBITSZ -1 : 0] intdstdat;
wire intdstseek = (
	intdstdat[1:0] == CMDINTDST &&
	dstidx != intdstdat[(CLOG2INTDSTCOUNT +2) -1 : 2]);

reg intrqstpend; /* set to 1 when an interrupt request is waiting to be acknowledged */

genvar gen_intrdysrc_o_idx;
generate for ( // Logic that drives the input intrdy of a source.
	gen_intrdysrc_o_idx = 0;
	gen_intrdysrc_o_idx < INTSRCCOUNT;
	gen_intrdysrc_o_idx = gen_intrdysrc_o_idx + 1) begin :gen_intrdysrc_o
	assign intrdysrc_o[gen_intrdysrc_o_idx] = (
		srcidx != gen_intrdysrc_o_idx || !intrqstpend || intdstdat[1:0] == CMDINTDST);
end endgenerate

genvar gen_intrqstdst_o_idx;
generate for ( // Logic that drives the input intrqst of a destination.
	gen_intrqstdst_o_idx = 0;
	gen_intrqstdst_o_idx < INTDSTCOUNT;
	gen_intrqstdst_o_idx = gen_intrqstdst_o_idx + 1) begin :gen_intrqstdst_o
	assign intrqstdst_o[gen_intrqstdst_o_idx] = (
		dstidx == gen_intrqstdst_o_idx && intrqstpend && !intdstseek &&
		// Raise intrqst only when the controller is ready for the next command,
		// otherwise an interrupt would cause software to send the controller a new
		// command while it is not ready, waiting indefinitely for it to be ready.
		prevcmdisdevrdy);
end endgenerate

wire [CLOG2INTSRCCOUNT -1 : 0] nextsrcidx =
	((srcidx < (INTSRCCOUNT-1)) ? (srcidx + 1'b1) : {CLOG2INTSRCCOUNT{1'b0}});
wire [CLOG2INTDSTCOUNT -1 : 0] nextdstidx =
	((dstidx < (INTDSTCOUNT-1)) ? (dstidx + 1'b1) : {CLOG2INTDSTCOUNT{1'b0}});

reg [INTSRCCOUNT -1 : 0] intsrcen;
reg [INTDSTCOUNT -1 : 0] intdsten;

always @ (posedge clk_i) begin
	if (rst_i) begin
		wb_dat_o <= {ARCHBITSZ{1'b0}};
		srcidx <= {CLOG2INTSRCCOUNT{1'b0}};
		dstidx <= {CLOG2INTDSTCOUNT{1'b0}};
		intrqstpend <= 1'b0;
		intdstdat <= {ARCHBITSZ{1'b0}};
		intsrcen <= {INTSRCCOUNT{1'b0}};
		intdsten <= {INTDSTCOUNT{1'b0}};
	end else if (cmddevrdy) begin
		wb_dat_o <= {ARCHBITSZ{1'b0}};
	end else if (cmdenaint) begin
		if (wb_dat_r[ARCHBITSZ -1 : 3] < INTSRCCOUNT) begin
			intsrcen[wb_dat_r[(CLOG2INTSRCCOUNT +3) -1 : 3]] <= wb_dat_r[2];
			wb_dat_o <= {
				{((ARCHBITSZ-2)-CLOG2INTSRCCOUNT){1'b0}},
				wb_dat_r[(CLOG2INTSRCCOUNT +3) -1 : 3],
				wb_dat_r[1:0]};
		end else
			wb_dat_o <= {{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]};
	end else if (cmdintdst) begin
		if (wb_dat_r[ARCHBITSZ -1 : 2] < INTDSTCOUNT) begin
			if (intrqstpend) begin
				wb_dat_o <= {{(ARCHBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
			end else begin
				wb_dat_o <= {
					{((ARCHBITSZ-2)-CLOG2INTDSTCOUNT){1'b0}},
					wb_dat_r[(CLOG2INTDSTCOUNT +2) -1 : 2],
					wb_dat_r[1:0]};
				intrqstpend <= 1'b1;
				intdstdat <= wb_dat_r;
			end
		end else
			wb_dat_o <= {{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]};
	end else if (intdstseek) begin
		// Keep incrementing dstidx until the targeted interrupt destination is indexed.
		dstidx <= nextdstidx;
	end else if (intrqstpend || cmdackint) begin
		// Logic that acknowledges a triggered interrupt.
		if (cmdackint) begin
			if (wb_dat_r[ARCHBITSZ -1 : 3] == dstidx) begin
				wb_dat_o <= ((intdstdat[1:0] == CMDINTDST) ?
					{{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]} :
					{{((ARCHBITSZ-2)-CLOG2INTSRCCOUNT){1'b0}}, srcidx, wb_dat_r[1:0]});
				intrqstpend <= 1'b0;
				intdstdat <= {ARCHBITSZ{1'b0}};
				// The destination with the lowest index is always preferred.
				dstidx <= {CLOG2INTDSTCOUNT{1'b0}};
				srcidx <= nextsrcidx;
			end else begin
				wb_dat_o <= {{(ARCHBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
			end
			if (wb_dat_r[ARCHBITSZ -1 : 3] < INTDSTCOUNT)
				intdsten[wb_dat_r[(CLOG2INTDSTCOUNT +3) -1 : 3]] <= wb_dat_r[2];
		end
	end else if (intsrcen[srcidx] && intrqstsrc_i[srcidx]) begin
		// If there is no preferred interrupt destination available
		// and the indexed destination for the interrupt is not
		// ready, I try the next one.
		// If there is a preferred interrupt destination available,
		// dstidx keeps incrementing until the preferred interrupt
		// destination is indexed.
		if (intdsten[dstidx] &&
			((!(intbestdst_i & intdsten) && intrdydst_i[dstidx]) ||
				intbestdst_i[dstidx])) begin
			// Only when the controller is ready for the next command,
			// since intrqst is raised only then.
			if (prevcmdisdevrdy)
				intrqstpend <= 1'b1;
		end else
			dstidx <= nextdstidx;
	// I check the next interrupt source if there is no request on the current interrupt source.
	end else
		srcidx <= nextsrcidx;
end

endmodule
