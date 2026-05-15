// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// TODO: Ports description:
// conly_i: Make cache behave like an sram; no slave memory operation occur.
// cmiss_i: Cache-miss to force slave memory operation; any cache-tag-hit get flushed-and-invalidated.

`ifndef DCACHE_V
`define DCACHE_V

module dCacheSub (

	 rst_i

	,clk_i

	,conly_i
	,cmiss_i

	,m_wb_stb_i
	,m_wb_lock_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_stb_o
	,s_wb_lock_o
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

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter INITFILE = "";

localparam CLOG2CACHESETCNT = clog2(CACHESETCNT);
localparam CLOG2CACHEWAYCNT = clog2(CACHEWAYCNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

input wire rst_i;

input wire clk_i;

input wire conly_i;
input wire cmiss_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_lock_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output wire                               m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;

output reg                                s_wb_stb_o;
output reg                                s_wb_lock_o;
output reg                                s_wb_we_o;
output reg  [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output reg  [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output reg  [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

wire _m_wb_stb_i = (m_wb_stb_i && !m_wb_bsy_o);

reg                               m_wb_lock_r;
reg                               m_wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        m_wb_sel_r;
reg [WORDBITSZ -1 : 0]            m_wb_dat_r;

reg rst_r;
reg conly_r;
reg cmiss_r;

localparam READY  = 0;
localparam TSTHIT = 1;
localparam WRITEB = 2;
localparam REFILL = 3;
reg [2 -1 : 0] state;

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] s_wb_ack_pending;
generate if (MAXPENDINGACK) begin
always_ff @(posedge clk_i) begin
	if (rst_i)
		s_wb_ack_pending <= 0;
	else if (s_wb_stb_o && !s_wb_bsy_i && s_wb_ack_i);
	else if (s_wb_ack_i)
		s_wb_ack_pending <= s_wb_ack_pending - 1'b1;
	else if (s_wb_stb_o && !s_wb_bsy_i) begin
		s_wb_ack_pending <= s_wb_ack_pending + 1'b1;
	end
end
end endgenerate

// When MAXPENDINGACK is non-null, and the sequencing of WRITEB followed by REFILL
// occurs, the expression (!s_wb_stb_o && s_wb_ack_pending == 1) identifies the ack
// of REFILL, because we could still be waiting for the ack of WRITEB.
wire refill_ack = (s_wb_ack_i && (!MAXPENDINGACK || (!s_wb_stb_o && s_wb_ack_pending == 1)));

wire cache_we = (!cmiss_r && (
	(state == TSTHIT && m_wb_we_r) ||
	(state == REFILL && !s_wb_we_o && refill_ack)));

localparam CACHETAGBITSIZE = ((ADDRBITSZ-MSBSZIGN) - CLOG2CACHESETCNT);

wire [CLOG2CACHESETCNT -1 : 0] cache_rdidx = m_wb_addr_i[0 +: CLOG2CACHESETCNT];
wire [CLOG2CACHESETCNT -1 : 0] cache_wridx = m_wb_addr_r[0 +: CLOG2CACHESETCNT];

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

reg [CLOG2CACHEWAYCNT -1 : 0] cache_we_wayidx_;

always_ff @(posedge clk_i) begin
	if (CACHEWAYCNT == 1 || (_m_wb_stb_i && conly_i) || conly_r) begin
		cache_we_wayidx_ <= 0;
	end else if (cache_we && (cache_tag_hit && cache_we_wayidx_ == cache_tag_hit_wayidx)) begin
		cache_we_wayidx_ <= cache_we_wayidx_ + 1'b1;
	end
end

wire [CLOG2CACHEWAYCNT -1 : 0] cache_we_wayidx = (cache_tag_hit ? cache_tag_hit_wayidx : cache_we_wayidx_);

wire [CACHETAGBITSIZE -1 : 0] cache_tag_i = m_wb_addr_r[(ADDRBITSZ-MSBSZIGN) -1 : CLOG2CACHESETCNT];

wire [(WORDBITSZ/8) -1 : 0] cache_sel_o_tag_hit = cache_sel_o[cache_tag_hit_wayidx];

wire [WORDBITSZ -1 : 0] cache_dat_o_tag_hit = cache_dat_o[cache_tag_hit_wayidx];

wire [(WORDBITSZ/8) -1 : 0] cache_sel_i = (
	(conly_r || cmiss_r) ? {(WORDBITSZ/8){1'b0}} :
	(state == TSTHIT) ? (cache_tag_hit ? (m_wb_sel_r | cache_sel_o_tag_hit) : m_wb_sel_r) :
	(state == REFILL) ? {(WORDBITSZ/8){1'b1}} : {(WORDBITSZ/8){1'b0}});

wire [WORDBITSZ -1 : 0] _m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [WORDBITSZ -1 : 0] cache_dat_i = ((state == TSTHIT) ?
		(cache_tag_hit ?
			((m_wb_dat_r & _m_wb_sel_r) | (cache_dat_o_tag_hit & _m_wb_sel_r_n)) :
			m_wb_dat_r) :
		s_wb_dat_i);

wire cache_drt_i = (!(/*rst_r ||*/ conly_r || cmiss_r) && m_wb_we_r);

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

always_ff @(posedge clk_i) begin
	if (_m_wb_stb_i) begin
		cache_tag_o[gen_cache_idx] <= cache_tags[cache_rdidx];
		cache_sel_o[gen_cache_idx] <= cache_sels[cache_rdidx];
		cache_dat_o[gen_cache_idx] <= cache_dats[cache_rdidx];
		cache_drt_o[gen_cache_idx] <= cache_drts[cache_rdidx];
	end
end

wire _cache_we = (cache_we && gen_cache_idx == cache_we_wayidx);

always_ff @(posedge clk_i) begin
	if (_cache_we) begin
		cache_tags[cache_wridx] <= cache_tag_i;
		cache_dats[cache_wridx] <= cache_dat_i;
	end
end

always_ff @(posedge clk_i) begin
	if (rst_r || _cache_we || (state == TSTHIT && cache_tag_hit_[gen_cache_idx] && cmiss_r)) begin
		cache_sels[cache_wridx] <= cache_sel_i;
		cache_drts[cache_wridx] <= cache_drt_i;
	end
end

assign cache_tag_hit_[gen_cache_idx] = ((|cache_sel_o[gen_cache_idx]) &&
	m_wb_addr_r[(ADDRBITSZ-MSBSZIGN) -1 : CLOG2CACHESETCNT] == cache_tag_o[gen_cache_idx]);

end endgenerate

wire cache_hit = (conly_r ||
	// There is a cachehit when there is a cache tag hit and the selected bits are in the cache.
	(cache_tag_hit && (m_wb_sel_r & cache_sel_o_tag_hit) == m_wb_sel_r));

wire cache_miss = (state == TSTHIT && !cache_hit);

wire cache_drt_o_we_wayidx = cache_drt_o[cache_we_wayidx];

wire cache_writeb = (cache_drt_o_we_wayidx && (!m_wb_we_r || !cache_tag_hit));

assign m_wb_bsy_o = (rst_r || cmiss_r || !(state == READY || state == TSTHIT) ||
	(m_wb_we_r && cache_rdidx == cache_wridx) /* wait for cache-write */ ||
	(cache_miss && (cache_writeb || !m_wb_we_r)));

assign m_wb_ack_o = (state == TSTHIT ? ((!cmiss_r && cache_hit) || m_wb_we_r) :
	(state == REFILL && !s_wb_we_o && refill_ack));

assign m_wb_dat_o = (state == TSTHIT ? cache_dat_o_tag_hit : s_wb_dat_i);

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rst_r <= 1;

		m_wb_we_r <= 0;

		m_wb_addr_r <= 0;

		s_wb_stb_o <= 0;

		conly_r <= 0;
		cmiss_r <= 0;

		state <= READY;

	end else begin

		unique if (state == READY || state == TSTHIT) begin

			if (rst_r) begin

				if (m_wb_addr_r == (CACHESETCNT - 1))
					rst_r <= 0;
				else
					m_wb_addr_r <= m_wb_addr_r + 1'b1;

			end else if (cmiss_r ? (cache_tag_hit && cache_drt_o_we_wayidx) :
				(cache_miss && cache_writeb)) begin

				s_wb_stb_o <= 1;
				s_wb_lock_o <= 0;
				s_wb_we_o <= 1;
				s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
				s_wb_sel_o <= cache_sel_o[cache_we_wayidx];
				s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

				state <= WRITEB;

			end else if ((cache_miss && !m_wb_we_r) || cmiss_r) begin

				s_wb_stb_o <= 1;
				s_wb_lock_o <= m_wb_lock_r;
				s_wb_we_o <= m_wb_we_r;
				s_wb_addr_o <= m_wb_addr_r;
				s_wb_sel_o <= cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}};
				if (m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
					s_wb_dat_o <= m_wb_dat_r;

				state <= REFILL;

			end else if (_m_wb_stb_i) begin

				m_wb_lock_r <= m_wb_lock_i;
				m_wb_we_r <= m_wb_we_i;
				m_wb_addr_r <= m_wb_addr_i;
				m_wb_sel_r <= m_wb_sel_i;
				m_wb_dat_r <= m_wb_dat_i;

				conly_r <= conly_i;
				cmiss_r <= cmiss_i;

				state <= TSTHIT;

			end else begin

				m_wb_we_r <= 0;

				conly_r <= 0;
				cmiss_r <= 0;

				state <= READY;
			end

		end else if (state == WRITEB) begin

			if (MAXPENDINGACK ? !s_wb_bsy_i : s_wb_ack_i) begin

				if (m_wb_we_r && !cmiss_r) begin

					m_wb_we_r <= 0;

					s_wb_stb_o <= 0;

					conly_r <= 0;
					cmiss_r <= 0;

					state <= READY;

				end else begin

					s_wb_stb_o <= 1;
					s_wb_lock_o <= m_wb_lock_r;
					s_wb_we_o <= m_wb_we_r;
					s_wb_addr_o <= m_wb_addr_r;
					s_wb_sel_o <= (cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}});
					if (m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
						s_wb_dat_o <= m_wb_dat_r;

					state <= REFILL;
				end

			end else if (!s_wb_bsy_i && !MAXPENDINGACK)
				s_wb_stb_o <= 0;

		end else if (state == REFILL) begin

			if (refill_ack || (MAXPENDINGACK && m_wb_we_r && !s_wb_bsy_i)) begin

				m_wb_we_r <= 0;

				s_wb_stb_o <= 0;

				conly_r <= 0;
				cmiss_r <= 0;

				state <= READY;

			end else if (!s_wb_bsy_i)
				s_wb_stb_o <= 0;
		end
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

endmodule

module dCache (

	 rst_i

	,clk_i

	,conly_i
	,cmiss_i

	,m_wb_stb_i
	,m_wb_lock_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_stb_o
	,s_wb_lock_o
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

parameter REGMSTOUTPUT = 0;
parameter REGSLVINPUT  = 0;

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter INITFILE = "";

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input wire conly_i;
input wire cmiss_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_lock_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output reg                                m_wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire                               s_wb_stb_o;
output wire                               s_wb_lock_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

wire                    m_wb_ack_o_;
wire [WORDBITSZ -1 : 0] m_wb_dat_o_;
generate if (REGMSTOUTPUT) begin
	always_ff @(posedge clk_i) begin
		m_wb_ack_o <= m_wb_ack_o_;
		m_wb_dat_o <= m_wb_dat_o_;
	end
end else begin
	always_comb begin
		m_wb_ack_o = m_wb_ack_o_;
		m_wb_dat_o = m_wb_dat_o_;
	end
end endgenerate

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
end endgenerate

reg lock_r;
always_ff @(posedge clk_i) begin
	if (rst_i)
		lock_r <= 0;
	else if (m_wb_stb_i && !m_wb_bsy_o)
		lock_r <= m_wb_lock_i;
end
wire _cmiss_i = (cmiss_i || m_wb_lock_i || lock_r);

dCacheSub #(
	 .WORDBITSZ     (WORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.CACHESETCNT   (CACHESETCNT)
	,.CACHEWAYCNT   (CACHEWAYCNT)
	,.MAXPENDINGACK (MAXPENDINGACK)
	,.INITFILE      (INITFILE)
) dCacheSub (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.conly_i (conly_i)
	,.cmiss_i (_cmiss_i)

	,.m_wb_stb_i  (m_wb_stb_i)
	,.m_wb_lock_i (m_wb_lock_i)
	,.m_wb_we_i   (m_wb_we_i)
	,.m_wb_addr_i (m_wb_addr_i)
	,.m_wb_sel_i  (m_wb_sel_i)
	,.m_wb_dat_i  (m_wb_dat_i)
	,.m_wb_bsy_o  (m_wb_bsy_o)
	,.m_wb_ack_o  (m_wb_ack_o_)
	,.m_wb_dat_o  (m_wb_dat_o_)

	,.s_wb_stb_o  (s_wb_stb_o)
	,.s_wb_lock_o (s_wb_lock_o)
	,.s_wb_we_o   (s_wb_we_o)
	,.s_wb_addr_o (s_wb_addr_o)
	,.s_wb_sel_o  (s_wb_sel_o)
	,.s_wb_dat_o  (s_wb_dat_o)
	,.s_wb_bsy_i  (s_wb_bsy_i)
	,.s_wb_ack_i  (_s_wb_ack_i)
	,.s_wb_dat_i  (_s_wb_dat_i)
);

endmodule

`endif /* DCACHE_V */
