// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/ram/bram.v"

module icache (

	 rst_i

	,clk_i

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

`include "lib/clog2.v"

parameter WAYCNT = 1;
parameter SETCNT = 2;
parameter TAGBITSZ = 1;
parameter DATBITSZ = 1;

localparam CLOG2WAYCNT = clog2(WAYCNT);
localparam CLOG2SETCNT = clog2(SETCNT);

input wire rst_i;

input wire clk_i;

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

reg hit_o_; // ### comb-block-reg.
assign hit_o = (hit_o_ && rdy_o);

wire _we_i = (we_i && rdy_o);

// Register used as counter during the cache reset.
reg [CLOG2SETCNT -1 : 0] rstidx;

always @ (posedge clk_i) begin
	if (rst_i) begin
		rdy_o <= 0;
		rstidx <= {CLOG2SETCNT{1'b1}};
	end else if (!rdy_o) begin
		if (rstidx)
			rstidx <= rstidx - 1'b1;
		else
			rdy_o <= 1;
	end
end

// Register used to hold clock cycle count of _we_i high.
reg [CLOG2SETCNT -1 : 0] wecnt = 0;
// Register used to hold the way index to write next.
reg [CLOG2WAYCNT -1 : 0] waywidx = 0;
// Eventhough there can be more than one way containing same tags,
// it wouldn't be a problem because instruction data are read-only;
// the data associated with two same tags would always be the same.
always @ (posedge clk_i) begin
	if (WAYCNT > 1 && (_we_i || nxtway_i)) begin
		if ((wecnt >= (SETCNT-1)) || (nxtway_i && wecnt)) begin
			wecnt <= 0;
			if (waywidx >= (WAYCNT-1))
				waywidx <= 0;
			else
				waywidx <= waywidx + 1'b1;
		end else
			wecnt <= wecnt + 1'b1;
	end
end

wire [TAGBITSZ -1 : 0] tago [0 : WAYCNT -1];
wire [DATBITSZ -1 : 0] dato [0 : WAYCNT -1];
wire                   vldo [0 : WAYCNT -1];

genvar gen_ways_idx;
generate for (
	gen_ways_idx = 0;
	gen_ways_idx < WAYCNT;
	gen_ways_idx = gen_ways_idx + 1) begin :gen_ways

bram #(
	 .SZ (SETCNT)
	,.DW (TAGBITSZ)
) tags (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (tago[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   (_we_i && waywidx == gen_ways_idx)
	,.we1_i   (_we_i && waywidx == gen_ways_idx)
	,.addr1_i (widx_i)
	,.i1      (wtag_i)
);

bram #(
	 .SZ (SETCNT)
	,.DW (DATBITSZ)
) dats (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (dato[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   (_we_i && waywidx == gen_ways_idx)
	,.we1_i   (_we_i && waywidx == gen_ways_idx)
	,.addr1_i (widx_i)
	,.i1      (dat_i)
);

bram #(
	 .SZ (SETCNT)
	,.DW (1)
) vlds (
	 .clk0_i  (clk_i)
	,.en0_i   (re_i)
	,.addr0_i (ridx_i)
	,.o0      (vldo[gen_ways_idx])
	,.clk1_i  (clk_i)
	,.en1_i   ((_we_i && waywidx == gen_ways_idx) || !rdy_o)
	,.we1_i   ((_we_i && waywidx == gen_ways_idx) || !rdy_o)
	,.addr1_i (rdy_o ? widx_i : rstidx)
	,.i1      (rdy_o)
);

end endgenerate

reg [TAGBITSZ -1 : 0] rtag_r;

always @ (posedge clk_i) begin
	if (re_i)
		rtag_r <= rtag_i;
end

reg [CLOG2WAYCNT -1 : 0] hitidx; // ### comb-block-reg.

integer gen_hit_idx;
always @* begin
	hit_o_ = 0;
	hitidx = 0;
	for (
		gen_hit_idx = 0;
		gen_hit_idx < WAYCNT;
		gen_hit_idx = gen_hit_idx + 1) begin :gen_hit
		if (!hit_o_ && (vldo[gen_hit_idx] && (rtag_r == tago[gen_hit_idx]))) begin
			hit_o_ = 1;
			hitidx = gen_hit_idx;
		end
	end
end

assign dat_o = dato[hitidx];

endmodule
