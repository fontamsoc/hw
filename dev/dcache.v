// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// TODO: Comments to use:
// TODO: conly_i; // Make cache behave like an sram; invalidate any cachehit entry; no slave memory operation occur.
// TODO: cmiss_i; // cache-miss to force slave memory operation; invalidate any cachehit entry.

`ifndef DCACHE_V
`define DCACHE_V

module dcache (

	 rst_i

	,clk_i

	,conly_i
	,cmiss_i

	,m_wb_cyc_i
	,m_wb_stb_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_cyc_o
	,s_wb_stb_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter CACHESETCOUNT = 2;
parameter CACHEWAYCOUNT = 1;

parameter REGCACHEHIT = 0;

parameter INITFILE = "";

localparam CLOG2CACHESETCOUNT = clog2(CACHESETCOUNT);
localparam CLOG2CACHEWAYCOUNT = clog2(CACHEWAYCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input wire conly_i;
input wire cmiss_i;

input  wire                        m_wb_cyc_i;
input  wire                        m_wb_stb_i;
input  wire                        m_wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     m_wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] m_wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     m_wb_dat_i;
output reg                         m_wb_bsy_o;
output reg                         m_wb_ack_o;
output reg  [ARCHBITSZ -1 : 0]     m_wb_dat_o;

output reg                         s_wb_cyc_o;
output reg                         s_wb_stb_o;
output reg                         s_wb_we_o;
output reg  [ADDRBITSZ -1 : 0]     s_wb_addr_o;
output reg  [(ARCHBITSZ/8) -1 : 0] s_wb_sel_o;
output reg  [ARCHBITSZ -1 : 0]     s_wb_dat_o;
input  wire                        s_wb_bsy_i;
input  wire                        s_wb_ack_i;
input  wire [ARCHBITSZ -1 : 0]     s_wb_dat_i;

wire _m_wb_stb_i = (m_wb_cyc_i && m_wb_stb_i);

reg                        m_wb_we_r;
reg [ADDRBITSZ -1 : 0]     m_wb_addr_r;
reg [(ARCHBITSZ/8) -1 : 0] m_wb_sel_r;
reg [ARCHBITSZ -1 : 0]     m_wb_dat_r;

reg rst_r;
reg conly_r;
reg cmiss_r;

localparam IDLE    = 0;
localparam TESTHIT = 1;
localparam EVICT   = 2;
localparam REFILL  = 3;
reg [2 -1 : 0] state;

(* direct_enable = "true" *)
wire cache_stb = (!rst_i && state == IDLE && _m_wb_stb_i);

reg cache_hit_; // ### comb-block-reg.
reg cache_hit;
generate if (REGCACHEHIT) begin
always @ (posedge clk_i)
	cache_hit <= cache_hit_;
end else begin
always @*
	cache_hit = cache_hit_;
end endgenerate

reg cache_bsy;

wire conly_r_or_cache_hit = (conly_r || cache_hit);

wire cache_we = (!rst_i && (
	(state == TESTHIT && !cache_bsy && conly_r_or_cache_hit && m_wb_we_r) ||
	(s_wb_cyc_o && !s_wb_we_o && s_wb_ack_i && !cmiss_r)));

reg [CLOG2CACHEWAYCOUNT -1 : 0] cache_we_wayidx;

localparam CACHETAGBITSIZE = (ADDRBITSZ - CLOG2CACHESETCOUNT);

wire [CLOG2CACHESETCOUNT -1 : 0] cache_rdidx = m_wb_addr_i[CLOG2CACHESETCOUNT -1 : 0];
wire [CLOG2CACHESETCOUNT -1 : 0] cache_wridx = m_wb_addr_r[CLOG2CACHESETCOUNT -1 : 0];

reg [CACHETAGBITSIZE -1 : 0] cache_tag_o [CACHEWAYCOUNT -1 : 0];
reg [ARCHBITSZ -1 : 0]       cache_dat_o [CACHEWAYCOUNT -1 : 0];
reg                          cache_drt_o [CACHEWAYCOUNT -1 : 0];

reg [CLOG2CACHEWAYCOUNT -1 : 0] cache_hit_wayidx_; // ### comb-block-reg.
reg [CLOG2CACHEWAYCOUNT -1 : 0] cache_hit_wayidx;
generate if (REGCACHEHIT) begin
always @ (posedge clk_i)
	cache_hit_wayidx <= cache_hit_wayidx_;
end else begin
always @*
	cache_hit_wayidx = cache_hit_wayidx_;
end endgenerate

wire [CACHETAGBITSIZE -1 : 0] cache_tag_i = m_wb_addr_r[ADDRBITSZ -1 : CLOG2CACHESETCOUNT];

wire [ARCHBITSZ -1 : 0] _m_wb_sel_r;
wire [ARCHBITSZ -1 : 0] m_wb_dat_r_and__m_wb_sel_r = (m_wb_dat_r & _m_wb_sel_r);
wire [ARCHBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [ARCHBITSZ -1 : 0] cache_dat_i = ((state == TESTHIT) ?
	(m_wb_dat_r_and__m_wb_sel_r | (cache_dat_o[cache_hit_wayidx] & _m_wb_sel_r_n)) :
	(m_wb_we_r ? (m_wb_dat_r_and__m_wb_sel_r | (s_wb_dat_i & _m_wb_sel_r_n)) :
	             s_wb_dat_i));

wire cache_drt_i = (!rst_r && !conly_r && !cmiss_r && m_wb_we_r);

genvar gen_cache_idx;
generate for (
	gen_cache_idx = 0;
	gen_cache_idx < CACHEWAYCOUNT;
	gen_cache_idx = gen_cache_idx + 1) begin :gen_cache

	reg [CACHETAGBITSIZE -1 : 0] cache_tags [CACHESETCOUNT -1 : 0];
	reg [ARCHBITSZ -1 : 0]       cache_dats [CACHESETCOUNT -1 : 0];
	reg                          cache_drts [CACHESETCOUNT -1 : 0];

	initial begin
		if (INITFILE != "" && gen_cache_idx == 0 /* TODO: check whether worst logic */) begin
			$readmemh (INITFILE, cache_dats);
			`ifdef SIMULATION
			$display ("%s loaded", INITFILE);
			`endif
			// Initial state initialized here, otherwise
			// block ram fails to be inferred by yosys.
			cache_dat_o[gen_cache_idx] = 0;
		end
	end

	always @ (posedge clk_i) begin
		if (cache_stb) begin
			cache_tag_o[gen_cache_idx] <= cache_tags[cache_rdidx];
			cache_dat_o[gen_cache_idx] <= cache_dats[cache_rdidx];
			cache_drt_o[gen_cache_idx] <= cache_drts[cache_rdidx];
		end
	end

	wire _cache_we = (cache_we && gen_cache_idx == (cache_hit ? cache_hit_wayidx : cache_we_wayidx));

	always @ (posedge clk_i) begin
		if (_cache_we) begin
			cache_tags[cache_wridx] <= cache_tag_i;
			cache_dats[cache_wridx] <= cache_dat_i;
		end
		if (rst_r || _cache_we)
			cache_drts[cache_wridx] <= cache_drt_i;
	end

end endgenerate

integer gen_cachehit_idx;
always @* begin
	cache_hit_ = 0;
	cache_hit_wayidx_ = 0;
	for (
		gen_cachehit_idx = 0;
		gen_cachehit_idx < CACHEWAYCOUNT;
		gen_cachehit_idx = gen_cachehit_idx + 1) begin
		if (!cache_hit_ && !conly_r &&
			m_wb_addr_r[ADDRBITSZ -1 : CLOG2CACHESETCOUNT] == cache_tag_o[gen_cachehit_idx]) begin
			cache_hit_ = 1;
			cache_hit_wayidx_ = gen_cachehit_idx;
		end
	end
end

always @ (posedge clk_i) begin
	if (CACHEWAYCOUNT == 1 || (cache_stb && conly_i) || conly_r) begin
		cache_we_wayidx <= 0;
	end else if (cache_we && !cache_hit) begin
		cache_we_wayidx <= cache_we_wayidx + 1'b1;
	end
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		m_wb_bsy_o <= 1;
		m_wb_ack_o <= 0;

		s_wb_cyc_o <= 0;
		s_wb_stb_o <= 0;

		m_wb_addr_r <= 0;

		rst_r <= 1;
		conly_r <= 0;
		cmiss_r <= 0;

		state <= IDLE;

	end else if (state == IDLE) begin

		if (rst_r) begin

			if (m_wb_addr_r == (CACHESETCOUNT - 1)) begin
				m_wb_bsy_o <= 0;
				rst_r <= 0;
			end else
				m_wb_addr_r <= m_wb_addr_r + 1'b1;

		end else if (_m_wb_stb_i) begin

			m_wb_bsy_o <= 1;
			m_wb_ack_o <= 0;

			m_wb_we_r <= m_wb_we_i;
			m_wb_addr_r <= m_wb_addr_i;
			m_wb_sel_r <= m_wb_sel_i;
			m_wb_dat_r <= m_wb_dat_i;

			conly_r <= conly_i;
			cmiss_r <= cmiss_i;

			cache_bsy <= (REGCACHEHIT && !(conly_i || cmiss_i));

			state <= TESTHIT;

		end else begin

			m_wb_bsy_o <= 0;
			m_wb_ack_o <= 0;
		end

	end else if (state == TESTHIT) begin

		if (cache_bsy) // 1 clock cycle needed to compute cache_hit.
			cache_bsy <= 0;
		else if (conly_r_or_cache_hit && !cmiss_r) begin

			m_wb_bsy_o <= 0;
			m_wb_ack_o <= 1;

			if (!m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
				m_wb_dat_o <= cache_dat_o[cache_hit_wayidx];

			state <= IDLE;

		end else if (cache_drt_o[cache_we_wayidx] && !cmiss_r) begin

			s_wb_cyc_o <= 1;
			s_wb_stb_o <= 1;
			s_wb_we_o <= 1;
			s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
			s_wb_sel_o <= {(ARCHBITSZ/8){1'b1}};
			s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

			state <= EVICT;

		end else begin

			s_wb_cyc_o <= 1;
			s_wb_stb_o <= 1;
			s_wb_we_o <= m_wb_we_r;
			s_wb_addr_o <= m_wb_addr_r;
			s_wb_sel_o <= cmiss_r ? m_wb_sel_r : {(ARCHBITSZ/8){1'b1}};
			if (m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
				s_wb_dat_o <= m_wb_dat_r;

			state <= REFILL;
		end

	end else if (state == EVICT) begin

		if (s_wb_ack_i) begin

			s_wb_stb_o <= 1;
			s_wb_we_o <= 0;
			s_wb_addr_o <= m_wb_addr_r;
			s_wb_sel_o <= {(ARCHBITSZ/8){1'b1}};

			state <= REFILL;

		end else if (!s_wb_bsy_i)
			s_wb_stb_o <= 0;

	end else if (state == REFILL) begin

		if (s_wb_ack_i) begin

			m_wb_bsy_o <= 0;
			m_wb_ack_o <= 1;

			if (!m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
				m_wb_dat_o <= cache_dat_i;

			s_wb_cyc_o <= 0;
			s_wb_stb_o <= 0;

			state <= IDLE;

		end else if (!s_wb_bsy_i)
			s_wb_stb_o <= 0;
	end
end

generate if (ARCHBITSZ == 16) begin
	assign _m_wb_sel_r = {{8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (ARCHBITSZ == 32) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (ARCHBITSZ == 64) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[7]}}, {8{m_wb_sel_r[6]}}, {8{m_wb_sel_r[5]}}, {8{m_wb_sel_r[4]}},
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (ARCHBITSZ == 128) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[15]}}, {8{m_wb_sel_r[14]}}, {8{m_wb_sel_r[13]}}, {8{m_wb_sel_r[12]}},
		{8{m_wb_sel_r[11]}}, {8{m_wb_sel_r[10]}}, {8{m_wb_sel_r[9]}}, {8{m_wb_sel_r[8]}},
		{8{m_wb_sel_r[7]}}, {8{m_wb_sel_r[6]}}, {8{m_wb_sel_r[5]}}, {8{m_wb_sel_r[4]}},
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (ARCHBITSZ == 256) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[31]}}, {8{m_wb_sel_r[30]}}, {8{m_wb_sel_r[29]}}, {8{m_wb_sel_r[28]}},
		{8{m_wb_sel_r[27]}}, {8{m_wb_sel_r[26]}}, {8{m_wb_sel_r[25]}}, {8{m_wb_sel_r[24]}},
		{8{m_wb_sel_r[23]}}, {8{m_wb_sel_r[22]}}, {8{m_wb_sel_r[21]}}, {8{m_wb_sel_r[20]}},
		{8{m_wb_sel_r[19]}}, {8{m_wb_sel_r[18]}}, {8{m_wb_sel_r[17]}}, {8{m_wb_sel_r[16]}},
		{8{m_wb_sel_r[15]}}, {8{m_wb_sel_r[14]}}, {8{m_wb_sel_r[13]}}, {8{m_wb_sel_r[12]}},
		{8{m_wb_sel_r[11]}}, {8{m_wb_sel_r[10]}}, {8{m_wb_sel_r[9]}}, {8{m_wb_sel_r[8]}},
		{8{m_wb_sel_r[7]}}, {8{m_wb_sel_r[6]}}, {8{m_wb_sel_r[5]}}, {8{m_wb_sel_r[4]}},
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate

endmodule

`endif /* DCACHE_V */
