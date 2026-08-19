// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// wb_rqst_cnt and wb_resp_cnt are kept as absolute sequence tags: they demux
// instruction-fetch responses from dCache responses on the shared bus (iF_mem_seq,
// iF_mem_ack, dCache_s_ack_i below), which needs the absolute counts, not just their
// difference. Occupancy is instead tracked by a dedicated up/down register so
// wb_max_pending reads a registered bit rather than the subtract (wb_rqst_cnt - wb_resp_cnt).
reg [(CLOG2MAXPENDINGACK +1) -1 : 0] wb_rqst_cnt;
reg [(CLOG2MAXPENDINGACK +1) -1 : 0] wb_resp_cnt;

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] wb_pending_acks; // Occupancy: accepted requests not yet responded.

wire wb_max_pending = wb_pending_acks[CLOG2MAXPENDINGACK];

assign _wb_bsy_i = (wb_bsy_i || wb_max_pending);

wire wb_rqst_accepted = (wb_stb_o && !_wb_bsy_i); // a request is accepted onto the bus
wire wb_resp_received = wb_ack_i;                 // a response returns

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_rqst_cnt <= 0;
	else if (wb_rqst_accepted)
		wb_rqst_cnt <= wb_rqst_cnt + 1'b1;
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_resp_cnt <= 0;
	else if (wb_resp_received)
		wb_resp_cnt <= wb_resp_cnt + 1'b1;
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_pending_acks <= 0;
	else if (wb_rqst_accepted != wb_resp_received) // net change only when exactly one occurs
		wb_pending_acks <= (wb_rqst_accepted ? (wb_pending_acks + 1'b1) : (wb_pending_acks - 1'b1));
end

// wb_arbiter.sv releases the bus lock on the next accepted access that does not carry it.
// An instruction fetch interleaves inside an atomic operation's window, between its
// load-reserved and store-conditional, or between its read and write-back, so leaving
// wb_lock_o null for the fetch would release the lock in the middle of that window.
// wb_lock_r retains what the last accepted access carried, and wb_lock_o defaults to it
// below, hence a fetch holds the lock instead of releasing it, and only the data-cache
// branch ever changes it. This mirrors dcache.sv's lock_r, which tracks the same state
// from the same accesses to give an atomic operation priority over coherency requests.
reg wb_lock_r;

always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_lock_r <= 1'b0;
	else if (wb_rqst_accepted)
		wb_lock_r <= wb_lock_o;
end

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] iF_mem_seq;

assign dCache_s_ack_i = (wb_ack_i && (!iF_mem_seq_valid || wb_resp_cnt != iF_mem_seq));

reg iF_mem_stb;
reg iF_mem_stb_r;
reg [(XADDRBITSZ-XMSBSZIGN) -1 : 0] iF_mem_addr;
wire iF_mem_bsy = ((dCache_s_stb_o && !iF_mem_stb_r) || _wb_bsy_i);
wire iF_mem_ack = (wb_ack_i && iF_mem_seq_valid && wb_resp_cnt == iF_mem_seq);

assign dCache_s_bsy_i = (iF_mem_stb_r || _wb_bsy_i);

assign iCache_we_w   = iF_mem_ack;
assign iCache_dati_w = wb_dat_i;
assign iCache_widx_w = iF_mem_addr[CLOG2ICACHESETCNT-1:0];
assign iCache_wtag_w = iF_mem_addr[((WORDBITSZ-MSBSZIGN)-CLOG2XWORDBITSZBY8)-1:CLOG2ICACHESETCNT];

reg iF_mem_wait;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		iF_mem_stb <= 0;
		iF_mem_stb_r <= 0;
		iF_mem_seq_valid <= 0;
		iF_mem_wait <= 1;
	end else if (iF_mem_stb) begin
		if (!iF_mem_bsy) begin
			iF_mem_seq <= wb_rqst_cnt;
			iF_mem_seq_valid <= 1;
			iF_mem_stb <= 0;
			iF_mem_stb_r <= 0;
		end else
			iF_mem_stb_r <= 1;
	end else if (iF_mem_seq_valid) begin
		if (iF_mem_ack) begin
			iF_mem_seq_valid <= 0;
			iF_mem_wait <= 1;
		end
	end else if (iF_mem_wait) begin
		if (iCache_re_w) // Wait for an icache access before checking iCache_hit_w.
			iF_mem_wait <= 0;
	end else if (iF_eX_JumpOrBranch_i) begin
		iF_mem_wait <= 1; // Set in order to begin with an icache access on branching.
	end else if (!iCache_hit_w) begin
		iF_mem_stb <= iCache_rdy_w;
		iF_mem_addr <= { // MSB oring of ignored bits.
			|iF_pc[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
			iF_pc[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2XWORDBITSZBY8]};
	end
end

// Instruction fetching has the least priority so that load
// and store instructions can be completed as soon as possible,
// and so that the next instruction in the buffer can be sequenced
// as soon as possible.

always_comb begin

	wb_stb_o = 0;
	wb_lock_o = wb_lock_r;
	wb_we_o = 0;
	wb_addr_o = 0;
	wb_sel_o = 0;
	wb_dat_o = 0;

	if (wb_max_pending);
	else if (dCache_s_stb_o && !iF_mem_stb_r) begin
		wb_stb_o = 1;
		wb_lock_o = dCache_s_lock_o;
		wb_we_o = dCache_s_we_o;
		wb_addr_o = dCache_s_addr_o;
		wb_sel_o = dCache_s_sel_o;
		wb_dat_o = dCache_s_dat_o;
	end else if (iF_mem_stb) begin
		wb_stb_o = 1;
		wb_addr_o = iF_mem_addr;
		wb_sel_o = {(XWORDBITSZ/8){1'b1}};
	end
end

`ifdef PUICACHEFILLBYPASS
// iF_mem_ack is the one clockcycle the refilled word is live on wb_dat_i, and the
// same edge writes it into the i-cache. Capture it beside that write and hold the
// capture until the fetch stage takes it, so that a decode stalled in the clockcycle
// the word arrives costs no more than it costs an ordinary hit, whose block ram
// outputs hold while the read enable is low. The capture is qualified as follow.
// The address compared: the response carries the address the request was made for,
// and iF_pc moves on its own, so the two can differ -- a redirect taken while a
// refill is in flight retargets the fetch, and a refill armed on an i-cache verdict
// left over from a swallowed redirect asks for a line that is already cached, whose
// read then hits and advances iF_pc past it. Re-probing is what makes both harmless
// today; a forced hit would hand the fetch stage an instruction from an address it
// has already left. Both are registers, so the compare is made in the clockcycle
// before the fetch stage needs it and never reaches the read address.
// iCache_rdy_w: a refill armed before a fence.i can be responded to during the
// invalidate walk, where iCache drops the fill and the miss controller re-requests
// once the walk ends. Without this term the word read from memory before the walk
// would be handed over as the instruction after the fence.i, and the address
// compare does not cover it, the redirect target and the in-flight address being
// the very same word whenever the instruction after the fence.i is what missed.
// !iF_eX_JumpOrBranch_i covers the redirect taken in this very clockcycle, iF_pc
// moving on the same edge the capture would be validated on. It also covers
// excTriggered, which eX_JumpOrBranch_i carries, and fence.i, which always
// redirects in the clockcycle it invalidates, so neither is written again here.
// iF_en clears the capture: while it is valid the fetch stage is not flushed,
// hence iF_en is iD_en and is also iCache_re_w, ie: the one term means the
// instruction was taken, the read for the next pc was issued, and iF_mem_wait
// above was cleared.
// !iCache_hit_w: the response can land while the fetch stage is consuming a hit
// of the very word being refilled -- a stale refill of a cached line ridden into
// mid-word, which XWORDBITSZ wider than INSNBITSZ makes ordinary -- and the set
// outranks the clear below, so a capture taken in a consuming clockcycle would
// survive its own consume and stand at the next pc, ie: the wrong instruction.
// The fetch stage already has the word whenever it hits, so nothing is lost.
// The state machine is left reading iCache_hit_w raw: iF_bypass_vld is set by the
// same arm that sets iF_mem_wait and cleared by what clears it, so the branches
// below the wait one are unreachable while the capture is valid, and this feature
// adds nothing at all to the bus request cone.
always_ff @(posedge clk_i) begin
	if (rst_i)
		iF_bypass_vld <= 1'b0;
	else if (iF_mem_ack && iCache_rdy_w && !iF_eX_JumpOrBranch_i && !iCache_hit_w &&
		iF_mem_addr == { // MSB oring of ignored bits.
			|iF_pc[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
			iF_pc[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2XWORDBITSZBY8]})
		iF_bypass_vld <= 1'b1;
	else if (iF_en || iF_eX_JumpOrBranch_i)
		iF_bypass_vld <= 1'b0;
end

always_ff @(posedge clk_i) begin
	if (iF_mem_ack)
		iF_bypass_dat <= wb_dat_i;
end

`ifdef SIMULATION
// The fill bypass rests on three properties, and each is checked at its consumer
// rather than trusted, as follow.
// The word is handed over for the address it was requested for. The capture above
// compares the two in the clockcycle the response returns, but the capture is then
// held until the fetch stage takes it, and it is that hold -- not the compare --
// which rests on iF_pc being unable to move while the capture is valid. Checked
// here at the consume, which is where a moved iF_pc pairs the word with an address
// it does not belong to, ie: executes a wrong instruction rather than merely
// mispredicting. Every way of getting the hold wrong lands on this one compare.
// The state machine never sees the forced hit. iF_bypass_vld implies iF_mem_wait,
// hence the branches below the wait one are unreachable while the capture is valid,
// which is what lets the miss branch above keep reading iCache_hit_w raw and keeps
// this feature out of the bus request cone entirely. Checked rather than argued,
// as the whole placement of the feature rests on it.
// The clockcycle bypassed is a miss. The read the fetch stage would need in the
// response clockcycle is withheld, so the bram outputs hold the verdict of the
// missing pc, which is a miss by construction. A hit here means the clockcycle
// this feature removes is not the clockcycle it was measured on.
// Each is reported once and flushed, as the first two hand the pipeline a wrong
// instruction rather than merely slowing it. A clean run prints nothing.
reg iF_bypass_pcrpt;
reg iF_bypass_waitrpt;
reg iF_bypass_hitrpt;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		iF_bypass_pcrpt <= 1'b0;
		iF_bypass_waitrpt <= 1'b0;
		iF_bypass_hitrpt <= 1'b0;
	end else begin
		if (iF_bypass_vld && iF_en && !iF_bypass_pcrpt &&
			iF_mem_addr != { // MSB oring of ignored bits.
				|iF_pc[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
				iF_pc[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2XWORDBITSZBY8]}) begin
			$display("pu%0d: error: fill bypass of %h consumed at pc %h",
				PUID, iF_mem_addr, iF_pc);
			$fflush();
			iF_bypass_pcrpt <= 1'b1;
		end
		if (iF_bypass_vld && !iF_mem_wait && !iF_bypass_waitrpt) begin
			$display("pu%0d: error: fill bypass valid while the fetch miss controller is not waiting",
				PUID);
			$fflush();
			iF_bypass_waitrpt <= 1'b1;
		end
		if (iF_bypass_vld && iCache_hit_w && !iF_bypass_hitrpt) begin
			$display("pu%0d: error: fill bypass valid on an i-cache hit at pc %h",
				PUID, iF_pc);
			$fflush();
			iF_bypass_hitrpt <= 1'b1;
		end
	end
end
`endif
`endif
