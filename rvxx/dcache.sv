// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// TODO: Ports description:
// conly_i: Make cache behave like an sram; no slave memory operation occurs.
// cmiss_i: Cache-miss to force slave memory operation; any cache-tag-hit gets flushed-and-invalidated.
// coherency_en_i: Enable logic that uses/generates coherency traffic.

/* ### Cache Coherency logic:
- Data-caches in the same coherency circle are daisy-chained serially in a round-robin fashion
	using valid-ready handshake connections.
- When reading:
	- On cache-miss, look for a hit in other data-caches by sending a read request.
		If a data-cache has a hit, it modifies the read request with the requested data.
		If no data-cache has a hit, the read request goes around back to the requesting data-cache, and gets
			discarded while the requesting data-cache proceed to the REFILL state to fetch the data needed.
- When writing:
	- Send write request to update any other data-caches with a matching cache-tag,
		keeping their dirty state unchanged (made clean instead when the write request updates
		all bits), because only the data-cache being written will have
		its cache-entry set dirty, and we only want one of the data-caches to flush-to-memory.
- Coherency requests have priority over regular operations that are not atomic.
- Coherency requests never create/flush/refill a cache-entry in a data-cache; they only use/update
	an existing cache-entry if its cache-tag matches. */

`ifndef DCACHE_V
`define DCACHE_V

`include "lib/skidbuf.sv"

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

	,coherency_en_i

	,coherency_stb_i
	,coherency_rqid_i
	,coherency_we_i
	,coherency_addr_i
	,coherency_sel_i
	,coherency_dat_i
	,coherency_shr_i
	,coherency_bsy_o

	,coherency_stb_o
	,coherency_rqid_o
	,coherency_we_o
	,coherency_addr_o
	,coherency_sel_o
	,coherency_dat_o
	,coherency_shr_o
	,coherency_bsy_i
	,coherency_near_bsy_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter ADDRLIMIT = 'h2000;

parameter CACHESETCNT = 2;
parameter CACHEWAYCNT = 1;

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter INITFILE = "";

parameter PUIDBITSZ = 1;
parameter PUID      = 0;

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

input wire coherency_en_i;

input  wire                               coherency_stb_i;
input  wire [PUIDBITSZ -1 : 0]            coherency_rqid_i;
input  wire                               coherency_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        coherency_sel_i;
input  wire [WORDBITSZ -1 : 0]            coherency_dat_i;
input  wire                               coherency_shr_i;
output wire                               coherency_bsy_o;

output reg                                coherency_stb_o;
output reg  [PUIDBITSZ -1 : 0]            coherency_rqid_o;
output reg                                coherency_we_o;
output reg  [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_o;
output reg  [(WORDBITSZ/8) -1 : 0]        coherency_sel_o;
output reg  [WORDBITSZ -1 : 0]            coherency_dat_o;
output reg                                coherency_shr_o;
input  wire                               coherency_bsy_i;
input  wire                               coherency_near_bsy_i;

wire _m_wb_stb_i = (m_wb_stb_i && !m_wb_bsy_o);

reg lock_r;
always_ff @(posedge clk_i) begin
	if (rst_i)
		lock_r <= 0;
	else if (_m_wb_stb_i)
		lock_r <= m_wb_lock_i;
end
wire _cmiss_i = (cmiss_i || m_wb_lock_i || lock_r);

reg [PUIDBITSZ -1 : 0]            m_wb_rqid_r;
reg                               m_wb_lock_r;
reg                               m_wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        m_wb_sel_r;
reg [WORDBITSZ -1 : 0]            m_wb_dat_r;
reg                               m_wb_shr_r;

reg rst_r;
reg conly_r;
reg cmiss_r;
reg coherency_r; // True when handling a coherency request.

reg                               coherency_stb_r; // True when looking for data in other data-caches.
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        coherency_sel_r;

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

wire cache_we = (!(cmiss_r || coherency_r) && (
	(state == TSTHIT && m_wb_we_r) ||
	(state == REFILL && !s_wb_we_o && refill_ack)));

wire [CACHEWAYCNT -1 : 0] cache_we0;
wire [CACHEWAYCNT -1 : 0] cache_we1;
wire [CACHEWAYCNT -1 : 0] cache_we2;

localparam CACHETAGBITSIZE = ((ADDRBITSZ-MSBSZIGN) - CLOG2CACHESETCNT);

// The check `(coherency_rqid_i != PUID || coherency_we_i)` is used for the same reason it is used to set __coherency_stb_i.
wire [CLOG2CACHESETCNT -1 : 0] cache_rdidx = ((coherency_stb_i && (coherency_rqid_i != PUID || coherency_we_i) && !lock_r) || coherency_stb_r) ?
	coherency_addr_i[0 +: CLOG2CACHESETCNT] : m_wb_addr_i[0 +: CLOG2CACHESETCNT];
wire [CLOG2CACHESETCNT -1 : 0] cache_wridx = m_wb_addr_r[0 +: CLOG2CACHESETCNT];

reg [CACHETAGBITSIZE -1 : 0] cache_tag_o [CACHEWAYCNT];
reg [(WORDBITSZ/8) -1 : 0]   cache_sel_o [CACHEWAYCNT];
reg [WORDBITSZ -1 : 0]       cache_dat_o [CACHEWAYCNT];
reg                          cache_drt_o [CACHEWAYCNT];
reg                          cache_shr_o [CACHEWAYCNT];

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
// Note that cache_we_wayidx_ does not get incremented when coherency_r is true because it makes cache_we null.
// cache_we_wayidx_ must remain constant until the cache-entry has been written, even much later after a coherency search.
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

wire cache_shr_o_tag_hit = cache_shr_o[cache_tag_hit_wayidx];

wire [(WORDBITSZ/8) -1 : 0] cache_sel_i_ = (cache_tag_hit ? (m_wb_sel_r | cache_sel_o_tag_hit) : m_wb_sel_r);
wire [(WORDBITSZ/8) -1 : 0] cache_sel_i = (
	conly_r ? {(WORDBITSZ/8){1'b0}} :
	(state == TSTHIT) ? (cache_sel_i_ & (cmiss_r ? ~m_wb_sel_r : {(WORDBITSZ/8){1'b1}})) :
	(state == REFILL) ? ((cache_tag_hit ? cache_sel_o_tag_hit : {(WORDBITSZ/8){1'b0}}) | s_wb_sel_o) : {(WORDBITSZ/8){1'b0}});

wire [WORDBITSZ -1 : 0] _m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit_n = ~_cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _s_wb_dat_i = ((m_wb_dat_r & _m_wb_sel_r) |
	(s_wb_dat_i & _m_wb_sel_r_n & (cache_tag_hit ? _cache_sel_o_tag_hit_n : {WORDBITSZ{1'b1}})) |
	(cache_tag_hit ? (cache_dat_o_tag_hit & _cache_sel_o_tag_hit) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i_ = ((m_wb_dat_r & _m_wb_sel_r) | (cache_tag_hit ? (cache_dat_o_tag_hit & _m_wb_sel_r_n) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i = ((state == TSTHIT) ? cache_dat_i_ : _s_wb_dat_i);

wire cache_drt_i = (coherency_r ?
	// If coherency request updates all bits, then make dirty state clean instead of preserving dirty state.
	(((&m_wb_sel_r) && m_wb_rqid_r != PUID) ? 1'b0 : (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx])) :
	(!(/*rst_r ||*/ conly_r || (cmiss_r && (&m_wb_sel_r))) && ((m_wb_we_r && !cmiss_r) || (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx]))));

wire cache_shr_i = ((state == TSTHIT) ? // m_wb_shr_r is used only when the coherency request has come back around.
	(coherency_r ? (!m_wb_we_r || m_wb_rqid_r != PUID || m_wb_shr_r) : (cache_tag_hit ? cache_shr_o_tag_hit : 1'b1)) :
	(|m_wb_sel_r)); // m_wb_sel_r is non-null at REFILL when merging data from coherency search.

wire _coherency_stb_i;

reg _coherency_stb_r_r;
reg __coherency_stb_r_r;

wire cache_hit = (conly_r ||
	// There is a cachehit when there is a cache tag hit and the selected bits are in the cache.
	(cache_tag_hit && (m_wb_sel_r & cache_sel_o_tag_hit) == m_wb_sel_r));

genvar gen_cache_idx;
generate for (
	gen_cache_idx = 0;
	gen_cache_idx < CACHEWAYCNT;
	gen_cache_idx = gen_cache_idx + 1) begin :gen_cache

reg [CACHETAGBITSIZE -1 : 0] cache_tags [CACHESETCNT];
reg [(WORDBITSZ/8) -1 : 0]   cache_sels [CACHESETCNT];
reg [WORDBITSZ -1 : 0]       cache_dats [CACHESETCNT];
reg                          cache_drts [CACHESETCNT];
reg                          cache_shrs [CACHESETCNT];

initial begin
	if (INITFILE != "" && gen_cache_idx == 0 /* TODO: check whether worst logic */) begin
		$readmemh (INITFILE, cache_dats);
		`ifdef SIMULATION
		$display ("%s loaded", INITFILE);
		`endif
	end
end

always_ff @(posedge clk_i) begin
	if (_m_wb_stb_i || _coherency_stb_i) begin
		cache_tag_o[gen_cache_idx] <= cache_tags[cache_rdidx];
		cache_sel_o[gen_cache_idx] <= cache_sels[cache_rdidx];
		cache_dat_o[gen_cache_idx] <= cache_dats[cache_rdidx];
		cache_drt_o[gen_cache_idx] <= cache_drts[cache_rdidx];
		cache_shr_o[gen_cache_idx] <= cache_shrs[cache_rdidx];
	end
end

assign cache_we0[gen_cache_idx] = (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && m_wb_rqid_r != PUID) || __coherency_stb_r_r) && (coherency_r && m_wb_we_r))));
assign cache_we1[gen_cache_idx] = (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && (cache_tag_hit_[gen_cache_idx] || __coherency_stb_r_r) && coherency_r)));
assign cache_we2[gen_cache_idx] = (rst_r || (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && (cmiss_r ||  m_wb_rqid_r != PUID)) || __coherency_stb_r_r) &&
			((cmiss_r && cache_hit) || (coherency_r && m_wb_we_r))))));

always_ff @(posedge clk_i) begin
	if (cache_we0[gen_cache_idx]) begin
		cache_tags[cache_wridx] <= cache_tag_i;
		cache_dats[cache_wridx] <= cache_dat_i;
	end
end

always_ff @(posedge clk_i) begin
	if (cache_we1[gen_cache_idx]) begin
		cache_shrs[cache_wridx] <= cache_shr_i;
	end
end

always_ff @(posedge clk_i) begin
	if (cache_we2[gen_cache_idx]) begin
		cache_sels[cache_wridx] <= cache_sel_i;
		cache_drts[cache_wridx] <= cache_drt_i;
	end
end

assign cache_tag_hit_[gen_cache_idx] = ((|cache_sel_o[gen_cache_idx]) &&
	m_wb_addr_r[(ADDRBITSZ-MSBSZIGN) -1 : CLOG2CACHESETCNT] == cache_tag_o[gen_cache_idx]);

end endgenerate

wire cache_miss = (state == TSTHIT && !cache_hit);

wire cache_drt_o_we_wayidx = cache_drt_o[cache_we_wayidx];

wire cache_writeb = (cache_drt_o_we_wayidx && !cache_tag_hit);

// This signal is true when coherency_*_o registers cannot be updated with a new request for the next data-cache.
wire _coherency_bsy_i = (state == READY ? (coherency_bsy_i && coherency_stb_o) : coherency_near_bsy_i);

// This signal is high when coherency_stb_i cannot yet be consumed.
wire coherency_bsy_o_ = (rst_r || cmiss_r || !(state == READY || state == TSTHIT) || _coherency_bsy_i ||
	(m_wb_we_r && cache_rdidx == cache_wridx) /* wait for cache-write */ ||
	(cache_miss && (cache_writeb || !m_wb_we_r) && !coherency_r && !coherency_stb_r));

// `lock_r` is used to insure that atomic operation has priority over coherency request.
assign _coherency_stb_i = (coherency_stb_i && !coherency_bsy_o_ && !lock_r);
// coherency_we_i is checked to process a write coherency request that came back around;
// it is used to mark the cache-entry as exclusive if it did not modified another data-cache.
wire __coherency_stb_i = (_coherency_stb_i && (coherency_rqid_i != PUID || coherency_we_i));

assign coherency_bsy_o = (coherency_bsy_o_ || lock_r);

// True when we were looking for data in other data-caches and we received a response
// which would be a hit if `(coherency_sel_i & coherency_sel_r) == coherency_sel_r`.
wire _coherency_stb_r = (coherency_stb_r && _coherency_stb_i && !coherency_we_i &&
	coherency_rqid_i == PUID && coherency_addr_i == coherency_addr_r);

always_ff @(posedge clk_i)
	_coherency_stb_r_r <= _coherency_stb_r;

wire __coherency_stb_r = (_coherency_stb_r && (coherency_sel_i & coherency_sel_r) == coherency_sel_r);

always_ff @(posedge clk_i)
	__coherency_stb_r_r <= (__coherency_stb_r && (state == READY || state == TSTHIT));

always_ff @(posedge clk_i) begin
	// State machine generating coherency requests, sending it to the next data-cache.
	if (rst_i || !coherency_en_i) begin
		coherency_stb_o <= 1'b0;
		coherency_stb_r <= 1'b0;
	end else if (state == TSTHIT && !coherency_r &&
		(m_wb_we_r || !cache_hit) && !(conly_r || cmiss_r) &&
		(!m_wb_we_r || !cache_tag_hit || cache_shr_o_tag_hit)) begin
		// When writing, this state generates write request to update other data-caches only if the cache-entry is shared.
		// When reading, on cache-miss, this state generates read request to look for data in other data-caches.
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= PUID;
		coherency_we_o <= m_wb_we_r;
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= (m_wb_sel_r & {(WORDBITSZ/8){m_wb_we_r}}); // Initially null for aggregation.
		coherency_dat_o <= (m_wb_dat_r & {WORDBITSZ{m_wb_we_r}}); // Initially null for aggregation.
		coherency_shr_o <= 1'b0; // Becomes non-null when any of the next data-caches use the request.
		if (!m_wb_we_r) begin // For power-efficiency, otherwise this test is not needed.
			coherency_addr_r <= m_wb_addr_r;
			coherency_sel_r <= (m_wb_sel_r & (cache_tag_hit ? ~cache_sel_o_tag_hit : {(WORDBITSZ/8){1'b1}}));
			// Note that we exclude the bits already in the cache-entry so that __coherency_stb_r matches
			// only the bits we need, and so that we correctly merge them for the result.
		end
		coherency_stb_r <= !m_wb_we_r;
	end else if (state == TSTHIT && coherency_r && !m_wb_we_r && cache_tag_hit && m_wb_rqid_r != PUID) begin
		// This state modifies the read request aggregating cache_tag_hit(s).
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= m_wb_rqid_r;
		coherency_we_o <= 1'b0;
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= (m_wb_sel_r | cache_sel_o_tag_hit);
		coherency_dat_o <= ((m_wb_dat_r & _cache_sel_o_tag_hit_n) | (cache_dat_o_tag_hit & _cache_sel_o_tag_hit));
		coherency_shr_o <= 1'b1;
	end else if (state == TSTHIT && coherency_r && m_wb_rqid_r != PUID) begin
		// This state forwards the request to the next data-cache.
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= m_wb_rqid_r;
		coherency_we_o <= m_wb_we_r;
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= m_wb_sel_r;
		coherency_dat_o <= m_wb_dat_r;
		if (cache_tag_hit)
			coherency_shr_o <= 1'b1;
		else
			coherency_shr_o <= m_wb_shr_r;
	end else begin
		if (coherency_stb_o)
			coherency_stb_o <= coherency_bsy_i;
		if  (_coherency_stb_r_r)
			coherency_stb_r <= 1'b0;
	end
end

wire coherency_write_req = (state == TSTHIT && m_wb_we_r && !coherency_r &&
	!(conly_r || cmiss_r) && (!cache_tag_hit || cache_shr_o_tag_hit));

wire coherency_write_ack = (_coherency_stb_i && coherency_rqid_i == PUID && coherency_we_i);

reg [(PUIDBITSZ**2) -1 : 0] coherency_write_pending;
always_ff @(posedge clk_i) begin
	if (rst_i || !coherency_en_i)
		coherency_write_pending <= 0;
	else if (coherency_write_req && coherency_write_ack);
	else if (coherency_write_ack)
		coherency_write_pending <= coherency_write_pending - 1'b1;
	else if (coherency_write_req) begin
		coherency_write_pending <= coherency_write_pending + 1'b1;
	end
end

assign m_wb_bsy_o = (coherency_bsy_o_ || __coherency_stb_i || coherency_stb_r ||
	// Right before the start of an atomic operation, coherency_write_pending is
	// used to wait for pending coherency writes to update all other data caches.
	(coherency_write_pending && m_wb_lock_i && !lock_r));

assign m_wb_ack_o = (
	state == TSTHIT ? (((cache_hit || m_wb_we_r) && !coherency_r) || __coherency_stb_r_r) :
	state == REFILL ? (!s_wb_we_o && refill_ack) : 1'b0);

assign m_wb_dat_o = (state == TSTHIT ? (__coherency_stb_r_r ? cache_dat_i_ : cache_dat_o_tag_hit) : _s_wb_dat_i);

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rst_r <= 1;

		m_wb_we_r <= 0;

		m_wb_addr_r <= 0;

		s_wb_stb_o <= 0;

		conly_r <= 0;
		cmiss_r <= 0;

		coherency_r <= 0;

		state <= READY;

	end else begin

		unique if (state == READY || state == TSTHIT) begin

			if (rst_r) begin

				if (m_wb_addr_r == (CACHESETCNT - 1))
					rst_r <= 0;
				else
					m_wb_addr_r <= m_wb_addr_r + 1'b1;

			end else if (!coherency_r && (cmiss_r ?
				(cache_hit && !m_wb_we_r && (m_wb_lock_r || cache_drt_o_we_wayidx)) :
				(cache_miss && cache_writeb))) begin

				s_wb_stb_o <= 1;
				s_wb_lock_o <= m_wb_lock_r;
				s_wb_we_o <= 1;
				s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
				s_wb_sel_o <= cache_sel_o[cache_we_wayidx] & (cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}});
				s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

				state <= WRITEB;

			end else if ((cache_miss && !m_wb_we_r && !coherency_en_i) || cmiss_r) begin

				m_wb_sel_r <= {(WORDBITSZ/8){1'b0}}; // Used when writing cache at (state == REFILL).

				s_wb_stb_o <= 1;
				s_wb_lock_o <= m_wb_lock_r;
				s_wb_we_o <= m_wb_we_r;
				s_wb_addr_o <= m_wb_addr_r;
				s_wb_sel_o <= cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}};
				if (m_wb_we_r) // For power-efficiency, otherwise this test is not needed.
					s_wb_dat_o <= m_wb_dat_r;

				state <= REFILL;

			end else if (_m_wb_stb_i || __coherency_stb_i || _coherency_stb_r) begin

				if (__coherency_stb_r) begin

					m_wb_rqid_r <= coherency_rqid_i;
					m_wb_we_r <= 1;
					m_wb_addr_r <= coherency_addr_i;
					m_wb_sel_r <= coherency_sel_r; // coherency_sel_i is not used because it may contain atomic data not meant to be cached.
					m_wb_dat_r <= coherency_dat_i;
					m_wb_shr_r <= coherency_shr_i; // Updated only when setting coherency_r true.

					coherency_r <= 1;

					state <= TSTHIT;

				end else if (_coherency_stb_r) begin

					m_wb_we_r <= 0; // Used when writing cache at (state == REFILL).
					m_wb_addr_r <= coherency_addr_r; // Used when writing cache at (state == REFILL).
					m_wb_sel_r <= coherency_sel_i; // Used when writing cache at (state == REFILL).
					m_wb_dat_r <= coherency_dat_i;

					s_wb_stb_o <= 1;
					s_wb_lock_o <= 0;
					s_wb_we_o <= 0;
					s_wb_addr_o <= coherency_addr_r;
					s_wb_sel_o <= coherency_sel_r;

					state <= REFILL;

				end else if (__coherency_stb_i) begin

					m_wb_rqid_r <= coherency_rqid_i;
					m_wb_we_r <= coherency_we_i;
					m_wb_addr_r <= coherency_addr_i;
					m_wb_sel_r <= coherency_sel_i;
					m_wb_dat_r <= coherency_dat_i;
					m_wb_shr_r <= coherency_shr_i; // Updated only when setting coherency_r true.

					coherency_r <= 1;

					state <= TSTHIT;

				end else begin

					m_wb_lock_r <= m_wb_lock_i;
					m_wb_we_r <= m_wb_we_i;
					m_wb_addr_r <= m_wb_addr_i;
					m_wb_sel_r <= m_wb_sel_i;
					m_wb_dat_r <= m_wb_dat_i;

					conly_r <= conly_i;
					cmiss_r <= _cmiss_i;

					coherency_r <= 0;

					state <= TSTHIT;
				end

			end else begin

				m_wb_we_r <= 0;

				conly_r <= 0;
				cmiss_r <= 0;

				coherency_r <= 0;

				state <= READY;
			end

		end else if (state == WRITEB) begin

			if (MAXPENDINGACK ? !s_wb_bsy_i : s_wb_ack_i) begin

				if (cmiss_r || m_wb_we_r || coherency_en_i) begin

					m_wb_we_r <= 0;

					s_wb_stb_o <= 0;

					conly_r <= 0;
					cmiss_r <= 0;

					state <= READY;

				end else begin

					m_wb_sel_r <= {(WORDBITSZ/8){1'b0}}; // Used when writing cache at (state == REFILL).

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

	,coherency_en_i

	,coherency_stb_i
	,coherency_rqid_i
	,coherency_we_i
	,coherency_addr_i
	,coherency_sel_i
	,coherency_dat_i
	,coherency_shr_i
	,coherency_bsy_o

	,coherency_stb_o
	,coherency_rqid_o
	,coherency_we_o
	,coherency_addr_o
	,coherency_sel_o
	,coherency_dat_o
	,coherency_shr_o
	,coherency_bsy_i
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

parameter PUIDBITSZ = 1;
parameter PUID      = 0;

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

input wire coherency_en_i;

input  wire                               coherency_stb_i;
input  wire [PUIDBITSZ -1 : 0]            coherency_rqid_i;
input  wire                               coherency_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        coherency_sel_i;
input  wire [WORDBITSZ -1 : 0]            coherency_dat_i;
input  wire                               coherency_shr_i;
output wire                               coherency_bsy_o;

output wire                               coherency_stb_o;
output wire [PUIDBITSZ -1 : 0]            coherency_rqid_o;
output wire                               coherency_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        coherency_sel_o;
output wire [WORDBITSZ -1 : 0]            coherency_dat_o;
output reg                                coherency_shr_o;
input  wire                               coherency_bsy_i;

wire                               coherency_stb_o_;
wire [PUIDBITSZ -1 : 0]            coherency_rqid_o_;
wire                               coherency_we_o_;
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_o_;
wire [(WORDBITSZ/8) -1 : 0]        coherency_sel_o_;
wire [WORDBITSZ -1 : 0]            coherency_dat_o_;
wire                               coherency_shr_o_;
wire                               coherency_bsy_i_; // ### Should be named _coherency_bsy_i as it is downstream.
wire                               coherency_near_bsy_i;

skidbuf #(
	 .WIDTH       (2 + (2*PUIDBITSZ) + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ)
	,.DEPTH       (1<<PUIDBITSZ)
	,.USEFWFTFIFO (1)
) skidBuf_coherency (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (coherency_stb_o_)
	,.dat_i ({coherency_rqid_o_, coherency_we_o_, coherency_addr_o_, coherency_sel_o_, coherency_dat_o_, coherency_shr_o_})
	,.bsy_o (coherency_bsy_i_)
	,.near_bsy_o (coherency_near_bsy_i)

	,.stb_o (coherency_stb_o)
	,.dat_o ({coherency_rqid_o, coherency_we_o, coherency_addr_o, coherency_sel_o, coherency_dat_o, coherency_shr_o})
	,.bsy_i (coherency_bsy_i)
);

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

dCacheSub #(
	 .WORDBITSZ     (WORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.CACHESETCNT   (CACHESETCNT)
	,.CACHEWAYCNT   (CACHEWAYCNT)
	,.MAXPENDINGACK (MAXPENDINGACK)
	,.INITFILE      (INITFILE)
	,.PUIDBITSZ     (PUIDBITSZ)
	,.PUID          (PUID)
) dCacheSub (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.conly_i (conly_i)
	,.cmiss_i (cmiss_i)

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

	,.coherency_en_i (coherency_en_i)

	,.coherency_stb_i  (coherency_stb_i)
	,.coherency_rqid_i (coherency_rqid_i)
	,.coherency_we_i   (coherency_we_i)
	,.coherency_addr_i (coherency_addr_i)
	,.coherency_sel_i  (coherency_sel_i)
	,.coherency_dat_i  (coherency_dat_i)
	,.coherency_shr_i  (coherency_shr_i)
	,.coherency_bsy_o  (coherency_bsy_o)

	,.coherency_stb_o  (coherency_stb_o_)
	,.coherency_rqid_o (coherency_rqid_o_)
	,.coherency_we_o   (coherency_we_o_)
	,.coherency_addr_o (coherency_addr_o_)
	,.coherency_sel_o  (coherency_sel_o_)
	,.coherency_dat_o  (coherency_dat_o_)
	,.coherency_shr_o  (coherency_shr_o_)
	,.coherency_bsy_i  (coherency_bsy_i_)
	,.coherency_near_bsy_i (coherency_near_bsy_i)
);

endmodule

`endif /* DCACHE_V */
