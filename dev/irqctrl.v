// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Interrupt controller peripheral.
// It dispatches an interrupt to a destination
// for which its irq_rdy_o is high, iterating in
// a round-robin fashion through each destination.
// Preference is given to destination driving
// intbest high.

// Parameters:
//
// IRQDSTCOUNT
// 	Number of interrupt destination.
// 	It must be non-null and less than ((1<<(ARCHBITSZ-5))-2).
//
// IRQSRCCOUNT
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
// wb_mapsz_o
// 	Memory map size in bytes.
//
// irq_dst_stb_o
// irq_dst_rdy_i
// irq_dst_pri_i
// 	Destination interrupt signals.
// 	irq_dst_stb_o is raised to request an interrupt from the destination.
// 	The destination drives irq_dst_rdy_i high when it is ready to take
// 	on a requested interrupt; it keeps irq_dst_pri_i low when it wouldn't
// 	be the best choice to service the interrupt; irq_dst_pri_i is used
// 	in a multi-pu system where it is driven by PUs output "halted_o"
// 	in order to give a preference to PUs that are halted when looking
// 	for an interrupt destination.
// 	The destination with the lowest index is always preferred.
//
// irq_src_stb_i
// irq_src_rdy_o
// 	Source interrupt signals.
// 	irq_src_stb_i is high to request an interrupt, and irq_src_rdy_o
// 	is driven low when the requested interrupt is being acknowledged.
// 	The source device must drive irq_src_stb_i low as soon as a falling edge
// 	of irq_src_rdy_o occurs, otherwise another interrupt request will occur
// 	when irq_src_rdy_o has become high and irq_src_stb_i is still high.
//
// Commands are sent to the controller writing to it with the
// following expected format | arg: (ARCHBITSZ-2) bits | cmd: 2 bit |
// where the field "cmd" values are CMDDEVRDY(2'b00), CMDACKIRQ(2'b01),
// CMDINTDST(2'b10) and CMDENAIRQ(2'b11). The result of a previously
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
// 	CMDACKIRQ: Acknowledges an interrupt source; field "arg" is expected
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
// 	CMDENAIRQ: Enable/Disable an interrupt source; field "arg" is expected
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
// that the irqctrl can dispatch another interrupt request.

module irqctrl (

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
	,wb_mapsz_o

	,irq_dst_stb_o
	,irq_dst_rdy_i
	,irq_dst_pri_i

	,irq_src_stb_i
	,irq_src_rdy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter IRQSRCCOUNT = 0;
parameter IRQDSTCOUNT = 0;

localparam CLOG2IRQSRCCOUNT = clog2(IRQSRCCOUNT);
localparam CLOG2IRQDSTCOUNT = clog2(IRQDSTCOUNT);

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
output wire [ARCHBITSZ -1 : 0]     wb_mapsz_o;

output wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_o;
input  wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_i;
input  wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_i;

input  wire [IRQSRCCOUNT -1 : 0] irq_src_stb_i;
output wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_o;

assign wb_bsy_o = 1'b0;

// Actual mmapsz is (1*(ARCHBITSZ/8)), but aligning to 64bits.
assign wb_mapsz_o = (((ARCHBITSZ<64)?(64/ARCHBITSZ):1)*(ARCHBITSZ/8));

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
reg [CLOG2IRQSRCCOUNT -1 : 0] srcidx;
reg [CLOG2IRQDSTCOUNT -1 : 0] dstidx;

localparam CMDDEVRDY = 2'b00;
localparam CMDACKIRQ = 2'b01;
localparam CMDINTDST = 2'b10;
localparam CMDENAIRQ = 2'b11;

wire prevcmdisdevrdy = (wb_dat_o[1:0] == CMDDEVRDY);

wire prevcmddone = (!rst_i && wb_stb_r && wb_we_r && prevcmdisdevrdy);

wire cmddevrdy = (!rst_i && wb_stb_r && wb_we_r && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdackirq = (prevcmddone && wb_dat_r[1:0] == CMDACKIRQ);
wire cmdintdst = (prevcmddone && wb_dat_r[1:0] == CMDINTDST);
wire cmdenairq = (prevcmddone && wb_dat_r[1:0] == CMDENAIRQ);

reg [ARCHBITSZ -1 : 0] irqdstdat;
wire irqdstseek = (
	irqdstdat[1:0] == CMDINTDST &&
	dstidx != irqdstdat[(CLOG2IRQDSTCOUNT +2) -1 : 2]);

reg irqpending; /* set to 1 when an interrupt request is waiting to be acknowledged */

genvar gen_irq_src_rdy_o_idx;
generate for ( // Logic that drives the irq_rdy_i of a source.
	gen_irq_src_rdy_o_idx = 0;
	gen_irq_src_rdy_o_idx < IRQSRCCOUNT;
	gen_irq_src_rdy_o_idx = gen_irq_src_rdy_o_idx + 1) begin :gen_irq_src_rdy_o
	assign irq_src_rdy_o[gen_irq_src_rdy_o_idx] = (
		srcidx != gen_irq_src_rdy_o_idx || !irqpending || irqdstdat[1:0] == CMDINTDST);
end endgenerate

genvar gen_irq_dst_stb_o_idx;
generate for ( // Logic that drives the irq_stb_i of a destination.
	gen_irq_dst_stb_o_idx = 0;
	gen_irq_dst_stb_o_idx < IRQDSTCOUNT;
	gen_irq_dst_stb_o_idx = gen_irq_dst_stb_o_idx + 1) begin :gen_irq_dst_stb_o
	assign irq_dst_stb_o[gen_irq_dst_stb_o_idx] = (
		dstidx == gen_irq_dst_stb_o_idx && irqpending && !irqdstseek &&
		// Raise irq_stb_i only when the controller is ready for the next command,
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

always @ (posedge clk_i) begin
	if (rst_i) begin
		wb_dat_o <= {ARCHBITSZ{1'b0}};
		srcidx <= {CLOG2IRQSRCCOUNT{1'b0}};
		dstidx <= {CLOG2IRQDSTCOUNT{1'b0}};
		irqpending <= 1'b0;
		irqdstdat <= {ARCHBITSZ{1'b0}};
		irqsrcen <= {IRQSRCCOUNT{1'b0}};
		irqdsten <= {IRQDSTCOUNT{1'b0}};
	end else if (cmddevrdy) begin
		wb_dat_o <= {ARCHBITSZ{1'b0}};
	end else if (cmdenairq) begin
		if (wb_dat_r[ARCHBITSZ -1 : 3] < IRQSRCCOUNT) begin
			irqsrcen[wb_dat_r[(CLOG2IRQSRCCOUNT +3) -1 : 3]] <= wb_dat_r[2];
			wb_dat_o <= {
				{((ARCHBITSZ-2)-CLOG2IRQSRCCOUNT){1'b0}},
				wb_dat_r[(CLOG2IRQSRCCOUNT +3) -1 : 3],
				wb_dat_r[1:0]};
		end else
			wb_dat_o <= {{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]};
	end else if (cmdintdst) begin
		if (wb_dat_r[ARCHBITSZ -1 : 2] < IRQDSTCOUNT) begin
			if (irqpending) begin
				wb_dat_o <= {{(ARCHBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
			end else begin
				wb_dat_o <= {
					{((ARCHBITSZ-2)-CLOG2IRQDSTCOUNT){1'b0}},
					wb_dat_r[(CLOG2IRQDSTCOUNT +2) -1 : 2],
					wb_dat_r[1:0]};
				irqpending <= 1'b1;
				irqdstdat <= wb_dat_r;
			end
		end else
			wb_dat_o <= {{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]};
	end else if (irqdstseek) begin
		// Keep incrementing dstidx until the targeted interrupt destination is indexed.
		dstidx <= nextdstidx;
	end else if (irqpending || cmdackirq) begin
		// Logic that acknowledges a triggered interrupt.
		if (cmdackirq) begin
			if (wb_dat_r[ARCHBITSZ -1 : 3] == dstidx) begin
				wb_dat_o <= ((irqdstdat[1:0] == CMDINTDST) ?
					{{(ARCHBITSZ-2){1'b1}}, wb_dat_r[1:0]} :
					{{((ARCHBITSZ-2)-CLOG2IRQSRCCOUNT){1'b0}}, srcidx, wb_dat_r[1:0]});
				irqpending <= 1'b0;
				irqdstdat <= {ARCHBITSZ{1'b0}};
				// The destination with the lowest index is always preferred.
				dstidx <= {CLOG2IRQDSTCOUNT{1'b0}};
				srcidx <= nextsrcidx;
			end else begin
				wb_dat_o <= {{(ARCHBITSZ-3){1'b1}}, 1'b0, wb_dat_r[1:0]};
			end
			if (wb_dat_r[ARCHBITSZ -1 : 3] < IRQDSTCOUNT)
				irqdsten[wb_dat_r[(CLOG2IRQDSTCOUNT +3) -1 : 3]] <= wb_dat_r[2];
		end
	end else if (irqsrcen[srcidx] && irq_src_stb_i[srcidx]) begin
		// If there is no preferred interrupt destination available
		// and the indexed destination for the interrupt is not
		// ready, I try the next one.
		// If there is a preferred interrupt destination available,
		// dstidx keeps incrementing until the preferred interrupt
		// destination is indexed.
		if (irqdsten[dstidx] &&
			((!(irq_dst_pri_i & irqdsten) && irq_dst_rdy_i[dstidx]) ||
				irq_dst_pri_i[dstidx])) begin
			// Only when the controller is ready for the next command,
			// since irq_stb_i is raised only then.
			if (prevcmdisdevrdy)
				irqpending <= 1'b1;
		end else
			dstidx <= nextdstidx;
	// I check the next interrupt source if there is no request on the current interrupt source.
	end else
		srcidx <= nextsrcidx;
end

endmodule
