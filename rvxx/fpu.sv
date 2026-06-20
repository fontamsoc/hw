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
localparam OP_ADD = 5'd13;
localparam OP_SUB = 5'd14;
localparam OP_MUL = 5'd15;
localparam OP_DIV  = 5'd16;
localparam OP_SQRT = 5'd17;

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

// Count leading zeros of a 64-bit value (64 if zero).
function automatic logic [6:0] clz64(input logic [63:0] x);
	integer i; logic done;
	begin
		clz64 = 7'd64; done = 1'b0;
		for (i = 63; i >= 0; i = i - 1)
			if (!done && x[i]) begin clz64 = 7'd63 - i[6:0]; done = 1'b1; end
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
wire [31:0] ifAln  = ifMag << ifLz;                  // MSB now at bit31 (clz+shift)
// PIPELINE: register the clz+shift outputs so the round is a separate stage.
reg  [31:0] pp_ifAln; reg [7:0] pp_ifExp; reg pp_ifSign, pp_ifZero; // ### pipeline reg.
wire [23:0] ifSig  = pp_ifAln[31:8];                 // 1.frac (24 bits)
wire        ifG    = pp_ifAln[7];
wire        ifS    = |pp_ifAln[6:0];
wire        ifRup  = roundUp(ifSig[0], ifG, ifS, pp_ifSign, rm);
wire [24:0] ifRnd  = {1'b0, ifSig} + {24'd0, ifRup};
wire [22:0] ifFrac = ifRnd[24] ? 23'd0 : ifRnd[22:0];     // rounding carry -> mantissa 1.0
wire [7:0]  ifExpF = ifRnd[24] ? (pp_ifExp + 8'd1) : pp_ifExp;
wire [31:0] resCvtIF = pp_ifZero ? 32'd0 : {pp_ifSign, ifExpF, ifFrac};
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
// PIPELINE: register the shifted magnitude so the saturate/clamp is a separate stage.
wire [63:0] fiMag_c     = fiLeft ? fiLsh : ({32'd0, fiRsInt} + {63'd0, fiRup});
wire        fiInexact_c = fiLeft ? 1'b0 : (fiG | fiS);
reg  [63:0] pp_fiMag; reg pp_fiInexact; // ### pipeline reg.
wire [63:0] fiMag   = pp_fiMag;
wire        fiInexact = pp_fiInexact;

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

// ===== normalized unpack (unify normal + subnormal): value = sig * 2^(eU-23), sig has bit23=1 =====
wire [6:0]  aLz64 = clz64({41'd0, fracA});
wire [5:0]  aLz   = aLz64[5:0] - 6'd41;           // leading zeros within the 23-bit frac
wire [23:0] aSig  = normalA ? {1'b1, fracA} : (24'(fracA) << (aLz + 6'd1));
wire signed [11:0] aEU = normalA ? ($signed({4'b0, expA}) - 12'sd127)
                                 : (-12'sd127 - $signed({6'b0, aLz}));
wire        normalB = (expB != 8'd0 && expB != 8'hff);
wire [6:0]  bLz64 = clz64({41'd0, fracB});
wire [5:0]  bLz   = bLz64[5:0] - 6'd41;
wire [23:0] bSig  = normalB ? {1'b1, fracB} : (24'(fracB) << (bLz + 6'd1));
wire signed [11:0] bEU = normalB ? ($signed({4'b0, expB}) - 12'sd127)
                                 : (-12'sd127 - $signed({6'b0, bLz}));

// ===== fmul =====
// Pipelined: the 24x24 product is registered (pp_mulP) so the multiply is its own stage,
// off the unpack→normalize→pack combinational chain. Downstream reads pp_mulP.
wire        mulSign = signA ^ signB;
wire [47:0] mulP    = aSig * bSig;                 // 24x24 product (registered into pp_mulP)
reg  [47:0] pp_mulP; // ### pipeline reg (clocked below).
wire        mulTop  = pp_mulP[47];
wire [23:0] mulMant = mulTop ? pp_mulP[47:24] : pp_mulP[46:23];
wire        mulG    = mulTop ? pp_mulP[23]    : pp_mulP[22];
wire        mulS    = mulTop ? (|pp_mulP[22:0]) : (|pp_mulP[21:0]);
wire signed [11:0] mulEbU = aEU + bEU + (mulTop ? 12'sd1 : 12'sd0) + 12'sd127; // biased
wire        mulIZ = (isInfA && isZeroB) || (isZeroA && isInfB);
wire        mulSpecial = isNaNA || isNaNB || isInfA || isInfB || isZeroA || isZeroB;
reg  [31:0] mulSpecRes; reg [4:0] mulSpecFlg; // ### comb-block-reg.
always_comb begin
	if (isNaNA || isNaNB)       begin mulSpecRes = CANON_QNAN;            mulSpecFlg = {eitherSNaN,4'd0}; end
	else if (mulIZ)             begin mulSpecRes = CANON_QNAN;            mulSpecFlg = 5'b10000; end // inf*0
	else if (isInfA || isInfB)  begin mulSpecRes = {mulSign, 8'hff, 23'd0}; mulSpecFlg = 5'b0; end
	else                        begin mulSpecRes = {mulSign, 31'd0};     mulSpecFlg = 5'b0; end // zero
end

// ===== fadd / fsub (fsub flips b's sign) =====
wire effSb = signB ^ (optype == OP_SUB);
wire aBigger = (aEU > bEU) || ((aEU == bEU) && (aSig >= bSig));
wire        bigSign = aBigger ? signA : effSb;
wire signed [11:0] bigEU = aBigger ? aEU : bEU;
wire [23:0] bigSig = aBigger ? aSig : bSig;
wire        smlSign = aBigger ? effSb : signA;
wire [23:0] smlSig = aBigger ? bSig : aSig;
wire signed [11:0] addExpDiff = aBigger ? (aEU - bEU) : (bEU - aEU); // >= 0
// Align with explicit guard/round/sticky (bits [2:0]) so SUBTRACTION borrows correctly
// when the small operand is fully shifted out (a tiny opposite-sign operand must pull the
// result just below the large mantissa, not merely set sticky).
wire        addSame  = (bigSign == smlSign);
wire [26:0] bigA     = {bigSig, 3'b000};           // mantissa[26:3], G/R/S at [2:0]
wire [26:0] smlBase  = {smlSig, 3'b000};
wire [7:0]  addD     = (addExpDiff > 12'sd27) ? 8'd27 : addExpDiff[7:0];
wire [26:0] smlSh    = smlBase >> addD;
wire        smlLost  = |(smlBase & (((27'd1) << addD) - 27'd1)); // bits shifted off bit0
wire [26:0] smlAligned = {smlSh[26:1], (smlSh[0] | smlLost)};    // collapse lost bits into sticky
// PIPELINE: register the align+add result so the unpack+align+add is its own stage,
// separate from the leading-cancellation clz-normalize + packer-input select.
wire [27:0] addR28_c = addSame ? ({1'b0, bigA} + {1'b0, smlAligned})
                               : ({1'b0, bigA} - {1'b0, smlAligned});
reg  [27:0] pp_addR28; // ### pipeline reg (clocked below).
wire [27:0] addR28   = pp_addR28;
wire        addZero  = (addR28 == 28'd0);
wire [6:0]  addLz    = clz64({36'd0, addR28}) - 7'd36;
wire [27:0] addNorm  = addR28 << addLz;            // MSB -> bit27
wire [23:0] addMant  = addNorm[27:4];
wire        addG     = addNorm[3];
wire        addS     = |addNorm[2:0];
wire signed [11:0] addEbU = bigEU + 12'sd1 - $signed({5'b0, addLz}) + 12'sd127; // biased
wire        addSign  = bigSign;
wire        addBothZero = isZeroA && isZeroB;
wire        addSpecial  = isNaNA || isNaNB || isInfA || isInfB || addBothZero || addZero;
reg  [31:0] addSpecRes; reg [4:0] addSpecFlg; // ### comb-block-reg.
wire        zSign = (rm == 3'b010) ? 1'b1 : 1'b0;  // cancellation/0+0 -> +0, except RDN -> -0
always_comb begin
	if (isNaNA || isNaNB)               begin addSpecRes = CANON_QNAN; addSpecFlg = {eitherSNaN,4'd0}; end
	else if (isInfA && isInfB)          begin
		if (signA == effSb)             begin addSpecRes = {signA, 8'hff, 23'd0}; addSpecFlg = 5'b0; end
		else                            begin addSpecRes = CANON_QNAN;            addSpecFlg = 5'b10000; end
	end
	else if (isInfA)                    begin addSpecRes = {signA, 8'hff, 23'd0}; addSpecFlg = 5'b0; end
	else if (isInfB)                    begin addSpecRes = {effSb, 8'hff, 23'd0}; addSpecFlg = 5'b0; end
	else if (addBothZero)               begin addSpecRes = {((signA==effSb)?signA:zSign), 31'd0}; addSpecFlg = 5'b0; end
	else /* addZero (cancellation) */   begin addSpecRes = {zSign, 31'd0}; addSpecFlg = 5'b0; end
end

// ===== fdiv / fsqrt (iterative; the recurrence runs in the FSM below) =====
reg  [29:0] fRem;  // remainder
reg  [25:0] fQuo;  // quotient (div) / root (sqrt): {hidden, 23 frac, guard, round}
reg  [51:0] fRad;  // sqrt radicand shift register
reg  [5:0]  cntr;  // iteration counter
localparam ITERLAST = 6'd26; // 26 quotient/root bits (24 mantissa + guard + round)

// div: dividend = sigA prescaled so dividend/sigB is in [1,2).
wire        divSign = signA ^ signB;
wire        divLt   = (aSig < bSig);
wire signed [11:0] divEb = (aEU - bEU - (divLt ? 12'sd1 : 12'sd0)) + 12'sd127;
wire [23:0] divMant = fQuo[25:2];
wire        divG    = fQuo[1];
wire        divS    = fQuo[0] | (fRem != 30'd0);
wire        divSpecial = isNaNA || isNaNB || isInfA || isInfB || isZeroA || isZeroB;
reg  [31:0] divSpecRes; reg [4:0] divSpecFlg; // ### comb-block-reg.
always_comb begin
	if (isNaNA || isNaNB)        begin divSpecRes = CANON_QNAN;             divSpecFlg = {eitherSNaN,4'd0}; end
	else if (isInfA && isInfB)   begin divSpecRes = CANON_QNAN;             divSpecFlg = 5'b10000; end // inf/inf
	else if (isZeroA && isZeroB) begin divSpecRes = CANON_QNAN;             divSpecFlg = 5'b10000; end // 0/0
	else if (isInfA)             begin divSpecRes = {divSign, 8'hff, 23'd0};divSpecFlg = 5'b0; end // inf/finite
	else if (isInfB)             begin divSpecRes = {divSign, 31'd0};       divSpecFlg = 5'b0; end // finite/inf
	else if (isZeroB)            begin divSpecRes = {divSign, 8'hff, 23'd0};divSpecFlg = 5'b01000; end // x/0 -> inf, DZ
	else /* isZeroA */           begin divSpecRes = {divSign, 31'd0};       divSpecFlg = 5'b0; end // 0/finite
end

// sqrt
wire signed [11:0] sqrtEb = (aEU >>> 1) + 12'sd127; // floor(aEU/2)
wire [23:0] sqrtMant = fQuo[25:2];
wire        sqrtG    = fQuo[1];
wire        sqrtS    = fQuo[0] | (fRem != 30'd0);
wire        sqrtSpecial = isNaNA || isZeroA || signA || isInfA;
reg  [31:0] sqrtSpecRes; reg [4:0] sqrtSpecFlg; // ### comb-block-reg.
always_comb begin
	if (isNaNA)       begin sqrtSpecRes = CANON_QNAN;           sqrtSpecFlg = {isSNaNA,4'd0}; end
	else if (isZeroA) begin sqrtSpecRes = {signA, 31'd0};       sqrtSpecFlg = 5'b0; end // sqrt(+/-0) = +/-0
	else if (signA)   begin sqrtSpecRes = CANON_QNAN;           sqrtSpecFlg = 5'b10000; end // sqrt(neg)
	else /* isInfA */ begin sqrtSpecRes = {1'b0, 8'hff, 23'd0}; sqrtSpecFlg = 5'b0; end // +inf
end

// recurrence-step combinational helpers (one quotient/root bit per cycle).
wire        divCmp     = (fRem >= {6'd0, bSig});
wire [29:0] divRemNext = ((divCmp ? (fRem - {6'd0, bSig}) : fRem) << 1);
wire [29:0] sqRem2     = {fRem[27:0], fRad[51:50]};         // (fRem << 2) | next 2 radicand bits
wire [29:0] sqTrial    = {2'd0, fQuo, 2'b01};               // (root << 2) | 1
wire        sqCmp      = (sqTrial <= sqRem2);
wire [29:0] sqRemNext  = (sqCmp ? (sqRem2 - sqTrial) : sqRem2);
// init values (from the now-valid unpacked operands, on the first post-stb cycle).
wire [29:0] divInitRem = divLt ? {5'd0, aSig, 1'b0} : {6'd0, aSig}; // dividend = sigA<<1 or sigA
wire [24:0] sqrtMint   = aEU[0] ? {aSig, 1'b0} : {1'b0, aSig};            // 1.frac or 2*1.frac

// ===== shared round + pack to binary32 (normal / overflow / subnormal) =====
// Inputs selected by optype: a normalized 1.frac significand pkM (bit23=1), its SIGNED
// biased exponent pkEb, guard pkG, sticky pkS, sign pkSign.
reg        pkSign;          // ### comb-block-reg.
reg signed [11:0] pkEb;     // ### comb-block-reg.
reg [23:0] pkM;             // ### comb-block-reg.
reg        pkG, pkS;        // ### comb-block-reg.
always_comb begin
	pkSign = mulSign; pkEb = mulEbU; pkM = mulMant; pkG = mulG; pkS = mulS;
	if (optype == OP_ADD || optype == OP_SUB) begin
		pkSign = addSign; pkEb = addEbU; pkM = addMant; pkG = addG; pkS = addS;
	end
	if (optype == OP_DIV)  begin pkSign = divSign; pkEb = divEb;  pkM = divMant;  pkG = divG;  pkS = divS;  end
	if (optype == OP_SQRT) begin pkSign = 1'b0;    pkEb = sqrtEb; pkM = sqrtMant; pkG = sqrtG; pkS = sqrtS; end
end
// PIPELINE STAGE BOUNDARY: register the packer inputs + the fmul product, so the round +
// 48-bit subnormal denormalize-shift + overflow logic is its own timing stage (pp_pk*),
// separate from the op-specific front-end compute. rm comes from the held `operands`, stable.
reg        pp_pkSign; // ### pipeline reg.
reg signed [11:0] pp_pkEb;
reg [23:0] pp_pkM;
reg        pp_pkG, pp_pkS;
always_ff @(posedge clk_i) begin
	pp_mulP   <= mulP;
	pp_addR28 <= addR28_c;
	pp_pkSign <= pkSign; pp_pkEb <= pkEb; pp_pkM <= pkM; pp_pkG <= pkG; pp_pkS <= pkS;
	pp_ifAln  <= ifAln; pp_ifExp <= ifExp; pp_ifSign <= ifSign; pp_ifZero <= ifZero;
	pp_fiMag  <= fiMag_c; pp_fiInexact <= fiInexact_c;
end

// PACKER STAGE A: the 48-bit subnormal denormalize-shift (the deep part). Register its
// output + the off-shifted sticky + forward the pk inputs into stage B (pp2_*).
wire signed [11:0] pkShS = 12'sd1 - pp_pkEb;
wire [7:0]  pkShC = (pkShS > 12'sd48) ? 8'd48 : pkShS[7:0];
wire [47:0] pkExt = {pp_pkM, 24'd0};
wire [47:0] pkExtSh = pkExt >> pkShC;
wire        pkShiftLost = |(pkExt & (((48'd1) << pkShC) - 48'd1)); // bits shifted past bit0

reg        pp2_pkSign; // ### pipeline reg (packer stage B).
reg signed [11:0] pp2_pkEb;
reg [23:0] pp2_pkM;
reg        pp2_pkG, pp2_pkS;
reg [47:0] pp2_pkExtSh;
reg        pp2_pkShiftLost;
always_ff @(posedge clk_i) begin
	pp2_pkSign <= pp_pkSign; pp2_pkEb <= pp_pkEb; pp2_pkM <= pp_pkM;
	pp2_pkG <= pp_pkG; pp2_pkS <= pp_pkS;
	pp2_pkExtSh <= pkExtSh; pp2_pkShiftLost <= pkShiftLost;
end

// PACKER STAGE B: rounding + overflow + final mux, from the registered stage-A values.
wire pkInx = pp2_pkG | pp2_pkS;
wire pkToInf = (rm == 3'b000) || (rm == 3'b100) || (rm == 3'b011 && !pp2_pkSign) || (rm == 3'b010 && pp2_pkSign);
wire [31:0] pkOvfRes = pkToInf ? {pp2_pkSign, 8'hff, 23'd0} : {pp2_pkSign, 8'hfe, 23'h7fffff};
wire [23:0] pkSubM = pp2_pkExtSh[47:24];
wire        pkSubG = pp2_pkExtSh[23];
wire        pkSubS = pp2_pkG | pp2_pkS | (|pp2_pkExtSh[22:0]) | pp2_pkShiftLost;
wire        pkSubRup = roundUp(pkSubM[0], pkSubG, pkSubS, pp2_pkSign, rm);
wire [24:0] pkSubMr  = {1'b0, pkSubM} + {24'd0, pkSubRup};
wire        pkSubInx = pkSubG | pkSubS;
// Tininess (after rounding): tiny unless rounding the NORMALIZED mantissa would carry up into
// the normal range. Needed so a subnormal that rounds up to the smallest normal still flags UF.
wire [24:0] pkNormMr   = {1'b0, pp2_pkM} + {24'd0, roundUp(pp2_pkM[0], pp2_pkG, pp2_pkS, pp2_pkSign, rm)};
wire        pkIsTiny   = (pp2_pkEb < 12'sd0) || ((pp2_pkEb == 12'sd0) && !pkNormMr[24]);
reg  [31:0] pkRes; reg [4:0] pkFlg; // ### comb-block-reg.
always_comb begin
	if (pp2_pkEb >= 12'sd255) begin                     // overflow before rounding
		pkRes = pkOvfRes; pkFlg = 5'b00101;             // OF | NX
	end else if (pp2_pkEb <= 12'sd0) begin              // subnormal / underflow
		pkRes = {pp2_pkSign, 7'd0, pkSubMr[23:0]};      // exp = pkSubMr[23] (1 if rounded up to smallest normal)
		pkFlg = {1'b0,1'b0,1'b0, (pkSubInx && pkIsTiny), pkSubInx}; // UF, NX
	end else begin                                      // normal range
		logic rup; logic [24:0] mr;
		rup = roundUp(pp2_pkM[0], pp2_pkG, pp2_pkS, pp2_pkSign, rm);
		mr = {1'b0, pp2_pkM} + {24'd0, rup};
		if (mr[24] && (pp2_pkEb == 12'sd254)) begin     // rounding overflowed into inf range
			pkRes = pkOvfRes; pkFlg = 5'b00101;
		end else if (mr[24]) begin                      // mantissa carry -> 1.0, exp+1
			pkRes = {pp2_pkSign, (pp2_pkEb[7:0] + 8'd1), 23'd0}; pkFlg = {4'd0, pkInx};
		end else begin
			pkRes = {pp2_pkSign, pp2_pkEb[7:0], mr[22:0]}; pkFlg = {4'd0, pkInx};
		end
	end
end

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
	OP_MUL:          begin rslt_o = mulSpecial ? mulSpecRes : pkRes; flags_o = mulSpecial ? mulSpecFlg : pkFlg; end
	OP_ADD, OP_SUB:  begin rslt_o = addSpecial ? addSpecRes : pkRes; flags_o = addSpecial ? addSpecFlg : pkFlg; end
	OP_DIV:          begin rslt_o = divSpecial ? divSpecRes : pkRes; flags_o = divSpecial ? divSpecFlg : pkFlg; end
	OP_SQRT:         begin rslt_o = sqrtSpecial ? sqrtSpecRes : pkRes; flags_o = sqrtSpecial ? sqrtSpecFlg : pkFlg; end
	default: begin rslt_o = {WORDBITSZ{1'b0}}; flags_o = 5'b0; end
	endcase
end

// Only non-special fdiv/fsqrt iterate; every other op (incl special div/sqrt) is short.
wire optIter = ((optype == OP_DIV && !divSpecial) || (optype == OP_SQRT && !sqrtSpecial));
// Total latency to rdy_o (cycles after stb). The pp_* pipeline registers clock every cycle;
// only the value at rdy_o is sampled. shallow: 2; fcvt: 3 (shift reg); fadd/fsub/fmul: 4
// (front-end reg + 2-stage packer); div/sqrt: ITERLAST iterations + 4 (2-stage pack tail).
wire isCvt = (optype == OP_CVTWS || optype == OP_CVTWUS || optype == OP_CVTSW || optype == OP_CVTSWU);
wire [6:0] opLat = optIter           ? ({1'b0, ITERLAST} + 7'd4)
                 : (optype == OP_MUL || optype == OP_ADD || optype == OP_SUB) ? 7'd4
                 : isCvt              ? 7'd3
                 :                      7'd2;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		rdy_o <= 1;
	end else if (rdy_o) begin
		if (stb_i) begin
			operands <= args_i;
			rdy_o    <= 0;
			cntr     <= 0;
		end
	end else begin
		// div/sqrt recurrence: cntr 0 = init, 1..ITERLAST = one quotient/root bit each.
		if (optIter) begin
			if (cntr == 6'd0) begin
				if (optype == OP_DIV) begin fRem <= divInitRem; fQuo <= 26'd0; end
				else                  begin fRad <= {sqrtMint, 27'd0}; fRem <= 30'd0; fQuo <= 26'd0; end
			end else if (cntr <= ITERLAST) begin
				if (optype == OP_DIV) begin fRem <= divRemNext; fQuo <= {fQuo[24:0], divCmp}; end
				else                  begin fRem <= sqRemNext;  fQuo <= {fQuo[24:0], sqCmp}; fRad <= {fRad[49:0], 2'b0}; end
			end
		end
		if ({1'b0, cntr} == (opLat - 7'd2)) rdy_o <= 1;
		cntr <= cntr + 6'd1;
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
