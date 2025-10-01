// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// TODO: Comments to use:
// TODO: conly_i; // Make cache behave like an sram; no slave memory operation occur.
// TODO: cmiss_i; // cache-miss to force slave memory operation; any cachehit entry is left untouched.

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

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter ADDRLIMIT = 'h2000;

parameter CACHESETCNT = 2;
parameter CACHEWAYCNT = 1;

parameter REGMASTROUT = 1;
parameter REGSLVINPUT = 0;

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter INITFILE = "";

localparam CLOG2CACHESETCNT = clog2(CACHESETCNT);
localparam CLOG2CACHEWAYCNT = clog2(CACHEWAYCNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input wire conly_i;
input wire cmiss_i;

input  wire                               m_wb_cyc_i;
input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output reg                                m_wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire                               s_wb_cyc_o;
output reg                                s_wb_stb_o;
output reg                                s_wb_we_o;
output reg  [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output reg  [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output reg  [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

wire _m_wb_stb_i = (m_wb_cyc_i && m_wb_stb_i && !m_wb_bsy_o);

reg                               m_wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        m_wb_sel_r;
reg [WORDBITSZ -1 : 0]            m_wb_dat_r;

reg rst_r;
reg conly_r;
reg cmiss_r;

localparam IDLE    = 0;
localparam EVICT   = 2;
localparam REFILL  = 3;
reg [2 -1 : 0] state;

reg                    _s_wb_ack_i;
reg [WORDBITSZ -1 : 0] _s_wb_dat_i;
generate if (REGSLVINPUT) begin
	always_ff @(posedge clk_i) begin
		_s_wb_ack_i <= s_wb_ack_i;
		_s_wb_dat_i <= s_wb_dat_i;
	end
end else begin
	always_comb begin
		_s_wb_ack_i = s_wb_ack_i;
		_s_wb_dat_i = s_wb_dat_i;
	end
end
endgenerate

// (MAXPENDINGACK+2) is used instead of just MAXPENDINGACK
// otherwise parameter MAXPENDINGACK must be >= 3, where +2
// account for the sequencing of EVICT followed by REFILL.
reg [clog2((MAXPENDINGACK+2)+1) -1 : 0] ack_pending;
generate if (MAXPENDINGACK) begin
always_ff @(posedge clk_i) begin
	if (rst_i)
		ack_pending <= 0;
	else if (s_wb_stb_o && !s_wb_bsy_i && _s_wb_ack_i);
	else if (_s_wb_ack_i)
		ack_pending <= ack_pending - 1'b1;
	else if (s_wb_stb_o && !s_wb_bsy_i) begin
		ack_pending <= ack_pending + 1'b1;
	end
end
end
endgenerate
reg s_wb_cyc_o_;
assign s_wb_cyc_o = (s_wb_cyc_o_ || (MAXPENDINGACK && ack_pending));

// When MAXPENDINGACK is non-null, and the sequencing of EVICT followed by REFILL
// occurs, the expression (!s_wb_stb_o && ack_pending == 1) identifies the ack of
// REFILL, because we could still be waiting for the ack of EVICT.
wire refill_ack = (_s_wb_ack_i && (!MAXPENDINGACK || (!s_wb_stb_o && ack_pending == 1)));

reg m_wb_ack;

wire cache_we = (!cmiss_r &&
	((m_wb_ack && m_wb_we_r) || (!s_wb_we_o && refill_ack)));

localparam CACHETAGBITSIZE = ((ADDRBITSZ-MSBSZIGN) - CLOG2CACHESETCNT);

wire [CLOG2CACHESETCNT -1 : 0] cache_rdidx = m_wb_addr_i[0 +: CLOG2CACHESETCNT];
wire [CLOG2CACHESETCNT -1 : 0] cache_wridx = m_wb_addr_r[0 +: CLOG2CACHESETCNT];

wire [CLOG2CACHESETCNT -1 : 0] _cache_rdidx = (_m_wb_stb_i ? cache_rdidx : cache_wridx);

reg [CACHETAGBITSIZE -1 : 0] cache_tag_o [CACHEWAYCNT];
reg [(WORDBITSZ/8) -1 : 0]   cache_sel_o [CACHEWAYCNT];
reg [WORDBITSZ -1 : 0]       cache_dat_o [CACHEWAYCNT];
reg                          cache_drt_o [CACHEWAYCNT];

wire [CACHEWAYCNT -1 : 0] cache_tag_hit_;
wire cache_tag_hit = (|cache_tag_hit_);

reg [CLOG2CACHEWAYCNT -1 : 0] cache_tag_hit_wayidx; // ### comb-block-reg.
integer gen_hitidx_idx;
always_comb begin
	cache_tag_hit_wayidx = 0;
	for (
		gen_hitidx_idx = CACHEWAYCNT;
		gen_hitidx_idx > 0;
		gen_hitidx_idx = gen_hitidx_idx-1) begin
		if (cache_tag_hit_[gen_hitidx_idx-1])
			cache_tag_hit_wayidx = (gen_hitidx_idx-1);
	end
end

reg [CLOG2CACHEWAYCNT -1 : 0] cache_we_wayidx;

wire [CACHETAGBITSIZE -1 : 0] cache_tag_i = m_wb_addr_r[(ADDRBITSZ-MSBSZIGN) -1 : CLOG2CACHESETCNT];

wire [(WORDBITSZ/8) -1 : 0] cache_sel_o_tag_hit = cache_sel_o[cache_tag_hit_wayidx];
wire [(WORDBITSZ/8) -1 : 0] _cache_sel_o;
wire [(WORDBITSZ/8) -1 : 0] cache_sel_i = (
	conly_r ? {(WORDBITSZ/8){1'b0}} :
	m_wb_ack ? (cache_tag_hit ? (m_wb_sel_r | _cache_sel_o) : m_wb_sel_r) :
	(state == REFILL) ? {(WORDBITSZ/8){1'b1}} : {(WORDBITSZ/8){1'b0}});

wire [WORDBITSZ -1 : 0] cache_dat_o_tag_hit = cache_dat_o[cache_tag_hit_wayidx];

wire [WORDBITSZ -1 : 0] m_wb_dat_o_;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit_n = ~_cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] cache_dat_i = (m_wb_ack ?
	((m_wb_dat_r & _m_wb_sel_r) | (m_wb_dat_o_ & _m_wb_sel_r_n)) :
	(cache_tag_hit ?
		((cache_dat_o_tag_hit & _cache_sel_o_tag_hit) |
			(_s_wb_dat_i & _cache_sel_o_tag_hit_n)) :
		_s_wb_dat_i));

//wire cache_drt_o_tag_hit = cache_drt_o[cache_tag_hit_wayidx];
// There is no need to use cache_drt_o_tag_hit because
// on cache REFILL, cache_tag_hit is true for a dirty cache entry.
wire cache_drt_i = (!rst_r && !conly_r &&
	(m_wb_we_r || (cache_tag_hit/* && cache_drt_o_tag_hit*/)));

reg use_cache_dat_r;

genvar gen_cache_idx;
generate for (
	gen_cache_idx = 0;
	gen_cache_idx < CACHEWAYCNT;
	gen_cache_idx = gen_cache_idx + 1) begin :gen_cache

reg [CACHETAGBITSIZE -1 : 0] cache_tags [CACHESETCNT];
reg [(WORDBITSZ/8) -1 : 0]   cache_sels [CACHESETCNT];
reg [WORDBITSZ -1 : 0]       cache_dats [CACHESETCNT];
reg                          cache_drts [CACHESETCNT];

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

wire _cache_we = (cache_we && gen_cache_idx == (cache_tag_hit ? cache_tag_hit_wayidx : cache_we_wayidx));

always_ff @(posedge clk_i) begin
	// use_cache_dat_r is used below to update the cache output
	// needed for a cache refill write, when there is a cache miss.
	if (_m_wb_stb_i || use_cache_dat_r) begin
		cache_tag_o[gen_cache_idx] <= cache_tags[_cache_rdidx];
		cache_sel_o[gen_cache_idx] <= cache_sels[_cache_rdidx];
		cache_dat_o[gen_cache_idx] <= cache_dats[_cache_rdidx];
		cache_drt_o[gen_cache_idx] <= cache_drts[_cache_rdidx];
	end
end

always_ff @(posedge clk_i) begin
	if (_cache_we) begin
		cache_tags[cache_wridx] <= cache_tag_i;
		cache_dats[cache_wridx] <= cache_dat_i;
	end
end

always_ff @(posedge clk_i) begin
	if (rst_r || _cache_we) begin
		cache_sels[cache_wridx] <= cache_sel_i;
		cache_drts[cache_wridx] <= cache_drt_i;
	end
end

assign cache_tag_hit_[gen_cache_idx] = ((|cache_sel_o[gen_cache_idx]) &&
	m_wb_addr_r[(ADDRBITSZ-MSBSZIGN) -1 : CLOG2CACHESETCNT] == cache_tag_o[gen_cache_idx]);

end endgenerate

// There is a cachehit when there is a cache tag hit and the selected bits are in the cache.
wire cache_hit = (cache_tag_hit && ((m_wb_sel_r & _cache_sel_o) == m_wb_sel_r));

always_ff @(posedge clk_i) begin
	if (CACHEWAYCNT == 1 || (_m_wb_stb_i && conly_i) || conly_r) begin
		cache_we_wayidx <= 0;
	end else if (cache_we && !cache_tag_hit) begin
		cache_we_wayidx <= cache_we_wayidx + 1'b1;
	end
end

reg [WORDBITSZ -1 : 0] cache_dat_r;
reg [(WORDBITSZ/8) -1 : 0] cache_sel_r;
always_ff @(posedge clk_i) begin
	if (state == REFILL && !s_wb_we_o && refill_ack) begin
		// Note that when set here, cache_dat_r is not used
		// to update the cache, but only to set m_wb_dat_o_.
		use_cache_dat_r <= 1'b1;
		cache_dat_r <= cache_dat_i;
	end else if (_m_wb_stb_i && !cmiss_i) begin
		use_cache_dat_r <= (m_wb_we_r && m_wb_addr_i == m_wb_addr_r);
		cache_dat_r <= cache_dat_i;
		cache_sel_r <= cache_sel_i;
	end else
		use_cache_dat_r <= 1'b0;
end

assign m_wb_dat_o_ = (use_cache_dat_r ? cache_dat_r : cache_dat_o_tag_hit);
generate if (REGMASTROUT) begin
always_ff @(posedge clk_i)
	m_wb_dat_o <= m_wb_dat_o_;
end else begin
always_comb
	m_wb_dat_o = m_wb_dat_o_;
end endgenerate

assign _cache_sel_o = (use_cache_dat_r ? cache_sel_r : cache_sel_o_tag_hit);

wire _cache_hit = ((conly_r || cache_hit || (cache_tag_hit && m_wb_we_r)) && !cmiss_r);

wire _use_cache_dat_r = (use_cache_dat_r && ((m_wb_sel_r & cache_sel_r) == m_wb_sel_r));

wire cache_miss = (m_wb_ack && !_cache_hit && !_use_cache_dat_r);

wire m_wb_ack_o_ = (m_wb_ack ? (_use_cache_dat_r || (_cache_hit || m_wb_we_r)) : use_cache_dat_r);
generate if (REGMASTROUT) begin
always_ff @(posedge clk_i)
	m_wb_ack_o <= m_wb_ack_o_;
end else begin
always_comb
	m_wb_ack_o = m_wb_ack_o_;
end endgenerate

wire cache_drt_o_we_wayidx = cache_drt_o[cache_we_wayidx];

assign m_wb_bsy_o = (
	(cache_miss &&
		// On cache_miss, m_wb_bsy_o should be high because we can transition
		// to EVICT or REFILL, but when m_wb_we_r is true, the check below
		// identifies the state for which there is no transition to EVICT.
		(!m_wb_we_r || !cache_tag_hit || cache_drt_o_we_wayidx)) ||
	(state != IDLE) || rst_r);

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		m_wb_ack <= 0;

		s_wb_cyc_o_ <= 0;
		s_wb_stb_o <= 0;

		m_wb_addr_r <= 0;

		rst_r <= 1;
		conly_r <= 0;
		cmiss_r <= 0;

		state <= IDLE;

	end else if (state == IDLE) begin

		if (rst_r) begin

			if (m_wb_addr_r == (CACHESETCNT - 1)) begin
				rst_r <= 0;
			end else
				m_wb_addr_r <= m_wb_addr_r + 1'b1;

		end else if (_m_wb_stb_i || cache_miss) begin

			if (cache_miss) begin

				if (cache_drt_o_we_wayidx && !cache_tag_hit && !cmiss_r) begin

					m_wb_ack <= 0;

					s_wb_cyc_o_ <= 1;
					s_wb_stb_o <= 1;
					s_wb_we_o <= 1;
					s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
					s_wb_sel_o <= cache_sel_o[cache_we_wayidx];
					s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

					state <= EVICT;

				end else if (!m_wb_we_r || cmiss_r) begin

					m_wb_ack <= 0;

					s_wb_cyc_o_ <= 1;
					s_wb_stb_o <= 1;
					s_wb_we_o <= m_wb_we_r;
					s_wb_addr_o <= m_wb_addr_r;
					s_wb_sel_o <= cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}};
					if (m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
						s_wb_dat_o <= m_wb_dat_r;

					state <= REFILL;

				end else if (_m_wb_stb_i) begin

					m_wb_ack <= 1;

					m_wb_we_r <= m_wb_we_i;
					m_wb_addr_r <= m_wb_addr_i;
					m_wb_sel_r <= m_wb_sel_i;
					m_wb_dat_r <= m_wb_dat_i;

					conly_r <= conly_i;
					cmiss_r <= cmiss_i;

				end else begin

					m_wb_ack <= 0;

					m_wb_we_r <= 0;

					conly_r <= 0;
					cmiss_r <= 0;
				end

			end else begin

				m_wb_ack <= 1;

				m_wb_we_r <= m_wb_we_i;
				m_wb_addr_r <= m_wb_addr_i;
				m_wb_sel_r <= m_wb_sel_i;
				m_wb_dat_r <= m_wb_dat_i;

				conly_r <= conly_i;
				cmiss_r <= cmiss_i;
			end

		end else begin

			m_wb_ack <= 0;

			m_wb_we_r <= 0;

			conly_r <= 0;
			cmiss_r <= 0;
		end

	end else if (state == EVICT) begin

		if (MAXPENDINGACK ? !s_wb_bsy_i : _s_wb_ack_i) begin

			if (m_wb_we_r) begin

				m_wb_we_r <= 0;

				s_wb_cyc_o_ <= 0;
				s_wb_stb_o <= 0;

				conly_r <= 0;
				cmiss_r <= 0;

				state <= IDLE;

			end else begin

				s_wb_stb_o <= 1;
				s_wb_we_o <= 0;
				s_wb_addr_o <= m_wb_addr_r;
				s_wb_sel_o <= {(WORDBITSZ/8){1'b1}};

				state <= REFILL;
			end

		end else if (!s_wb_bsy_i && !MAXPENDINGACK)
			s_wb_stb_o <= 0;

	end else if (state == REFILL) begin

		if ((m_wb_we_r && !s_wb_bsy_i && MAXPENDINGACK) || refill_ack) begin

			m_wb_we_r <= 0;

			s_wb_cyc_o_ <= 0;
			s_wb_stb_o <= 0;

			conly_r <= 0;
			cmiss_r <= 0;

			state <= IDLE;

		end else if (!s_wb_bsy_i)
			s_wb_stb_o <= 0;
	end
end

generate if (WORDBITSZ == 16) begin
	assign _m_wb_sel_r = {{8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 32) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 64) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[7]}}, {8{m_wb_sel_r[6]}}, {8{m_wb_sel_r[5]}}, {8{m_wb_sel_r[4]}},
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 128) begin
	assign _m_wb_sel_r = {
		{8{m_wb_sel_r[15]}}, {8{m_wb_sel_r[14]}}, {8{m_wb_sel_r[13]}}, {8{m_wb_sel_r[12]}},
		{8{m_wb_sel_r[11]}}, {8{m_wb_sel_r[10]}}, {8{m_wb_sel_r[9]}}, {8{m_wb_sel_r[8]}},
		{8{m_wb_sel_r[7]}}, {8{m_wb_sel_r[6]}}, {8{m_wb_sel_r[5]}}, {8{m_wb_sel_r[4]}},
		{8{m_wb_sel_r[3]}}, {8{m_wb_sel_r[2]}}, {8{m_wb_sel_r[1]}}, {8{m_wb_sel_r[0]}}};
end endgenerate
generate if (WORDBITSZ == 256) begin
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

generate if (WORDBITSZ == 16) begin
	assign _cache_sel_o_tag_hit = {{8{cache_sel_o_tag_hit[1]}}, {8{cache_sel_o_tag_hit[0]}}};
end endgenerate
generate if (WORDBITSZ == 32) begin
	assign _cache_sel_o_tag_hit = {
		{8{cache_sel_o_tag_hit[3]}}, {8{cache_sel_o_tag_hit[2]}}, {8{cache_sel_o_tag_hit[1]}}, {8{cache_sel_o_tag_hit[0]}}};
end endgenerate
generate if (WORDBITSZ == 64) begin
	assign _cache_sel_o_tag_hit = {
		{8{cache_sel_o_tag_hit[7]}}, {8{cache_sel_o_tag_hit[6]}}, {8{cache_sel_o_tag_hit[5]}}, {8{cache_sel_o_tag_hit[4]}},
		{8{cache_sel_o_tag_hit[3]}}, {8{cache_sel_o_tag_hit[2]}}, {8{cache_sel_o_tag_hit[1]}}, {8{cache_sel_o_tag_hit[0]}}};
end endgenerate
generate if (WORDBITSZ == 128) begin
	assign _cache_sel_o_tag_hit = {
		{8{cache_sel_o_tag_hit[15]}}, {8{cache_sel_o_tag_hit[14]}}, {8{cache_sel_o_tag_hit[13]}}, {8{cache_sel_o_tag_hit[12]}},
		{8{cache_sel_o_tag_hit[11]}}, {8{cache_sel_o_tag_hit[10]}}, {8{cache_sel_o_tag_hit[9]}}, {8{cache_sel_o_tag_hit[8]}},
		{8{cache_sel_o_tag_hit[7]}}, {8{cache_sel_o_tag_hit[6]}}, {8{cache_sel_o_tag_hit[5]}}, {8{cache_sel_o_tag_hit[4]}},
		{8{cache_sel_o_tag_hit[3]}}, {8{cache_sel_o_tag_hit[2]}}, {8{cache_sel_o_tag_hit[1]}}, {8{cache_sel_o_tag_hit[0]}}};
end endgenerate
generate if (WORDBITSZ == 256) begin
	assign _cache_sel_o_tag_hit = {
		{8{cache_sel_o_tag_hit[31]}}, {8{cache_sel_o_tag_hit[30]}}, {8{cache_sel_o_tag_hit[29]}}, {8{cache_sel_o_tag_hit[28]}},
		{8{cache_sel_o_tag_hit[27]}}, {8{cache_sel_o_tag_hit[26]}}, {8{cache_sel_o_tag_hit[25]}}, {8{cache_sel_o_tag_hit[24]}},
		{8{cache_sel_o_tag_hit[23]}}, {8{cache_sel_o_tag_hit[22]}}, {8{cache_sel_o_tag_hit[21]}}, {8{cache_sel_o_tag_hit[20]}},
		{8{cache_sel_o_tag_hit[19]}}, {8{cache_sel_o_tag_hit[18]}}, {8{cache_sel_o_tag_hit[17]}}, {8{cache_sel_o_tag_hit[16]}},
		{8{cache_sel_o_tag_hit[15]}}, {8{cache_sel_o_tag_hit[14]}}, {8{cache_sel_o_tag_hit[13]}}, {8{cache_sel_o_tag_hit[12]}},
		{8{cache_sel_o_tag_hit[11]}}, {8{cache_sel_o_tag_hit[10]}}, {8{cache_sel_o_tag_hit[9]}}, {8{cache_sel_o_tag_hit[8]}},
		{8{cache_sel_o_tag_hit[7]}}, {8{cache_sel_o_tag_hit[6]}}, {8{cache_sel_o_tag_hit[5]}}, {8{cache_sel_o_tag_hit[4]}},
		{8{cache_sel_o_tag_hit[3]}}, {8{cache_sel_o_tag_hit[2]}}, {8{cache_sel_o_tag_hit[1]}}, {8{cache_sel_o_tag_hit[0]}}};
end endgenerate

endmodule

`endif /* DCACHE_V */
