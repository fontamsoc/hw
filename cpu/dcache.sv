// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Data-cache between a master and memory, connecting to both through pipelined
// wishbone interfaces; it is write-back, and kept coherent with the other
// data-caches of its coherency ring, within the limits stated under Cache
// coherency.
//
// The data-cache holds CACHESETCNT cache sets of CACHEWAYCNT cache-entries,
// each made of a word, the cache-tag of its address, a valid bit for each of
// its bytes, a dirty bit and a shared bit. The cache set of an address is
// selected by the least significant bits of its word address, the remaining
// bits making its cache-tag. An access is a cache-hit when every byte that it
// selects is held by a cache-entry whose cache-tag matches, and a cache-miss
// otherwise.
//
// An access is accepted in the clockcycle in which m_wb_stb_i is high while
// m_wb_bsy_o is low, and tested in the clockcycle which follows (TSTHIT), in
// which the next access can already be accepted. An access which is not forced
// to miss (as explained under Ports for cmiss_i) is handled as follow:
// - A read cache-hit is acknowledged in TSTHIT, with the word of the
// 	cache-entry.
// - A write is acknowledged in TSTHIT as well, whether it is a cache-hit or
// 	not, and made in the cache-entry whose cache-tag matches, else in a
// 	cache-entry that it replaces, without reading memory (write-allocate);
// 	the bytes that it writes become valid in the cache-entry, which is
// 	marked dirty.
// - A read cache-miss is acknowledged once it has the bytes that it selects:
// 	while coherency_en_i is low, the whole word is read from memory
// 	(REFILL); while it is high, the bytes that it selects and that the
// 	cache-entry lacks are looked for in the other data-caches (as described
// 	under Cache coherency), and read from memory (REFILL) when they are not
// 	all found there.
// - A sync, a read selecting no byte on a ring of more than two data-caches,
// 	issues a read request whether or not it is a cache-hit, and is
// 	acknowledged once that request has come back around, replacing no
// 	cache-entry, as described under Cache coherency.
// - A cache-miss whose cache-tag matches no cache-entry replaces one, whose
// 	content, when dirty, is written back to memory (WRITEB), while
// 	coherency_en_i is high only once the write requests that the data-cache
// 	issued, and which may be for it, have come back around, as described
// 	under Cache coherency. The way replaced is selected by an index common
// 	to all cache sets, which moves to the next way only when a write, or a
// 	refill from memory, is made in a cache-entry of the way it selects whose
// 	cache-tag matched; an allocation does not move it. Hence, with more than
// 	one way, and unless the index moves meanwhile, a cache-entry just
// 	allocated in a cache set is the next one replaced there, whereas one
// 	that a write or a refill has just hit is not.
// A dirty cache-entry reaches memory only when it gets replaced, or, for the
// bytes that it selects, when a read forced to miss hits it, or, while
// ATOMIC_COHERENCE is non-null, when a take from another data-cache takes it,
// as described under Cache coherency; the data-cache cannot be flushed as a
// whole.

// Cache coherency:
//
// - Data-caches in the same coherency ring are daisy-chained, the coherency_*_o
// 	ports and coherency_bsy_i of each one connected to the coherency_*_i
// 	ports and coherency_bsy_o of the next one, and those of the last one to
// 	the first one. A coherency request travels the whole ring, each
// 	data-cache it goes through using it and forwarding it, until it comes
// 	back around to the data-cache which issued it.
// - Coherency traffic is generated only while coherency_en_i is high, and only
// 	by accesses that are not forced to miss; one forced to miss, by cmiss_i,
// 	by the bus lock, or because it follows a locked access, generates none,
// 	but for the take which a locked read issues while ATOMIC_COHERENCE is
// 	non-null.
// - While ATOMIC_COHERENCE is null, an access forced to miss thus neither sees
// 	nor updates the copies held by the other data-caches: a write forced to
// 	miss, ie: that of a store-conditional or of an atomic memory operation,
// 	leaves stale their copies of the bytes it writes; and a read forced to
// 	miss, ie: a load-reserved or the read of an atomic memory operation, can
// 	return data from memory older than a dirty copy held by another
// 	data-cache. This holds as well for the access which follows a locked
// 	one, which may be an ordinary load or store, ie: the first one after a
// 	compare-and-swap whose compare failed. A write forced to miss also
// 	invalidates the bytes that it writes in its own data-cache, hence a
// 	later read of those bytes there misses, and gathers the stale copies of
// 	the other data-caches when they hold any, ie: returns the value from
// 	before that write. A word accessed through atomic memory operations is
// 	therefore not to be accessed otherwise, as cpu/README.md requires, and
// 	the access which follows a load-reserved whose store-conditional does
// 	not come is to be an atomic one, or one to a word that no other
// 	data-cache may hold.
// - While ATOMIC_COHERENCE is non-null, an atomic memory operation, ie: a
// 	locked read, the read of a load-reserved or of an atomic memory
// 	operation, and the write which follows it, that of the store-conditional
// 	or of the atomic memory operation, takes its word from the ring before
// 	it reads it: the locked read issues a take, a request which removes the
// 	word from every other data-cache, a dirty copy being first written back
// 	to memory, and is made, from memory under the bus lock as described for
// 	cmiss_i, only once the take has come back around; a locked read whose
// 	cache-tag matches a cache-entry marked exclusive issues no take,
// 	whichever bytes of the word that cache-entry holds, and is made as
// 	described for cmiss_i at once: no other data-cache holds the word, but
// 	one which wrote it since, and whose write request has not come by yet;
// 	that write then comes after the atomic, its write request being held off
// 	as described next, and its cache-entry not being written back meanwhile.
// 	The ring is held off from the take's return, or from the acceptance of a
// 	locked read issuing none, until the access which follows the locked
// 	read, ie: the write, which is made in memory, releasing the lock, its
// 	bytes being invalidated in the data-cache. Hence the read sees the
// 	stores made before it in every data-cache, no copy is left which the
// 	write would leave stale, and a store made meanwhile in another
// 	data-cache, its write request being held off, comes after the write. A
// 	locked read of a word which is not to be cached issues no take, no
// 	data-cache holding that word.
// - A data-cache lets the take go by marked, with its copy left as it is,
// 	while a request of its own which may be for that word has not come back
// 	around: a write request, ie: it holds the word dirty while one which
// 	may be for it travels, or while a store waits for its own (as described
// 	below for a dirty cache-entry), as writing the word back would put in
// 	memory bytes that such a write request is yet to carry to the copies
// 	made since; or its read request for that word, which may have gathered
// 	bytes that the take is yet to remove, and which is completed with the
// 	bytes that the cache-entry holds. The data-cache which issued the take
// 	issues it again. A data-cache which a take goes through marked, by
// 	itself or by one before it, accepts no access from its master until a
// 	take of the same data-cache comes by unmarked, but the access which
// 	follows a locked read of its own, which issues no request; it keeps
// 	that hold for each data-cache of the ring, so that the take of another
// 	one does not end it early. Its requests have then come back around when
// 	the take next comes by, hence a trip of a take can only be marked by a
// 	data-cache nearer its issuer than on the trip before, and a take is
// 	issued again fewer times than the ring holds data-caches, whatever the
// 	other data-caches load or store. No access is accepted either in the
// 	clockcycle in which a take from another data-cache is tested.
// - The access which follows a locked one is forced to miss as well, so that it
// 	reaches the slave interface and releases the lock; while coherency_en_i
// 	is high and ATOMIC_COHERENCE non-null, it is therefore to be the write
// 	of the atomic memory operation, or a read selecting no byte, which
// 	releases the lock and changes nothing, as cpu/dcache.pu.sv makes it when
// 	a load-reserved is abandoned, ahead of any other access: an ordinary
// 	load or store would neither see nor update the copies held by the other
// 	data-caches. A locked read which follows a locked one issues no take,
// 	staying under the lock that the latter took.
// - Reading generates a read request only on a cache-miss, ie: when some
// 	selected byte is not in the cache-entry, and asks for those bytes only,
// 	but for a sync, described below, which asks for none on a cache-hit as
// 	well. The request always comes back around: each other data-cache whose
// 	cache-tag matches merges into it every byte it holds, and marks its own
// 	cache-entry shared. When the merged bytes cover the request, the
// 	cache-entry is filled from them, otherwise the missing bytes are read
// 	from memory (REFILL), the bytes that the cache-entry holds winning over
// 	those merged. The cache-entry is then marked shared if another
// 	data-cache matched the cache-tag, was itself waiting on a read of that
// 	word, or had a write waiting for its write request to come back around
// 	(as described below for a dirty cache-entry), and exclusive otherwise.
// 	Yet when a write request from another data-cache for that word went
// 	through the data-cache while its read request travelled the ring, the
// 	read is answered without filling the cache-entry, as the read request
// 	may have overtaken the write request and gathered, from a data-cache
// 	which the write request had not reached yet, bytes older than that
// 	write.
// - A read refilled from memory takes memory to hold the current value of the
// 	bytes that no data-cache holds, hence the slave interface is to take the
// 	accesses of the data-caches of a ring in a single order, in which a
// 	write-back is ahead of every access accepted after it from another
// 	data-cache, the data-cache not waiting for the acknowledgement of a
// 	write-back when MAXPENDINGACK is non-null. lib/wb_arbiter.sv insures it,
// 	as it accepts the access of the master that it grants only, and passes
// 	it on in that order; a buffer per data-cache ahead of the arbiter would
// 	not.
// - A dirty cache-entry is not written back while a write request that the
// 	data-cache issued, and which may be for its word, has not come back
// 	around: memory would then hold the bytes that it carries while it has
// 	yet to update the copies it has not reached, ie: an atomic memory
// 	operation could read them from memory, and the write request, applied
// 	after it to a copy made since, would undo it there. A write request may
// 	be for the word of a cache-entry when the low bits of their cache sets
// 	are the same, which is what the data-cache keeps of the write requests
// 	that it issued, until none of them travels; a stream of writes replacing
// 	dirty cache-entries thus waits for the ring only when it comes back to
// 	such a cache set while its write requests kept travelling, instead of at
// 	every write. Hence a read cache-miss replacing such a dirty cache-entry
// 	writes it back once its read request has come back around, ahead of the
// 	REFILL; and a write cache-miss replacing one is acknowledged, but made
// 	in the cache-entry, which is written back then, only once its write
// 	request, which carries the bytes that it writes, has come back around,
// 	the master being held meanwhile; the ring being FIFO, no write request
// 	that the data-cache issued is travelling at either time. That also
// 	insures that a word which two data-caches wrote in turn ends holding in
// 	memory the value of the later write when both write it back: the write
// 	request carrying it updates the older copy on its way, or, when that
// 	copy is being written back, waits for that write-back to be accepted
// 	first. While a write waits so for its write request, its data-cache
// 	holds no copy of the word that it writes, and does not keep which word
// 	that is: it counts as holding a copy for every request that it forwards
// 	meanwhile, so that no other data-cache marks exclusive a cache-entry of
// 	that word.
// - Writing generates a write request whether or not it is a cache-miss, unless
// 	its cache-tag matches a cache-entry marked exclusive. When it comes back
// 	around, the cache-entry is marked exclusive if no other data-cache
// 	matched the cache-tag, was waiting on a read of that word, nor had a
// 	write waiting for its own write request to come back around. A write
// 	which selects no byte writes nothing: while coherency_en_i is high and
// 	ATOMIC_COHERENCE non-null, and unless it is forced to miss, it is
// 	acknowledged and does nothing else, ie: it issues no write request,
// 	which would read as a take, allocates no cache-entry and replaces none.
// - A read/write request from another data-cache that matches the cache-tag
// 	marks the cache-entry shared. Hence a cache-entry becomes exclusive only
// 	when a request of its own comes back having found no other copy: a
// 	write, or a read refilled from memory, including a read of a cache-entry
// 	holding only some of the selected bytes.
// - A write request from another data-cache updates, in the cache-entry whose
// 	cache-tag matches, the bytes that it holds, and makes none valid: the
// 	cache-entry of the data-cache which issued it may have been marked
// 	exclusive since, when an earlier write request came back around, its
// 	stores then issuing no write request, hence a byte that a write request
// 	still travelling made valid in a copy allocated meanwhile would hold a
// 	value that nothing corrects. It does not change the dirty state of the
// 	cache-entry, so that a write request never makes another copy dirty; the
// 	cache-entry is made clean instead when the write request writes every
// 	byte of the word, all of which the store that issued it made dirty in
// 	its own data-cache, unless a write request that the data-cache issued
// 	has not come back around: the two may be for the same word and crossing
// 	on the ring, and each data-cache would then make the copy of the other
// 	clean, leaving the word dirty in neither.
// - A coherency request from another data-cache never allocates nor refills a
// 	cache-entry, and writes one back only when it is a take; it only reads,
// 	updates, or, for a take, invalidates, a cache-entry whose cache-tag
// 	matches.
// - Coherency requests have priority over the accesses of the master: a
// 	coherency request is taken ahead of an access presented in the same
// 	clockcycle; yet no coherency request is taken while the data-cache
// 	handles an access forced to miss, or a cache-miss in WRITEB or REFILL,
// 	nor while it holds the bus lock, ie: from an access carrying m_wb_lock_i
// 	until the access which follows it, the ring being held off meanwhile,
// 	but while the take of a locked read travels the ring, the data-cache
// 	then taking coherency requests as it otherwise does. As a data-cache
// 	whose own read request travels the ring is busy until it comes back
// 	around, every other data-cache of the ring then stalls on its next read
// 	cache-miss: one held in WRITEB or REFILL by an access that the slave
// 	interface does not accept, or holding the bus lock after a load-reserved
// 	until the access which follows it, ie: its store-conditional, or, while
// 	ATOMIC_COHERENCE is non-null, the release that cpu/dcache.pu.sv makes,
// 	stops every hart of the ring meanwhile, as cpu/README.md details.
// - A locked read, when the access before it was not one, is accepted only once
// 	every write request that the data-cache issued has come back around,
// 	including that of a write in TSTHIT, so that the writes made before it
// 	have reached the other data-caches when it takes effect in memory; the
// 	take that it issues while ATOMIC_COHERENCE is non-null, which follows
// 	those write requests on the ring, would wait for them as well, but a
// 	locked read of a word that is not to be cached issues none, nor does one
// 	whose cache-tag matches a cache-entry marked exclusive.
// - The ring keeps the order of the requests that a data-cache issues, hence
// 	every other data-cache sees a write before a later write of the same
// 	data-cache; but a read of another word, answered meanwhile from a
// 	cache-entry, can be made before a write of the same data-cache is seen
// 	everywhere, which coherency_pending_o tells, and which a fence ordering
// 	stores before loads waits for.
// - A write request reaches the other data-caches one after the other, hence
// 	two data-caches may see the writes of two others in opposite orders,
// 	which a full fence forbids. On a ring of more than two data-caches, a
// 	sync rules it out: a read which selects no byte, carries no lock and
// 	does not follow a locked access, as no other access of the master does.
// 	It is not forced to miss, its address being that of any word, and
// 	issues a read request selecting no byte, whether or not its cache-tag
// 	matches; it is acknowledged once that request has come back around, the
// 	master being held meanwhile. The ring being FIFO, every write request
// 	travelling the ring when that request was issued has then gone through
// 	the data-cache, or come back around when the data-cache issued it, hence
// 	the accesses made after the sync see every write made in another
// 	data-cache before it. The sync is answered as a read whose request a
// 	write request crossed, filling no cache-entry, and the cache-entry whose
// 	cache-tag matches is marked shared when the request comes back, the
// 	request having filled nothing that could make it exclusive; the other
// 	data-caches handle the request as any read request. A ring of two
// 	data-caches needs no sync, a write request having a single data-cache
// 	to reach there; nor does a read selecting no byte make one when it
// 	follows a locked access, being then forced to miss as described above.
// 	cpu/dcache.pu.sv makes a sync for a full fence, which it then does not
// 	hold until coherency_pending_o is low, and after an atomic memory
// 	operation which is fully ordered.
// - Note that writes to the same word from different data-caches, whose write
// 	requests cross on the ring, are not ordered: each data-cache applies the
// 	write of the other after its own, hence each cache-entry ends up holding
// 	the value of the other for the bytes both wrote, and stays dirty, memory
// 	getting the value of the one written back last, while another data-cache
// 	holding the word ends up with, for the bytes both wrote, the value of
// 	the write request that reached it last.

// Parameters:
//
// WORDBITSZ
// 	Width of a word in bits, ie: of the data of a cache-entry, and of the
// 	data buses. It must be 16, 32, 64, 128 or 256.
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
// 	When non-null, m_wb_ack_o and m_wb_dat_o are registered, delaying the
// 	response to the master by a clockcycle; m_wb_bsy_o is not registered.
//
// REGSLVINPUT
// 	When non-null, s_wb_ack_i and s_wb_dat_i are registered before use,
// 	delaying the response of the slave by a clockcycle; s_wb_bsy_i is not
// 	registered.
//
// MAXPENDINGACK
// 	When null, the data-cache waits for the acknowledgement of each access
// 	that it makes on the slave interface before going on. When non-null, it
// 	does not wait for that of a write, ie: a write-back, which speeds up
// 	evictions, or a write forced to miss; the slave interface must then
// 	never hold more than MAXPENDINGACK accesses accepted and not yet
// 	acknowledged, that count being kept to tell which acknowledgement is
// 	that of a refill.
//
// PUIDBITSZ
// 	Width of coherency_rqid_*, which must hold the PUID of every data-cache
// 	of the ring; (1<<PUIDBITSZ) also sizes the skidbuf of coherency_*_o, and
// 	the count of write requests which have not come back around. It must be
// 	non-null. A sync is made only when it is greater than one, ie: on a ring
// 	of more than two data-caches, as described under Cache coherency.
//
// PUID
// 	Identifier of the data-cache in its ring, carried by the coherency
// 	requests that it issues, from which it recognizes them when they come
// 	back around; it must be unique within the ring.
//
// ATOMIC_COHERENCE
// 	When non-null, atomic memory operations take part in the coherency
// 	protocol of the ring while coherency_en_i is high, as described under
// 	Cache coherency: a locked read takes its word from the ring before it
// 	reads it, and a word may be accessed by atomic and plain accesses alike.
// 	When null, they do not, and a word accessed through atomic memory
// 	operations is not to be accessed otherwise. It is to be the same in
// 	every data-cache of a ring: a take is a write request selecting no
// 	byte, which a data-cache built with it null forwards as a plain write
// 	request, marked when its cache-tag matches, and which is then issued
// 	again for as long as that data-cache holds the word.

// Ports:
//
// rst_i
// 	When held high at the rising edge of the clock signal, the module
// 	resets; it must be held low for normal operation. Once it is low, the
// 	data-cache invalidates its cache-entries, a cache set per clockcycle,
// 	being busy meanwhile, ie: m_wb_bsy_o and coherency_bsy_o high. The
// 	data-caches of a ring are to be reset together, as a reset drops the
// 	coherency requests that a data-cache holds.
//
// clk_i
// 	Clock signal.
//
// cmiss_i
// 	When high along with m_wb_stb_i, the access is forced to miss, as are an
// 	access carrying m_wb_lock_i and the access which follows it; cmiss_i is
// 	to be set high combinationally from m_wb_addr_i for an address which
// 	must not be cached. An access forced to miss reaches the slave
// 	interface; while coherency_en_i is high, a locked read of a word which
// 	may be cached, when the access before it was not a locked read, first
// 	takes it from the ring while ATOMIC_COHERENCE is non-null, as described
// 	under Cache coherency; an access forced to miss otherwise neither sees
// 	nor updates the copies held by the other data-caches, with the
// 	consequences described there. It is handled as follow:
// 	- A write is made in memory, the bytes that it writes being invalidated
// 		in the cache-entry whose cache-tag matches.
// 	- A read is made in memory, unless it selects only bytes held by a dirty
// 		cache-entry, which then answers it and writes them back; either
// 		way, a cache-entry holding every byte that it selects has them
// 		invalidated. When the read is made in memory, the bytes held by
// 		the cache-entry whose cache-tag matches are merged over the data
// 		read, unless the read carries m_wb_lock_i and that cache-entry
// 		is clean, holding then nothing that memory lacks, or, on a ring
// 		while ATOMIC_COHERENCE is null, being possibly behind memory, as
// 		follows from Cache coherency.
// 	A sync, described under Cache coherency, is not forced to miss by
// 	cmiss_i: its address is that of any word, and it reaches only the
// 	coherency ring.
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
// 	Pipelined wishbone slave interface, to which the master connects. An
// 	access is accepted in the clockcycle in which m_wb_stb_i is high while
// 	m_wb_bsy_o is low; each access is acknowledged by m_wb_ack_o high for a
// 	clockcycle, in the order the accesses were accepted, m_wb_dat_o then
// 	holding the bytes that a read selects. An access carrying m_wb_lock_i
// 	requests the bus lock: it reaches the slave interface with s_wb_lock_o
// 	high; when the access before it did not carry the lock, it is accepted
// 	only once every write request that the data-cache issued, or is issuing,
// 	has come back around, as described under Cache coherency. The lock is
// 	released by the next access which does not carry it, that access being
// 	forced to miss, as explained for cmiss_i; while coherency_en_i is high,
// 	that access is to be the write of the atomic memory operation, or, while
// 	ATOMIC_COHERENCE is non-null, a read selecting no byte, and else an
// 	atomic access or one to a word that no other data-cache may hold, as
// 	described under Cache coherency. A read selecting no byte which neither
// 	carries m_wb_lock_i nor follows an access which does is a sync, to be
// 	presented only on a ring of more than two data-caches, and acknowledged
// 	once it has synced with the ring, as described under Cache coherency.
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
// 	Pipelined wishbone master interface, which connects to the slave, ie:
// 	memory, which is to acknowledge every access, a write as well as a read.
// 	Through it are made the write-backs, the refills and the accesses forced
// 	to miss, each one carrying the bus lock of the access that it is made
// 	for.
//
// coherency_en_i
// 	When high, the data-cache takes part in the cache-coherency logic, ie:
// 	it issues coherency requests, and forwards those of the other
// 	data-caches of the ring. It is to be low for a data-cache which is not
// 	part of a ring, its coherency_stb_i being then held low.
//
// coherency_stb_i
// coherency_rqid_i
// coherency_we_i
// coherency_addr_i
// coherency_sel_i
// coherency_dat_i
// coherency_shr_i
// coherency_bsy_o
// 	Coherency requests from the previous data-cache of the ring, each taken
// 	in the clockcycle in which coherency_stb_i is high while coherency_bsy_o
// 	is low:
// 	- coherency_rqid_i is the PUID of the data-cache which issued the
// 		request.
// 	- coherency_we_i is high for a write request, and low for a read
// 		request.
// 	- coherency_addr_i is the word address.
// 	- coherency_sel_i and coherency_dat_i are, for a write request, the
// 		bytes written and their value, and for a read request, the bytes
// 		gathered so far from the data-caches that it went through, and
// 		their value.
// 	- coherency_shr_i is high when a data-cache that the request went
// 		through matched the cache-tag, or was waiting on a read of that
// 		word.
// 	- While ATOMIC_COHERENCE is non-null, a write request selecting no byte
// 		is a take (cf. Cache coherency), coherency_shr_i being then high
// 		when a data-cache that it went through let it go by marked.
//
// coherency_stb_o
// coherency_rqid_o
// coherency_we_o
// coherency_addr_o
// coherency_sel_o
// coherency_dat_o
// coherency_shr_o
// coherency_bsy_i
// 	Coherency requests to the next data-cache of the ring, with the same
// 	meaning, presented through a skidbuf of (1<<PUIDBITSZ) requests.
//
// coherency_pending_o
// 	High while a write request that the data-cache issued has not come back
// 	around, ie: while a write made through the data-cache may not yet be
// 	seen by every data-cache of the ring; cpu/dcache.pu.sv holds a fence
// 	ordering stores before loads until it is low, but one which syncs with
// 	the ring, the sync coming back around behind those write requests.
//
// Module dCacheSub, which dCache wraps, has the same parameters, except
// REGMSTOUTPUT and REGSLVINPUT, and the same ports, its coherency_*_o being
// those that dCache presents through the skidbuf, plus coherency_near_bsy_i,
// high when that skidbuf is full or one request away from being full.

`ifndef DCACHE_V
`define DCACHE_V

`include "lib/skidbuf.sv"

module dCacheSub (

	 rst_i

	,clk_i

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

	,coherency_pending_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter ADDRLIMIT = 'h2000;

parameter CACHESETCNT = 2;
parameter CACHEWAYCNT = 1;

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter PUIDBITSZ = 1;
parameter PUID      = 0;

parameter ATOMIC_COHERENCE = 0; // Atomics take their word from the ring when non-null.

localparam CLOG2CACHESETCNT = clog2(CACHESETCNT);
localparam CLOG2CACHEWAYCNT = clog2(CACHEWAYCNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

// A read selecting no byte syncs with the ring on a ring of more than two data-caches, cf. syn_r.
localparam RINGSYNC = (PUIDBITSZ > 1);

input wire rst_i;

input wire clk_i;

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

output wire                               coherency_pending_o;

wire _m_wb_stb_i = (m_wb_stb_i && !m_wb_bsy_o);

reg lock_r;
always_ff @(posedge clk_i) begin
	if (rst_i)
		lock_r <= 0;
	else if (_m_wb_stb_i)
		lock_r <= m_wb_lock_i;
end
// The access presented is a sync, cf. syn_r; it is not forced to miss by cmiss_i, its address being that of any
// word, which it does not access.
wire syn_i = (RINGSYNC && coherency_en_i && !m_wb_we_i && !(|m_wb_sel_i) && !m_wb_lock_i && !lock_r);
wire _cmiss_i = ((cmiss_i && !syn_i) || m_wb_lock_i || lock_r);

reg [PUIDBITSZ -1 : 0]            m_wb_rqid_r;
reg                               m_wb_lock_r;
reg                               m_wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        m_wb_sel_r;
reg [WORDBITSZ -1 : 0]            m_wb_dat_r;
reg                               m_wb_shr_r;

reg rst_r;
reg cmiss_r;
reg coherency_r; // True when handling a coherency request.

reg                               coherency_stb_r; // True when looking for data in other data-caches.
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] coherency_addr_r;
reg [(WORDBITSZ/8) -1 : 0]        coherency_sel_r;
reg                               coherency_xw_r; // True when a write request from another data-cache for that word crossed the read.

// A dirty victim is not written back while a write request of this data-cache travels the ring, cf. evict_defer.
reg defst_r;      // True while a store waits for its write request to come back, to evict its victim and be made.
reg defstalloc_r; // True in the TSTHIT which evicts that victim and makes that store, which was acknowledged already.
reg defld_r;      // True while a load waits for its read request to come back, to evict its victim.
reg defldtst_r;   // True in the TSTHIT which evicts that victim, and in the WRITEB which follows, ahead of the REFILL.
wire evict_defer;

// While ATOMIC_COHERENCE is non-null, an atomic memory operation takes its word from the ring before it
// reads it, cf. Cache coherency. A take is a write request selecting no byte; coherency_shr_* is high when
// a data-cache let it go by marked, a request of its own which may be for that word not having come back
// around, cf. tkmark. While ATOMIC_COHERENCE is null, the registers below are null.
reg tkp_r; // True in the TSTHIT of a locked read which is to take its word, cf. tktake.
reg tko_r; // True while the take of the locked read travels the ring.
// A bit per data-cache of the ring, true while the master waits for a take of that data-cache, which went
// through marked, to come by again, cf. tkmark.
reg [(1<<PUIDBITSZ) -1 : 0] tkf_r;
// True when the request accepted last is a take from another data-cache, cf. tktst.
reg tk_r;
// The ring is held off from the clockcycle the take comes back until the access after the locked read.
wire lock_hold = (lock_r && !tko_r);
// The request in TSTHIT is a take, for the state machine generating coherency requests, which forwards it
// from WRITEB as well, tk_r being null there.
wire _m_wb_tk_r = (ATOMIC_COHERENCE && coherency_r && m_wb_we_r && !(|m_wb_sel_r));
wire tkinv; // A take from another data-cache invalidates the word in TSTHIT, cf. tkmark.
// A locked read whose cache-tag matches a cache-entry marked exclusive takes no word from the ring,
// whichever bytes of the word that cache-entry holds, a cache-entry being marked for its word: no other
// data-cache holds a copy of the word, as a request of theirs for it marks the cache-entry shared when it
// goes through, hence it is handled as a read forced to miss is, the ring being held off from its
// acceptance as before. The only copy which may exist is that of a store which another data-cache made
// since, the write request of which has not come by yet: that write request is held off with the ring until
// the write of the atomic, and the cache-entry of that store is not written back while it travels, cf.
// evict_defer, hence that store comes after the atomic.
wire tktake; // The locked read in TSTHIT issues its take.
// On a ring of more than two data-caches (RINGSYNC), a read selecting no byte which neither carries the lock
// nor follows a locked access, as no other access of the master does, is a sync, cf. Cache coherency: it
// issues a read request selecting no byte, whatever the cache-tag test, and is acknowledged only once that
// request has come back around, behind every request that was travelling the ring when it was issued, the
// ring being FIFO, the master being held meanwhile. The request is issued as one which a write request
// crossed (coherency_xw_r), so that it fills no cache-entry when it comes back, and as one already found
// shared (coherency_shr_o), so that the cache-entry whose cache-tag matches is marked shared then, the request
// having filled nothing which could make it exclusive; the sync neither replaces nor writes back a
// cache-entry. The other data-caches handle the request as any read request.
reg syn_r; // True in the TSTHIT of a sync.
// A store selecting no byte writes nothing: on a ring while ATOMIC_COHERENCE is non-null, when it is not
// forced to miss, it is acknowledged and does nothing else, ie: it neither allocates a cache-entry nor
// replaces one. It issues no write request, which would read as a take, hence neither its allocation nor
// the write-back of the cache-entry that it would replace could wait for one to come back, cf. evict_defer.
wire nullst = (ATOMIC_COHERENCE && coherency_en_i && !coherency_r && !cmiss_r && m_wb_we_r && !(|m_wb_sel_r));

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

// When MAXPENDINGACK is non-null, and the sequencing of WRITEB followed by REFILL
// occurs, the expression (!s_wb_stb_o && s_wb_ack_pending == 1) identifies the ack
// of REFILL, because we could still be waiting for the ack of WRITEB.
wire refill_ack = (s_wb_ack_i && (!MAXPENDINGACK || (!s_wb_stb_o && s_wb_ack_pending == 1)));

wire cache_we = (!(cmiss_r || coherency_r) && (
	(state == TSTHIT && m_wb_we_r && !evict_defer && !nullst) ||
	(state == REFILL && !s_wb_we_o && refill_ack && !coherency_xw_r)));

wire [CACHEWAYCNT -1 : 0] cache_we0;
wire [CACHEWAYCNT -1 : 0] cache_we1;
wire [CACHEWAYCNT -1 : 0] cache_we2;

localparam CACHETAGBITSIZE = ((ADDRBITSZ-MSBSZIGN) - CLOG2CACHESETCNT);

// The check `(coherency_rqid_i != PUID || coherency_we_i)` is used for the same reason it is used to set __coherency_stb_i.
wire [CLOG2CACHESETCNT -1 : 0] cache_rdidx = ((coherency_stb_i && (coherency_rqid_i != PUID || coherency_we_i) && !lock_hold) || coherency_stb_r) ?
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
	if (CACHEWAYCNT == 1) begin
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

// A write request from another data-cache updates the bytes that the cache-entry holds, and makes none valid:
// the cache-entry of the data-cache which issued it may have been marked exclusive since, its stores then
// issuing no write request, hence a byte made valid here would never see them.
wire [(WORDBITSZ/8) -1 : 0] cache_sel_i_ = (cache_tag_hit ?
	((m_wb_sel_r & {(WORDBITSZ/8){!(coherency_en_i && coherency_r && m_wb_rqid_r != PUID)}}) | cache_sel_o_tag_hit) : m_wb_sel_r);
wire [(WORDBITSZ/8) -1 : 0] cache_sel_i = (
	(state == TSTHIT) ? (cache_sel_i_ & ((cmiss_r || tkinv) ? ~(m_wb_sel_r | {(WORDBITSZ/8){tkinv}}) : {(WORDBITSZ/8){1'b1}})) :
	(state == REFILL) ? ((cache_tag_hit ? cache_sel_o_tag_hit : {(WORDBITSZ/8){1'b0}}) | s_wb_sel_o) : {(WORDBITSZ/8){1'b0}});

// Whether the bytes held by a cache-tag-hit are merged over the data from memory at (state == REFILL).
// They are, but for an access carrying the bus lock, ie: a load-reserved or the read of an atomic
// memory operation, which hits a clean entry: it holds nothing that memory lacks, the word being out of a
// ring, or the take of the locked read having removed it from every other data-cache, whereas a dirty
// entry holds stores this hart made since; while ATOMIC_COHERENCE is null, it may be behind memory on a
// ring instead, as an atomic memory operation from another hart, which the cache-coherency logic does not
// carry then, may have updated memory since the entry was filled. The access following a locked one is
// forced to miss as well, so that it reaches the bus and releases the lock, but it is not atomic, and the
// entry it hits, ahead of memory when filled from another data-cache, is what a hit returns.
wire _cache_tag_hit = (cache_tag_hit && (!cmiss_r || !m_wb_lock_r || cache_drt_o[cache_tag_hit_wayidx]));

wire [WORDBITSZ -1 : 0] _m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _m_wb_sel_r_n = ~_m_wb_sel_r;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit;
wire [WORDBITSZ -1 : 0] _cache_sel_o_tag_hit_n = ~_cache_sel_o_tag_hit;
// The bytes that the cache-entry holds win over those gathered from the other data-caches, which may
// hold an older copy of them, as a write request crossing the read request updated those held.
wire [WORDBITSZ -1 : 0] _s_wb_dat_i = ((m_wb_dat_r & _m_wb_sel_r & ((coherency_en_i && _cache_tag_hit) ? _cache_sel_o_tag_hit_n : {WORDBITSZ{1'b1}})) |
	(s_wb_dat_i & _m_wb_sel_r_n & (_cache_tag_hit ? _cache_sel_o_tag_hit_n : {WORDBITSZ{1'b1}})) |
	(_cache_tag_hit ? (cache_dat_o_tag_hit & _cache_sel_o_tag_hit) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i_ = ((m_wb_dat_r & _m_wb_sel_r) | (cache_tag_hit ? (cache_dat_o_tag_hit & _m_wb_sel_r_n) : {WORDBITSZ{1'b0}}));
wire [WORDBITSZ -1 : 0] cache_dat_i = ((state == TSTHIT) ? cache_dat_i_ : _s_wb_dat_i);

wire cache_drt_i = (tkinv ? 1'b0 : coherency_r ?
	// A write request from another data-cache which writes every byte makes the cache-entry clean, as the
	// store which issued it made them all dirty in its own data-cache; but not while a write request of
	// this data-cache has not come back around: the two may be for the same word and crossing, and each
	// data-cache would then make the copy of the other clean, leaving the word dirty in neither.
	(((&m_wb_sel_r) && m_wb_rqid_r != PUID && !coherency_write_pending) ? 1'b0 : (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx])) :
	(!(rst_r || (cmiss_r && (&m_wb_sel_r))) && ((m_wb_we_r && !cmiss_r) || (cache_tag_hit && cache_drt_o[cache_tag_hit_wayidx]))));

wire cache_shr_i = ((state == TSTHIT) ? // m_wb_shr_r is used only when the coherency request has come back around.
	(coherency_r ? (!m_wb_we_r || m_wb_rqid_r != PUID || m_wb_shr_r) : (cache_tag_hit ? cache_shr_o_tag_hit : 1'b1)) :
	((|m_wb_sel_r) || m_wb_shr_r)); // m_wb_sel_r is non-null at REFILL when merging data from coherency search.

wire _coherency_stb_i;

reg _coherency_stb_r_r;
reg __coherency_stb_r_r;

// There is a cachehit when there is a cache tag hit and the selected bits are in the cache.
wire cache_hit = (cache_tag_hit && (m_wb_sel_r & cache_sel_o_tag_hit) == m_wb_sel_r);

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
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && m_wb_rqid_r != PUID) || (__coherency_stb_r_r && !coherency_xw_r)) && (coherency_r && m_wb_we_r))));
assign cache_we1[gen_cache_idx] = (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && (cache_tag_hit_[gen_cache_idx] || (__coherency_stb_r_r && !coherency_xw_r)) && coherency_r)));
assign cache_we2[gen_cache_idx] = (rst_r || (gen_cache_idx == cache_we_wayidx && (cache_we ||
		(state == TSTHIT && ((cache_tag_hit_[gen_cache_idx] && (cmiss_r ||  m_wb_rqid_r != PUID)) || (__coherency_stb_r_r && !coherency_xw_r)) &&
			((cmiss_r && !tktake && (cache_hit || m_wb_we_r)) || (coherency_r && m_wb_we_r))))));

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

// A dirty victim is not written back while a write request of this data-cache travels the ring: the victim
// may be the word that write request is for, and memory would then hold the bytes it carries while it is
// still to update the copies it has not reached yet, ie: an atomic memory operation could read them from
// memory, and the write request, applied after it to a copy made since, would undo it there. A load then
// writes its victim back once its read request has come back, a store once its write request has, the
// ring being FIFO, hence the count null then.
// Which words a write request of this data-cache travelling the ring may be for, told by the low bits of
// their cache set: a bit is set when a write request is issued for a word of that bucket, and all are
// cleared once none travels. The victim of a miss shares the cache set of the access, and a take is for the
// word itself, hence the bit of the access is high whenever such a write request is for that victim, or for
// that word; a miss replacing a dirty victim thus waits only when the bit of its bucket is high, instead of
// for every write request of this data-cache, which a stream of stores would otherwise do at every store.
localparam CLOG2COHERENCYWRITEBKTCNT = ((CLOG2CACHESETCNT < 4) ? CLOG2CACHESETCNT : 4);
reg [(1 << CLOG2COHERENCYWRITEBKTCNT) -1 : 0] coherency_write_bkt;
wire coherency_write_bkt_hit = ((|coherency_write_pending) && coherency_write_bkt[m_wb_addr_r[0 +: CLOG2COHERENCYWRITEBKTCNT]]);

assign evict_defer = (coherency_en_i && coherency_write_bkt_hit &&
	state == TSTHIT && !coherency_r && !cmiss_r && cache_miss && cache_writeb && !nullst && !syn_r);

// A take from another data-cache, in TSTHIT, removes the word from this data-cache: a clean copy is
// invalidated, and the take forwarded; a dirty one is written back, invalidated, and the take forwarded
// only once memory accepted that write-back (tkwb), so that the read of the atomic memory operation, which
// follows the take, is ordered after it. But the copy is left as it is while a request of this data-cache
// which may be for that word travels the ring: a write request, ie: the copy is dirty while one which may
// be for it travels, or a store waits on its own (defst_r), as that would write back bytes that such a
// write request is still to carry to copies made since, cf. evict_defer; or its read request for that
// word, which may have gathered bytes that the take is yet to remove, and which is completed with the bytes
// that the cache-entry holds. The take is then forwarded marked (tkmark), and its data-cache issues it
// again. A data-cache which a take goes through marked, here or before, accepts nothing from its master
// until a take of the same data-cache comes by unmarked, cf. tkf_r, which holds a bit per data-cache issuing
// takes, but the access which follows a locked read of its own, which issues no request: it then has no
// request travelling when the take next comes by, hence a trip of a take can only be marked by a data-cache
// nearer its issuer than on the trip before, and a take is issued again fewer times than the ring holds
// data-caches, whatever the other data-caches load or store, their takes included. Nothing is accepted in
// the TSTHIT of a take from another data-cache (tktst in coherency_bsy_o_, which is registers only): its
// word may be written back, and no access is to slip in ahead of the hold when it is, or gets, marked. That
// TSTHIT is told by tk_r, set when the take is accepted, rather than from the request held, so that
// coherency_bsy_o_, which the read enables of the cache follow, sees a single register.
wire tktst = (coherency_en_i && state == TSTHIT && tk_r);
wire tkmark = (tktst && (defst_r || (cache_tag_hit && cache_drt_o_we_wayidx && coherency_write_bkt_hit) ||
	(coherency_stb_r && coherency_addr_r == m_wb_addr_r)));
wire tkwb = (tktst && !tkmark && cache_tag_hit && cache_drt_o_we_wayidx);
assign tkinv = (tktst && !tkmark && cache_tag_hit);
assign tktake = (tkp_r && !(cache_tag_hit && !cache_shr_o_tag_hit));

// This signal is true when coherency_*_o registers cannot be updated with a new request for the next data-cache.
wire _coherency_bsy_i = (state == READY ? (coherency_bsy_i && coherency_stb_o) : coherency_near_bsy_i);

// This signal is high when coherency_stb_i cannot yet be consumed.
wire coherency_bsy_o_ = (rst_r || cmiss_r || defldtst_r || tktst || !(state == READY || state == TSTHIT) || _coherency_bsy_i ||
	(m_wb_we_r && cache_rdidx == cache_wridx) /* wait for cache-write */ ||
	(cache_miss && (cache_writeb || !m_wb_we_r) && !coherency_r && !coherency_stb_r));

// The hold is used to insure that atomic operation has priority over coherency request, cf. lock_hold.
assign _coherency_stb_i = (coherency_stb_i && !coherency_bsy_o_ && !lock_hold);
// coherency_we_i is checked to process a write coherency request that came back around;
// it is used to mark the cache-entry as exclusive if it did not modified another data-cache.
wire __coherency_stb_i = (_coherency_stb_i && (coherency_rqid_i != PUID || coherency_we_i));

assign coherency_bsy_o = (coherency_bsy_o_ || lock_hold);

// True when we were looking for data in other data-caches and we received a response
// which would be a hit if `(coherency_sel_i & coherency_sel_r) == coherency_sel_r`.
wire _coherency_stb_r = (coherency_stb_r && _coherency_stb_i && !coherency_we_i &&
	coherency_rqid_i == PUID && coherency_addr_i == coherency_addr_r);

always_ff @(posedge clk_i)
	_coherency_stb_r_r <= _coherency_stb_r;

wire __coherency_stb_r = (_coherency_stb_r && (coherency_sel_i & coherency_sel_r) == coherency_sel_r);

always_ff @(posedge clk_i)
	__coherency_stb_r_r <= (__coherency_stb_r && (state == READY || state == TSTHIT) && !defld_r);

always_ff @(posedge clk_i) begin
	// State machine generating coherency requests, sending it to the next data-cache.
	if (rst_i || !coherency_en_i) begin
		coherency_stb_o <= 1'b0;
		coherency_stb_r <= 1'b0;
		coherency_xw_r <= 1'b0;
	end else if (state == TSTHIT && (tktake || (!coherency_r && !defstalloc_r && !defldtst_r &&
		(m_wb_we_r || !cache_hit || syn_r) && !cmiss_r && (!m_wb_we_r || (|m_wb_sel_r) || !ATOMIC_COHERENCE) &&
		(!m_wb_we_r || !cache_tag_hit || cache_shr_o_tag_hit)))) begin
		// When writing, this state generates write request to update other data-caches only if the cache-entry is shared.
		// When reading, on cache-miss, this state generates read request to look for data in other data-caches.
		// For a locked read which is to take its word (tktake), this state generates its take, ie: a write
		// request selecting no byte, and saves the bytes that the locked read selects, with which it is
		// resumed once the take has come back around.
		// For a sync (syn_r), this state generates a read request selecting no byte, whatever the cache-tag
		// test, which fills no cache-entry and marks shared that whose cache-tag matches, cf. syn_r.
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= PUID;
		coherency_we_o <= (m_wb_we_r || tktake);
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= (m_wb_sel_r & {(WORDBITSZ/8){m_wb_we_r}}); // Initially null for aggregation; null for a take.
		coherency_dat_o <= (m_wb_dat_r & {WORDBITSZ{m_wb_we_r}}); // Initially null for aggregation; null for a take.
		// Becomes non-null when any of the next data-caches use the request, or marks a take; non-null for a sync.
		coherency_shr_o <= syn_r;
		if (!m_wb_we_r) begin // For power-efficiency, otherwise this test is not needed.
			coherency_addr_r <= m_wb_addr_r;
			coherency_sel_r <= (m_wb_sel_r & ((cache_tag_hit && !tktake) ? ~cache_sel_o_tag_hit : {(WORDBITSZ/8){1'b1}}));
			// Note that we exclude the bits already in the cache-entry so that __coherency_stb_r matches
			// only the bits we need, and so that we correctly merge them for the result.
			coherency_xw_r <= syn_r; // A sync fills no cache-entry.
		end
		coherency_stb_r <= (!m_wb_we_r && !tktake);
	end else if (state == TSTHIT && coherency_r && !m_wb_we_r && cache_tag_hit && m_wb_rqid_r != PUID) begin
		// This state modifies the read request aggregating cache_tag_hit(s).
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= m_wb_rqid_r;
		coherency_we_o <= 1'b0;
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= (m_wb_sel_r | cache_sel_o_tag_hit);
		coherency_dat_o <= ((m_wb_dat_r & _cache_sel_o_tag_hit_n) | (cache_dat_o_tag_hit & _cache_sel_o_tag_hit));
		coherency_shr_o <= 1'b1;
	end else if ((state == TSTHIT && coherency_r && m_wb_rqid_r != PUID && !tkwb) ||
		(ATOMIC_COHERENCE && state == WRITEB && coherency_r && (MAXPENDINGACK ? !s_wb_bsy_i : s_wb_ack_i))) begin
		// This state forwards the request to the next data-cache; a take whose word is written back first
		// (tkwb) is forwarded from WRITEB, which no other coherency request enters, once memory accepted
		// that write-back.
		coherency_stb_o <= 1'b1;
		coherency_rqid_o <= m_wb_rqid_r;
		coherency_we_o <= m_wb_we_r;
		coherency_addr_o <= m_wb_addr_r;
		coherency_sel_o <= m_wb_sel_r;
		coherency_dat_o <= m_wb_dat_r;
		// A take is marked when this data-cache could not let it go by, cf. tkmark.
		if (_m_wb_tk_r)
			coherency_shr_o <= (m_wb_shr_r || tkmark);
		// A data-cache waiting on its own read of the same word is about to hold it as well; as is one whose
		// store waits for its write request to come back around (defst_r), which holds no copy of the word of
		// that store meanwhile, and does not keep which word that is: every request forwarded then is marked.
		else if (cache_tag_hit || (coherency_stb_r && coherency_addr_r == m_wb_addr_r) || defst_r)
			coherency_shr_o <= 1'b1;
		else
			coherency_shr_o <= m_wb_shr_r;
		// The read request of this data-cache may have overtaken that write request, and gathered older
		// bytes from a data-cache which it had not yet reached: the load is answered, but not cached.
		// A take changes no byte, and is marked when it meets such a read.
		if (m_wb_we_r && !_m_wb_tk_r && coherency_stb_r && coherency_addr_r == m_wb_addr_r)
			coherency_xw_r <= 1'b1;
	end else begin
		if (coherency_stb_o)
			coherency_stb_o <= coherency_bsy_i;
		if  (_coherency_stb_r_r)
			coherency_stb_r <= 1'b0;
	end
end

// While ATOMIC_COHERENCE is non-null, a store selecting no byte issues no write request, which would read
// as a take, cf. nullst.
wire coherency_write_req = (state == TSTHIT && m_wb_we_r && !coherency_r && !defstalloc_r &&
	!cmiss_r && (!coherency_en_i || !ATOMIC_COHERENCE || (|m_wb_sel_r)) && (!cache_tag_hit || cache_shr_o_tag_hit));

// A take is not counted: while it travels (tko_r), it is the only write request of this data-cache which can
// come back, every other one having come back before its locked read was accepted.
wire coherency_write_ack = (_coherency_stb_i && coherency_rqid_i == PUID && coherency_we_i && !tko_r);

// A store is counted on the clockedge ending its TSTHIT, which is the earliest that its master counts its
// acknowledgement, hence the master sees no clockcycle between the two.
assign coherency_pending_o = (|coherency_write_pending);

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

always_ff @(posedge clk_i) begin
	if (rst_i || !coherency_en_i)
		coherency_write_bkt <= 0;
	else begin
		if (!coherency_write_pending)
			coherency_write_bkt <= 0;
		if (coherency_write_req)
			coherency_write_bkt[m_wb_addr_r[0 +: CLOG2COHERENCYWRITEBKTCNT]] <= 1'b1;
	end
end

assign m_wb_bsy_o = (coherency_bsy_o_ || __coherency_stb_i || coherency_stb_r || defst_r || tko_r || syn_r ||
	// Nothing is accepted while a take which went through marked is to come by again, cf. tkmark, but the
	// access which follows a locked read of this data-cache: it ends the hold of the ring, which that take
	// may be waiting behind, and which issues no request.
	((|tkf_r) && !lock_r) ||
	// Right before the start of an atomic operation, coherency_write_pending is
	// used to wait for pending coherency writes to update all other data caches.
	// A store in TSTHIT is counted only on the clockedge ending TSTHIT, hence it holds off as well.
	((coherency_write_pending || (coherency_en_i && state == TSTHIT && m_wb_we_r && !coherency_r)) && m_wb_lock_i && !lock_r));

// A read forced to miss is acknowledged from the cache only on a cache-hit of a dirty entry, which is
// then written back; a clean one is invalidated and the read is made in memory, ie: acknowledged at REFILL.
assign m_wb_ack_o = (
	state == TSTHIT ? ((((cache_hit && (!cmiss_r || cache_drt_o_we_wayidx)) || m_wb_we_r) && !coherency_r && !defstalloc_r && !tktake && !syn_r) ||
		__coherency_stb_r_r) :
	state == REFILL ? (!s_wb_we_o && refill_ack) : 1'b0);

assign m_wb_dat_o = (state == TSTHIT ? (__coherency_stb_r_r ? cache_dat_i_ : cache_dat_o_tag_hit) : _s_wb_dat_i);

always_ff @(posedge clk_i) begin

	if (rst_i) begin

		rst_r <= 1;

		m_wb_we_r <= 0;

		m_wb_addr_r <= 0;

		s_wb_stb_o <= 0;

		cmiss_r <= 0;

		coherency_r <= 0;

		defst_r <= 0;
		defstalloc_r <= 0;
		defld_r <= 0;
		defldtst_r <= 0;

		tkp_r <= 0;
		tko_r <= 0;
		tkf_r <= 0;
		tk_r <= 0;

		syn_r <= 0;

		state <= READY;

	end else begin

		if (state == READY || state == TSTHIT) begin

			defstalloc_r <= 0;
			tk_r <= 0;
			syn_r <= 0;
			// A locked read which takes no word, cf. tktake, is handled below as a read forced to miss.
			if (state == TSTHIT)
				tkp_r <= 0;

			if (tktst)
				tkf_r[m_wb_rqid_r] <= (tkmark || m_wb_shr_r);

			if (evict_defer) begin
				if (m_wb_we_r)
					defst_r <= 1;
				else
					defld_r <= 1;
			end

			if (rst_r) begin

				if (m_wb_addr_r == (CACHESETCNT - 1))
					rst_r <= 0;
				else
					m_wb_addr_r <= m_wb_addr_r + 1'b1;

			end else if (tktake) begin
				// The locked read issues its take, cf. the state machine generating coherency
				// requests, and waits for it to come back, the ring flowing meanwhile.

				tko_r <= 1;

				cmiss_r <= 0;

				state <= READY;

			end else if (tkwb || (!coherency_r && (cmiss_r ?
				(cache_hit && !m_wb_we_r && cache_drt_o_we_wayidx) :
				(cache_miss && cache_writeb && !evict_defer && !nullst && !syn_r)))) begin
				// A read forced to miss writes back the entry it hits only when dirty. A clean entry is only
				// invalidated, through cache_we2, as it holds nothing that memory lacks, or is behind memory,
				// cf. _cache_tag_hit, and the read is made in memory by the REFILL arm below, carrying the same
				// lock, and acknowledged once from there; the bytes it held are merged back for an access not
				// carrying the lock, cf. _cache_tag_hit.
				// A take from another data-cache writes back here as well the word that it removes, when it
				// is held dirty (tkwb): the cache-entry is the one whose cache-tag matches, and the take is
				// forwarded once memory accepted the write-back, cf. the state machine generating coherency
				// requests.

				s_wb_stb_o <= 1;
				// The write-back of a take carries no lock, its m_wb_lock_r being that of an earlier access
				// of the master: the take may be travelling while the take of a locked read of this data-cache
				// does, and that lock would hold the bus against the data-cache which issued it.
				s_wb_lock_o <= (m_wb_lock_r && !coherency_r);
				s_wb_we_o <= 1;
				s_wb_addr_o <= {cache_tag_o[cache_we_wayidx], cache_wridx};
				s_wb_sel_o <= cache_sel_o[cache_we_wayidx] & (cmiss_r ? m_wb_sel_r : {(WORDBITSZ/8){1'b1}});
				s_wb_dat_o <= cache_dat_o[cache_we_wayidx];

				state <= WRITEB;

			end else if (defldtst_r) begin
				// The victim of a load deferred by evict_defer is clean, or was written back by the
				// arm above, which then starts this same REFILL from WRITEB.

				defldtst_r <= 0;

				s_wb_stb_o <= 1;
				s_wb_lock_o <= 0;
				s_wb_we_o <= 0;
				s_wb_addr_o <= m_wb_addr_r;
				s_wb_sel_o <= coherency_sel_r;

				state <= REFILL;

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

				if (_coherency_stb_i && coherency_rqid_i == PUID && coherency_we_i && tko_r) begin
					// The take of the locked read came back: the locked read is resumed in the TSTHIT which
					// follows, unless the take is marked, ie: is to be issued again from there, cf. tkmark.

					m_wb_lock_r <= 1;
					m_wb_we_r <= 0;
					m_wb_addr_r <= coherency_addr_r;
					m_wb_sel_r <= coherency_sel_r;

					cmiss_r <= 1;

					coherency_r <= 0;

					tko_r <= 0;
					tkp_r <= coherency_shr_i;

					state <= TSTHIT;

				end else if (_coherency_stb_r && defld_r) begin
					// The read request of a load deferred by evict_defer came back, hence the count is
					// null: its victim is tested in the TSTHIT which follows, written back if dirty, and
					// the REFILL which answers the load set up as below, cf. defldtst_r.

					m_wb_we_r <= 0;
					m_wb_addr_r <= coherency_addr_r;
					m_wb_sel_r <= coherency_sel_i;
					m_wb_dat_r <= coherency_dat_i;
					m_wb_shr_r <= coherency_shr_i;

					coherency_r <= 0;

					defld_r <= 0;
					defldtst_r <= 1;

					state <= TSTHIT;

				end else if (__coherency_stb_r) begin

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

					if (defst_r && coherency_rqid_i == PUID && coherency_we_i && coherency_write_pending == 1) begin
						// The write request of a store deferred by evict_defer came back, as the last one
						// that this data-cache issued, hence the count is null: the store, which that
						// request carries, is made in the TSTHIT which follows, evicting its victim.

						m_wb_we_r <= 1;
						m_wb_addr_r <= coherency_addr_i;
						m_wb_sel_r <= coherency_sel_i;
						m_wb_dat_r <= coherency_dat_i;

						coherency_r <= 0;

						defst_r <= 0;
						defstalloc_r <= 1;

					end else begin

						m_wb_rqid_r <= coherency_rqid_i;
						m_wb_we_r <= coherency_we_i;
						m_wb_addr_r <= coherency_addr_i;
						m_wb_sel_r <= coherency_sel_i;
						m_wb_dat_r <= coherency_dat_i;
						m_wb_shr_r <= coherency_shr_i; // Updated when setting coherency_r true, and for REFILL.

						coherency_r <= 1;

						// A take from another data-cache, cf. tktst.
						tk_r <= (coherency_we_i && !(|coherency_sel_i) && coherency_rqid_i != PUID);
					end

					state <= TSTHIT;

				end else begin

					m_wb_lock_r <= m_wb_lock_i;
					m_wb_we_r <= m_wb_we_i;
					m_wb_addr_r <= m_wb_addr_i;
					m_wb_sel_r <= m_wb_sel_i;
					m_wb_dat_r <= m_wb_dat_i;

					cmiss_r <= _cmiss_i;

					coherency_r <= 0;

					// A locked read to a cacheable word first takes it from the ring, cf. tkp_r, unless it
					// follows a locked read, being then forced to miss as any access which does.
					tkp_r <= (coherency_en_i && m_wb_lock_i && !m_wb_we_i && !cmiss_i && !lock_r);

					syn_r <= syn_i;

					state <= TSTHIT;
				end

			end else begin

				m_wb_we_r <= 0;

				cmiss_r <= 0;

				coherency_r <= 0;

				state <= READY;
			end

		end else if (state == WRITEB) begin

			if (MAXPENDINGACK ? !s_wb_bsy_i : s_wb_ack_i) begin

				if (defldtst_r) begin
					// The victim of a load deferred by evict_defer is written back: start its REFILL.

					defldtst_r <= 0;

					s_wb_stb_o <= 1;
					s_wb_lock_o <= 0;
					s_wb_we_o <= 0;
					s_wb_addr_o <= m_wb_addr_r;
					s_wb_sel_o <= coherency_sel_r;

					state <= REFILL;

				end else if (cmiss_r || m_wb_we_r || coherency_en_i) begin
					// This is as well where the write-back of the word that a take removes ends, m_wb_we_r
					// being high for a take, which the state machine generating coherency requests forwards.

					m_wb_we_r <= 0;

					s_wb_stb_o <= 0;

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

				cmiss_r <= 0;

				state <= READY;

			end else if (!s_wb_bsy_i)
				s_wb_stb_o <= 0;
		end
	end

	// The deferrals of evict_defer occur on a coherency ring only, and the takes as well, only while
	// ATOMIC_COHERENCE is non-null.
	if (!coherency_en_i) begin
		defst_r <= 0;
		defstalloc_r <= 0;
		defld_r <= 0;
		defldtst_r <= 0;
	end
	if (!coherency_en_i || !ATOMIC_COHERENCE) begin
		tkp_r <= 0;
		tko_r <= 0;
		tkf_r <= 0;
		tk_r <= 0;
	end
	// The syncs occur on a ring of more than two data-caches only.
	if (!coherency_en_i || !RINGSYNC)
		syn_r <= 0;
	// A take is tested only from another data-cache, cf. tktst: the bit of this data-cache is never set.
	tkf_r[PUID] <= 1'b0;
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
// m_wb_bsy_o, cache_drt_i, coherency_write_bkt_hit and coherency_pending_o above read
// coherency_write_pending as a plain non-null test, hence a count that does not fit its width does not
// merely lose precision, it reads null while coherency writes are still travelling the ring: the barrier
// is released, the atomic operation then starting early, and another data-cache being left holding a
// cache-entry that the writes had not yet updated; a crossing write request makes clean a copy that is
// to stay dirty; a dirty cache-entry is written back, and a take goes by unmarked, while a write request
// which may be for their word travels (evict_defer, tkmark), the buckets being cleared as well; and a
// fence of stores before loads stops waiting. The store deferred by evict_defer, which takes for its own
// the write request coming back while the count is one, would take that of another store. Nothing
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

// The holds that the atomics add (cf. Cache coherency) fail as a stall rather than as a wrong value: a take
// which never comes back, a master held by a take which went through marked and never comes by again, a
// store or a load deferred by evict_defer whose request never comes back; so does the hold of a sync whose
// request never comes back. Each is reported once past a bound that no correct run reaches, and flushed, as
// the run may then never reach $finish. Also reported is a take coming back marked as many times in a row
// as the ring can hold data-caches, which the hold of the data-caches that it went through marked rules
// out, cf. tkf_r.
localparam HOLDAGELIMIT = 4096;
reg [(clog2(HOLDAGELIMIT) +1) -1 : 0] tko_age_r;
reg [(clog2(HOLDAGELIMIT) +1) -1 : 0] tkf_age_r;
reg [(clog2(HOLDAGELIMIT) +1) -1 : 0] def_age_r;
reg [(clog2(HOLDAGELIMIT) +1) -1 : 0] syn_age_r;
reg [8 -1 : 0] tk_reissue_r;
reg tko_age_rpt_r;
reg tkf_age_rpt_r;
reg def_age_rpt_r;
reg syn_age_rpt_r;
reg tk_reissue_rpt_r;
wire tk_return = (_coherency_stb_i && coherency_rqid_i == PUID && coherency_we_i && tko_r);
// The read request travelling is that of a sync, the only one which selects no byte, cf. syn_r.
wire syn_trv = (coherency_stb_r && !(|coherency_sel_r));
always_ff @(posedge clk_i) begin
	if (rst_i || !coherency_en_i) begin
		tko_age_r <= 0;
		tkf_age_r <= 0;
		def_age_r <= 0;
		syn_age_r <= 0;
		tk_reissue_r <= 0;
		tko_age_rpt_r <= 1'b0;
		tkf_age_rpt_r <= 1'b0;
		def_age_rpt_r <= 1'b0;
		syn_age_rpt_r <= 1'b0;
		tk_reissue_rpt_r <= 1'b0;
	end else begin
		tko_age_r <= (tko_r ? (tko_age_r + (tko_age_r != HOLDAGELIMIT)) : 0);
		if (tko_age_r == (HOLDAGELIMIT - 1) && tko_r && !tko_age_rpt_r) begin
			tko_age_rpt_r <= 1'b1;
			$display("dcache%0d: error: a take has not come back in %0d clockcycles", PUID, HOLDAGELIMIT);
			$fflush();
		end
		tkf_age_r <= (((|tkf_r) && !lock_r) ? (tkf_age_r + (tkf_age_r != HOLDAGELIMIT)) : 0);
		if (tkf_age_r == (HOLDAGELIMIT - 1) && (|tkf_r) && !lock_r && !tkf_age_rpt_r) begin
			tkf_age_rpt_r <= 1'b1;
			$display("dcache%0d: error: the master has been held %0d clockcycles for marked takes, of the data-caches %b",
				PUID, HOLDAGELIMIT, tkf_r);
			$fflush();
		end
		def_age_r <= ((defst_r || defld_r) ? (def_age_r + (def_age_r != HOLDAGELIMIT)) : 0);
		if (def_age_r == (HOLDAGELIMIT - 1) && (defst_r || defld_r) && !def_age_rpt_r) begin
			def_age_rpt_r <= 1'b1;
			$display("dcache%0d: error: a deferred %s has waited %0d clockcycles for its request",
				PUID, (defst_r ? "store" : "load"), HOLDAGELIMIT);
			$fflush();
		end
		syn_age_r <= (syn_trv ? (syn_age_r + (syn_age_r != HOLDAGELIMIT)) : 0);
		if (syn_age_r == (HOLDAGELIMIT - 1) && syn_trv && !syn_age_rpt_r) begin
			syn_age_rpt_r <= 1'b1;
			$display("dcache%0d: error: a sync has not come back in %0d clockcycles", PUID, HOLDAGELIMIT);
			$fflush();
		end
		if (tk_return)
			tk_reissue_r <= (coherency_shr_i ? (tk_reissue_r + (tk_reissue_r != 8'hff)) : 8'd0);
		if (tk_return && coherency_shr_i && tk_reissue_r == ((1<<PUIDBITSZ) - 1) && !tk_reissue_rpt_r) begin
			tk_reissue_rpt_r <= 1'b1;
			$display("dcache%0d: error: a take came back marked %0d times in a row", PUID, (1<<PUIDBITSZ));
			$fflush();
		end
	end
end

// What the take logic takes for granted of the master and of itself, each reported once and flushed, while
// ATOMIC_COHERENCE is non-null; nothing of it is reported while it is null, no take being issued then, the
// access which follows a locked read being free to select bytes, and a write request selecting no byte
// being that of a store:
// - On a ring, the access which follows a locked read of a word which may be cached is the write of the
//   atomic, or a read selecting no byte (cf. Cache coherency): a read selecting bytes there is forced to
//   miss and takes no part in the cache-coherency logic, which cpu/dcache.pu.sv insures does not occur.
// - tk_r tells the TSTHIT of a take from another data-cache (cf. tktst): it is to be high there only, and
//   whenever the request held is one.
// - A write request selecting no byte is a take: one of this data-cache coming back while none of its takes
//   travels is a store selecting no byte which was issued as a write request (cf. nullst), and the
//   data-caches that it went through marked would hold their master for a take which is never issued again.
// - A take which came back marked is issued again in the TSTHIT which follows: the data-caches that it went
//   through marked hold their master until it comes by again (cf. tkf_r).
reg lockfollow_rpt_r;
reg tk_decode_rpt_r;
reg nulltake_rpt_r;
reg tkret_marked_r;
reg tk_noreissue_rpt_r;
wire tk_decode = (coherency_r && m_wb_we_r && !(|m_wb_sel_r) && m_wb_rqid_r != PUID);
always_ff @(posedge clk_i) begin
	if (rst_i || !coherency_en_i || !ATOMIC_COHERENCE) begin
		lockfollow_rpt_r <= 1'b0;
		tk_decode_rpt_r <= 1'b0;
		nulltake_rpt_r <= 1'b0;
		tkret_marked_r <= 1'b0;
		tk_noreissue_rpt_r <= 1'b0;
	end else begin
		if (_m_wb_stb_i && lock_r && !cmiss_i && !m_wb_we_i && (|m_wb_sel_i) && !lockfollow_rpt_r) begin
			lockfollow_rpt_r <= 1'b1;
			$display("dcache%0d: error: a read selecting bytes follows a locked read, at word address %h", PUID, m_wb_addr_i);
			$fflush();
		end
		if ((state == TSTHIT ? (tk_r != tk_decode) : tk_r) && !tk_decode_rpt_r) begin
			tk_decode_rpt_r <= 1'b1;
			$display("dcache%0d: error: tk_r is %0d in state %0d, where it is to be %0d",
				PUID, tk_r, state, (state == TSTHIT && tk_decode));
			$fflush();
		end
		if (_coherency_stb_i && coherency_rqid_i == PUID && coherency_we_i && !(|coherency_sel_i) && !tko_r && !nulltake_rpt_r) begin
			nulltake_rpt_r <= 1'b1;
			$display("dcache%0d: error: a write request selecting no byte came back while no take travels", PUID);
			$fflush();
		end
		tkret_marked_r <= (tk_return && coherency_shr_i);
		if (tkret_marked_r && !(state == TSTHIT && tktake) && !tk_noreissue_rpt_r) begin
			tk_noreissue_rpt_r <= 1'b1;
			$display("dcache%0d: error: a take which came back marked is not issued again", PUID);
			$fflush();
		end
	end
end

// What the deferral of evict_defer takes for granted, each reported once and flushed:
// - No access is deferred while another one is, the master being held meanwhile.
// - The write request taken for that of a deferred store, ie: the one which comes back while a single one
//   travels, is for the word of that store; the monitor keeps that word, which the data-cache does not.
// - The TSTHIT which makes a deferred store finds no write request of this data-cache travelling, and no
//   cache-tag hit, nothing having allocated the word of that store meanwhile; nor does the TSTHIT which
//   evicts the victim of a deferred load find such a write request (cf. evict_defer).
reg def_nest_rpt_r;
reg def_back_rpt_r;
reg def_stresume_rpt_r;
reg def_ldresume_rpt_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] def_addr_r;
always_ff @(posedge clk_i) begin
	if (rst_i || !coherency_en_i) begin
		def_nest_rpt_r <= 1'b0;
		def_back_rpt_r <= 1'b0;
		def_stresume_rpt_r <= 1'b0;
		def_ldresume_rpt_r <= 1'b0;
	end else begin
		if (evict_defer && m_wb_we_r)
			def_addr_r <= m_wb_addr_r;
		if (evict_defer && (defst_r || defld_r || defstalloc_r || defldtst_r) && !def_nest_rpt_r) begin
			def_nest_rpt_r <= 1'b1;
			$display("dcache%0d: error: an access is deferred while another one is", PUID);
			$fflush();
		end
		if (state == TSTHIT && defstalloc_r && m_wb_addr_r != def_addr_r && !def_back_rpt_r) begin
			def_back_rpt_r <= 1'b1;
			$display("dcache%0d: error: the write request taken for that of a deferred store is for word address %h, not %h",
				PUID, m_wb_addr_r, def_addr_r);
			$fflush();
		end
		if (state == TSTHIT && defstalloc_r && ((|coherency_write_pending) || cache_tag_hit) && !def_stresume_rpt_r) begin
			def_stresume_rpt_r <= 1'b1;
			$display("dcache%0d: error: a deferred store is made while a write request travels, or on a cache-tag hit", PUID);
			$fflush();
		end
		if (state == TSTHIT && defldtst_r && (|coherency_write_pending) && !def_ldresume_rpt_r) begin
			def_ldresume_rpt_r <= 1'b1;
			$display("dcache%0d: error: the victim of a deferred load is evicted while a write request travels", PUID);
			$fflush();
		end
	end
end

// What the sync takes for granted, each reported once and flushed (cf. syn_r):
// - The ring keeps the order of the requests: the request of a sync comes back around behind every write
//   request that this data-cache issued before it, hence none of them travels when the sync is acknowledged.
// - A read selecting no byte which neither carries the lock nor follows a locked access is a sync, which the
//   master is to present only on a ring of more than two data-caches (RINGSYNC): elsewhere, such a read
//   would be answered as a cache-hit, or issue a read request filling with no byte the cache-entry that it
//   replaces.
reg syn_ackpending_rpt_r;
reg syn_undefined_rpt_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		syn_ackpending_rpt_r <= 1'b0;
		syn_undefined_rpt_r <= 1'b0;
	end else begin
		if (state == TSTHIT && __coherency_stb_r_r && syn_trv && (|coherency_write_pending) && !syn_ackpending_rpt_r) begin
			syn_ackpending_rpt_r <= 1'b1;
			$display("dcache%0d: error: a sync is acknowledged while %0d write requests of its data-cache travel",
				PUID, coherency_write_pending);
			$fflush();
		end
		if (_m_wb_stb_i && !m_wb_we_i && !(|m_wb_sel_i) && !m_wb_lock_i && !lock_r && !syn_i && !syn_undefined_rpt_r) begin
			syn_undefined_rpt_r <= 1'b1;
			$display("dcache%0d: error: a read selecting no byte, following no locked access, is presented where no sync is made, at word address %h",
				PUID, m_wb_addr_i);
			$fflush();
		end
	end
end
`endif

endmodule

module dCache (

	 rst_i

	,clk_i

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

	,coherency_pending_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter ADDRLIMIT = 'h2000;

parameter CACHESETCNT = 2;
parameter CACHEWAYCNT = 1;

parameter REGMSTOUTPUT = 0;
parameter REGSLVINPUT  = 0;

parameter MAXPENDINGACK = 0; // Enables faster eviction when non-null.

parameter PUIDBITSZ = 1;
parameter PUID      = 0;

parameter ATOMIC_COHERENCE = 0; // Atomics take their word from the ring when non-null.

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

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

output wire                               coherency_pending_o;

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
	,.PUIDBITSZ     (PUIDBITSZ)
	,.PUID          (PUID)
	,.ATOMIC_COHERENCE (ATOMIC_COHERENCE)
) dCacheSub (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

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

	,.coherency_pending_o (coherency_pending_o)
);

endmodule

`endif /* DCACHE_V */
