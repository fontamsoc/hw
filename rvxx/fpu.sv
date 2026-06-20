// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Single-precision (Zfinx) floating-point unit as a multi-cycle unit, modeled on
// idiv/clmul: it connects to the pipeline ONLY through the stb/rdy + ostb/ordy
// handshake (see fpu.pu.sv), so the whole FPU is register-isolated and stays off
// the scoreboard/forwarding Fmax cone. Every FP op (even the 1-cycle ones) retires
// through the WriteBack arbiter as a lateResult.
//
// args_i carries (high->low): the already-resolved 3-bit rounding mode `rm`, a 5-bit
// `optype` selector, the destination gpr id, and rs1/rs2. The 5 fflags exception bits
// {NV,DZ,OF,UF,NX} are returned alongside the result.
//
// Bring-up is staged. THIS revision implements the 1-cycle ops:
//   fsgnj/fsgnjn/fsgnjx, fmin/fmax, feq/flt/fle, fclass.
// (fcvt, fadd/fsub/fmul, fdiv/fsqrt are added in later revisions; their optype codes
//  9..17 are reserved below and currently produce 0.)

module fpu (

	 rst_i

	,clk_i

	,stb_i

	,args_i
	,rslt_o
	,gprid_o
	,flags_o

	,rdy_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter GPRCNT    = 32;

localparam CLOG2GPRCNT = clog2(GPRCNT);

localparam OPTYPEBITSZ = 5;
localparam OPTYPELSB   = ((WORDBITSZ*2)+CLOG2GPRCNT);
localparam RMLSB       = (OPTYPELSB + OPTYPEBITSZ);

// optype encoding -- MUST match iF_opFpu_optype in pu.sv.
localparam OP_SGNJ  = 5'd0;
localparam OP_SGNJN = 5'd1;
localparam OP_SGNJX = 5'd2;
localparam OP_MIN   = 5'd3;
localparam OP_MAX   = 5'd4;
localparam OP_EQ    = 5'd5;
localparam OP_LT    = 5'd6;
localparam OP_LE    = 5'd7;
localparam OP_CLASS = 5'd8;
localparam OP_CVTWS  = 5'd9;  // f -> int32 (signed)
localparam OP_CVTWUS = 5'd10; // f -> uint32
localparam OP_CVTSW  = 5'd11; // int32 -> f
localparam OP_CVTSWU = 5'd12; // uint32 -> f
// reserved (later stages): 13 ADD,14 SUB,15 MUL,16 DIV,17 SQRT.

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPTYPEBITSZ+3) -1 : 0] args_i;

output reg  [WORDBITSZ -1 : 0]   rslt_o;  // ### comb-block-reg.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;
output reg  [5 -1 : 0]           flags_o; // ### comb-block-reg. {NV,DZ,OF,UF,NX}.

output reg rdy_o;

// Captured args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPTYPEBITSZ+3) -1 : 0] operands;

assign gprid_o = operands[OPTYPELSB-1 : WORDBITSZ*2];

wire [OPTYPEBITSZ -1 : 0] optype = operands[OPTYPELSB +: OPTYPEBITSZ];
wire [3 -1 : 0]           rm = operands[RMLSB +: 3]; // resolved rounding mode.

// ---- shared rounding (all 5 modes) ----
// Should the magnitude be incremented, given the kept LSB, the guard bit (weight 1/2
// ULP), the sticky bit (OR of everything below guard), the result sign, and rm?
function automatic logic roundUp(input logic lsb, input logic g, input logic s,
                                 input logic sgn, input logic [2:0] rmode);
	case (rmode)
	3'b000:  roundUp = g && (s || lsb);  // RNE: ties to even.
	3'b001:  roundUp = 1'b0;             // RTZ: truncate.
	3'b010:  roundUp = (g || s) && sgn;  // RDN: toward -inf.
	3'b011:  roundUp = (g || s) && !sgn; // RUP: toward +inf.
	3'b100:  roundUp = g;                // RMM: ties to max magnitude.
	default: roundUp = g && (s || lsb);  // reserved -> treat as RNE.
	endcase
endfunction

// Count leading zeros of a 32-bit value (32 if zero).
function automatic logic [5:0] clz32(input logic [31:0] x);
	integer i; logic done;
	begin
		clz32 = 6'd32; done = 1'b0;
		for (i = 31; i >= 0; i = i - 1)
			if (!done && x[i]) begin clz32 = 6'd31 - i[5:0]; done = 1'b1; end
	end
endfunction

wire [WORDBITSZ -1 : 0] a = operands[(WORDBITSZ*2)-1 : WORDBITSZ]; // rs1
wire [WORDBITSZ -1 : 0] b = operands[WORDBITSZ-1 : 0];            // rs2

// ---- unpack / classify (IEEE-754 binary32) ----
wire        signA = a[31];    wire        signB = b[31];
wire [7:0]  expA  = a[30:23]; wire [7:0]  expB  = b[30:23];
wire [22:0] fracA = a[22:0];  wire [22:0] fracB = b[22:0];

wire isZeroA = (expA==8'd0   && fracA==23'd0); wire isZeroB = (expB==8'd0   && fracB==23'd0);
wire isSubA  = (expA==8'd0   && fracA!=23'd0); wire isSubB  = (expB==8'd0   && fracB!=23'd0);
wire isInfA  = (expA==8'hff  && fracA==23'd0); wire isInfB  = (expB==8'hff  && fracB==23'd0);
wire isNaNA  = (expA==8'hff  && fracA!=23'd0); wire isNaNB  = (expB==8'hff  && fracB!=23'd0);
wire isSNaNA = (isNaNA && !fracA[22]);         wire isSNaNB = (isNaNB && !fracB[22]);
wire normalA = (expA!=8'd0  && expA!=8'hff);

wire eitherNaN  = (isNaNA  || isNaNB);
wire eitherSNaN = (isSNaNA || isSNaNB);
wire bothZero   = (isZeroA && isZeroB);

wire [30:0] magA = a[30:0]; wire [30:0] magB = b[30:0];

localparam [31:0] CANON_QNAN = 32'h7fc00000;

// Numeric less-than, valid only when neither operand is NaN; zeros compare equal.
wire numLt = (signA != signB) ? (signA && !bothZero)
           : bothZero          ? 1'b0
           : (signA == 1'b0)    ? (magA <  magB)
           :                      (magA >  magB);
// Numeric equality (quiet), false if either is NaN; +0 == -0.
wire fpEqNum = (!eitherNaN) && (bothZero || (a == b));

// Sign-injection result sign.
wire signSel = (optype==OP_SGNJN) ? ~signB
             : (optype==OP_SGNJX) ? (signA ^ signB)
             :                       signB;       // OP_SGNJ

// fclass 10-bit mask.
wire [9:0] classMask = {
	  isNaNA &&  fracA[22],   // [9] qNaN
	  isSNaNA,                // [8] sNaN
	 !signA &&  isInfA,       // [7] +inf
	 !signA &&  normalA,      // [6] +normal
	 !signA &&  isSubA,       // [5] +subnormal
	 !signA &&  isZeroA,      // [4] +0
	  signA &&  isZeroA,      // [3] -0
	  signA &&  isSubA,       // [2] -subnormal
	  signA &&  normalA,      // [1] -normal
	  signA &&  isInfA };     // [0] -inf

// ===== int -> float (CVTSW signed / CVTSWU unsigned) =====
// 32-bit int never overflows binary32 (max ~2^32 < 2^128) and never underflows, so the
// only possible flag is NX (inexact, when the integer has > 24 significant bits).
wire        ifUns  = (optype == OP_CVTSWU);
wire        ifSign = (~ifUns) & a[31];              // signed-negative input
wire [31:0] ifMag  = ifSign ? (~a + 32'd1) : a;     // magnitude (unsigned input as-is)
wire        ifZero = (ifMag == 32'd0);
wire [5:0]  ifLz   = clz32(ifMag);
wire [7:0]  ifExp  = 8'd127 + (8'd31 - {2'd0, ifLz}); // biased exp = 127 + msbpos
wire [31:0] ifAln  = ifMag << ifLz;                  // MSB now at bit31
wire [23:0] ifSig  = ifAln[31:8];                    // 1.frac (24 bits)
wire        ifG    = ifAln[7];
wire        ifS    = |ifAln[6:0];
wire        ifRup  = roundUp(ifSig[0], ifG, ifS, ifSign, rm);
wire [24:0] ifRnd  = {1'b0, ifSig} + {24'd0, ifRup};
wire [22:0] ifFrac = ifRnd[24] ? 23'd0 : ifRnd[22:0];     // rounding carry -> mantissa 1.0
wire [7:0]  ifExpF = ifRnd[24] ? (ifExp + 8'd1) : ifExp;
wire [31:0] resCvtIF = ifZero ? 32'd0 : {ifSign, ifExpF, ifFrac};
wire [4:0]  flgCvtIF = {4'd0, (ifG | ifS)};               // NX only.

// ===== float -> int (CVTWS signed int32 / CVTWUS uint32) =====
wire cvtFiUns = (optype == OP_CVTWUS);
wire signed [10:0] fiE = $signed({3'b0, expA}) - 11'sd127; // unbiased exponent
wire [23:0] fiSig  = {normalA, fracA};                     // hidden = 1 (normal) / 0 (sub/zero)
wire [63:0] fiSig64 = {40'd0, fiSig};
wire        fiLeft  = (fiE >= 11'sd23);                    // exact integer (no fraction)
// right (fractional) case: shift right by (23 - E), capture guard/sticky.
wire signed [10:0] fiRsS = 11'sd23 - fiE;                  // >0 when E < 23
wire [6:0]  fiRsC = (fiRsS >= 11'sd64) ? 7'd64 : fiRsS[6:0];
wire [63:0] fiRsh = fiSig64 >> fiRsC;
wire [31:0] fiRsInt = fiRsh[31:0];
wire        fiG = (fiRsC == 7'd0) ? 1'b0 : fiSig64[fiRsC - 7'd1];
wire        fiS = (fiRsC <= 7'd1) ? 1'b0 : (|(fiSig64 & ((64'd1 << (fiRsC - 7'd1)) - 64'd1)));
wire        fiRup = roundUp(fiRsInt[0], fiG, fiS, signA, rm);
// left (exact) case: shift left by (E - 23); E>31(signed)/E>32(unsigned) always overflows,
// so cap the shift (<=8 for the in-range path) and force a saturating magnitude otherwise.
wire        fiLsBig = (fiE > 11'sd31);
wire [3:0]  fiLsC   = fiLsBig ? 4'd0 : (fiE[3:0] - 4'd7); // E-23 for E in [23,31] (low nibble)
wire [63:0] fiLsh   = fiLsBig ? 64'hFFFFFFFFFFFFFFFF : (fiSig64 << fiLsC);
wire [63:0] fiMag   = fiLeft ? fiLsh : ({32'd0, fiRsInt} + {63'd0, fiRup});
wire        fiInexact = fiLeft ? 1'b0 : (fiG | fiS);

reg  [31:0] resCvtFI; // ### comb-block-reg.
reg         fiNV;     // ### comb-block-reg.
always_comb begin
	resCvtFI = 32'd0; fiNV = 1'b0;
	if (cvtFiUns) begin // -> uint32
		if (isNaNA || (!signA && isInfA))        begin resCvtFI = 32'hffffffff; fiNV = 1'b1; end
		else if (signA)                          begin // negative input
			if (fiMag == 64'd0) resCvtFI = 32'd0;                       // rounds to 0: just NX
			else                begin resCvtFI = 32'd0; fiNV = 1'b1; end// truly negative: NV
		end
		else if (fiMag > 64'hffffffff)           begin resCvtFI = 32'hffffffff; fiNV = 1'b1; end
		else                                            resCvtFI = fiMag[31:0];
	end else begin // -> int32
		if (isNaNA || (!signA && isInfA))        begin resCvtFI = 32'h7fffffff; fiNV = 1'b1; end
		else if (signA && isInfA)                begin resCvtFI = 32'h80000000; fiNV = 1'b1; end
		else if (!signA) begin
			if (fiMag > 64'h7fffffff)            begin resCvtFI = 32'h7fffffff; fiNV = 1'b1; end
			else                                        resCvtFI = fiMag[31:0];
		end else begin // negative
			if (fiMag > 64'h80000000)            begin resCvtFI = 32'h80000000; fiNV = 1'b1; end
			else                                        resCvtFI = (~fiMag[31:0] + 32'd1);
		end
	end
end
wire [4:0] flgCvtFI = fiNV ? 5'b10000 : {4'd0, fiInexact}; // NV suppresses NX.

always_comb begin
	rslt_o  = {WORDBITSZ{1'b0}};
	flags_o = 5'b0;
	case (optype)
	OP_SGNJ, OP_SGNJN, OP_SGNJX: rslt_o = {signSel, a[30:0]};
	OP_CLASS: rslt_o = {{(WORDBITSZ-10){1'b0}}, classMask};
	OP_EQ: begin rslt_o = {{(WORDBITSZ-1){1'b0}},  fpEqNum};                        flags_o[4] = eitherSNaN; end
	OP_LT: begin rslt_o = {{(WORDBITSZ-1){1'b0}}, (!eitherNaN && numLt)};           flags_o[4] = eitherNaN;  end
	OP_LE: begin rslt_o = {{(WORDBITSZ-1){1'b0}}, (!eitherNaN && (numLt||fpEqNum))};flags_o[4] = eitherNaN;  end
	OP_MIN: begin
		rslt_o = (isNaNA && isNaNB) ? CANON_QNAN : isNaNA ? b : isNaNB ? a
		       : bothZero ? (signA ? a : b) : (numLt ? a : b);
		flags_o[4] = eitherSNaN;
	end
	OP_MAX: begin
		rslt_o = (isNaNA && isNaNB) ? CANON_QNAN : isNaNA ? b : isNaNB ? a
		       : bothZero ? (signA ? b : a) : (numLt ? b : a);
		flags_o[4] = eitherSNaN;
	end
	OP_CVTWS, OP_CVTWUS: begin rslt_o = resCvtFI; flags_o = flgCvtFI; end
	OP_CVTSW, OP_CVTSWU: begin rslt_o = resCvtIF; flags_o = flgCvtIF; end
	default: begin rslt_o = {WORDBITSZ{1'b0}}; flags_o = 5'b0; end
	endcase
end

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		rdy_o <= 1;
	end else if (rdy_o) begin
		if (stb_i) begin
			operands <= args_i;
			rdy_o    <= 0;
		end
	end else begin
		// All currently-implemented ops are 1-cycle: the combinational result/flags
		// above are valid one clockedge after the operands were captured. Later
		// stages replace this with a per-op iteration counter (like idiv).
		rdy_o <= 1;
	end
end

endmodule

module opfpu (

	 rst_i

	,clk_i

	,stb_i
	,args_i
	,rdy_o
	,busy_o

	,ostb_i
	,rslt_o
	,gprid_o
	,flags_o
	,ordy_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter GPRCNT    = 32;
parameter INSTCNT   = 1;

localparam CLOG2GPRCNT = clog2(GPRCNT);

localparam OPTYPEBITSZ = 5;

localparam CLOG2INSTCNT = clog2(INSTCNT);

localparam ARGSZ = (((WORDBITSZ*2)+CLOG2GPRCNT)+OPTYPEBITSZ+3);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [ARGSZ -1 : 0] args_i;

output wire rdy_o;

// High while any op is queued (issued but not yet retired). Used to drain-gate
// fcsr/frm/fflags CSR accesses at iDecode (the fflags ordering hazard).
output wire busy_o;

input wire ostb_i;

output wire [WORDBITSZ -1 : 0]   rslt_o;
output wire [CLOG2GPRCNT -1 : 0] gprid_o;
output wire [5 -1 : 0]           flags_o;

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

wire [5 -1 : 0] flags_ww [INSTCNT -1 : 0];
assign flags_o = flags_ww[_rdidx];

wire [INSTCNT -1 : 0] rdy_w;

assign rdy_o  = ((usage < INSTCNT) && rdy_w[_wridx]);
assign ordy_o = ((usage != 0)      && rdy_w[_rdidx]);
assign busy_o = (usage != 0);

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

genvar gen_fpu_idx;
generate for (gen_fpu_idx = 0; gen_fpu_idx < INSTCNT; gen_fpu_idx = gen_fpu_idx + 1) begin :gen_fpu
fpu #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
) fpu (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (stb_i && (_wridx[CLOG2INSTCNT -1 : 0] == gen_fpu_idx))

	,.args_i  (args_i)
	,.rslt_o  (data_w[gen_fpu_idx])
	,.gprid_o (gprid_w[gen_fpu_idx])
	,.flags_o (flags_ww[gen_fpu_idx])

	,.rdy_o (rdy_w[gen_fpu_idx])
);
end endgenerate

endmodule
