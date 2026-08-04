// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Carry-less multiply (RISC-V Zbc: clmul/clmulh/clmulr). The carry-less product has no
// carry chains, so the full product is a combinational AND/XOR tree; this is a 2-cycle
// register-isolated unit (mirroring imul's PUIMULDSP): cycle 1 captures the operands,
// cycle 2 registers the requested slice of the product. See the note at end of file.

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

// Registered result of the carry-less multiply (the requested product slice).
output reg [WORDBITSZ -1 : 0] rslt_o;

// Net set to the id of the gpr to which the result is to be stored.
output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o;

// Reg used to capture args_i.
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+CLMULTYPEBITSZ) -1 : 0] operands;

assign gprid_o = operands[((WORDBITSZ*2)+CLOG2GPRCNT)-1:WORDBITSZ*2];

wire [CLMULTYPEBITSZ -1 : 0] optype = operands[CLMULTYPELSB +: CLMULTYPEBITSZ];

// The carry-less product has NO carry chains, so the full 2*WORDBITSZ-bit product is a shallow
// AND/XOR tree. Registered as a 2-cycle unit (mirror imul's PUIMULDSP path): cycle 1 captures the
// operands, cycle 2 registers the requested slice into rslt_o.
function automatic [(WORDBITSZ*2) -1 : 0] clmulFull (
		input [WORDBITSZ -1 : 0] a, input [WORDBITSZ -1 : 0] b);
	integer i;
	reg [(WORDBITSZ*2) -1 : 0] p;
	begin
		p = {(WORDBITSZ*2){1'b0}};
		for (i = 0; i < WORDBITSZ; i = i + 1)
			p = p ^ (b[i] ? ({{WORDBITSZ{1'b0}}, a} << i) : {(WORDBITSZ*2){1'b0}});
		clmulFull = p;
	end
endfunction
// Full product P from the registered operands (rs1 in the high half, rs2 in the low half).
// P spans bits [(2*WORDBITSZ)-2:0]; bit [(2*WORDBITSZ)-1] stays 0.
wire [(WORDBITSZ*2) -1 : 0] cumulator = clmulFull(
	operands[(WORDBITSZ*2)-1:WORDBITSZ], operands[WORDBITSZ-1:0]);

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		rdy_o <= 1;
	end else if (rdy_o) begin
		if (stb_i) begin
			operands <= args_i;
			rdy_o    <= 0;
		end
	end else begin
		// Register the requested slice of the full carry-less product P.
		case (optype)
		2'b11:   rslt_o <= cumulator[(WORDBITSZ*2)-1 : WORDBITSZ];   // clmulh: P[2n-1:n]
		2'b10:   rslt_o <= cumulator[(WORDBITSZ*2)-2 : WORDBITSZ-1]; // clmulr: P[2n-2:n-1]
		default: rslt_o <= cumulator[WORDBITSZ-1 : 0];               // clmul : P[n-1:0]
		endcase
		rdy_o <= 1;
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
// Computed here as one combinational AND/XOR tree (no carry chains), registered as a 2-cycle unit.
