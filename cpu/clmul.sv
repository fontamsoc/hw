// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Carry-less multiply (RISC-V Zbc: clmul/clmulh/clmulr). The carry-less product has no
// carry chains, so the full product is a combinational AND/XOR tree; this is a 2-cycle
// register-isolated unit (mirroring imul's PUIMULDSP): cycle 1 captures the operands,
// cycle 2 pushes the requested slice of the product into the result fifo, while a new
// carry-less multiply is accepted. See the note at end of file.

`include "lib/fifo_fwft.sv"

module clmul (

	 rst_i

	,clk_i

	,stb_i

	,args_i
	,rslt_o
	,gprid_o

	,rdy_o

	,ostb_i
	,ordy_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter GPRCNT    = 32;

localparam CLOG2GPRCNT    = clog2(GPRCNT);

// Significance of the type field within args_i; it is iD_func3[1:0]:
//   2'b01 clmul  (low word  P[WORDBITSZ-1:0]),
//   2'b11 clmulh (high word P[(2*WORDBITSZ)-1:WORDBITSZ]),
//   2'b10 clmulr (reversed  P[(2*WORDBITSZ)-2:WORDBITSZ-1]).
localparam CLMULTYPEBITSZ = 2;
localparam CLMULTYPELSB   = ((WORDBITSZ*2)+CLOG2GPRCNT);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of carry-less multiply to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first (rs1) and second (rs2) operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ) -1 : 0] args_i;

// Net set to the result of the carry-less multiply (the requested product slice).
output wire [WORDBITSZ -1 : 0] rslt_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Result handshake. ordy_o is high while a completed result sits at the head of
// the result fifo, and ostb_i retires it. It is kept separate from rdy_o, which
// means "another carry-less multiply can be accepted", not "the unit is idle".
input wire ostb_i;

output wire ordy_o;

// Carry-less multiply with pipelined acceptance: a new carry-less multiply is
// captured while the one before it is still crossing the XOR tree. What tracks
// whether the operand register holds one is a valid pipe (vld_r), and completed
// products land in a result fifo, which insures a completed result is not
// overwritten by the one behind it while the WriteBack arbiter has not yet
// granted it.

// The operand capture register; the XOR tree that follows it is combinational,
// hence a single stage.
localparam CLMULPPLNSTAGES = 1;

// rdy_o is a register, hence the accept, and with it the operand register's
// clock-enable, is the same (rdy_o && stb_i) product it already was.
wire accept_w = (rdy_o && stb_i);

// Reg used to capture args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ) -1 : 0] operands;

// operands is the tag pipe as much as it is the operand pipe. imul carries its
// result-half select and destination gpr id in a tag pipe of their own, because
// its operand registers must feed only the multiply so that synthesis absorbs
// them into the DSP input registers, and because its pipe is up to three stages
// deep, ie: deeper than any one holding register can track. Neither applies
// here: the XOR tree is fabric logic that no primitive absorbs, and with
// CLMULPPLNSTAGES == 1 a one-deep holding register IS the pipe; splitting it
// would spend the same flip-flops in two clock-enable groups instead of one.
// That equivalence is exactly what CLMULPPLNSTAGES == 1 buys: were the tree
// ever split across a second register stage, a tag pipe must come back with it,
// else a younger accept overwrites an older one's optype and gprid before they
// are pushed; the generate below fails elaboration so that cannot go unnoticed.
wire [CLMULTYPEBITSZ -1 : 0] optype  = operands[CLMULTYPELSB +: CLMULTYPEBITSZ];
wire [CLOG2GPRCNT   -1 : 0] gprid_w = operands[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2];

generate if (CLMULPPLNSTAGES != 1) begin :gen_stages_needs_tag_pipe
clmulPplnStagesRequiresTagPipe u ();
end endgenerate

// Valid pipe; high means the full product of the carry-less multiply held in
// operands is on cumulator, ie: it is the push into the result fifo.
reg [CLMULPPLNSTAGES -1 : 0] vld_r;

// The carry-less product has NO carry chains, so the full 2*WORDBITSZ-bit product is a shallow
// AND/XOR tree, computed in the cycle that follows the operand capture.
function automatic [(WORDBITSZ*2) -1 : 0] clmulFull (
		input [WORDBITSZ -1 : 0] a, input [WORDBITSZ -1 : 0] b);
	integer i;
	reg [(WORDBITSZ*2) -1 : 0] p;
	begin
		p = {(WORDBITSZ*2){1'b0}};
		for (i = 0; i < WORDBITSZ; i = i + 1)
			p = p ^ (b[i] ? ({{WORDBITSZ{1'b0}}, a} << i) : {(WORDBITSZ*2){1'b0}});
		clmulFull = p;
	end
endfunction
// Full product P from the registered operands (rs1 in the high half, rs2 in the low half).
// P spans bits [(2*WORDBITSZ)-2:0]; bit [(2*WORDBITSZ)-1] stays 0.
wire [(WORDBITSZ*2) -1 : 0] cumulator = clmulFull(
	operands[(WORDBITSZ*2)-1:WORDBITSZ], operands[WORDBITSZ-1:0]);

// The requested slice of P, muxed on the push side of the result fifo, as imul
// muxes its result half there, so that what the WriteBack arbiter sees is the
// fifo head and nothing else. The default arm is not a catch-all for
// unreachable values: iF_isZbc admits iD_func3[1:0] == 2'b00, a reserved
// encoding that the decode does not trap, hence a case with a default and not a
// unique case, so that RTL and gates keep agreeing on it.
reg [WORDBITSZ -1 : 0] rslt_i; // ### comb-block-reg.
always_comb begin
	case (optype)
	2'b11:   rslt_i = cumulator[(WORDBITSZ*2)-1 : WORDBITSZ];   // clmulh: P[2n-1:n]
	2'b10:   rslt_i = cumulator[(WORDBITSZ*2)-2 : WORDBITSZ-1]; // clmulr: P[2n-2:n-1]
	default: rslt_i = cumulator[WORDBITSZ-1 : 0];               // clmul : P[n-1:0]
	endcase
end

// Result fifo. One deeper than the pipe is exactly what the acceptance rule
// admits: at most CLMULFIFODEPTH carry-less multiplies are accepted-and-unretired
// at once, and every one of them can be a fifo entry once the pipe drains, ie:
// the fifo can fill but never overflow.
localparam CLMULFIFODEPTH      = (CLMULPPLNSTAGES + 1);
localparam CLOG2CLMULFIFODEPTH = clog2(CLMULFIFODEPTH);

wire fifoPush_w = vld_r[CLMULPPLNSTAGES-1];
wire fifoPop_w  = (ordy_o && ostb_i);

// Carry-less multiplies accepted and not yet retired, ie: held in operands plus
// queued in the fifo; keeping it at or below CLMULFIFODEPTH is what insures the
// fifo cannot overflow, hence it is what rdy_o is derived from.
reg [(CLOG2CLMULFIFODEPTH +1) -1 : 0] usage_r;

// Feeds usage_r, and with it rdy_o, on the next clockedge.
wire [(CLOG2CLMULFIFODEPTH +1) -1 : 0] usage_i =
	((accept_w == fifoPop_w) ? usage_r :
		(accept_w ? (usage_r + 1'b1) : (usage_r - 1'b1)));

wire fifoEmpty_w;
wire fifoFull_w;

// The result fifo is a fwft fifo: its data_o presents the head combinationally
// off its registered indices, which is what the WriteBack arbiter's same-cycle
// grant needs, and the shape the load unit's ldUnit_rqsts already puts on this
// cone.
fifo_fwft #(
	 .WIDTH (WORDBITSZ + CLOG2GPRCNT)
	,.DEPTH (CLMULFIFODEPTH)
) rsltfifo (
	 .rst_i      (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (fifoPush_w)
	,.data_i     ({rslt_i, gprid_w})
	,.full_o     (fifoFull_w)
	,.clk_pop_i  (clk_i)
	,.pop_i      (fifoPop_w)
	,.data_o     ({rslt_o, gprid_o})
	,.empty_o    (fifoEmpty_w)
);

// A function of the fifo's registered indices alone; like rdy_o below it reads
// neither stb_i nor ostb_i combinationally, which is what insures no
// combinational loop back through iD_stalled, nor through excTriggered.
assign ordy_o = !fifoEmpty_w;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		rdy_o   <= 1;
		vld_r   <= 0;
		usage_r <= 0;
	end else begin
		// A new capture and the push of the product of the capture it replaces
		// land on the same clockedge; the fifo takes the value the XOR tree has
		// from the pre-edge operands, ie: from the carry-less multiply being
		// replaced, as follow from nonblocking assignment.
		if (accept_w)
			operands <= args_i;
		vld_r   <= accept_w;
		usage_r <= usage_i;
		// Set from the credit count the next cycle will see, hence exact and yet
		// a single register on the issue-stall cone. rdy_o falls only when
		// accepting one more carry-less multiply could overflow the result fifo,
		// ie: it stays high while one is computing and results are draining.
		rdy_o <= (usage_i != CLMULFIFODEPTH);
	end
end

`ifdef SIMULATION
// The fifo depth is derived from the acceptance rule, not enforced here: a push while
// full is silently refused by the fifo (its write-enable gates on full_o), dropping a
// completed carry-less multiply, whose gpr is then never unlocked by the WriteBack, and
// the hart spins forever on an operand that never becomes ready, ie: a run that gets
// killed rather than reaching $finish, which is exactly when an unflushed report is lost.
// A retirement strobed with no result held is reported for the mirror-image reason: it
// would mean opclmul granted a retirement to an instance it was not presenting, ie:
// results retiring out of the order they were dispatched in, which the scoreboard cannot
// catch because a carry-less multiply cannot have two producers of the same gpr in
// flight. Each is reported once, as the condition that caused it repeats for as long as
// it lasts.
reg fifoOvfl_r;
reg fifoUndf_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		fifoOvfl_r <= 1'b0;
		fifoUndf_r <= 1'b0;
	end else begin
		if (fifoPush_w && fifoFull_w && !fifoOvfl_r) begin
			fifoOvfl_r <= 1'b1;
			$display("%m: error: result fifo overflow: a carry-less multiply result was dropped");
			$fflush();
		end
		if (ostb_i && !ordy_o && !fifoUndf_r) begin
			fifoUndf_r <= 1'b1;
			$display("%m: error: retirement strobed with no result held");
			$fflush();
		end
	end
end
`endif

endmodule

module opclmul (

	 rst_i

	,clk_i

	,stb_i
	,args_i
	,rdy_o

	,ostb_i
	,rslt_o
	,gprid_o
	,ordy_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter GPRCNT    = 32;
parameter INSTCNT   = 1;

localparam CLOG2GPRCNT = clog2(GPRCNT);

localparam CLMULTYPEBITSZ = 2;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ) -1 : 0] args_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the carry-less multiply.
output wire [WORDBITSZ -1 : 0] rslt_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2INSTCNT +1) -1 : 0] wridx;
reg [(CLOG2INSTCNT +1) -1 : 0] rdidx;

wire [(CLOG2INSTCNT +1) -1 : 0] _wridx = ((INSTCNT-1) ? wridx : 0);
wire [(CLOG2INSTCNT +1) -1 : 0] _rdidx = ((INSTCNT-1) ? rdidx : 0);

wire [WORDBITSZ -1 : 0] data_w [INSTCNT -1 : 0];
assign rslt_o = data_w[_rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [INSTCNT -1 : 0];
assign gprid_o = gprid_w[_rdidx];

wire [INSTCNT -1 : 0] rdy_w;

// Each clmul instance pipelines acceptance and queues its completed results,
// hence backpressure is per-instance and there is nothing left for the wrapper
// to cap: rdy_w[] means "this instance can accept another carry-less multiply"
// and ordy_w[] means "this instance has a completed result to retire". The
// (usage < INSTCNT) cap they replace existed only to protect each instance's
// single held rslt_o, which the result fifo replaces, and the (usage != 0)
// term existed only because rdy_w doubled as "a result is held", which an
// instance that was never dispatched to also reported. wridx/rdidx keep their
// width and their strict rotation, which is what insures results retire in the
// order they were dispatched: instance i takes every carry-less multiply whose
// wridx is i modulo INSTCNT, each instance's fifo is in order, and rdidx walks
// the same rotation. rdy_o must therefore not skip a busy instance for a free
// one. The counters are rotation-only: at full occupancy (INSTCNT times the
// fifo depth accepted-and-unretired) their difference wraps to exactly 0, ie:
// it aliases empty and must never be re-read as an occupancy.
wire [INSTCNT -1 : 0] ordy_w;

assign rdy_o = rdy_w[_wridx];

assign ordy_o = ordy_w[_rdidx];

always_ff @(posedge clk_i) begin
	if (rst_i)
		wridx <= 0;
	else if (rdy_o && stb_i)
		wridx <= (wridx + 1'b1);
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		rdidx <= 0;
	else if (ordy_o && ostb_i)
		rdidx <= (rdidx + 1'b1);
end

genvar gen_clmul_idx;
generate for (gen_clmul_idx = 0; gen_clmul_idx < INSTCNT; gen_clmul_idx = gen_clmul_idx + 1) begin :gen_clmul
clmul #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
) clmul (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (stb_i && (_wridx[CLOG2INSTCNT -1 : 0] == gen_clmul_idx))

	,.args_i  (args_i)
	,.rslt_o  (data_w[gen_clmul_idx])
	,.gprid_o (gprid_w[gen_clmul_idx])

	,.rdy_o (rdy_w[gen_clmul_idx])

	// Retirement is routed to the instance rdidx points at, mirroring the
	// dispatch fanout above; the same implicit truncation to CLOG2INSTCNT
	// bits gives the mod-INSTCNT rotation.
	,.ostb_i (ostb_i && (_rdidx[CLOG2INSTCNT -1 : 0] == gen_clmul_idx))
	,.ordy_o (ordy_w[gen_clmul_idx])
);
end endgenerate

endmodule

// Carry-less multiply: like binary multiply but partial products are combined with
// XOR instead of addition (no carries). The full 2*WORDBITSZ-bit product is
//   P = XOR over i in [0,WORDBITSZ) of (rs2[i] ? (rs1 << i) : 0).
// RISC-V Zbc returns slices of P:
//   clmul  rd = P[WORDBITSZ-1:0]            (low word)
//   clmulh rd = P[(2*WORDBITSZ)-1:WORDBITSZ] (high word)
//   clmulr rd = P[(2*WORDBITSZ)-2:WORDBITSZ-1] (reversed: rev(clmul(rev(a),rev(b)))).
// Computed here as one combinational AND/XOR tree (no carry chains), registered as a
// 2-cycle unit whose acceptance is pipelined; see the head of this file.
