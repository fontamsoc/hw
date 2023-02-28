// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Written using:
// https://github.com/danshanley/FPU/blob/master/fpu.v
// Round-to-even implemented using:
// https://stackoverflow.com/a/8984135

`ifdef PUFDIV
module fdiv_normalizer (
	 exp_i
	,mant_i
	,exp_o
	,mant_o
);

parameter EXPBITSZ   = 8;
parameter MANTBITSZ  = 23;
parameter GUARDBITSZ = 3;

input wire [(EXPBITSZ+1)             -1 : 0] exp_i;
input wire [(MANTBITSZ+1)+GUARDBITSZ -1 : 0] mant_i;
// ### Nets declared as reg so as to be useable
// ### by verilog within the always block.
output reg [(EXPBITSZ+1)             -1 : 0] exp_o;
output reg [(MANTBITSZ+1)+GUARDBITSZ -1 : 0] mant_o;

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
	exp_o = {(EXPBITSZ+1){1'b1}};
	mant_o = {(MANTBITSZ+1+GUARDBITSZ){1'b1}};
end
end endgenerate

endmodule

// Written from opidiv.pu.v .
// arg0_i and arg1_i must remain constant throughout the computation.
module fdiv_idiv (

	 rst_i

	,clk_i

	,stb_i

	,arg0_i
	,arg1_i
	,rslt_o

	,rdy_o
);

`include "lib/clog2.v"

parameter BITSZ = 24;

localparam CLOG2BITSZ = clog2(BITSZ);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [BITSZ -1 : 0] arg0_i;
input wire [BITSZ -1 : 0] arg1_i;

// Register in which the division will be computed.
output reg [(BITSZ*2) -1 : 0] rslt_o;

output reg rdy_o;

// Net used by the division; compute the difference
// between the quotient and the left shifted divider.
wire [(BITSZ*2) -1 : 0] divdiff = (rslt_o - ({arg1_i, {(BITSZ-1){1'b0}}}));

// Register used to count the number of bits already used from the divider.
reg [(CLOG2BITSZ+1) -1 : 0] cntr;

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin
			// The dividend is in arg0_i.
			// The divider is in arg1_i.
			rslt_o <= {{BITSZ{1'b0}}, arg0_i};
			rdy_o <= 0;
			cntr <= 0;
		end

	end else begin
		// divdiff[(BITSZ*2)-1] is 1 when
		// the difference is negative, otherwise it is 0.
		rslt_o <= (divdiff[(BITSZ*2)-1]) ?
			{rslt_o[(BITSZ*2)-2:0], 1'b0} :
			{divdiff[(BITSZ*2)-2:0], 1'b1};

		if (cntr == ((BITSZ*2)-2)) begin
			// The division is complete after cntr has been
			// incremented ((BITSZ*2)-2) times; the result will
			// be ready in rslt_o after the next clockedge.
			rdy_o <= 1;
		end

		cntr <= cntr + 1'b1;
	end
end

endmodule

module fdiv_divider (

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

output reg  [(MANTBITSZ+2) -1 : 0] rslt_mant_o;
output reg  [(EXPBITSZ+1)  -1 : 0] rslt_exp_o;
output wire                        rslt_sign_o;

output reg rdy_o;

assign rslt_sign_o = (arg0_sign_i ^ arg1_sign_i);

wire [(MANTBITSZ+1+GUARDBITSZ) -1 : 0] rslt_mant_w;
reg  [(EXPBITSZ+1)             -1 : 0] rslt_exp_w;

always @ (posedge clk_i) begin
	rslt_exp_w <= (({1'b0, arg0_exp_i} + {(EXPBITSZ-1){1'b1}}) - {1'b0, arg1_exp_i});
end

reg norm_rdy_n;

wire idiv_rdy_w;
fdiv_idiv #(
	.BITSZ (MANTBITSZ+1+GUARDBITSZ)
) idiv (
	 .rst_i  (rst_i)
	,.clk_i  (clk_i)
	,.stb_i  (stb_i)
	,.arg0_i ({arg0_mant_i, {GUARDBITSZ{1'b0}}})
	,.arg1_i ({arg1_mant_i, {GUARDBITSZ{1'b0}}})
	,.rslt_o (rslt_mant_w)
	,.rdy_o  (idiv_rdy_w)
);
always @ (posedge clk_i) begin
	if (rst_i)
		rdy_o <= 1;
	else if (stb_i) begin
		norm_rdy_n <= 1;
		rdy_o <= 0;
	end else if (idiv_rdy_w) begin
		if (norm_rdy_n) begin
			norm_rdy_n <= 0;
		end else begin
			rdy_o <= 1;
		end
	end
end

localparam GUARDBITSZ = (ROUNDING ? 3/* Must be at least 2 */: 0);

wire [(EXPBITSZ+1)             -1 : 0] norm_exp_o;
wire [(MANTBITSZ+1)+GUARDBITSZ -1 : 0] norm_mant_o;

fdiv_normalizer #(
	 .EXPBITSZ   (EXPBITSZ)
	,.MANTBITSZ  (MANTBITSZ)
	,.GUARDBITSZ (GUARDBITSZ)
) norm (
	 .exp_i  (rslt_exp_w)
	,.mant_i (rslt_mant_w)
	,.exp_o  (norm_exp_o)
	,.mant_o (norm_mant_o)
);

reg [(MANTBITSZ+1)+GUARDBITSZ -1 : 0] rslt_mant_o_;
reg [(EXPBITSZ+1)             -1 : 0] rslt_exp_o_;

always @ (posedge clk_i) begin
	/*if (rslt_mant_w[MANTBITSZ+1+GUARDBITSZ] == 1) begin
		rslt_exp_o_ <= (rslt_exp_w + 1);
		rslt_mant_o_ <= (rslt_mant_w >> 1);
	end else */if ((rslt_mant_w[MANTBITSZ+GUARDBITSZ] == 0) && (rslt_exp_w != 0)) begin
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
wire [(MANTBITSZ+1) -1 : 0] _rslt_mant_o_ =  rslt_mant_o_[(MANTBITSZ+1+GUARDBITSZ)-1:GUARDBITSZ];
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
	rslt_mant_o <= rslt_mant_o_[(MANTBITSZ+1+GUARDBITSZ)-1:GUARDBITSZ];
end
end endgenerate

endmodule

module fdiv (

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

input wire rst_i;

input wire clk_i;

input wire stb_i;

// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// stores the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [((ARCHBITSZ*2)+CLOG2GPRCNT) -1 : 0] data_i;

// Net set to the result of the division.
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

reg                         divider_stb = 0;
reg  [(MANTBITSZ+1) -1 : 0] divider_arg0_mant;
reg  [EXPBITSZ      -1 : 0] divider_arg0_exp;
reg                         divider_arg0_sign;
reg  [(MANTBITSZ+1) -1 : 0] divider_arg1_mant;
reg  [EXPBITSZ      -1 : 0] divider_arg1_exp;
reg                         divider_arg1_sign;
wire [(MANTBITSZ+2) -1 : 0] divider_rslt_mant;
wire [(EXPBITSZ+1)  -1 : 0] divider_rslt_exp;
wire                        divider_rslt_sign;
wire                        divider_rdy;

fdiv_divider #(
	 .EXPBITSZ  (EXPBITSZ)
	,.MANTBITSZ (MANTBITSZ)
	,.ROUNDING  (1)
) divider (
	 .rst_i       (rst_i)
	,.clk_i       (clk_i)
	,.stb_i       (divider_stb)
	,.arg0_mant_i (divider_arg0_mant)
	,.arg0_exp_i  (divider_arg0_exp)
	,.arg0_sign_i (divider_arg0_sign)
	,.arg1_mant_i (divider_arg1_mant)
	,.arg1_exp_i  (divider_arg1_exp)
	,.arg1_sign_i (divider_arg1_sign)
	,.rslt_mant_o (divider_rslt_mant)
	,.rslt_exp_o  (divider_rslt_exp)
	,.rslt_sign_o (divider_rslt_sign)
	,.rdy_o       (divider_rdy)
);

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;
		divider_stb <= 0;

	end else if (rdy_o) begin

		if (stb_i) begin
			// If (arg0 or arg1) is NaN or (arg0 and arg1) is 0 or (arg0 and arg1) is Inf return NaN.
			if ((arg0_exp == {EXPBITSZ{1'b1}} && arg0_mant != 0) ||
				(arg1_exp == {EXPBITSZ{1'b1}} && arg1_mant != 0) ||
				(((arg0_exp == 0 && arg0_mant == 0) || arg0_exp == {EXPBITSZ{1'b1}}) &&
					(arg1_exp == 0 && arg1_mant == 0)) ||
				(arg0_exp == {EXPBITSZ{1'b1}} && arg1_exp == {EXPBITSZ{1'b1}})) begin
				rslt_sign <= (arg0_sign ^ arg1_sign);
				rslt_exp <= {EXPBITSZ{1'b1}};
				rslt_mant <= {1'b1, {(MANTBITSZ-1){1'b0}}};
			// If arg0 is Inf or arg1 is 0 return Inf.
			end else if (arg0_exp == {EXPBITSZ{1'b1}} || (arg1_exp == 0 && arg1_mant == 0)) begin
				rslt_sign <= arg0_sign;
				rslt_exp <= {EXPBITSZ{1'b1}};
				rslt_mant <= {MANTBITSZ{1'b0}};
			// If arg0 is 0 or arg1 is Inf return 0.
			end else if ((arg0_exp == 0 && arg0_mant == 0) || arg1_exp == {EXPBITSZ{1'b1}}) begin
				rslt_sign <= (arg0_sign ^ arg1_sign);
				rslt_exp <= {EXPBITSZ{1'b0}};
				rslt_mant <= {MANTBITSZ{1'b0}};
			end else begin // Passed all corner cases.
				divider_arg0_sign <= arg0_sign;
				divider_arg0_exp <= ((arg0_exp == 0) ? {{(EXPBITSZ-1){1'b0}}, 1'b1} : arg0_exp);
				divider_arg0_mant <= {((arg0_exp == 0) ? 1'b0 : 1'b1), arg0_mant};
				divider_arg1_sign <= arg1_sign;
				divider_arg1_exp <= ((arg1_exp == 0) ? {{(EXPBITSZ-1){1'b0}}, 1'b1} : arg1_exp);
				divider_arg1_mant <= {((arg1_exp == 0) ? 1'b0 : 1'b1), arg1_mant};
				rdy_o <= 0;
				divider_stb <= 1;
			end

			gprid_o <= gprid;
		end
	end else if (divider_stb) begin
		divider_stb <= 0;
	end else if (divider_rdy) begin
		rslt_sign <= divider_rslt_sign;
		if (divider_rslt_exp >= (({EXPBITSZ{1'b1}}+{(EXPBITSZ-1){1'b1}})-1)) begin
			// Underflow; return 0.
			rslt_exp <= {EXPBITSZ{1'b0}};
			rslt_mant <= {MANTBITSZ{1'b0}};
		end else if (divider_rslt_exp >= ({EXPBITSZ{1'b1}}-1)) begin
			// Overflow; return Inf.
			rslt_exp <= {EXPBITSZ{1'b1}};
			rslt_mant <= {MANTBITSZ{1'b0}};
		end else begin
			rslt_exp <= divider_rslt_exp[EXPBITSZ-1:0];
			rslt_mant <= divider_rslt_mant[MANTBITSZ-1:0];
		end
		rdy_o <= 1;
	end
end

endmodule

// clk_fdiv_i frequency must be clk_i frequency times a power-of-2.
module opfdiv (

	 rst_i

	,clk_i
	,clk_fdiv_i

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

localparam CLOG2INSTCNT = clog2(INSTCNT);

input wire rst_i;

input wire clk_i;
input wire clk_fdiv_i;

input wire stb_i;

// bits[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2]
// stores the id of the register to which the result will be saved,
// bits[(ARCHBITSZ*2)-1:ARCHBITSZ] and bits[ARCHBITSZ-1:0]
// respectively store the first and second operand values.
input wire [((ARCHBITSZ*2)+CLOG2GPRCNT) -1 : 0] data_i;

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

`ifdef PUFDIVCLK
reg                                       stb_r    = 0;
reg  [((ARCHBITSZ*2)+CLOG2GPRCNT) -1 : 0] data_r   = 0;
reg  [(CLOG2INSTCNT +1) -1 : 0]           _wridx_r = 0;
`else
wire                                      stb_r    = stb_i;
wire [((ARCHBITSZ*2)+CLOG2GPRCNT) -1 : 0] data_r   = data_i;
wire [(CLOG2INSTCNT +1) -1 : 0]           _wridx_r = _wridx;
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

`ifdef PUFDIVCLK
always @ (posedge clk_i) begin
	// With clk_fdiv_i faster than clk_i, fdiv signals stb_i data_i _wridx must
	// be registered using clk_i so to be stable input values; it also means that
	// sigmal rdy_o posegde must happen at least (freq(clk_fdiv_i)/freq(clk_i))
	// clk_fdiv_i cycles after its negedge; which is guarateed by the fact that
	// fdiv computation takes at least that many clk_fdiv_i cycles.
	stb_r  <= stb_i;
	data_r <= data_i;
	_wridx_r <= _wridx;
end
`endif

genvar gen_fdiv_idx;
generate for (gen_fdiv_idx = 0; gen_fdiv_idx < INSTCNT; gen_fdiv_idx = gen_fdiv_idx + 1) begin :gen_fdiv
fdiv #(
	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)
	,.EXPBITSZ  (EXPBITSZ)
	,.MANTBITSZ (MANTBITSZ)
) fdiv (

	 .rst_i (rst_i)

	`ifdef PUFDIVCLK
	,.clk_i (clk_fdiv_i)
	`else
	,.clk_i (clk_i)
	`endif

	,.stb_i (stb_r && (_wridx_r[CLOG2INSTCNT -1 : 0] == gen_fdiv_idx))

	,.data_i  (data_r)
	,.data_o  (data_w[gen_fdiv_idx])
	,.gprid_o (gprid_w[gen_fdiv_idx])

	,.rdy_o (rdy_w[gen_fdiv_idx])
);
end endgenerate

endmodule
`endif
