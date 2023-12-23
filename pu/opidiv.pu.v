// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The implementation of the division is documented at the end of this file.

module idiv (

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

// Significance of each bit in the field within
// data_i storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam IDIVTYPEBITSZ = 2;
localparam IDIVMSBRSLT   = ((ARCHBITSZ*2)+CLOG2GPRCNT);
localparam IDIVSIGNED    = ((ARCHBITSZ*2)+CLOG2GPRCNT+1);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of division to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] data_i;

// Net set to the result of the division.
output reg [ARCHBITSZ -1 : 0] data_o; // ### comb-block-reg.

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Register in which the division will be computed.
reg  [(ARCHBITSZ*2) -1 : 0] cumulator = 0;

// Reg set to the right operand value of the division, which is the divider.
reg [ARCHBITSZ -1 : 0] rval;

// Net used by the division; compute the difference
// between the quotient and the left shifted divider.
wire [(ARCHBITSZ*2) -1 : 0] divdiff = (cumulator - ({rval, {(ARCHBITSZ-1){1'b0}}}));

// Register used to count the number of bits already used from the divider.
reg [CLOG2ARCHBITSZ -1 : 0] cntr;

// Reg used to capture data_i.
reg [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2];

reg tst_remainder_sign;
always @ (posedge clk_i) begin
	tst_remainder_sign <= (operands[IDIVSIGNED] && operands[(ARCHBITSZ*2)-1]);
end

reg tst_quotient_sign;
always @ (posedge clk_i) begin
	tst_quotient_sign <= (operands[IDIVSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]));
end

always @* begin
	// Logic setting data_o using the result computed in cumulator.

	// When operands[IDIVMSBRSLT] == 0, the quotient is used as result.
	// When operands[IDIVMSBRSLT] == 1, the remainder is used as result.
	// When operands[IDIVSIGNED] == 0, an unsigned division was done.
	// When operands[IDIVSIGNED] == 1, a signed division was done.
	if (operands[IDIVMSBRSLT]) begin
		// If I get here, the remainder is used as result.
		// The sign of the remainder is the same as the sign of the dividend.
		if (tst_remainder_sign)
			data_o = -cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
		else
			data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

	end else begin
		// If I get here, the quotient is used as result.
		// The sign of the quotient is positive if the dividend
		// and divisor have the same sign otherwise it is negative.
		if (tst_quotient_sign)
			data_o = -cumulator[ARCHBITSZ-1:0];
		else
			data_o = cumulator[ARCHBITSZ-1:0];
	end
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin

			operands <= data_i;

			// If data_i[IDIVSIGNED] == 0, it is an unsigned computation.
			// If data_i[IDIVSIGNED] == 1, it is a signed computation.
			// For a signed computation, I turn the right operand positive if it was negative.
			if (data_i[IDIVSIGNED] && data_i[(ARCHBITSZ-1)])
				rval <= -data_i[ARCHBITSZ-1:0];
			else
				rval <= data_i[ARCHBITSZ-1:0];

			// The dividend is in data_i[(ARCHBITSZ*2)-1:ARCHBITSZ].
			// The divider is in data_i[ARCHBITSZ-1:0].

			// If data_i[IDIVSIGNED] == 0, an unsigned computation is to be done.
			// If data_i[IDIVSIGNED] == 1, a signed computation is to be done.
			// If a signed computation is to be done, I turn the left operand positive if it was negative.
			if (data_i[IDIVSIGNED] && data_i[(ARCHBITSZ*2)-1])
				cumulator <= {{ARCHBITSZ{1'b0}}, -data_i[(ARCHBITSZ*2)-1:ARCHBITSZ]};
			else
				cumulator <= {{ARCHBITSZ{1'b0}}, data_i[(ARCHBITSZ*2)-1:ARCHBITSZ]};

			rdy_o <= 0;

			cntr <= 0;
		end

	end else begin
		// divdiff[(ARCHBITSZ*2)-1] is 1 when
		// the difference is negative, otherwise it is 0.
		if (divdiff[(ARCHBITSZ*2)-1])
			cumulator <= {cumulator[(ARCHBITSZ*2)-2:0], 1'b0};
		else
			cumulator <= {divdiff[(ARCHBITSZ*2)-2:0], 1'b1};

		if (cntr == (ARCHBITSZ-1)) begin
			// The division is complete after cntr has been
			// incremented ARCHBITSZ times; the result will be
			// ready in cumulator after the next clockedge.
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
parameter INSTCNT   = 2; // pipeline depth.

localparam CLOG2GPRCNT = clog2(GPRCNT);

// Significance of each bit in the field within
// data_i storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam IDIVTYPEBITSZ = 2;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_idiv_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of division to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] data_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the division.
output wire [ARCHBITSZ -1 : 0] data_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2INSTCNT +1) -1 : 0] wridx = 0;
reg [(CLOG2INSTCNT +1) -1 : 0] rdidx = 0;

wire [(CLOG2INSTCNT +1) -1 : 0] _wridx = ((INSTCNT-1) ? wridx : 0);
wire [(CLOG2INSTCNT +1) -1 : 0] _rdidx = ((INSTCNT-1) ? rdidx : 0);

wire [(CLOG2INSTCNT +1) -1 : 0] usage;
assign usage = (wridx - rdidx);

wire [ARCHBITSZ -1 : 0] data_w [INSTCNT -1 : 0];
assign data_o = data_w[_rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [INSTCNT -1 : 0];
assign gprid_o = gprid_w[_rdidx];

wire [INSTCNT -1 : 0] rdy_w;

assign rdy_o = ((usage < INSTCNT) && rdy_w[_wridx]);

assign ordy_o = ((usage != 0) && rdy_w[_rdidx]);

`ifdef PUIDIVCLK
reg                                                       stb_r    = 0;
reg  [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] data_r   = 0;
reg  [(CLOG2INSTCNT +1) -1 : 0]                           _wridx_r = 0;
`else
wire                                                      stb_r  = stb_i;
wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IDIVTYPEBITSZ) -1 : 0] data_r = data_i;
wire [(CLOG2INSTCNT +1) -1 : 0]                           _wridx_r = _wridx;
`endif

always @ (posedge clk_i) begin
	if (rst_i)
		wridx <= 0;
	else if (rdy_o && stb_i)
		wridx <= (wridx + 1'b1);
end

always @ (posedge clk_i) begin
	if (rst_i)
		rdidx <= 0;
	else if (ordy_o && ostb_i)
		rdidx <= (rdidx + 1'b1);
end

`ifdef PUIDIVCLK
always @ (posedge clk_i) begin
	// With clk_idiv_i faster than clk_i, idiv signals stb_i data_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_idiv_i)/freq(clk_i))
	// clk_idiv_i cycles after its negedge; which is guarateed by the fact that
	// idiv computation takes at least that many clk_idiv_i cycles.
	stb_r  <= stb_i;
	data_r <= data_i;
	_wridx_r <= _wridx;
end
`endif

genvar gen_idiv_idx;
generate for (gen_idiv_idx = 0; gen_idiv_idx < INSTCNT; gen_idiv_idx = gen_idiv_idx + 1) begin :gen_idiv
idiv #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)

) idiv (

	 .rst_i (rst_i)

	`ifdef PUIDIVCLK
	,.clk_i (clk_idiv_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (stb_r && (_wridx_r[CLOG2INSTCNT -1 : 0] == gen_idiv_idx))

	,.data_i  (data_r)
	,.data_o  (data_w[gen_idiv_idx])
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
