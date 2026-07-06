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
localparam ZBBTYPEBITSZ = 5;
localparam [ZBBTYPEBITSZ-1:0]
	ZBB_ANDN  = 5'd0,  ZBB_ORN   = 5'd1,  ZBB_XNOR = 5'd2,
	ZBB_MIN   = 5'd3,  ZBB_MINU  = 5'd4,  ZBB_MAX  = 5'd5,  ZBB_MAXU = 5'd6,
	ZBB_ROL   = 5'd7,  ZBB_ROR   = 5'd8,  ZBB_RORI = 5'd9,
	ZBB_ZEXTH = 5'd10, ZBB_CLZ   = 5'd11, ZBB_CTZ  = 5'd12, ZBB_CPOP = 5'd13,
	ZBB_SEXTB = 5'd14, ZBB_SEXTH = 5'd15, ZBB_REV8 = 5'd16, ZBB_ORCB = 5'd17;

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
function automatic bit [WORDBITSZ -1 : 0] zbb_ctz; // Count trailing zeros.
	input bit [WORDBITSZ -1 : 0] v;
	bit found;
	begin
		zbb_ctz = 0;
		found = 0;
		for (int i = 0; i < WORDBITSZ; ++i)
			if (!found) begin
				if (v[i]) found = 1'b1;
				else      zbb_ctz = zbb_ctz + 1'b1;
			end
	end
endfunction
function automatic bit [WORDBITSZ -1 : 0] zbb_cpop; // Population count.
	input bit [WORDBITSZ -1 : 0] v;
	begin
		zbb_cpop = 0;
		for (int i = 0; i < WORDBITSZ; ++i)
			zbb_cpop = zbb_cpop + v[i];
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

// Rotate via a single right-shifter: ror(x,a) = ({x,x} >> a) low word, rol = ror(x,-a).
// Amount is rs2[4:0] (rol/ror use rs2, rori carries its immediate in the rs2 slot).
wire [5            -1 : 0] zbbRorAmt = (optype == ZBB_ROL) ? (5'd0 - rs2[4:0]) : rs2[4:0];
wire [(2*WORDBITSZ)-1 : 0] zbbDbl    = {rs1, rs1};
wire [WORDBITSZ    -1 : 0] zbbRot    = (zbbDbl >> zbbRorAmt); // low word.

reg [WORDBITSZ -1 : 0] zbbRes; // ### comb-block-reg.
always_comb begin
	case (optype)
	ZBB_ANDN:  zbbRes =  (rs1 & ~rs2);
	ZBB_ORN:   zbbRes =  (rs1 | ~rs2);
	ZBB_XNOR:  zbbRes = ~(rs1 ^  rs2);
	ZBB_MIN:   zbbRes = ($signed(rs1) < $signed(rs2)) ? rs1 : rs2;
	ZBB_MINU:  zbbRes = (rs1 < rs2) ? rs1 : rs2;
	ZBB_MAX:   zbbRes = ($signed(rs1) < $signed(rs2)) ? rs2 : rs1;
	ZBB_MAXU:  zbbRes = (rs1 < rs2) ? rs2 : rs1;
	ZBB_ROL,
	ZBB_ROR,
	ZBB_RORI:  zbbRes = zbbRot;
	ZBB_ZEXTH: zbbRes = {{(WORDBITSZ-16){1'b0}},     rs1[15:0]};
	ZBB_CLZ:   zbbRes = zbb_ctz(reverseBits(rs1)); // clz = ctz of bit-reversed.
	ZBB_CTZ:   zbbRes = zbb_ctz(rs1);
	ZBB_CPOP:  zbbRes = zbb_cpop(rs1);
	ZBB_SEXTB: zbbRes = {{(WORDBITSZ-8){rs1[7]}},   rs1[7:0]};
	ZBB_SEXTH: zbbRes = {{(WORDBITSZ-16){rs1[15]}}, rs1[15:0]};
	ZBB_REV8:  zbbRes = zbb_rev8(rs1);
	default:   zbbRes = zbb_orcb(rs1); // ZBB_ORCB
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
