// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Data-cache between a master and memory, connecting to both through pipelined wishbone interfaces;
// it is write-back, and kept coherent with the other data-caches of its coherency ring, within the
// limits stated under Cache coherency.
//
// The data-cache holds CACHESETCNT cache sets of CACHEWAYCNT cache-entries, each made of a word,
// the cache-tag of its address, a valid bit for each of its bytes, a dirty bit and a shared bit.
// The cache set of an address is selected by the least significant bits of its word address, the
// remaining bits making its cache-tag. An access is a cache-hit when every byte that it selects is
// held by a cache-entry whose cache-tag matches, and a cache-miss otherwise.
//
// An access is accepted in the clockcycle in which m_wb_stb_i is high while m_wb_bsy_o is low, and
// tested in the clockcycle which follows (TSTHIT), in which the next access can already be accepted.
// An access which is not forced to miss (as explained under Ports for cmiss_i), is handled as follows:
// - A read cache-hit is acknowledged in TSTHIT, with the word of the cache-entry.
// - A write is acknowledged in TSTHIT as well, whether it is a cache-hit or not, and made in the
// 	cache-entry whose cache-tag matches, else in a cache-entry that it replaces, without reading
// 	memory (write-allocate); the bytes that it writes become valid in the cache-entry, which is
// 	marked dirty.
// - A read cache-miss is acknowledged once it has the bytes that it selects: while coherency_en_i
// 	is low, the whole word is read from memory (REFILL); while it is high, the bytes that it selects
// 	and that the cache-entry lacks are looked for in the other data-caches (as described under
// 	Cache coherency), and read from memory (REFILL) when they are not all found there.
// - A cache-miss whose cache-tag matches no cache-entry replaces one, whose content, when dirty, is
// 	written back to memory (WRITEB). The way replaced is selected by an index common to all cache
// 	sets, which moves to the next way only when a write, or a refill from memory, is made in a
// 	cache-entry of the way it selects whose cache-tag matched; an allocation does not move it.
// 	Hence, with more than one way, and unless the index moves meanwhile, a cache-entry just
// 	allocated in a cache set is the next one replaced there, whereas one that a write or a refill
// 	has just hit is not.
// A dirty cache-entry reaches memory only when it gets replaced, or, for the bytes that it selects,
// when a read forced to miss hits it; the data-cache cannot be flushed as a whole.

// Cache coherency:
//
// - Data-caches in the same coherency ring are daisy-chained, the coherency_*_o ports and
// 	coherency_bsy_i of each one connected to the coherency_*_i ports and coherency_bsy_o of the
// 	next one, and those of the last one to the first one. A coherency request travels the whole
// 	ring, each data-cache it goes through using it and forwarding it, until it comes back around to
// 	the data-cache which issued it.
// - Coherency traffic is generated only while coherency_en_i is set, and only by accesses that are
// 	neither made with conly_i nor forced to miss; one forced to miss, by cmiss_i, by the bus lock,
// 	or because it follows a locked access, generates none.
// - An access forced to miss thus neither sees nor updates the copies held by the other
// 	data-caches: a write forced to miss, eg: that of a store-conditional or of an atomic memory
// 	operation, leaves stale their copies of the bytes it writes; and a read forced to miss, eg: a
// 	load-reserved or the read of an atomic memory operation, can return data from memory older than
// 	a dirty copy held by another data-cache. This holds as well for the access which follows a
// 	locked one, which may be an ordinary load or store, eg: the first one after a compare-and-swap
// 	whose compare failed. A word accessed through atomic memory operations is therefore not to be
// 	accessed otherwise, as cpu/README.md requires.
// - Reading generates a read request only on a cache-miss, ie: when some selected byte is not in the
// 	cache-entry, and asks for those bytes only. The request always comes back around: each other
// 	data-cache whose cache-tag matches merges into it every byte it holds, and marks its own
// 	cache-entry shared. When the merged bytes cover the request, the cache-entry is filled from them,
// 	otherwise the missing bytes are read from memory (REFILL). The cache-entry is then marked shared
// 	if another data-cache matched the cache-tag, or was itself waiting on a read of that word,
// 	and exclusive otherwise.
// - Writing generates a write request whether or not it is a cache-miss, unless its cache-tag
// 	matches a cache-entry marked exclusive. When it comes back around, the cache-entry is marked
// 	exclusive if no other data-cache matched the cache-tag nor was waiting on a read of that word.
// - A read/write request from another data-cache that matches the cache-tag marks the cache-entry
// 	shared. Hence a cache-entry becomes exclusive only when a request of its own comes back having
// 	found no other copy: a write, or a read refilled from memory, including a read of a cache-entry
// 	holding only some of the selected bytes.
// - A write request from another data-cache updates the cache-entry whose cache-tag matches, the
// 	bytes it writes becoming valid in it, without changing its dirty state, so that a write request
// 	never makes another copy dirty; the cache-entry is made clean instead when the write request
// 	writes every byte of the word, all of which the store that issued it made dirty in its own
// 	data-cache.
// - A coherency request from another data-cache never allocates, writes back nor refills a
// 	cache-entry; it only reads, or updates, a cache-entry whose cache-tag matches.
// - Coherency requests have priority over the accesses of the master: a coherency request is taken
// 	ahead of an access presented in the same clockcycle; yet no coherency request is taken while the
// 	data-cache handles an access forced to miss, or a cache-miss in WRITEB or REFILL, nor while it
// 	holds the bus lock, ie: from an access carrying m_wb_lock_i until the access which follows it,
// 	the ring being held off meanwhile.
// - Atomic memory operations do not travel the ring, being forced to miss; hence an access carrying
// 	m_wb_lock_i, when the access before it did not, is accepted only once every write request that
// 	the data-cache issued has come back around, including that of a write in TSTHIT, so that the
// 	writes made before it have reached the other data-caches when it takes effect in memory.
// - Note that writes to the same word from different data-caches, whose write requests cross on the
// 	ring, are not ordered: each data-cache applies the write of the other after its own, hence each
// 	cache-entry ends up holding the value of the other for the bytes both wrote; and when both write
// 	every byte, both cache-entries are made clean, and neither write reaches memory.

// Parameters:
//
// WORDBITSZ
// 	Width of a word in bits, ie: of the data of a cache-entry, and of the data buses.
// 	It must be 16, 32, 64, 128 or 256.
//
// ADDRLIMIT
// 	Address limit from which the address bus width is derived,
// 	as the modules of lib/ do; the address buses carry word addresses.
//
// CACHESETCNT
// 	Number of cache sets, each holding CACHEWAYCNT cache-entries.
// 	It must be at least 2, a power-of-2, and less than or equal to
// 	2^(w-1), where w is the width of the address buses.
//
// CACHEWAYCNT
// 	Number of cache-entries in a cache set, ie: of ways.
// 	It must be non-null and a power-of-2.
//
// REGMSTOUTPUT
// 	When non-null, m_wb_ack_o and m_wb_dat_o are registered, delaying
// 	the response to the master by a clockcycle; m_wb_bsy_o is not registered.
//
// REGSLVINPUT
// 	When non-null, s_wb_ack_i and s_wb_dat_i are registered before use, delaying
// 	the response of the slave by a clockcycle; s_wb_bsy_i is not registered.
//
// MAXPENDINGACK
// 	When null, the data-cache waits for the acknowledgement of each access that it
// 	makes on the slave interface before going on. When non-null, it does not wait for
// 	that of a write, ie: a write-back, which speeds up evictions, or a write forced to
// 	miss; the slave interface must then never hold more than MAXPENDINGACK accesses
// 	accepted and not yet acknowledged, that count being kept to tell which
// 	acknowledgement is that of a refill.
//
// INITFILE
// 	File from which the words of way 0 are initialized using $readmemh(),
// 	for use with conly_i.
//
// PUIDBITSZ
// 	Width of coherency_rqid_*, which must hold the PUID of every data-cache of the
// 	ring; (1<<PUIDBITSZ) also sizes the skid-buffer of coherency_*_o, and the count
// 	of write requests which have not come back around. It must be non-null.
//
// PUID
// 	Identifier of the data-cache in its ring, carried by the coherency requests that
// 	it issues, from which it recognizes them when they come back around; it must be
// 	unique within the ring.

// Ports:
//
// rst_i
// 	When held high at the rising edge of the clock signal, the module resets;
// 	it must be held low for normal operation. Once it is low, the data-cache
// 	invalidates its cache-entries, a cache set per clockcycle, being busy meanwhile,
// 	ie: m_wb_bsy_o and coherency_bsy_o high; the words that they hold are kept,
// 	hence those from INITFILE. The data-caches of a ring are to be reset together,
// 	as a reset drops the coherency requests that a data-cache holds.
//
// clk_i
// 	Clock signal.
//
// conly_i
// 	When high along with m_wb_stb_i, the access is made in the cache only, as in an
// 	sram of CACHESETCNT words, ie: way 0 of the cache set that the address selects,
// 	whatever the cache-tag of the address; neither a slave access nor a coherency
// 	request is made. A write stores the bytes that it selects without preserving
// 	the others, hence only whole-word writes are reliable in that mode.
//
// cmiss_i
// 	When high along with m_wb_stb_i, the access is forced to miss, as are an access
// 	carrying m_wb_lock_i and the access which follows it; cmiss_i is to be set high
// 	combinationally from m_wb_addr_i for an address which must not be cached.
// 	An access forced to miss reaches the slave interface, and neither sees nor
// 	updates the copies held by the other data-caches, with the consequences
// 	described under Cache coherency. It is handled as follows:
// 	- A write is made in memory, the bytes that it writes being invalidated in the
// 		cache-entry whose cache-tag matches.
// 	- A read is made in memory, unless it selects only bytes held by a dirty
// 		cache-entry, which then answers it and writes them back; either way, a
// 		cache-entry holding every byte that it selects has them invalidated.
// 		When the read is made in memory, the bytes held by the cache-entry whose
// 		cache-tag matches are merged over the data read, unless the read carries
// 		m_wb_lock_i and that cache-entry is clean, as it may then be behind memory.
//
// m_wb_stb_i
// m_wb_lock_i
// m_wb_we_i
// m_wb_addr_i
// m_wb_sel_i
// m_wb_dat_i
// m_wb_bsy_o
// m_wb_ack_o
// m_wb_dat_o
// 	Pipelined wishbone slave interface, to which the master connects. An access is
// 	accepted in the clockcycle in which m_wb_stb_i is high while m_wb_bsy_o is low;
// 	each access is acknowledged by m_wb_ack_o high for a clockcycle, in the order the
// 	accesses were accepted, m_wb_dat_o then holding the bytes that a read selects.
// 	An access carrying m_wb_lock_i requests the bus lock: it reaches the slave
// 	interface with s_wb_lock_o high, and the lock is released by the access which
// 	follows it, that access being forced to miss, as explained for cmiss_i; when the
// 	access before it did not carry the lock, it is accepted only once every write
// 	request that the data-cache issued, or is issuing, has come back around, as
// 	described under Cache coherency.
//
// s_wb_stb_o
// s_wb_lock_o
// s_wb_we_o
// s_wb_addr_o
// s_wb_sel_o
// s_wb_dat_o
// s_wb_bsy_i
// s_wb_ack_i
// s_wb_dat_i
// 	Pipelined wishbone master interface, which connects to the slave, ie: memory,
// 	which is to acknowledge every access, a write as well as a read. Through it are
// 	made the write-backs, the refills and the accesses forced to miss, each one
// 	carrying the bus lock of the access that it is made for.
//
// coherency_en_i
// 	When high, the data-cache takes part in the cache-coherency logic, ie: it issues
// 	coherency requests, and forwards those of the other data-caches of the ring.
// 	It is to be low for a data-cache which is not part of a ring, its
// 	coherency_stb_i being then held low.
//
// coherency_stb_i
// coherency_rqid_i
// coherency_we_i
// coherency_addr_i
// coherency_sel_i
// coherency_dat_i
// coherency_shr_i
// coherency_bsy_o
// 	Coherency requests from the previous data-cache of the ring, each taken in the
// 	clockcycle in which coherency_stb_i is high while coherency_bsy_o is low:
// 	- coherency_rqid_i is the PUID of the data-cache which issued the request.
// 	- coherency_we_i is high for a write request, and low for a read request.
// 	- coherency_addr_i is the word address.
// 	- coherency_sel_i and coherency_dat_i are, for a write request, the bytes written
// 		and their value, and for a read request, the bytes gathered so far from the
// 		data-caches that it went through, and their value.
// 	- coherency_shr_i is high when a data-cache that the request went through matched
// 		the cache-tag, or was waiting on a read of that word.
//
// coherency_stb_o
// coherency_rqid_o
// coherency_we_o
// coherency_addr_o
// coherency_sel_o
// coherency_dat_o
// coherency_shr_o
// coherency_bsy_i
// 	Coherency requests to the next data-cache of the ring, with the same meaning,
// 	presented through a skid-buffer of (1<<PUIDBITSZ) requests.
//
// Module dCacheSub, which dCache wraps, has the same parameters, except REGMSTOUTPUT
// and REGSLVINPUT, and the same ports, its coherency_*_o being those that dCache
// presents through the skid-buffer, plus coherency_near_bsy_i, high when that
// skid-buffer is full or one request away from being full.

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

// Whether the bytes held by a cache-tag-hit are merged over the data from memory at (state == REFILL).
// They are, but for an access carrying the bus lock, ie: a load-reserved or the read of an atomic
// memory operation, which hits a clean entry: it may be behind memory, as an atomic memory operation
// from another hart, which the cache-coherency logic does not carry, may have updated memory since the
// entry was filled, whereas a dirty entry holds stores this hart made since. The access following a
// locked one is forced to miss as well, so that it reaches the bus and releases the lock, but it is not
// atomic, and the entry it hits, ahead of memory when filled from another data-cache, is what a hit returns.
wire _cache_tag_hit = (cache_tag_hit && (!cmiss_r || !m_wb_lock_r || cache_drt_o[cache_tag_hit_wayidx]));

wire [WORDBITSZ -1 : 0] _m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit_n = ~_cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _s_wb_dat_i = ((m_wb_dat_r & _m_wb_sel_r) |
	(s_wb_dat_i & _m_wb_sel_r_n & (_cache_tag_hit ? _cache_sel_o_tag_hit_n : {WORDBITSZ{1'b1}})) |
	(_cache_tag_hit ? (cache_dat_o_tag_hit & _cache_sel_o_tag_hit) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i_ = ((m_wb_dat_r & _m_wb_sel_r) | (cache_tag_hit ? (cache_dat_o_tag_hit & _m_wb_sel_r_n) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i = ((state == TSTHIT) ? cache_dat_i_ : _s_wb_dat_i);

wire cache_drt_i = (coherency_r ?
	// If coherency request updates all bits, then make dirty state clean instead of preserving dirty state.
	(((&m_wb_sel_r) && m_wb_rqid_r != PUID) ? 1'b0 : (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx])) :
	(!(/*rst_r ||*/ conly_r || (cmiss_r && (&m_wb_sel_r))) && ((m_wb_we_r && !cmiss_r) || (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx]))));

wire cache_shr_i = ((state == TSTHIT) ? // m_wb_shr_r is used only when the coherency request has come back around.
	(coherency_r ? (!m_wb_we_r || m_wb_rqid_r != PUID || m_wb_shr_r) : (cache_tag_hit ? cache_shr_o_tag_hit : 1'b1)) :
	((|m_wb_sel_r) || m_wb_shr_r)); // m_wb_sel_r is non-null at REFILL when merging data from coherency search.

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
		// A remote read request marks the entry shared through cache_we1 while m_wb_we_r is null, hence
		// the "wait for cache-write" term does not hold off a same-set access; forward the bit being written.
		cache_shr_o[gen_cache_idx] <= ((cache_we1[gen_cache_idx] && cache_wridx == cache_rdidx) ?
			cache_shr_i : cache_shrs[cache_rdidx]);
	end
end

assign cache_we0[gen_cache_idx] = (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && m_wb_rqid_r != PUID) || __coherency_stb_r_r) && (coherency_r && m_wb_we_r))));
assign cache_we1[gen_cache_idx] = (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && (cache_tag_hit_[gen_cache_idx] || __coherency_stb_r_r) && coherency_r)));
assign cache_we2[gen_cache_idx] = (rst_r || (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && (cmiss_r ||  m_wb_rqid_r != PUID)) || __coherency_stb_r_r) &&
			((cmiss_r && (cache_hit || m_wb_we_r)) || (coherency_r && m_wb_we_r))))));

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
		// A data-cache waiting on its own read of the same word is about to hold it as well.
		if (cache_tag_hit || (coherency_stb_r && coherency_addr_r == m_wb_addr_r))
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

// A coherency write stays pending from the clockcycle it is issued until it has travelled the
// whole ring and come back, hence there cannot be more of them than the ring can hold: this
// data-cache's own coherency output register and its skidbuf, plus, for each of the other
// data-caches, its request capture registers, its coherency output register and its skidbuf.
// (1<<PUIDBITSZ) is the count of data-caches rounded up to a power of two, ie: never short.
localparam COHERENCYRINGCNT = (1<<PUIDBITSZ);
localparam COHERENCYWRITEPENDINGMAX =
	((COHERENCYRINGCNT*COHERENCYRINGCNT) + (2*COHERENCYRINGCNT) - 1);
// Note that the width below is not the (clog2(N) +1) used by the other pending counters here,
// as it does not need that extra bit: clog2() rounds up, so clog2(N) bits hold up to
// ((2**clog2(N))-1), which falls short of N only when N is an exact power of two, and the
// maximum above never is; it is (((COHERENCYRINGCNT+1)**2)-2), and COHERENCYRINGCNT is a power
// of two, hence that square is odd, hence the maximum is odd and greater than one.
localparam CLOG2COHERENCYWRITEPENDINGMAX = clog2(COHERENCYWRITEPENDINGMAX);
reg [CLOG2COHERENCYWRITEPENDINGMAX -1 : 0] coherency_write_pending;
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
	// A store in TSTHIT is counted only on the clockedge ending TSTHIT, hence it holds off as well.
	((coherency_write_pending || (state == TSTHIT && m_wb_we_r && !coherency_r)) && m_wb_lock_i && !lock_r));

// A read forced to miss is acknowledged from the cache only on a cache-hit of a dirty entry, which is
// then written back; a clean one is invalidated and the read is made in memory, ie: acknowledged at REFILL.
assign m_wb_ack_o = (
	state == TSTHIT ? ((((cache_hit && (!cmiss_r || cache_drt_o_we_wayidx)) || m_wb_we_r) && !coherency_r) || __coherency_stb_r_r) :
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

		if (state == READY || state == TSTHIT) begin

			if (rst_r) begin

				if (m_wb_addr_r == (CACHESETCNT - 1))
					rst_r <= 0;
				else
					m_wb_addr_r <= m_wb_addr_r + 1'b1;

			end else if (!coherency_r && (cmiss_r ?
				(cache_hit && !m_wb_we_r && cache_drt_o_we_wayidx) :
				(cache_miss && cache_writeb))) begin
				// A read forced to miss writes back the entry it hits only when dirty. A clean entry may be
				// behind memory, as an atomic memory operation from another hart, which the cache-coherency
				// logic does not carry, may have updated memory since it was filled, hence it is only
				// invalidated, through cache_we2, and the read is made in memory by the REFILL arm below,
				// carrying the same lock, and acknowledged once from there; the bytes it held are merged
				// back for an access not carrying the lock, cf. _cache_tag_hit.

				s_wb_stb_o <= 1;
				s_wb_lock_o <= m_wb_lock_r;
				s_wb_we_o <= 1;
				s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
				s_wb_sel_o <= cache_sel_o[cache_we_wayidx] & (cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}});
				s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

				state <= WRITEB;

			end else if ((cache_miss && !m_wb_we_r && !coherency_en_i) || cmiss_r) begin

				m_wb_sel_r <= {(WORDBITSZ/8){1'b0}}; // Used when writing cache at (state == REFILL).
				m_wb_shr_r <= 1'b0;

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
					m_wb_shr_r <= coherency_shr_i; // Updated when setting coherency_r true, and for REFILL.

					coherency_r <= 1;

					state <= TSTHIT;

				end else if (_coherency_stb_r) begin

					m_wb_we_r <= 0; // Used when writing cache at (state == REFILL).
					m_wb_addr_r <= coherency_addr_r; // Used when writing cache at (state == REFILL).
					m_wb_sel_r <= coherency_sel_i; // Used when writing cache at (state == REFILL).
					m_wb_dat_r <= coherency_dat_i;
					m_wb_shr_r <= coherency_shr_i; // Used when writing cache at (state == REFILL).

					coherency_r <= 0; // May still be set by the remote request serviced in this TSTHIT.

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
					m_wb_shr_r <= coherency_shr_i; // Updated when setting coherency_r true, and for REFILL.

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
					m_wb_shr_r <= 1'b0;

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

`ifdef SIMULATION_MONITOR
// m_wb_bsy_o above reads coherency_write_pending as a plain non-null test, hence a count that does
// not fit its width does not merely lose precision, it reads null and releases the barrier while
// coherency writes are still travelling the ring; the atomic operation then starts early, and
// another data-cache is left holding a cache-entry that the writes had not yet updated. Nothing
// about that is visible in a run, hence report it. Also reported is the count exceeding the ring
// capacity that its width is derived from, which would mean that derivation is wrong, and an
// acknowledgement arriving with nothing pending, which would mean a request was lost or duplicated.
// When the ring holds two data-caches, its capacity is exactly the largest value that the width
// holds, so the first two coincide and report as one.
// Each is reported once, as the condition that caused it repeats for as long as it lasts.
// The report is flushed because a barrier released early can leave a hart spinning on a lock
// release that it never observes, ie: a run that gets killed rather than reaching $finish, and an
// unflushed report is lost exactly when it is the only thing that was going to be printed.
reg coherency_write_pending_ovfl_r;
reg coherency_write_pending_max_r;
reg coherency_write_pending_undf_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		coherency_write_pending_ovfl_r <= 1'b0;
		coherency_write_pending_max_r <= 1'b0;
		coherency_write_pending_undf_r <= 1'b0;
	end else if (coherency_en_i) begin
		if (coherency_write_req && !coherency_write_ack) begin
			if (&coherency_write_pending && !coherency_write_pending_ovfl_r) begin
				coherency_write_pending_ovfl_r <= 1'b1;
				$display("dcache%0d: error: coherency write pending count overflowed its width", PUID);
				$fflush();
			end else if (coherency_write_pending == COHERENCYWRITEPENDINGMAX &&
				!coherency_write_pending_max_r) begin
				coherency_write_pending_max_r <= 1'b1;
				$display("dcache%0d: error: coherency write pending count exceeded the ring capacity %0d",
					PUID, COHERENCYWRITEPENDINGMAX);
				$fflush();
			end
		end else if (coherency_write_ack && !coherency_write_req &&
			!coherency_write_pending && !coherency_write_pending_undf_r) begin
			coherency_write_pending_undf_r <= 1'b1;
			$display("dcache%0d: error: coherency write acknowledged with none pending", PUID);
			$fflush();
		end
	end
end
`endif

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
	 .WIDTH       (PUIDBITSZ + 1 + (ADDRBITSZ-MSBSZIGN) + (WORDBITSZ/8) + WORDBITSZ + 1)
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
