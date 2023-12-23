// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The implementation of the multiplication is documented at the end of this file.

`ifndef PUDSPMUL
module imul (

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
// data_i storing the type of multiplication to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means ARCHBITSZ lsb/msb of result.
localparam IMULTYPEBITSZ = 2;
localparam IMULMSBRSLT   = ((ARCHBITSZ*2)+CLOG2GPRCNT);
localparam IMULSIGNED    = ((ARCHBITSZ*2)+CLOG2GPRCNT+1);

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] data_i;

// Net set to the result of the multiplication.
output reg [ARCHBITSZ -1 : 0] data_o; // ### comb-block-reg.

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Register in which the multiplication will be computed.
reg  [(ARCHBITSZ*2) -1 : 0] cumulator        = 0;
wire [(ARCHBITSZ*2) -1 : 0] cumulatornegated = -cumulator;

// Net used by the multiplication; compute the multiplier
// times 0, 1, 2 or 3 based on cumulator[1:0].
reg [(ARCHBITSZ+2) -1 : 0] mulx; // ### comb-block-reg.

// Reg set to the right operand value of the multiplication, which is the multiplier.
reg [ARCHBITSZ -1 : 0] rval;

// ### Used so that verilog simulation would work.
wire [(ARCHBITSZ+2) -1 : 0] cumulatorarg = (mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]);

// Reg used to capture data_i.
reg [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2];

always @* begin
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

reg tst_result_sign;
always @ (posedge clk_i) begin
	tst_result_sign <= (operands[IMULSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]));
end

always @* begin
	// Logic setting data_o using the result computed in cumulator.

	// When operands[IMULMSBRSLT] == 0, the ARCHBITSZ lsb are used as result.
	// When operands[IMULMSBRSLT] == 1, the ARCHBITSZ msb are used as result.
	// When operands[IMULSIGNED] == 0, an unsigned multiplication was done.
	// When operands[IMULSIGNED] == 1, a signed multiplication was done.
	if (operands[IMULMSBRSLT]) begin
		// The sign of the result is positive if the multiplicand
		// and multiplier have the same sign otherwise it is negative.
		if (tst_result_sign)
			data_o = cumulatornegated[(ARCHBITSZ*2)-1:ARCHBITSZ];
		else
			data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

	end else begin
		// When only the ARCHBITSZ lsb of the multiplication are used,
		// there is no difference between a signed and unsigned multiplication.
		data_o = cumulator[ARCHBITSZ-1:0];
	end
end

// Register used to count the number of two-bits-set already used from the multiplier.
reg [(CLOG2ARCHBITSZ-1) -1 : 0] cntr;

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin

			operands <= data_i;

			// If data_i[IMULSIGNED] == 0, it is an unsigned computation.
			// If data_i[IMULSIGNED] == 1, it is a signed computation.
			// For a signed computation, I turn the right operand positive if it was negative.
			if (data_i[IMULSIGNED] && data_i[(ARCHBITSZ-1)])
				rval <= -data_i[ARCHBITSZ-1:0];
			else
				rval <= data_i[ARCHBITSZ-1:0];

			// The multiplicand is in data_i[(ARCHBITSZ*2)-1:ARCHBITSZ].
			// The multiplier is in data_i[ARCHBITSZ-1:0].

			// If data_i[IMULSIGNED] == 0, an unsigned computation is to be done.
			// If data_i[IMULSIGNED] == 1, a signed computation is to be done.
			// If a signed computation is to be done, I turn the left operand positive if it was negative.
			if (data_i[IMULSIGNED] && data_i[(ARCHBITSZ*2)-1])
				cumulator <= {{ARCHBITSZ{1'b0}}, -data_i[(ARCHBITSZ*2)-1:ARCHBITSZ]};
			else
				cumulator <= {{ARCHBITSZ{1'b0}}, data_i[(ARCHBITSZ*2)-1:ARCHBITSZ]};

			rdy_o <= 0;

			cntr <= 0;
		end

	end else begin
		// Note that although mulx is (ARCHBITSZ+2) bits,
		// the result of mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]
		// will never generate a carry, because
		// mulx[(ARCHBITSZ+1):ARCHBITSZ] is guaranteed to never
		// be greater than 2'b10.
		// ### mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]
		// ### was computed in cumulatorarg so that
		// ### verilog simulation would work.
		// ### cumulatorarg is (ARCHBITSZ+2) bits.
		cumulator <= {cumulatorarg, cumulator[ARCHBITSZ-1:2]};

		if (cntr == ((ARCHBITSZ/2)-1)) begin
			// The multiplication is complete after cntr has been
			// incremented (ARCHBITSZ/2) times; the result will
			// be ready in cumulator after the next clockedge.
			rdy_o <= 1;
		end

		cntr <= cntr + 1'b1;
	end
end

endmodule

// clk_imul_i frequency must be clk_i frequency times a power-of-2.
module opimul (

	 rst_i

	,clk_i
	,clk_imul_i

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
// data_i storing the type of multiplication to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means ARCHBITSZ lsb/msb of result.
localparam IMULTYPEBITSZ = 2;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_imul_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// store the type of multiplication to perform,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// store the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] data_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the multiplication.
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

`ifdef PUIMULCLK
reg                                                       stb_r    = 0;
reg  [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] data_r   = 0;
reg  [(CLOG2INSTCNT +1) -1 : 0]                           _wridx_r = 0;
`else
wire                                                      stb_r  = stb_i;
wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+IMULTYPEBITSZ) -1 : 0] data_r = data_i;
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

`ifdef PUIMULCLK
always @ (posedge clk_i) begin
	// With clk_imul_i faster than clk_i, imul signals stb_i data_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_imul_i)/freq(clk_i))
	// clk_imul_i cycles after its negedge; which is guarateed by the fact that
	// imul computation takes at least that many clk_imul_i cycles.
	stb_r  <= stb_i;
	data_r <= data_i;
	_wridx_r <= _wridx;
end
`endif

genvar gen_imul_idx;
generate for (gen_imul_idx = 0; gen_imul_idx < INSTCNT; gen_imul_idx = gen_imul_idx + 1) begin :gen_imul
imul #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)

) imul (

	 .rst_i (rst_i)

	`ifdef PUIMULCLK
	,.clk_i (clk_imul_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (stb_r && (_wridx_r[CLOG2INSTCNT -1 : 0] == gen_imul_idx))

	,.data_i  (data_r)
	,.data_o  (data_w[gen_imul_idx])
	,.gprid_o (gprid_w[gen_imul_idx])

	,.rdy_o (rdy_w[gen_imul_idx])
);
end endgenerate

endmodule
`endif

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
