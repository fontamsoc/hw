// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifdef PUIMULDSP

`include "lib/fifo_fwft.sv"

module imul (

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

localparam CLOG2WORDBITSZ = clog2(WORDBITSZ);
localparam CLOG2GPRCNT    = clog2(GPRCNT);

// Significance of each bit in the field within
// args_i storing the type of multiplication to perform.
// [2]: 0/1 means always treat the left operand as signed.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means WORDBITSZ lsb/msb of result.
localparam IMULTYPEBITSZ = 3;
localparam IMULMSBRSLT   = ((WORDBITSZ*2)+CLOG2GPRCNT);
localparam IMULSIGNED    = ((WORDBITSZ*2)+CLOG2GPRCNT+1);
localparam IMULLVALSIGND = ((WORDBITSZ*2)+CLOG2GPRCNT+2);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] args_i;

// Net set to the result of the multiplication.
output wire [WORDBITSZ -1 : 0] rslt_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Result handshake. ordy_o is high while a completed result sits at the head of
// the result fifo, and ostb_i retires it. It is kept separate from rdy_o, which
// means "another multiply can be accepted", not "the unit is idle".
input wire ostb_i;

output wire ordy_o;

// DSP multiply with pipelined acceptance: a new multiply is captured while
// earlier ones are still in flight. The sign-extension is folded into the
// operand capture, so nothing combinational sits between args_i and the DSP
// input registers; what tracks which pipeline registers hold a multiply is a
// valid pipe (vld_r) and a tag pipe (tag_r) marching alongside in fabric, and
// completed products land in a result fifo, which insures a completed result
// is not overwritten by the ones behind it while the WriteBack arbiter has not
// yet granted it. Under PUIMULDSPREG the product also traverses two
// free-running registers (prod_r/prod_rr) that synthesis absorbs into the DSP
// MREG/PREG, as it absorbs opa_r/opb_r into the DSP input registers, so
// nothing combinational separates a register from the multiplier; two more
// cycles per multiply, and a correspondingly deeper valid/tag pipe and fifo.

reg signed [WORDBITSZ:0] opa_r; // Feeds only the multiply.
reg signed [WORDBITSZ:0] opb_r; // Feeds only the multiply.
wire [(WORDBITSZ*2) -1 : 0] prod_w = (opa_r * opb_r);
`ifdef PUIMULDSPREG
// Free-running product registers (no clock-enable) so that they absorb
// cleanly into the DSP; vld_r paces when prod_rr is valid.
reg [(WORDBITSZ*2) -1 : 0] prod_r;
reg [(WORDBITSZ*2) -1 : 0] prod_rr;

localparam IMULPPLNSTAGES = 3;
`else
localparam IMULPPLNSTAGES = 1;
`endif

// rdy_o is a register, hence the accept, and with it the DSP input registers'
// clock-enable, is the same (rdy_o && stb_i) product it already was.
wire accept_w = (rdy_o && stb_i);

// args_r is retired: once the operands are captured the only fields still
// needed are the result-half select and the destination gpr id, and each must
// follow its own multiply down the pipe rather than sit in a holding register.
localparam IMULTAGBITSZ = (1 + CLOG2GPRCNT);
wire [IMULTAGBITSZ -1 : 0] tag_i = // Feeds the first tag pipe stage.
	{args_i[IMULMSBRSLT], args_i[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]};

// Tag pipe, as deep as the multiply it shadows; it shifts every cycle with no
// clock-enable, exactly as the product registers do, and vld_r says which
// stages hold a multiply. tag_w is the stage whose product is in prodend_w.
reg [(IMULPPLNSTAGES*IMULTAGBITSZ) -1 : 0] tag_r;
wire [IMULTAGBITSZ -1 : 0] tag_w = tag_r[(IMULPPLNSTAGES*IMULTAGBITSZ)-1 -: IMULTAGBITSZ];

// Valid pipe; its last stage high means prodend_w holds the product of the
// multiply whose tag is in tag_w, ie: it is the push into the result fifo.
reg [IMULPPLNSTAGES -1 : 0] vld_r;

always_ff @(posedge clk_i) begin
	`ifdef PUIMULDSPREG
	prod_r  <= prod_w;
	prod_rr <= prod_r;
	tag_r   <= {tag_r[(2*IMULTAGBITSZ)-1:0], tag_i};
	`else
	tag_r   <= tag_i;
	`endif
end

// Result fifo. One deeper than the pipe is exactly what the acceptance rule
// admits: at most IMULFIFODEPTH multiplies are accepted-and-unretired at once,
// and every one of them can be a fifo entry once the pipe drains, ie: the fifo
// can fill but never overflow.
localparam IMULFIFODEPTH      = (IMULPPLNSTAGES + 1);
localparam CLOG2IMULFIFODEPTH = clog2(IMULFIFODEPTH);

wire fifoPush_w = vld_r[IMULPPLNSTAGES-1];
wire fifoPop_w  = (ordy_o && ostb_i);

// Multiplies accepted and not yet retired, ie: marching the DSP registers plus
// queued in the fifo; keeping it at or below IMULFIFODEPTH is what insures the
// fifo cannot overflow, hence it is what rdy_o is derived from.
reg [(CLOG2IMULFIFODEPTH +1) -1 : 0] usage_r;

// Feeds usage_r, and with it rdy_o, on the next clockedge.
wire [(CLOG2IMULFIFODEPTH +1) -1 : 0] usage_i =
	((accept_w == fifoPop_w) ? usage_r :
		(accept_w ? (usage_r + 1'b1) : (usage_r - 1'b1)));

`ifdef PUIMULDSPREG
// The product leaving the pipeline is the PREG output; the MSB/LSB mux below
// therefore sits after the last product register, so prod_rr leaves the DSP
// into fabric combinational logic followed by a fabric register (the fifo
// entry), and absorption is unaffected.
wire [(WORDBITSZ*2) -1 : 0] prodend_w = prod_rr;
`else
wire [(WORDBITSZ*2) -1 : 0] prodend_w = prod_w;
`endif
// When tag_w[IMULTAGBITSZ-1] == 0, the WORDBITSZ lsb are used as result.
// When tag_w[IMULTAGBITSZ-1] == 1, the WORDBITSZ msb are used as result.
wire [WORDBITSZ -1 : 0] rslt_i = (tag_w[IMULTAGBITSZ-1] ?
	prodend_w[(WORDBITSZ*2)-1:WORDBITSZ] :
	prodend_w[WORDBITSZ-1:0]);

wire fifoEmpty_w;
wire fifoFull_w;

// The result fifo is a fwft fifo: its data_o presents the head combinationally
// off its registered indices, which is what the WriteBack arbiter's same-cycle
// grant needs, and the shape the load unit's ldUnit_rqsts already puts on this
// cone.
fifo_fwft #(
	 .WIDTH (WORDBITSZ + CLOG2GPRCNT)
	,.DEPTH (IMULFIFODEPTH)
) rsltfifo (
	 .rst_i      (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (fifoPush_w)
	,.data_i     ({rslt_i, tag_w[CLOG2GPRCNT-1:0]})
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
		if (accept_w) begin
			// Sign-extension folded into the capture; see arg0_sign/arg1_sign
			// in the unpipelined variant for the significance of each term.
			opa_r <= {(args_i[(WORDBITSZ*2)-1] & (args_i[IMULSIGNED] || args_i[IMULLVALSIGND])),
				args_i[(WORDBITSZ*2)-1:WORDBITSZ]};
			opb_r <= {(args_i[WORDBITSZ-1] & args_i[IMULSIGNED]),
				args_i[WORDBITSZ-1:0]};
		end
		`ifdef PUIMULDSPREG
		vld_r <= {vld_r[1:0], accept_w};
		`else
		vld_r <= accept_w;
		`endif
		usage_r <= usage_i;
		// Set from the credit count the next cycle will see, hence exact and yet
		// a single register on the issue-stall cone. rdy_o falls only when
		// accepting one more multiply could overflow the result fifo, ie: it
		// stays high while multiplies are in flight and results are draining.
		rdy_o <= (usage_i != IMULFIFODEPTH);
	end
end

`ifdef SIMULATION
// The fifo depth is derived from the acceptance rule, not enforced here: a push while
// full is silently refused by the fifo (its write-enable gates on full_o), dropping a
// completed multiply, whose gpr is then never unlocked by the WriteBack, and the hart
// spins forever on an operand that never becomes ready, ie: a run that gets killed
// rather than reaching $finish, which is exactly when an unflushed report is lost. A
// retirement strobed with no result held is reported for the mirror-image reason: it
// would mean opimul granted a retirement to an instance it was not presenting, ie:
// results retiring out of the order they were dispatched in, which the scoreboard
// cannot catch because a multiply cannot have two producers of the same gpr in flight.
// Each is reported once, as the condition that caused it repeats for as long as it
// lasts.
reg fifoOvfl_r;
reg fifoUndf_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		fifoOvfl_r <= 1'b0;
		fifoUndf_r <= 1'b0;
	end else begin
		if (fifoPush_w && fifoFull_w && !fifoOvfl_r) begin
			fifoOvfl_r <= 1'b1;
			$display("%m: error: result fifo overflow: a multiply result was dropped");
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

`else

module imul (

	 rst_i

	,clk_i

	,stb_i

	,args_i
	,rslt_o
	,gprid_o

	,rdy_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter GPRCNT    = 32;

localparam CLOG2WORDBITSZ = clog2(WORDBITSZ);
localparam CLOG2GPRCNT    = clog2(GPRCNT);

// Significance of each bit in the field within
// args_i storing the type of multiplication to perform.
// [2]: 0/1 means always treat the left operand as signed.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means WORDBITSZ lsb/msb of result.
localparam IMULTYPEBITSZ = 3;
localparam IMULMSBRSLT   = ((WORDBITSZ*2)+CLOG2GPRCNT);
localparam IMULSIGNED    = ((WORDBITSZ*2)+CLOG2GPRCNT+1);
localparam IMULLVALSIGND = ((WORDBITSZ*2)+CLOG2GPRCNT+2);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] args_i;

// Net set to the result of the multiplication.
output reg [WORDBITSZ -1 : 0] rslt_o; // ### comb-block-reg.

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Register in which the multiplication will be computed.
reg  [(WORDBITSZ*2) -1 : 0] cumulator;
wire [(WORDBITSZ*2) -1 : 0] cumulatornegated = -cumulator;

// Net used by the multiplication; compute the multiplier
// times 0, 1, 2 or 3 based on cumulator[1:0].
reg [(WORDBITSZ+2) -1 : 0] mulx; // ### comb-block-reg.

// Reg set to the right operand value of the multiplication, which is the multiplier.
reg [WORDBITSZ -1 : 0] rval;

// ### Used so that verilog simulation would work.
wire [(WORDBITSZ+2) -1 : 0] cumulatorarg = (mulx + cumulator[(WORDBITSZ*2)-1:WORDBITSZ]);

// Reg used to capture args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2];

always_comb begin
	// Logic used by the multiplication; compute the multiplier
	// times 0, 1, 2 or 3 based on cumulator[1:0].
	if (cumulator[1:0] == 1)
		mulx = {{2{1'b0}}, rval};
	else if (cumulator[1:0] == 2)
		mulx = {1'b0, rval, 1'b0};
	else if (cumulator[1:0] == 3)
		mulx = {rval, 1'b0} + rval;
	else
		mulx = 0;
end

reg rslt_sign;
always_ff @(posedge clk_i) begin
	// When operands[IMULSIGNED] == 0, an unsigned multiplication was done.
	// When operands[IMULSIGNED] == 1, a signed multiplication was done.
	if (operands[IMULSIGNED])
		rslt_sign <= (operands[(WORDBITSZ*2)-1] != operands[(WORDBITSZ-1)]);
	else if (operands[IMULLVALSIGND])
		rslt_sign <= operands[(WORDBITSZ*2)-1];
	else
		rslt_sign <= 0;
end

wire [(WORDBITSZ*2) -1 : 0] rslt_o_ = (rslt_sign ? cumulatornegated : cumulator);

always_comb begin
	// When operands[IMULMSBRSLT] == 0, the WORDBITSZ lsb are used as result.
	// When operands[IMULMSBRSLT] == 1, the WORDBITSZ msb are used as result.
	if (operands[IMULMSBRSLT])
		rslt_o = rslt_o_[(WORDBITSZ*2)-1:WORDBITSZ];
	else
		rslt_o = rslt_o_[WORDBITSZ-1:0];
end

// Register used to count the number of two-bits-set already used from the multiplicand.
reg [(CLOG2WORDBITSZ-1) -1 : 0] cntr;

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin

			operands <= args_i;

			// If args_i[IMULSIGNED] == 0, it is an unsigned computation.
			// If args_i[IMULSIGNED] == 1, it is a signed computation.
			// For a signed computation, I turn the right operand positive if it was negative.
			if (args_i[IMULSIGNED] && args_i[(WORDBITSZ-1)])
				rval <= -args_i[WORDBITSZ-1:0];
			else
				rval <= args_i[WORDBITSZ-1:0];

			// The multiplicand is in args_i[(WORDBITSZ*2)-1:WORDBITSZ].
			// The multiplier is in args_i[WORDBITSZ-1:0].

			// If args_i[IMULSIGNED] == 0, an unsigned computation is to be done.
			// If args_i[IMULSIGNED] == 1, a signed computation is to be done.
			// If args_i[IMULLVALSIGND] == 1, the left operand is always treated as signed.
			// If it applies, I turn the left operand positive if it was negative.
			if ((args_i[IMULLVALSIGND] || args_i[IMULSIGNED]) && args_i[(WORDBITSZ*2)-1])
				cumulator <= {{WORDBITSZ{1'b0}}, -args_i[(WORDBITSZ*2)-1:WORDBITSZ]};
			else
				cumulator <= {{WORDBITSZ{1'b0}}, args_i[(WORDBITSZ*2)-1:WORDBITSZ]};

			rdy_o <= 0;

			cntr <= 0;
		end

	end else begin
		// Note that although mulx is (WORDBITSZ+2) bits,
		// the result of mulx + cumulator[(WORDBITSZ*2)-1:WORDBITSZ]
		// will never generate a carry, because
		// mulx[(WORDBITSZ+1):WORDBITSZ] is guaranteed to never
		// be greater than 2'b10.
		// ### mulx + cumulator[(WORDBITSZ*2)-1:WORDBITSZ]
		// ### was computed in cumulatorarg so that
		// ### verilog simulation would work.
		// ### cumulatorarg is (WORDBITSZ+2) bits.
		cumulator <= {cumulatorarg, cumulator[WORDBITSZ-1:2]};

		if (cntr == ((WORDBITSZ/2)-1)) begin
			// The multiplication is complete after cntr has been
			// incremented (WORDBITSZ/2) times; the result will
			// be ready in cumulator after the next clockedge.
			rdy_o <= 1;
		end

		cntr <= cntr + 1'b1;
	end
end

endmodule

`endif /* PUIMULDSP */

// clk_imul_i frequency must be clk_i frequency times a power-of-2.
module opimul (

	 rst_i

	,clk_i
	,clk_imul_i

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
parameter INSTCNT   = 2;

localparam CLOG2GPRCNT = clog2(GPRCNT);

// Significance of each bit in the field within
// args_i storing the type of multiplication to perform.
// [2]: 0/1 means always treat the left operand as signed.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means WORDBITSZ lsb/msb of result.
localparam IMULTYPEBITSZ = 3;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_imul_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] args_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the multiplication.
output wire [WORDBITSZ -1 : 0] rslt_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2INSTCNT +1) -1 : 0] wridx;
reg [(CLOG2INSTCNT +1) -1 : 0] rdidx;

wire [(CLOG2INSTCNT +1) -1 : 0] _wridx = ((INSTCNT-1) ? wridx : 0);
wire [(CLOG2INSTCNT +1) -1 : 0] _rdidx = ((INSTCNT-1) ? rdidx : 0);

`ifndef PUIMULDSP
wire [(CLOG2INSTCNT +1) -1 : 0] usage;
assign usage = (wridx - rdidx);
`endif

wire [WORDBITSZ -1 : 0] rslt_w [INSTCNT -1 : 0];
assign rslt_o = rslt_w[_rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [INSTCNT -1 : 0];
assign gprid_o = gprid_w[_rdidx];

wire [INSTCNT -1 : 0] rdy_w;

`ifdef PUIMULDSP
// Each DSP imul instance pipelines acceptance and queues its completed
// results, hence backpressure is per-instance and there is nothing left for
// the wrapper to cap: rdy_w[] means "this instance can accept another
// multiply" and ordy_w[] means "this instance has a completed result to
// retire". The (usage < INSTCNT) cap below exists only to protect the
// iterative instance's single held rslt_o, which the result fifo replaces.
// wridx/rdidx keep their width and their strict rotation, which is what
// insures results retire in the order they were dispatched: instance i takes
// every multiply whose wridx is i modulo INSTCNT, each instance's fifo is in
// order, and rdidx walks the same rotation. rdy_o must therefore not skip a
// busy instance for a free one.
wire [INSTCNT -1 : 0] ordy_w;

assign rdy_o = rdy_w[_wridx];

assign ordy_o = ordy_w[_rdidx];
`else
assign rdy_o = ((usage < INSTCNT) && rdy_w[_wridx]);

assign ordy_o = ((usage != 0) && rdy_w[_rdidx]);
`endif

`ifdef PUIMULCLK
reg                                                       _stb_i;
reg  [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] _args_i;
reg  [(CLOG2INSTCNT +1) -1 : 0]                           __wridx;
`else
wire                                                      _stb_i  = stb_i;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] _args_i = args_i;
wire [(CLOG2INSTCNT +1) -1 : 0]                           __wridx = _wridx;
`endif

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

`ifdef PUIMULCLK
always_ff @(posedge clk_i) begin
	// With clk_imul_i faster than clk_i, imul signals stb_i args_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_imul_i)/freq(clk_i))
	// clk_imul_i cycles after its negedge; which is guarateed by the fact that
	// the iterative (non-PUIMULDSP) imul computation takes at least that many clk_imul_i cycles.
	// Neither DSP arm gives that guarantee: both accept while rdy_o stays high
	// (it falls only on result-fifo pressure), so the same stb_i would be
	// accepted once per clk_imul_i cycle of the ratio, and the ostb_i route
	// would retire the same result as many times; PUIMULCLK is therefore
	// usable only with the iterative multiply.
	if (rst_i)
		_stb_i <= 0;
	else begin
		_stb_i  <= stb_i;
		_args_i <= args_i;
		__wridx <= _wridx;
	end
end
`endif

genvar gen_imul_idx;
generate for (gen_imul_idx = 0; gen_imul_idx < INSTCNT; gen_imul_idx = gen_imul_idx + 1) begin :gen_imul
imul #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
) imul (

	 .rst_i (rst_i)

	`ifdef PUIMULCLK
	,.clk_i (clk_imul_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (_stb_i && (__wridx[CLOG2INSTCNT -1 : 0] == gen_imul_idx))

	,.args_i  (_args_i)
	,.rslt_o  (rslt_w[gen_imul_idx])
	,.gprid_o (gprid_w[gen_imul_idx])

	,.rdy_o (rdy_w[gen_imul_idx])

	`ifdef PUIMULDSP
	// Retirement is routed to the instance rdidx points at, mirroring the
	// dispatch fanout above; the same implicit truncation to CLOG2INSTCNT
	// bits gives the mod-INSTCNT rotation.
	,.ostb_i (ostb_i && (_rdidx[CLOG2INSTCNT -1 : 0] == gen_imul_idx))
	,.ordy_o (ordy_w[gen_imul_idx])
	`endif
);
end endgenerate

endmodule

// Multiplication algorithms (implementation above uses radix-4 by default,
// or DSP hardware multipliers under PUIMULDSP).
//
// Radix-2 Multiplication.
// The multiplier is examined one bit at a time.
//
// Multiply 5 times 12.
//
//    0101  Multiplicand
//    1100  Multiplier
//    """"
//    0000  0 x 0101
//   0000   0 x 0101
//  0101    1 x 0101
// 0101     1 x 0101
// """""""
// 0111100  Product
//
// Radix-4 Multiplication.
// The multiplier is examined two bits at a time.
// Twice as fast as radix-2.
//
// Let `a` denotes the multiplicand
// and `b` denotes the multiplier.
// Pre-compute 2a and 3a.
// Examine multiplier two bits at
// a time (rather than one bit at a time);
// based on the value of those bits
// add 0, a, 2a, or 3a (shifted by
// the appropriate amount).
//
// Multiply 5 times 12.
//
//    0101  Multiplicand
//    1100  Multiplier
//    """"
//   00000  00 x 0101
// 01111    11 x 0101
// """""""
// 0111100  Product
//
// Multiply 5 times 9.
//
//    0101  Multiplicand
//    1001  Multiplier
//    """"
//   00101  01 x 0101
// 01010    10 x 0101
// """""""
// 0101101  Product
//
// Signed multiplication is implemented by using the absolute value
// of operands and later remembering what were their signs.
