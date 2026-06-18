// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The implementation of the division is documented at the end of this file.

module idiv (

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
// args_i storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam IDIVTYPEBITSZ = 2;
localparam IDIVMSBRSLT   = ((WORDBITSZ*2)+CLOG2GPRCNT);
localparam IDIVSIGNED    = ((WORDBITSZ*2)+CLOG2GPRCNT+1);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of division to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] args_i;

// Net set to the result of the division.
output reg [WORDBITSZ -1 : 0] rslt_o; // ### comb-block-reg.

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Register in which the division will be computed.
reg  [(WORDBITSZ*2) -1 : 0] cumulator;

// Reg set to the right operand value of the division, which is the divider.
reg [WORDBITSZ -1 : 0] rval;
// 3*|divider|, precomputed once at stb for radix-4 quotient-digit selection.
reg [(WORDBITSZ+2) -1 : 0] rval3;
// |divider| from args_i (signed divisions use the absolute value).
wire [WORDBITSZ -1 : 0] divabsdvsr =
	((args_i[IDIVSIGNED] && args_i[(WORDBITSZ-1)]) ? -args_i[WORDBITSZ-1:0] : args_i[WORDBITSZ-1:0]);

// Radix-4 restoring step (2 quotient bits/cycle). R' is the top (WORDBITSZ+2) bits of
// cumulator (partial remainder with 2 new dividend bits shifted in); a leading 0 supplies
// a sign bit for the three trial subtractions of 1x/2x/3x the divider (computed in
// parallel, so the carry depth stays one ~(WORDBITSZ+2)-bit subtract plus a 4:1 select).
wire [(WORDBITSZ+3) -1 : 0] divRp = {1'b0, cumulator[(WORDBITSZ*2)-1 : (WORDBITSZ-2)]};
wire [(WORDBITSZ+3) -1 : 0] divd1 = (divRp - {3'b0, rval});       // R' - 1*divider
wire [(WORDBITSZ+3) -1 : 0] divd2 = (divRp - {2'b0, rval, 1'b0}); // R' - 2*divider
wire [(WORDBITSZ+3) -1 : 0] divd3 = (divRp - {1'b0, rval3});      // R' - 3*divider
// Quotient digit = largest q in {0,1,2,3} whose trial difference is non-negative;
// divrem is the corresponding reduced remainder (< divider).
reg [2 -1 : 0]         divq;   // ### comb-block-reg.
reg [WORDBITSZ -1 : 0] divrem; // ### comb-block-reg.
always_comb begin
	if      (!divd3[(WORDBITSZ+2)]) begin divq = 2'd3; divrem = divd3[WORDBITSZ-1:0]; end
	else if (!divd2[(WORDBITSZ+2)]) begin divq = 2'd2; divrem = divd2[WORDBITSZ-1:0]; end
	else if (!divd1[(WORDBITSZ+2)]) begin divq = 2'd1; divrem = divd1[WORDBITSZ-1:0]; end
	else                            begin divq = 2'd0; divrem = cumulator[(WORDBITSZ*2)-3 : (WORDBITSZ-2)]; end
end

// Register used to count the number of bits already used from the divider.
reg [CLOG2WORDBITSZ -1 : 0] cntr;

// Reg used to capture args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2];

reg remainder_sign;
always_ff @(posedge clk_i) begin
	remainder_sign <= (operands[IDIVSIGNED] && operands[(WORDBITSZ*2)-1]);
end

reg quotient_sign;
always_ff @(posedge clk_i) begin
	quotient_sign <= (operands[IDIVSIGNED] && (operands[(WORDBITSZ*2)-1] != operands[(WORDBITSZ-1)]));
end

always_comb begin
	// Logic setting rslt_o using the result computed in cumulator.

	// When operands[IDIVMSBRSLT] == 0, the quotient is used as result.
	// When operands[IDIVMSBRSLT] == 1, the remainder is used as result.
	// When operands[IDIVSIGNED] == 0, an unsigned division was done.
	// When operands[IDIVSIGNED] == 1, a signed division was done.
	if (operands[IDIVMSBRSLT]) begin
		// If I get here, the remainder is used as result.
		// The sign of the remainder is the same as the sign of the dividend.
		if (remainder_sign)
			rslt_o = -cumulator[(WORDBITSZ*2)-1:WORDBITSZ];
		else
			rslt_o = cumulator[(WORDBITSZ*2)-1:WORDBITSZ];

	end else begin
		// If I get here, the quotient is used as result.
		// The sign of the quotient is positive if the dividend
		// and divisor have the same sign otherwise it is negative.
		// RISC-V requires the result of dividing by zero to be -1.
		if (!operands[WORDBITSZ-1:0])
			rslt_o = {WORDBITSZ{1'b1}};
		else if (quotient_sign)
			rslt_o = -cumulator[WORDBITSZ-1:0];
		else
			rslt_o = cumulator[WORDBITSZ-1:0];
	end
end

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin

			operands <= args_i;

			// rval = |divider|, rval3 = 3*|divider|; both feed the radix-4 step.
			// (For a signed computation the divider is made positive; see divabsdvsr.)
			rval  <= divabsdvsr;
			rval3 <= ({2'b0, divabsdvsr} + {1'b0, divabsdvsr, 1'b0});

			// The dividend is in args_i[(WORDBITSZ*2)-1:WORDBITSZ].
			// The divider is in args_i[WORDBITSZ-1:0].

			// If args_i[IDIVSIGNED] == 0, an unsigned computation is to be done.
			// If args_i[IDIVSIGNED] == 1, a signed computation is to be done.
			// If a signed computation is to be done, I turn the left operand positive if it was negative.
			if (args_i[IDIVSIGNED] && args_i[(WORDBITSZ*2)-1])
				cumulator <= {{WORDBITSZ{1'b0}}, -args_i[(WORDBITSZ*2)-1:WORDBITSZ]};
			else
				cumulator <= {{WORDBITSZ{1'b0}}, args_i[(WORDBITSZ*2)-1:WORDBITSZ]};

			rdy_o <= 0;

			cntr <= 0;
		end

	end else begin
		// Radix-4 step: append the 2-bit quotient digit divq at the LSB, install
		// the reduced remainder divrem at the MSB, and shift the rest up by 2.
		cumulator <= {divrem, cumulator[(WORDBITSZ-3):0], divq};

		if (cntr == ((WORDBITSZ/2)-1)) begin
			// The division is complete after WORDBITSZ/2 radix-4 steps
			// (2 quotient bits each); the result will be ready in
			// cumulator after the next clockedge.
			rdy_o <= 1;
		end

		cntr <= cntr + 1'b1;
	end
end

endmodule

// clk_idiv_i frequency must be clk_i frequency times a power-of-2.
module opidiv (

	 rst_i

	,clk_i
	,clk_idiv_i

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
// args_i storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam IDIVTYPEBITSZ = 2;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_idiv_i;

input wire stb_i;

// bits[(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ)-1:((WORDBITSZ*2)+CLOG2GPRCNT)]
// store the type of division to perform,
// bits[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(WORDBITSZ*2)-1:WORDBITSZ] and bits[WORDBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] args_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the division.
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

`ifdef PUIDIVCLK
reg                                                       _stb_i;
reg  [(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] _args_i;
reg  [(CLOG2INSTCNT +1) -1 : 0]                           __wridx;
`else
wire                                                      _stb_i  = stb_i;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] _args_i = args_i;
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

`ifdef PUIDIVCLK
always_ff @(posedge clk_i) begin
	// With clk_idiv_i faster than clk_i, idiv signals stb_i args_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_idiv_i)/freq(clk_i))
	// clk_idiv_i cycles after its negedge; which is guarateed by the fact that
	// idiv computation takes at least that many clk_idiv_i cycles.
	if (rst_i)
		_stb_i <= 0;
	else begin
		_stb_i  <= stb_i;
		_args_i <= args_i;
		__wridx <= _wridx;
	end
end
`endif

genvar gen_idiv_idx;
generate for (gen_idiv_idx = 0; gen_idiv_idx < INSTCNT; gen_idiv_idx = gen_idiv_idx + 1) begin :gen_idiv
idiv #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
) idiv (

	 .rst_i (rst_i)

	`ifdef PUIDIVCLK
	,.clk_i (clk_idiv_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (_stb_i && (__wridx[CLOG2INSTCNT -1 : 0] == gen_idiv_idx))

	,.args_i  (_args_i)
	,.rslt_o  (data_w[gen_idiv_idx])
	,.gprid_o (gprid_w[gen_idiv_idx])

	,.rdy_o (rdy_w[gen_idiv_idx])
);
end endgenerate

endmodule

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
