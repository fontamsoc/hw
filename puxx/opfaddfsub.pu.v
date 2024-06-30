// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Written using:
// https://github.com/danshanley/FPU/blob/master/fpu.v
// Round-to-even implemented using:
// https://stackoverflow.com/a/8984135

`ifdef PUFADDFSUB
module faddfsub_normalizer (
	 exp_i
	,mant_i
	,exp_o
	,mant_o
);

parameter EXPBITSZ   = 8;
parameter MANTBITSZ  = 23;
parameter GUARDBITSZ = 3;

input wire [EXPBITSZ                 -1 : 0] exp_i;
input wire [(MANTBITSZ+2)+GUARDBITSZ -1 : 0] mant_i;
output reg [EXPBITSZ                 -1 : 0] exp_o; // ### comb-block-reg.
output reg [(MANTBITSZ+2)+GUARDBITSZ -1 : 0] mant_o; // ### comb-block-reg.

// ###: Only support MANTBITSZ == 23.
generate if (MANTBITSZ == 23) begin :gennormalizer
always @* begin
	// ###: (mant_i[MANTBITSZ+GUARDBITSZ] == 0) is true when this module is used.
	if          (mant_i[23+GUARDBITSZ:3+GUARDBITSZ] == 21'b000000000000000000001) begin
		exp_o = exp_i - 20;
		mant_o = mant_i << 20;
	end else if (mant_i[23+GUARDBITSZ:4+GUARDBITSZ] == 20'b00000000000000000001) begin
		exp_o = exp_i - 19;
		mant_o = mant_i << 19;
	end else if (mant_i[23+GUARDBITSZ:5+GUARDBITSZ] == 19'b0000000000000000001) begin
		exp_o = exp_i - 18;
		mant_o = mant_i << 18;
	end else if (mant_i[23+GUARDBITSZ:6+GUARDBITSZ] == 18'b000000000000000001) begin
		exp_o = exp_i - 17;
		mant_o = mant_i << 17;
	end else if (mant_i[23+GUARDBITSZ:7+GUARDBITSZ] == 17'b00000000000000001) begin
		exp_o = exp_i - 16;
		mant_o = mant_i << 16;
	end else if (mant_i[23+GUARDBITSZ:8+GUARDBITSZ] == 16'b0000000000000001) begin
		exp_o = exp_i - 15;
		mant_o = mant_i << 15;
	end else if (mant_i[23+GUARDBITSZ:9+GUARDBITSZ] == 15'b000000000000001) begin
		exp_o = exp_i - 14;
		mant_o = mant_i << 14;
	end else if (mant_i[23+GUARDBITSZ:10+GUARDBITSZ] == 14'b00000000000001) begin
		exp_o = exp_i - 13;
		mant_o = mant_i << 13;
	end else if (mant_i[23+GUARDBITSZ:11+GUARDBITSZ] == 13'b0000000000001) begin
		exp_o = exp_i - 12;
		mant_o = mant_i << 12;
	end else if (mant_i[23+GUARDBITSZ:12+GUARDBITSZ] == 12'b000000000001) begin
		exp_o = exp_i - 11;
		mant_o = mant_i << 11;
	end else if (mant_i[23+GUARDBITSZ:13+GUARDBITSZ] == 11'b00000000001) begin
		exp_o = exp_i - 10;
		mant_o = mant_i << 10;
	end else if (mant_i[23+GUARDBITSZ:14+GUARDBITSZ] == 10'b0000000001) begin
		exp_o = exp_i - 9;
		mant_o = mant_i << 9;
	end else if (mant_i[23+GUARDBITSZ:15+GUARDBITSZ] == 9'b000000001) begin
		exp_o = exp_i - 8;
		mant_o = mant_i << 8;
	end else if (mant_i[23+GUARDBITSZ:16+GUARDBITSZ] == 8'b00000001) begin
		exp_o = exp_i - 7;
		mant_o = mant_i << 7;
	end else if (mant_i[23+GUARDBITSZ:17+GUARDBITSZ] == 7'b0000001) begin
		exp_o = exp_i - 6;
		mant_o = mant_i << 6;
	end else if (mant_i[23+GUARDBITSZ:18+GUARDBITSZ] == 6'b000001) begin
		exp_o = exp_i - 5;
		mant_o = mant_i << 5;
	end else if (mant_i[23+GUARDBITSZ:19+GUARDBITSZ] == 5'b00001) begin
		exp_o = exp_i - 4;
		mant_o = mant_i << 4;
	end else if (mant_i[23+GUARDBITSZ:20+GUARDBITSZ] == 4'b0001) begin
		exp_o = exp_i - 3;
		mant_o = mant_i << 3;
	end else if (mant_i[23+GUARDBITSZ:21+GUARDBITSZ] == 3'b001) begin
		exp_o = exp_i - 2;
		mant_o = mant_i << 2;
	end else if (mant_i[23+GUARDBITSZ:22+GUARDBITSZ] == 2'b01) begin
		exp_o = exp_i - 1;
		mant_o = mant_i << 1;
	end else begin
		exp_o = exp_i;
		mant_o = mant_i;
	end
end
end else begin
always @* begin // NaN.
	exp_o = {EXPBITSZ{1'b1}};
	mant_o = {(MANTBITSZ+2+GUARDBITSZ){1'b1}};
end
end endgenerate

endmodule

// 1 clock cycle computation.
module faddfsub_adder (

	 rst_i

	,clk_i

	,stb_i

	,arg0_mant_i
	,arg0_exp_i
	,arg0_sign_i

	,arg1_mant_i
	,arg1_exp_i
	,arg1_sign_i

	,rslt_mant_o
	,rslt_exp_o
	,rslt_sign_o

	,rdy_o
);

parameter EXPBITSZ  = 8;
parameter MANTBITSZ = 23;
parameter ROUNDING  = 1;

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(MANTBITSZ+1) -1 : 0] arg0_mant_i;
input wire [EXPBITSZ      -1 : 0] arg0_exp_i;
input wire                        arg0_sign_i;

input wire [(MANTBITSZ+1) -1 : 0] arg1_mant_i;
input wire [EXPBITSZ      -1 : 0] arg1_exp_i;
input wire                        arg1_sign_i;

output reg [(MANTBITSZ+2) -1 : 0] rslt_mant_o;
output reg [EXPBITSZ      -1 : 0] rslt_exp_o;
output reg                        rslt_sign_o;

output reg rdy_o;

reg iadd_rdy_r;

reg norm_rdy_n;

always @ (posedge clk_i) begin
	if (rst_i)
		rdy_o <= 1;
	else if (stb_i) begin
		iadd_rdy_r <= (arg0_exp_i == arg1_exp_i) /* Equal exponents */;
		norm_rdy_n <= 1;
		rdy_o <= 0;
	end else if (iadd_rdy_r) begin
		if (norm_rdy_n) begin
			norm_rdy_n <= 0;
		end else begin
			rdy_o <= 1;
		end
	end else
		iadd_rdy_r <= 1;
end

localparam GUARDBITSZ = (ROUNDING ? 3/* Must be at least 2 */: 0);

reg [(MANTBITSZ+2)+GUARDBITSZ -1 : 0] rslt_mant_w;
reg [EXPBITSZ                 -1 : 0] rslt_exp_w;

wire [(MANTBITSZ+1) -1 : 0] tmp0_mant = (arg0_mant_i + arg1_mant_i);

reg [MANTBITSZ+GUARDBITSZ -1 : 0] tmp1_mant;
always @ (posedge clk_i) begin
	tmp1_mant <= (
		(arg0_exp_i > arg1_exp_i) ?
			({arg1_mant_i, {GUARDBITSZ{1'b0}}} >> (arg0_exp_i - arg1_exp_i)) :
			({arg0_mant_i, {GUARDBITSZ{1'b0}}} >> (arg1_exp_i - arg0_exp_i)));
end

always @ (posedge clk_i) begin
	if (arg0_exp_i == arg1_exp_i) begin // Equal exponents.
		rslt_exp_w <= arg0_exp_i;
		if (arg0_sign_i == arg1_sign_i) begin // Add if equal signs.
			rslt_mant_w <= {1'b1/*signal to shift*/, tmp0_mant, {GUARDBITSZ{1'b0}}};
			rslt_sign_o <= arg0_sign_i;
		end else begin // Substract if opposite signs.
			if (arg0_mant_i > arg1_mant_i) begin
				rslt_mant_w <= (
					{arg0_mant_i, {GUARDBITSZ{1'b0}}} -
					{arg1_mant_i, {GUARDBITSZ{1'b0}}});
				rslt_sign_o <= arg0_sign_i;
			end else begin
				rslt_mant_w <= (
					{arg1_mant_i, {GUARDBITSZ{1'b0}}} -
					{arg0_mant_i, {GUARDBITSZ{1'b0}}});
				rslt_sign_o <= arg1_sign_i;
			end
		end
	end else begin // Unequal exponents.
		if (arg0_exp_i > arg1_exp_i) begin // arg0 is bigger.
			rslt_exp_w <= arg0_exp_i;
			rslt_sign_o <= arg0_sign_i;
			if (arg0_sign_i == arg1_sign_i)
				rslt_mant_w <= ({arg0_mant_i, {GUARDBITSZ{1'b0}}} + tmp1_mant);
			else
				rslt_mant_w <= ({arg0_mant_i, {GUARDBITSZ{1'b0}}} - tmp1_mant);
		end else /* if (arg0_exp_i < arg1_exp_i) */ begin // arg1 is bigger.
			rslt_exp_w <= arg1_exp_i;
			rslt_sign_o <= arg1_sign_i;
			if (arg0_sign_i == arg1_sign_i)
				rslt_mant_w <= ({arg1_mant_i, {GUARDBITSZ{1'b0}}} + tmp1_mant);
			else
				rslt_mant_w <= ({arg1_mant_i, {GUARDBITSZ{1'b0}}} - tmp1_mant);
		end
	end
end

wire [EXPBITSZ                 -1 : 0] norm_exp_o;
wire [(MANTBITSZ+2)+GUARDBITSZ -1 : 0] norm_mant_o;

faddfsub_normalizer #(
	 .EXPBITSZ   (EXPBITSZ)
	,.MANTBITSZ  (MANTBITSZ)
	,.GUARDBITSZ (GUARDBITSZ)
) norm (
	 .exp_i  (rslt_exp_w)
	,.mant_i (rslt_mant_w)
	,.exp_o  (norm_exp_o)
	,.mant_o (norm_mant_o)
);

reg [(MANTBITSZ+2)+GUARDBITSZ -1 : 0] rslt_mant_o_;
reg [EXPBITSZ                 -1 : 0] rslt_exp_o_;

always @ (posedge clk_i) begin
	if (rslt_mant_w[MANTBITSZ+1+GUARDBITSZ] == 1) begin
		rslt_exp_o_ <= (rslt_exp_w + 1);
		rslt_mant_o_ <= (rslt_mant_w >> 1);
	end else if ((rslt_mant_w[MANTBITSZ+GUARDBITSZ] == 0) && (rslt_exp_w != 0)) begin
		rslt_exp_o_ <= norm_exp_o;
		rslt_mant_o_ <= norm_mant_o;
	end else begin
		rslt_exp_o_ <= rslt_exp_w;
		rslt_mant_o_ <= rslt_mant_w;
	end
end

generate if (ROUNDING) begin :genrounding
// Round-to-even logic; guard-bits are used as follow:
// 0xx - round-down.
// 100 - round-up if the mantissa's bit just before is 1, else round-down.
// 101 - round-up
// 110 - round-up
// 111 - round-up
wire [(MANTBITSZ+2) -1 : 0] _rslt_mant_o_ =  rslt_mant_o_[(MANTBITSZ+2+GUARDBITSZ)-1:GUARDBITSZ];
wire [(MANTBITSZ+2) -1 : 0] __rslt_mant_o_ = (_rslt_mant_o_ + 1'b1);
always @ (posedge clk_i) begin
	if (rslt_mant_o_[GUARDBITSZ-1] &&
		(rslt_mant_o_[GUARDBITSZ] || rslt_mant_o_[GUARDBITSZ-2:0])) begin
		if (__rslt_mant_o_[(MANTBITSZ+2)-1]) begin
			rslt_exp_o <= (rslt_exp_o_ + 1'b1);
			rslt_mant_o <= (__rslt_mant_o_ >> 1'b1);
		end else begin
			rslt_exp_o <= rslt_exp_o_;
			rslt_mant_o <= __rslt_mant_o_;
		end
	end else begin
		rslt_exp_o <= rslt_exp_o_;
		rslt_mant_o <= _rslt_mant_o_;
	end
end
end else begin
always @ (posedge clk_i) begin
	rslt_exp_o <= rslt_exp_o_;
	rslt_mant_o <= rslt_mant_o_[(MANTBITSZ+2+GUARDBITSZ)-1:GUARDBITSZ];
end
end endgenerate

endmodule

module faddfsub (

	 rst_i

	,clk_i

	,stb_i
	,data_i
	,data_o
	,gprid_o
	,rdy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 32;
parameter GPRCNT    = 32;
parameter EXPBITSZ  = 8;
parameter MANTBITSZ = 23;

localparam CLOG2GPRCNT = clog2(GPRCNT);

// Bit-size within data_i storing whether to perform
// addition or substraction is 0 or 1 respectively.
localparam OPSELBITSZ = 1;

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// stores whether to perform addition or substraction,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// stores the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ) -1 : 0] data_i;

// Net set to the result of the addition or substraction.
output wire [ARCHBITSZ -1 : 0] data_o;

// Reg set to the id of the gpr to which the result is to be stored.
output reg [CLOG2GPRCNT -1 : 0] gprid_o;

output reg rdy_o = 0;

reg [MANTBITSZ -1 : 0] rslt_mant;
reg [EXPBITSZ  -1 : 0] rslt_exp;
reg                    rslt_sign;

assign data_o = {rslt_sign, rslt_exp, rslt_mant};

wire [MANTBITSZ -1 : 0] arg1_mant = data_i[MANTBITSZ-1:0];
wire [EXPBITSZ  -1 : 0] arg1_exp  = data_i[(EXPBITSZ+MANTBITSZ)-1:MANTBITSZ];
wire                    arg1_sign = data_i[(1+EXPBITSZ+MANTBITSZ)-1:(EXPBITSZ+MANTBITSZ)];

wire [MANTBITSZ -1 : 0] arg0_mant = data_i[MANTBITSZ+ARCHBITSZ-1:ARCHBITSZ];
wire [EXPBITSZ  -1 : 0] arg0_exp  = data_i[(EXPBITSZ+MANTBITSZ)+ARCHBITSZ-1:MANTBITSZ+ARCHBITSZ];
wire                    arg0_sign = data_i[(1+EXPBITSZ+MANTBITSZ)+ARCHBITSZ-1:(EXPBITSZ+MANTBITSZ)+ARCHBITSZ];

wire [CLOG2GPRCNT -1 : 0] gprid = data_i[(CLOG2GPRCNT+(ARCHBITSZ*2))-1:(ARCHBITSZ*2)];

wire opsel = data_i[(1+CLOG2GPRCNT+(ARCHBITSZ*2))-1:(CLOG2GPRCNT+(ARCHBITSZ*2))];

reg                         adder_stb = 0;
reg  [(MANTBITSZ+1) -1 : 0] adder_arg0_mant;
reg  [EXPBITSZ      -1 : 0] adder_arg0_exp;
reg                         adder_arg0_sign;
reg  [(MANTBITSZ+1) -1 : 0] adder_arg1_mant;
reg  [EXPBITSZ      -1 : 0] adder_arg1_exp;
reg                         adder_arg1_sign;
wire [(MANTBITSZ+2) -1 : 0] adder_rslt_mant;
wire [EXPBITSZ      -1 : 0] adder_rslt_exp;
wire                        adder_rslt_sign;
wire                        adder_rdy;

faddfsub_adder #(
	 .EXPBITSZ  (EXPBITSZ)
	,.MANTBITSZ (MANTBITSZ)
	,.ROUNDING  (1)
) adder (
	 .rst_i       (rst_i)
	,.clk_i       (clk_i)
	,.stb_i       (adder_stb)
	,.arg0_mant_i (adder_arg0_mant)
	,.arg0_exp_i  (adder_arg0_exp)
	,.arg0_sign_i (adder_arg0_sign)
	,.arg1_mant_i (adder_arg1_mant)
	,.arg1_exp_i  (adder_arg1_exp)
	,.arg1_sign_i (adder_arg1_sign)
	,.rslt_mant_o (adder_rslt_mant)
	,.rslt_exp_o  (adder_rslt_exp)
	,.rslt_sign_o (adder_rslt_sign)
	,.rdy_o       (adder_rdy)
);

wire _arg1_sign = (opsel ? ~arg1_sign : arg1_sign);

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;
		adder_stb <= 0;

	end else if (rdy_o) begin

		if (stb_i) begin
			// If arg0 is NaN or arg1 is zero return arg0.
			if ((arg0_exp == {EXPBITSZ{1'b1}} && arg0_mant != 0) || (arg1_exp == 0 && arg1_mant == 0)) begin
				rslt_sign <= arg0_sign;
				rslt_exp <= arg0_exp;
				rslt_mant <= arg0_mant;
			// If arg1 is NaN or arg0 is zero return arg1.
			end else if ((arg1_exp == {EXPBITSZ{1'b1}} && arg1_mant != 0) || (arg0_exp == 0 && arg0_mant == 0)) begin
				rslt_sign <= _arg1_sign;
				rslt_exp <= arg1_exp;
				rslt_mant <= arg1_mant;
			// If arg0 or arg1 is Inf return Inf.
			end else if ((arg0_exp == {EXPBITSZ{1'b1}}) || (arg1_exp == {EXPBITSZ{1'b1}})) begin
				rslt_sign <= (arg0_sign ^ _arg1_sign);
				rslt_exp <= {EXPBITSZ{1'b1}};
				rslt_mant <= {MANTBITSZ{1'b0}};
			end else begin // Passed all corner cases.
				adder_arg0_sign <= arg0_sign;
				adder_arg0_exp <= ((arg0_exp == 0) ? {{(EXPBITSZ-1){1'b0}}, 1'b1} : arg0_exp);
				adder_arg0_mant <= {((arg0_exp == 0) ? 1'b0 : 1'b1), arg0_mant};
				adder_arg1_sign <= _arg1_sign;
				adder_arg1_exp <= ((arg1_exp == 0) ? {{(EXPBITSZ-1){1'b0}}, 1'b1} : arg1_exp);
				adder_arg1_mant <= {((arg1_exp == 0) ? 1'b0 : 1'b1), arg1_mant};
				rdy_o <= 0;
				adder_stb <= 1;
			end

			gprid_o <= gprid;
		end

	end else if (adder_stb) begin
		adder_stb <= 0;
	end else if (adder_rdy) begin

		rslt_sign <= adder_rslt_sign;
		rslt_exp <= adder_rslt_exp;
		rslt_mant <= adder_rslt_mant[MANTBITSZ-1:0];

		rdy_o <= 1;
	end
end

endmodule

// clk_faddfsub_i frequency must be clk_i frequency times a power-of-2.
module opfaddfsub (

	 rst_i

	,clk_i
	,clk_faddfsub_i

	,stb_i
	,data_i
	,rdy_o

	,ostb_i
	,data_o
	,gprid_o
	,ordy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 32;
parameter GPRCNT    = 32;
parameter EXPBITSZ  = 8;
parameter MANTBITSZ = 23;
parameter INSTCNT   = 2; // pipeline depth.

localparam CLOG2GPRCNT = clog2(GPRCNT);

// Bit-size within data_i storing whether to perform
// addition or substraction is 0 or 1 respectively.
localparam OPSELBITSZ = 1;

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_faddfsub_i;

input wire stb_i;

// bits[(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ)-1:((ARCHBITSZ*2)+CLOG2GPRCNT)]
// stores whether to perform addition or substraction,
// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// stores the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ) -1 : 0] data_i;

output wire rdy_o;

input wire ostb_i;

// Net set to the result of the multiplication or division.
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

`ifdef PUFADDFSUBCLK
reg                                                    stb_r    = 0;
reg  [(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ) -1 : 0] data_r   = 0;
reg  [(CLOG2INSTCNT +1) -1 : 0]                        _wridx_r = 0;
`else
wire                                                   stb_r    = stb_i;
wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+OPSELBITSZ) -1 : 0] data_r   = data_i;
wire [(CLOG2INSTCNT +1) -1 : 0]                        _wridx_r = _wridx;
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

`ifdef PUFADDFSUBCLK
always @ (posedge clk_i) begin
	// With clk_faddfsub_i faster than clk_i, faddfsub signals stb_i data_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_faddfsub_i)/freq(clk_i))
	// clk_faddfsub_i cycles after its negedge; which is guarateed by the fact that
	// faddfsub computation takes at least that many clk_faddfsub_i cycles.
	stb_r  <= stb_i;
	data_r <= data_i;
	_wridx_r <= _wridx;
end
`endif

genvar gen_faddfsub_idx;
generate for (gen_faddfsub_idx = 0; gen_faddfsub_idx < INSTCNT; gen_faddfsub_idx = gen_faddfsub_idx + 1) begin :gen_faddfsub
faddfsub #(
	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)
	,.EXPBITSZ  (EXPBITSZ)
	,.MANTBITSZ (MANTBITSZ)
) faddfsub (

	 .rst_i (rst_i)

	`ifdef PUFADDFSUBCLK
	,.clk_i (clk_faddfsub_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (stb_r && (_wridx_r[CLOG2INSTCNT -1 : 0] == gen_faddfsub_idx))

	,.data_i  (data_r)
	,.data_o  (data_w[gen_faddfsub_idx])
	,.gprid_o (gprid_w[gen_faddfsub_idx])

	,.rdy_o (rdy_w[gen_faddfsub_idx])
);
end endgenerate

endmodule
`endif
