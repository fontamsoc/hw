// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Zbb (basic bit-manipulation) as a multi-cycle unit, modeled on the clmul/idiv units.
// All 18 Zbb ops are single-cycle combinational, but routing that logic through the EX
// stage lands it on the binding scoreboard/forwarding Fmax cone (drops the OrangeCrab
// ~49 -> ~33 MHz). Here the op runs register-isolated: stb latches the operands, the
// result is combinational from the held operands, and rdy_o asserts one cycle later, so
// the only pipeline coupling is the stb/rdy + ostb/ordy handshake (like clmul). The
// operation is selected by a 5-bit optype packed into args_i by pu.sv.

module zbb (

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

localparam CLOG2GPRCNT = clog2(GPRCNT);

// optype field within args_i. Codes MUST match the opZbb_optype decode in zbb.pu.sv.
// Structured as {group[2:0], member[1:0]} so each op group selects on a bit-slice and
// the member bits directly drive the datapath controls within a group:
//   group 0 logic:  andn=00000 orn=00001 xnor=00010            (member = which function)
//   group 1 minmax: min=00100 minu=00101 max=00110 maxu=00111  (member = {isMax, isUnsigned})
//   group 2 rot:    rol=01000 ror=01001                        (member[0] = rotate right;
//                                                               rori issues as ror)
//   group 3 count:  clz=01100 ctz=01101 cpop=01110             (member = {isCpop, isCtz})
//   group 4 ext:    sext.b=10000 sext.h=10001 zext.h=10011     (member = {isZext, isHalf})
//   group 5 byte:   rev8=10100 orc.b=10101                     (member[0] = orc.b)
localparam ZBBTYPEBITSZ = 5;

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[...+ZBBTYPEBITSZ-1 : ...] = optype (which Zbb op),
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1 : WORDBITSZ*2] = destination gpr id,
// bits[(WORDBITSZ*2)-1 : WORDBITSZ] = rs1, bits[WORDBITSZ-1 : 0] = rs2 (or, for the
// OP-IMM ops, the immediate -- only its low 5 bits matter, as the rotate amount for rori).
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+ZBBTYPEBITSZ) -1 : 0] args_i;

// Registered result: the deep Zbb compute is operands-reg -> zbbRes -> result-reg, a
// self-contained register-to-register path. (If rslt_o were combinational from operands,
// the compute would sit on the arbiter -> iD_rW_rslt forwarding cone and cap Fmax.)
output wire [WORDBITSZ -1 : 0] rslt_o;

output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Regs used to capture args_i, one per field. The captured rs1 is dead once zbbRes has
// been computed from it, so the result is written back into rs1Slot (its FFs double as
// the result register; rslt_o aliases it) instead of a separate rslt_o register. Safe:
// the opzbb wrapper usage counter blocks a new stb into this instance until ostb_i has
// retired the held result, so a capture can never clobber it.
reg [ZBBTYPEBITSZ -1 : 0] optypeSlot;
reg [CLOG2GPRCNT  -1 : 0] gpridSlot;
reg [WORDBITSZ    -1 : 0] rs1Slot; // ### pipeline reg: rs1, then the result (clocked below).
reg [WORDBITSZ    -1 : 0] rs2Slot;

assign rslt_o  = rs1Slot;
assign gprid_o = gpridSlot;

wire [ZBBTYPEBITSZ -1 : 0] optype = optypeSlot;
wire [WORDBITSZ    -1 : 0] rs1    = rs1Slot;
wire [WORDBITSZ    -1 : 0] rs2    = rs2Slot;

function automatic bit [WORDBITSZ -1 : 0] reverseBits;
	input bit [WORDBITSZ -1 : 0] bits;
	for (int i = 0; i < WORDBITSZ; ++i)
		reverseBits[i] = bits[(WORDBITSZ -1) - i];
endfunction
// Population count as a balanced adder tree: a nibble layer (each count a 3-bit value,
// shallow per-bit LUT cones), then stride-doubling pairwise sums. A serial `+ v[i]`
// loop instead maps to a WORDBITSZ-long ribbon of chained adders. (Loop bounds must
// stay static -- no loop-carried bound -- or yosys refuses to elaborate the function.)
function automatic bit [WORDBITSZ -1 : 0] zbb_cpop;
	input bit [WORDBITSZ -1 : 0] v;
	bit [(WORDBITSZ/4)*8 -1 : 0] cnt; // per-group counts, 8 bits each, summed pairwise.
	begin
		for (int i = 0; i < WORDBITSZ/4; ++i)
			cnt[i*8 +: 8] = (v[i*4] + v[i*4+1] + v[i*4+2] + v[i*4+3]);
		for (int s = 1; s < WORDBITSZ/4; s = s*2)
			for (int i = 0; (i + s) < WORDBITSZ/4; i = i + 2*s)
				cnt[i*8 +: 8] = (cnt[i*8 +: 8] + cnt[(i+s)*8 +: 8]);
		zbb_cpop = {{(WORDBITSZ-8){1'b0}}, cnt[7:0]};
	end
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_rev8; // Reverse byte order.
	input bit [WORDBITSZ -1 : 0] v;
	for (int i = 0; i < WORDBITSZ/8; ++i)
		zbb_rev8[i*8 +: 8] = v[(WORDBITSZ-8) - i*8 +: 8];
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_orcb; // OR-combine within each byte.
	input bit [WORDBITSZ -1 : 0] v;
	for (int i = 0; i < WORDBITSZ/8; ++i)
		zbb_orcb[i*8 +: 8] = {8{|v[i*8 +: 8]}};
endfunction

// group 0 logic: rs1 op ~rs2, the function picked by the member bits. Written as a
// vector ternary so each result bit is a 4-input cone (rs1[i], rs2[i], optype[1:0])
// that techmaps to a single LUT4.
wire [WORDBITSZ -1 : 0] zbbLogic =
	(optype[1] ? ~(rs1 ^ rs2) : (optype[0] ? (rs1 | ~rs2) : (rs1 & ~rs2)));

// group 1 minmax: ONE unsigned comparator serves all four ops. A signed compare is an
// unsigned compare with both sign bits flipped (two's-complement -> offset-binary), so
// the member isUnsigned bit conditions the sign bits and isMax flips the pick (ties
// pick rs2 for min, rs1 for max -- equal words, either way the same value).
wire zbbCmpLt = ({rs1[WORDBITSZ-1] ^ ~optype[0], rs1[WORDBITSZ-2:0]}
              <  {rs2[WORDBITSZ-1] ^ ~optype[0], rs2[WORDBITSZ-2:0]});
wire [WORDBITSZ -1 : 0] zbbMinmax = ((zbbCmpLt ^ optype[1]) ? rs1 : rs2);

// group 2 rot, via a single right-shifter: ror(x,a) = ({x,x} >> a) low word, and
// rol = ror(x,-a). Amount is rs2[4:0] (rol/ror use rs2, rori issues as ror with its
// immediate in the rs2 slot).
wire [5            -1 : 0] zbbRorAmt = (optype[0] ? rs2[4:0] : (5'd0 - rs2[4:0]));
wire [(2*WORDBITSZ)-1 : 0] zbbDbl    = {rs1, rs1};
wire [WORDBITSZ    -1 : 0] zbbRot    = (zbbDbl >> zbbRorAmt); // low word.

// group 3 count: ONE popcount tree serves clz/ctz/cpop. ctz(v) = cpop(~v & (v-1)),
// the trailing-zeros mask (v=0 -> all-ones -> WORDBITSZ, per spec); clz = ctz of the
// bit-reversed word (free wiring). cpop bypasses the mask and counts rs1 directly.
wire [WORDBITSZ -1 : 0] zbbCntW    = (optype[0] ? rs1 : reverseBits(rs1));
wire [WORDBITSZ -1 : 0] zbbCntMask = (~zbbCntW & (zbbCntW - 1'b1));
wire [WORDBITSZ -1 : 0] zbbCnt     = zbb_cpop(optype[1] ? rs1 : zbbCntMask);

// group 4 ext: bits[7:0] pass through; bits[15:8] pick the half source or the sext.b
// sign fan-out; bits[WORDBITSZ-1:16] are one shared bit (0 for zext, else the sign).
wire zbbExtUpper = (!optype[1] && (optype[0] ? rs1[15] : rs1[7]));
wire [WORDBITSZ -1 : 0] zbbExt = {{(WORDBITSZ-16){zbbExtUpper}},
	(optype[0] ? rs1[15:8] : {8{rs1[7]}}), rs1[7:0]};

// group 5 byte.
wire [WORDBITSZ -1 : 0] zbbByte = (optype[0] ? zbb_orcb(rs1) : zbb_rev8(rs1));

reg [WORDBITSZ -1 : 0] zbbRes; // ### comb-block-reg.
always_comb begin
	case (optype[ZBBTYPEBITSZ-1:2]) // group.
	3'd0:    zbbRes = zbbLogic;
	3'd1:    zbbRes = zbbMinmax;
	3'd2:    zbbRes = zbbRot;
	3'd3:    zbbRes = zbbCnt;
	3'd4:    zbbRes = zbbExt;
	default: zbbRes = zbbByte; // 5.
	endcase
end

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin
			{optypeSlot, gpridSlot, rs1Slot, rs2Slot} <= args_i;
			rdy_o <= 0;
		end

	end else begin
		// Register the result (into rs1Slot, whose captured value is now dead) so the
		// deep compute stays a register-to-register path off the arbiter/forwarding
		// cone; ready (and rslt_o valid) after this edge.
		rs1Slot <= zbbRes;
		rdy_o <= 1;
	end
end

endmodule

module opzbb (

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

localparam ZBBTYPEBITSZ = 5;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+ZBBTYPEBITSZ) -1 : 0] args_i;

output wire rdy_o;

input wire ostb_i;

output wire [WORDBITSZ -1 : 0] rslt_o;

output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2INSTCNT +1) -1 : 0] wridx;
reg [(CLOG2INSTCNT +1) -1 : 0] rdidx;

wire [(CLOG2INSTCNT +1) -1 : 0] _wridx = ((INSTCNT-1) ? wridx : 0);
wire [(CLOG2INSTCNT +1) -1 : 0] _rdidx = ((INSTCNT-1) ? rdidx : 0);

wire [(CLOG2INSTCNT +1) -1 : 0] usage;
assign usage = (wridx - rdidx);

wire [WORDBITSZ -1 : 0] data_w [INSTCNT -1 : 0];
assign rslt_o = data_w[_rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [INSTCNT -1 : 0];
assign gprid_o = gprid_w[_rdidx];

wire [INSTCNT -1 : 0] rdy_w;

assign rdy_o = ((usage < INSTCNT) && rdy_w[_wridx]);

assign ordy_o = ((usage != 0) && rdy_w[_rdidx]);

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

genvar gen_zbb_idx;
generate for (gen_zbb_idx = 0; gen_zbb_idx < INSTCNT; gen_zbb_idx = gen_zbb_idx + 1) begin :gen_zbb
zbb #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
) zbb (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (stb_i && (_wridx[CLOG2INSTCNT -1 : 0] == gen_zbb_idx))

	,.args_i  (args_i)
	,.rslt_o  (data_w[gen_zbb_idx])
	,.gprid_o (gprid_w[gen_zbb_idx])

	,.rdy_o (rdy_w[gen_zbb_idx])
);
end endgenerate

endmodule
