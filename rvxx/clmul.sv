// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Carry-less multiply (RISC-V Zbc: clmul/clmulh/clmulr) as a multi-cycle unit,
// modeled on the idiv unit. One bit of rs2 is consumed per cycle (WORDBITSZ
// cycles); the full carry-less product accumulates in cumulator, and the
// requested slice is selected by the type field. See the note at end of file.

module clmul (

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

// Net set to the result of the carry-less multiply.
output reg [WORDBITSZ -1 : 0] rslt_o; // ### comb-block-reg.

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Register in which the carry-less product accumulates.
// The full product spans bits [(2*WORDBITSZ)-2:0]; bit [(2*WORDBITSZ)-1] stays 0.
reg [(WORDBITSZ*2) -1 : 0] cumulator;

// rs1 (the multiplicand), zero-extended to the product width and shifted left one
// position per cycle. It MUST be (2*WORDBITSZ) wide so partials rs1<<i (i up to
// WORDBITSZ-1) reach product bit (2*WORDBITSZ)-2; a WORDBITSZ-wide reg would drop
// the high product bits and break clmulh/clmulr.
reg [(WORDBITSZ*2) -1 : 0] rval;
// rs2 (the multiplier), consumed LSB-first one bit per cycle.
reg [WORDBITSZ -1 : 0] rmul;

// Register used to count the number of bits already consumed from rs2.
reg [CLOG2WORDBITSZ -1 : 0] cntr;

// Reg used to capture args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2];

wire [CLMULTYPEBITSZ -1 : 0] optype = operands[CLMULTYPELSB +: CLMULTYPEBITSZ];

always_comb begin
	// Select the requested slice of the full carry-less product P (in cumulator).
	case (optype)
	2'b11:   rslt_o = cumulator[(WORDBITSZ*2)-1 : WORDBITSZ];   // clmulh: P[2n-1:n]
	2'b10:   rslt_o = cumulator[(WORDBITSZ*2)-2 : WORDBITSZ-1]; // clmulr: P[2n-2:n-1]
	default: rslt_o = cumulator[WORDBITSZ-1 : 0];               // clmul : P[n-1:0]
	endcase
end

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin

			operands <= args_i;

			cumulator <= {(WORDBITSZ*2){1'b0}};
			// rs1 zero-extended to the product width; rs2 is the multiplier.
			rval <= {{WORDBITSZ{1'b0}}, args_i[(WORDBITSZ*2)-1:WORDBITSZ]};
			rmul <= args_i[WORDBITSZ-1:0];

			rdy_o <= 0;

			cntr <= 0;
		end

	end else begin
		// Carry-less multiply step: XOR rs1<<i into the product when rs2 bit i is
		// set, then shift rs1 up by one and bring in the next rs2 bit.
		cumulator <= (cumulator ^ (rmul[0] ? rval : {(WORDBITSZ*2){1'b0}}));
		rval <= {rval[(WORDBITSZ*2)-2 : 0], 1'b0}; // rs1 << (i+1)
		rmul <= {1'b0, rmul[WORDBITSZ-1 : 1]};     // next rs2 bit into bit 0

		if (cntr == (WORDBITSZ-1)) begin
			// Complete after WORDBITSZ steps (one rs2 bit each); the result is
			// ready in cumulator after the next clockedge.
			rdy_o <= 1;
		end

		cntr <= cntr + 1'b1;
	end
end

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
// Computed here LSB-of-rs2 first, one bit per cycle, accumulating into cumulator.
