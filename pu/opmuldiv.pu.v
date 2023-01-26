// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The implementation of the multiplication and division
// is documented at the end of this file.

module muldiv (

	 rst_i

	,clk_i

	,stb_i

	,data_i
	,data_o
	,gprid_o

	,rdy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;
parameter GPRCNT    = 32;

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2GPRCNT    = clog2(GPRCNT);

// Significance of each bit in the field within data_i
// storing the type of multiplication or division to perform.
// [3]: 0/1 mean integer/floating-point computation.
// [2]: 0/1 mean multiplication/division or fadd/fsub depending on [1].
// [1]: When doing integer multiplication/division,
// 	0/1 mean unsigned/signed computation.
// 	When doing floating-point computation,
// 	0/1 mean fmul/fdiv when [2] is 0,
// 	and mean fadd/fsub when [2] is 1.
// [0]: When doing multiplication, 0/1 mean ARCHBITSZ lsb/msb of result.
// 	When doing division, 0/1 mean quotient/remainder of result.
// 	Ignored when doing floating-point multiplication/division.
localparam MULDIVTYPEBITSZ = 4;
localparam MULDIVMSBRSLT   = ((ARCHBITSZ*2)+CLOG2GPRCNT);
localparam MULDIVSIGNED    = ((ARCHBITSZ*2)+CLOG2GPRCNT+1);
localparam MULDIVISDIV     = ((ARCHBITSZ*2)+CLOG2GPRCNT+2);
localparam MULDIVISFLOAT   = ((ARCHBITSZ*2)+CLOG2GPRCNT+3);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication or division to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_i;

// Net set to the result of the multiplication or division.
// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
output reg [ARCHBITSZ -1 : 0] data_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o = 0;

// Register in which the multiplication or division will be computed.
reg  [(ARCHBITSZ*2) -1 : 0] cumulator        = 0;
wire [(ARCHBITSZ*2) -1 : 0] cumulatornegated = -cumulator;

`ifndef PUDSPMUL
// Net used by the multiplication; compute the multiplier
// times 0, 1, 2 or 3 based on cumulator[1:0].
// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg [(ARCHBITSZ+2) -1 : 0] mulx;
`endif

// Net set to the right operand value of the multiplication/division,
// which is the multiplier/divider.
// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
reg [ARCHBITSZ -1 : 0] rval;

// Net used by the division; compute the difference
// between the quotient and the left shifted divider.
wire [(ARCHBITSZ*2) -1 : 0] divdiff = (cumulator - ({rval, {(ARCHBITSZ-1){1'b0}}}));

`ifndef PUDSPMUL
// ### Used so that verilog simulation would work.
wire [(ARCHBITSZ+2) -1 : 0] cumulatoroperand = (mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]);
`endif

// For the multiplication, this register is used to count the number
// of two bits set already used from the multiplier, and only
// cntr[(CLOG2ARCHBITSZ-1)-1:0] are used; for the division,
// this register is used to count the number of bits already used
// from the divider, and all its bits are used.
reg [CLOG2ARCHBITSZ -1 : 0] cntr = 0;

reg inprogress = 0;

reg start = 0;

// Register used to capture data_i.
reg [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] operands = 0;

assign gprid_o = operands[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2];

always @* begin
	// If operands[MULDIVSIGNED] == 0, it is an unsigned computation.
	// If operands[MULDIVSIGNED] == 1, it is a signed computation.
	// For a signed computation, I turn the right operand positive if it was negative.
	if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ-1)])
		rval = -operands[ARCHBITSZ-1:0];
	else
		rval = operands[ARCHBITSZ-1:0];

	`ifndef PUDSPMUL
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
	`endif

	// Logic setting data_o using the result computed in cumulator.
	`ifndef PUDSPMUL
	if (operands[MULDIVISDIV]) begin
	`endif
		// Division logic.

		// When operands[MULDIVMSBRSLT] == 0, the quotient is used as result.
		// When operands[MULDIVMSBRSLT] == 1, the remainder is used as result.
		// When operands[MULDIVSIGNED] == 0, an unsigned division was done.
		// When operands[MULDIVSIGNED] == 1, a signed division was done.
		if (operands[MULDIVMSBRSLT]) begin
			// If I get here, the remainder is used as result.
			// The sign of the remainder is the same as the sign of the dividend.
			if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ*2)-1])
				data_o = -cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
			else
				data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

		end else begin
			// If I get here, the quotient is used as result.
			// The sign of the quotient is positive if the dividend
			// and divisor have the same sign otherwise it is negative.
			if (operands[MULDIVSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]))
				data_o = -cumulator[ARCHBITSZ-1:0];
			else
				data_o = cumulator[ARCHBITSZ-1:0];
		end
	`ifndef PUDSPMUL
	end else begin
		// Multiplication logic.

		// When operands[MULDIVMSBRSLT] == 0, the ARCHBITSZ lsb are used as result.
		// When operands[MULDIVMSBRSLT] == 1, the ARCHBITSZ msb are used as result.
		// When operands[MULDIVSIGNED] == 0, an unsigned multiplication was done.
		// When operands[MULDIVSIGNED] == 1, a signed multiplication was done.
		if (operands[MULDIVMSBRSLT]) begin
			// The sign of the result is positive if the multiplicand
			// and multiplier have the same sign otherwise it is negative.
			if (operands[MULDIVSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]))
				data_o = cumulatornegated[(ARCHBITSZ*2)-1:ARCHBITSZ];
			else
				data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

		end else begin
			// When only the ARCHBITSZ lsb of the multiplication are used,
			// there is no difference between a signed and unsigned multiplication.
			data_o = cumulator[ARCHBITSZ-1:0];
		end
	end
	`endif
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin
			inprogress <= 0;
			start <= 1;
			operands <= data_i;
			rdy_o <= 0;
		end

	end else begin

		if (inprogress) begin
			// When operands[MULDIVISDIV] is 1, division
			// is performed, otherwise multiplication is performed.
			`ifndef PUDSPMUL
			if (operands[MULDIVISDIV]) begin
			`endif
				// Division logic.

				// divdiff[(ARCHBITSZ*2)-1] is 1 when
				// the difference is negative, otherwise it is 0.
				if (divdiff[(ARCHBITSZ*2)-1])
					cumulator <= {cumulator[(ARCHBITSZ*2)-2:0], 1'b0};
				else
					cumulator <= {divdiff[(ARCHBITSZ*2)-2:0], 1'b1};

				if (&cntr) begin
					// The division is complete after cntr
					// has been incremented ARCHBITSZ times; the result will be
					// ready in cumulator after the next clockedge.
					rdy_o <= 1;
					inprogress <= 0;
					start <= 0;
				end
			`ifndef PUDSPMUL
			end else begin
				// Multiplication logic.

				// Note that although mulx is 34bits,
				// the result of mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]
				// will never generate a carry, because
				// mulx[(ARCHBITSZ+1):ARCHBITSZ] is guaranteed to never
				// be greater than 2'b10.
				// ### mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]
				// ### was computed in cumulatoroperand so that
				// ### verilog simulation would work.
				// ### cumulatoroperand is 34bits.
				cumulator <= {cumulatoroperand, cumulator[ARCHBITSZ-1:2]};

				if (&(cntr[(CLOG2ARCHBITSZ-1)-1:0])) begin
					// The multiplication is complete after cntr
					// has been incremented (ARCHBITSZ/2) times; the result will
					// be ready in cumulator after the next clockedge.
					rdy_o <= 1;
					inprogress <= 0;
					start <= 0;
				end
			end
			`endif

			cntr <= cntr + 1'b1;

		end else if (start) begin
			// Note that the multiplication use only the 4lsb
			// while the division use all 5bits of cntr.
			cntr <= 0;

			// When doing a multiplication:
			// the multiplicand is in operands[(ARCHBITSZ*2)-1:ARCHBITSZ],
			// the multiplier is in operands[ARCHBITSZ-1:0].
			// When doing a division:
			// the dividend is in operands[(ARCHBITSZ*2)-1:ARCHBITSZ],
			// the divider is in operands[ARCHBITSZ-1:0].

			// If operands[MULDIVSIGNED] == 0, an unsigned computation is to be done.
			// If operands[MULDIVSIGNED] == 1, a signed computation is to be done.
			// If a signed computation is to be done, I turn the left operand positive if it was negative.
			if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ*2)-1])
				cumulator <= {{ARCHBITSZ{1'b0}}, -operands[(ARCHBITSZ*2)-1:ARCHBITSZ]};
			else
				cumulator <= {{ARCHBITSZ{1'b0}}, operands[(ARCHBITSZ*2)-1:ARCHBITSZ]};

			inprogress <= 1;
		end
	end
end

endmodule

// clk_muldiv_i frequency must be clk_i frequency times a power-of-2.
module opmuldiv (

	 rst_i

	,clk_i
	,clk_muldiv_i

	,stb_i
	,data_i
	,rdy_o

	,ostb_i
	,data_o
	,gprid_o
	,ordy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;
parameter GPRCNT    = 32;
parameter DEPTH     = 32; // pipeline depth.

localparam CLOG2GPRCNT = clog2(GPRCNT);

// Significance of each bit in the field within data_i
// storing the type of multiplication or division to perform.
// [3]: 0/1 mean integer/floating-point computation.
// [2]: 0/1 mean multiplication/division or fadd/fsub depending on [1].
// [1]: When doing integer multiplication/division,
// 	0/1 mean unsigned/signed computation.
// 	When doing floating-point computation,
// 	0/1 mean fmul/fdiv when [2] is 0,
// 	and mean fadd/fsub when [2] is 1.
// [0]: When doing multiplication, 0/1 mean ARCHBITSZ lsb/msb of result.
// 	When doing division, 0/1 mean quotient/remainder of result.
// 	Ignored when doing floating-point multiplication/division.
localparam MULDIVTYPEBITSZ = 4;

// Number of muldiv to instantiate.
// It is the minimum between the max number of cycles
// of a computation, and the total number of GPRs. ie:
// for 64bits, the max number of cycles of a computation is 64;
// there are 32 GPRs, so the muldiv buffer should be 32 because
// it is the minimum for which there would always be enough space
// to add a new computation.
localparam MULDIVCNT_     = ((ARCHBITSZ < GPRCNT) ? ARCHBITSZ : GPRCNT);
localparam MULDIVCNT      = ((MULDIVCNT_ < DEPTH) ? MULDIVCNT_ : DEPTH);
localparam CLOG2MULDIVCNT = clog2(MULDIVCNT);

input wire rst_i;

input wire clk_i;
input wire clk_muldiv_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication or division to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the multiplication or division.
output wire [ARCHBITSZ -1 : 0] data_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2MULDIVCNT +1) -1 : 0] wridx = 0;
reg [(CLOG2MULDIVCNT +1) -1 : 0] rdidx = 0;

wire [(CLOG2MULDIVCNT +1) -1 : 0] usage;
assign usage = (wridx - rdidx);

wire [ARCHBITSZ -1 : 0] data_w [MULDIVCNT -1 : 0];
assign data_o = data_w[rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [MULDIVCNT -1 : 0];
assign gprid_o = gprid_w[rdidx];

wire [MULDIVCNT -1 : 0] rdy_w;

assign rdy_o = ((usage < MULDIVCNT) && rdy_w[wridx]);

assign ordy_o = ((usage != 0) && rdy_w[rdidx]);

`ifdef PUMULDIVCLK
reg                                                        stb_r = 0;
reg                                                        rdy_r = 0;
reg [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_r;
`else
wire                                                        stb_r  = stb_i;
wire                                                        rdy_r  = rdy_o;
wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_r = data_i;
`endif

always @ (posedge clk_i) begin

	if (rdy_r && stb_r)
		wridx <= wridx + 1'b1;

	`ifdef PUMULDIVCLK
	// With clk_muldiv_i faster than clk_i, muldiv signals stb_i data_i must be
	// synchronized to clk_i so to be stable input values; it also means that
	// muldiv sigmal rdy_o posegde must happen (freq(clk_muldiv_i)/freq(clk_i))
	// clk_muldiv_i cycles after its negedge; which is guarateed by the fact that
	// the shortest muldiv computation takes (ARCHBITSZ/2) clk_muldiv_i cycles.
	stb_r  <= stb_i;
	rdy_r  <= rdy_o;
	data_r <= data_i;
	`endif
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		rdidx <= wridx;
	end else if (ordy_o && ostb_i)
		rdidx <= rdidx + 1'b1;
end

genvar gen_muldiv_idx;
generate for (gen_muldiv_idx = 0; gen_muldiv_idx < MULDIVCNT; gen_muldiv_idx = gen_muldiv_idx + 1) begin :gen_muldiv
muldiv #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)

) muldiv (

	 .rst_i (rst_i)

	`ifdef PUMULDIVCLK
	,.clk_i (clk_muldiv_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (stb_r && (wridx[CLOG2MULDIVCNT -1 : 0] == gen_muldiv_idx))

	,.data_i  (data_r)
	,.data_o  (data_w[gen_muldiv_idx])
	,.gprid_o (gprid_w[gen_muldiv_idx])

	,.rdy_o (rdy_w[gen_muldiv_idx])
);
end endgenerate

endmodule

// Implementation of the multiplication.
//
// Radix-2 Multiplication
// 	The multiplier is examined
// 	one bit at a time.
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
// Radix-4 Multiplication
// 	The multiplier is examined two bits at a time.
// 	Twice as fast as radix-2.
//
// 	Let "a" denotes the multiplicand
// 	and b denotes the multiplier.
// 	Pre-compute 2a and 3a.
// 	Examine multiplier two bits at
// 	a time (rather than one bit at a time);
// 	based on the value of those bits
// 	add 0, a, 2a, or 3a (shifted by
// 	the appropriate amount).
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
//
// This implementation use radix-4.
//
// Signed multiplication is implemented by using the absolute value
// of operands and later remembering what were their signs.

// Implementation of the division.
//
// 4bits binary division when done by hand:
//
// 11 divided by 3:
//
// 11 (1011) is dividend.
//  3 (0011) is divider.
//
//  """"""""|
//     1011 |
// -0011    |
//  """"""""|    0  Difference is negative: copy dividend and put 0 in quotient.
//     1011 |
//  -0011   |
//  """"""""|   00  Difference is negative: copy dividend and put 0 in quotient.
//     1011 |
//   -0011  |
//  """"""""|  001  Difference is positive: use difference and put 1 in quotient.
//     0101 |
//    -0011 |
//  """"""""| 0011  Difference is positive: use difference and put 1 in quotient.
//       10 |
//
// Remainder 2 (0010); Quotient, 3 (0011).
//
// The division logic is implemented as follow:
// The remainder and quotient use the same
// register; 0 is shifted-in from the right
// everytime the divider is greater than
// the quotien, otherwise 1 is shifted-in
// from the right.
// The example below is a 4bits division,
// hence four shift are needed; rq stands
// for remainder-quotient.
// At the end of the four shifts,
// the remainder is in the 4 msb of rq
// while the quotient is in the 4 lsb
// of rq.
//
//  """"""""|
//     1011 |   0000 1011     <- rq reg.
// -0011    |   -001 1        <- divider (never changes).
//  """"""""|   0000 1011     <- rq reg before shift.
//     1011 |   0001 0110     <- after shift.
//  -0011   |   -001 1
//  """"""""|   0001 0110     <- rq reg before shift.
//     1011 |   0010 1100     <- after shift.
//   -0011  |   -001 1
//  """"""""|   0001 0100     <- rq reg before shift.
//     0101 |   0010 1001     <- after shift.
//    -0011 |   -001 1
//  """"""""|   0001 0001     <- rq reg before shift.
//     0010 |   0010 0011     <- after shift.
//
// Remainder 2 (0010); Quotient, 3 (0011).
//
// Signed division is implemented by using the absolute value
// of operands and later remembering what were their signs.
//
// The sign of the quotient is positive if the dividend
// and divisor have the same sign otherwise it is negative.
// The sign of the remainder is the same as the sign
// of the dividend.
//
// Dividend  Divisor  |  Quotient  Remainder  |  Example
// -------------------+-----------------------+---------------------------
//    +        +      |      +        +       |  +85 / +7 == +12;  R == +1
//    +        -      |      -        +       |  +85 / -7 == -12;  R == +1
//    -        +      |      -        -       |  -85 / +7 == -12;  R == -1
//    -        -      |      +        -       |  -85 / -7 == +12;  R == -1
