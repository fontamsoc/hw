// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef ICACHE_V
`define ICACHE_V

`include "lib/ram/bram.sv"

module iCache (

	 rst_i

	,clk_i

	,invd_i
	,nxtway_i

	,we_i
	,widx_i
	,wtag_i
	,dat_i

	,re_i
	,ridx_i
	,rtag_i
	,dat_o
	,hit_o

	,rdy_o
);

`include "lib/clog2.sv"

parameter WAYCNT = 1;
parameter SETCNT = 2;
parameter TAGBITSZ = 1;
parameter DATBITSZ = 1;

localparam CLOG2WAYCNT = clog2(WAYCNT);
localparam CLOG2SETCNT = clog2(SETCNT);

input wire rst_i;

input wire clk_i;

input wire invd_i;
input wire nxtway_i;

input wire                      we_i;
input wire [CLOG2SETCNT -1 : 0] widx_i;
input wire [TAGBITSZ -1 : 0]    wtag_i;
input wire [DATBITSZ -1 : 0]    dat_i;

input  wire                      re_i;
input  wire [CLOG2SETCNT -1 : 0] ridx_i;
input  wire [TAGBITSZ -1 : 0]    rtag_i;
output wire [DATBITSZ -1 : 0]    dat_o;
output wire                      hit_o;

output reg rdy_o;

wire [WAYCNT -1 : 0] hit_o_;
assign hit_o = ((|hit_o_) && rdy_o);

wire _we_i = (we_i && rdy_o);

// Register used as counter during the cache reset.
reg [CLOG2SETCNT -1 : 0] rstidx;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		rdy_o <= 0;
		rstidx <= {CLOG2SETCNT{1'b1}};
	end else if (invd_i) begin
		// TODO: Invalidate using a date ...
		rdy_o <= 0;
		rstidx <= {CLOG2SETCNT{1'b1}};
	end else if (!rdy_o) begin
		if (rstidx)
			rstidx <= rstidx - 1'b1;
		else
			rdy_o <= 1;
	end
end

// Register used to hold the way index to write next; undriven and unused when (WAYCNT == 1).
reg [CLOG2WAYCNT -1 : 0] waywidx;
generate if (WAYCNT > 1) begin
// Register used to hold clock cycle count of _we_i high.
reg [CLOG2SETCNT -1 : 0] wecnt;
// Since there will be multiple clock cycles between
// posedge of nxtway_i and we_i, we can register nxtway_i
// for better timing if it is combinational.
reg nxtway_r, _nxtway_r;
always_ff @(posedge clk_i) begin
	nxtway_r <= nxtway_i;
	_nxtway_r <= nxtway_r;
end
wire nxtway_posedge = (!_nxtway_r && nxtway_r);
// Eventhough there can be more than one way containing same tags,
// it wouldn't be a problem because instruction data are read-only;
// the data associated with two same tags would always be the same.
always_ff @(posedge clk_i) begin
	if (_we_i || nxtway_posedge) begin
		if ((wecnt >= (SETCNT-1)) || (nxtway_posedge && wecnt)) begin
			wecnt <= 0;
			if (waywidx >= (WAYCNT-1))
				waywidx <= 0;
			else
				waywidx <= waywidx + 1'b1;
		end else
			wecnt <= wecnt + 1'b1;
	end
end
end endgenerate

reg [TAGBITSZ -1 : 0] rtag_r;

always_ff @(posedge clk_i) begin
	if (re_i)
		rtag_r <= rtag_i;
end

wire [TAGBITSZ -1 : 0] tago [WAYCNT];
wire [DATBITSZ -1 : 0] dato [WAYCNT];
wire                   vldo [WAYCNT];

genvar gen_ways_idx;
generate for (
	gen_ways_idx = 0;
	gen_ways_idx < WAYCNT;
	gen_ways_idx = gen_ways_idx + 1) begin :gen_ways

wire __we_i = (_we_i && (WAYCNT == 1 || waywidx == gen_ways_idx));

bram #(
	 .SZ (SETCNT)
	,.DW (TAGBITSZ)
	,.NO_RW_CHECK (1)
) tags (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (tago[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   (__we_i)
	,.we1_i   (__we_i)
	,.addr1_i (widx_i)
	,.i1      (wtag_i)
);

bram #(
	 .SZ (SETCNT)
	,.DW (DATBITSZ)
	,.NO_RW_CHECK (1)
) dats (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (dato[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   (__we_i)
	,.we1_i   (__we_i)
	,.addr1_i (widx_i)
	,.i1      (dat_i)
);

bram #(
	 .SZ (SETCNT)
	,.DW (1)
	,.NO_RW_CHECK (1)
) vlds (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (vldo[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   (__we_i || !rdy_o)
	,.we1_i   (__we_i || !rdy_o)
	,.addr1_i (rdy_o ? widx_i : rstidx)
	,.i1      (rdy_o)
);

assign hit_o_[gen_ways_idx] = (vldo[gen_ways_idx] && (rtag_r == tago[gen_ways_idx]));

end endgenerate

generate if (WAYCNT > 1) begin
reg [CLOG2WAYCNT -1 : 0] hitidx; // ### comb-block-reg.
integer gen_hitidx_idx;
always_comb begin
	hitidx = 0;
	for (
		gen_hitidx_idx = WAYCNT;
		gen_hitidx_idx > 0;
		gen_hitidx_idx = gen_hitidx_idx-1) begin
		if (hit_o_[gen_hitidx_idx-1])
			hitidx = (gen_hitidx_idx-1);
	end
end
assign dat_o = dato[hitidx];
end else begin
assign dat_o = dato[0];
end endgenerate

endmodule

`endif /* ICACHE_V */
