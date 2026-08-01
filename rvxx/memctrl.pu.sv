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
reg                                  iF_mem_seq_valid;

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
