// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Load Unit.

reg  [WORDBITSZ -1 : 0]     ldUnit_rqsts_dato; // ### comb-block-reg.
wire [(WORDBITSZ/8) -1 : 0] ldUnit_rqsts_sel;
wire                        ldUnit_rqsts_zxt;
// Apropriately set ldUnit_rqsts_dato depending on ldUnit_rqsts_sel.
generate if (WORDBITSZ == 32) begin always_comb begin
	if      (ldUnit_rqsts_sel == 4'b1100) ldUnit_rqsts_dato = {{16{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:16]};
	else if (ldUnit_rqsts_sel == 4'b0011) ldUnit_rqsts_dato = {{16{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:0]};
	else if (ldUnit_rqsts_sel == 4'b1000) ldUnit_rqsts_dato = {{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:24]};
	else if (ldUnit_rqsts_sel == 4'b0100) ldUnit_rqsts_dato = {{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[23]}}, dCache_m_dat_o[23:16]};
	else if (ldUnit_rqsts_sel == 4'b0010) ldUnit_rqsts_dato = {{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:8]};
	else if (ldUnit_rqsts_sel == 4'b0001) ldUnit_rqsts_dato = {{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[7]}},  dCache_m_dat_o[7:0]};
	else                                  ldUnit_rqsts_dato = dCache_m_dat_o;
end end endgenerate
generate if (WORDBITSZ == 64) begin always_comb begin
	if      (ldUnit_rqsts_sel == 8'b11110000) ldUnit_rqsts_dato = {{32{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:32]};
	else if (ldUnit_rqsts_sel == 8'b00001111) ldUnit_rqsts_dato = {{32{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:0]};
	else if (ldUnit_rqsts_sel == 8'b11000000) ldUnit_rqsts_dato = {{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:48]};
	else if (ldUnit_rqsts_sel == 8'b00110000) ldUnit_rqsts_dato = {{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[47]}}, dCache_m_dat_o[47:32]};
	else if (ldUnit_rqsts_sel == 8'b00001100) ldUnit_rqsts_dato = {{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:16]};
	else if (ldUnit_rqsts_sel == 8'b00000011) ldUnit_rqsts_dato = {{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:0]};
	else if (ldUnit_rqsts_sel == 8'b10000000) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:56]};
	else if (ldUnit_rqsts_sel == 8'b01000000) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[55]}}, dCache_m_dat_o[55:48]};
	else if (ldUnit_rqsts_sel == 8'b00100000) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[47]}}, dCache_m_dat_o[47:40]};
	else if (ldUnit_rqsts_sel == 8'b00010000) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[39]}}, dCache_m_dat_o[39:32]};
	else if (ldUnit_rqsts_sel == 8'b00001000) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:24]};
	else if (ldUnit_rqsts_sel == 8'b00000100) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[23]}}, dCache_m_dat_o[23:16]};
	else if (ldUnit_rqsts_sel == 8'b00000010) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:8]};
	else if (ldUnit_rqsts_sel == 8'b00000001) ldUnit_rqsts_dato = {{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[7]}},  dCache_m_dat_o[7:0]};
	else                                      ldUnit_rqsts_dato = dCache_m_dat_o;
end end endgenerate

wire ldUnit_rqsts_full;

`ifdef PUDCACHEREGRQST
// Registered near-full, keeping the (writeidx - readidx) usage comparator off
// the iD_stalled cone. It lags the sampling edge by one cycle, so up to two
// pushes can land past the sampled usage (one already issued, one issuing);
// low means usage was at most (MAXPENDINGACK-2), hence usage never exceeds
// MAXPENDINGACK -- the fifo can fill but never overflow, which is the same
// worst-case as the combinational full_o.
wire ldUnit_rqsts_nearFull;
reg  ldUnit_rqsts_nearFull_r;
always_ff @(posedge clk_i) begin
	if (rst_i)
		ldUnit_rqsts_nearFull_r <= 1'b0;
	else
		ldUnit_rqsts_nearFull_r <= ldUnit_rqsts_nearFull;
end
assign iD_ldUnit_bsy = (ldUnit_rqsts_nearFull_r || __dCache_m_bsy);
`else
assign iD_ldUnit_bsy = (ldUnit_rqsts_full || __dCache_m_bsy);
`endif

wire ldUnit_stb = (iD_ldUnit_stb && iD_insn_valid);

wire [CLOG2GPRCNT -1 : 0] ldUnit_rqsts_rIdx;
wire                      ldUnit_rqsts_isAMO;

wire [(CLOG2MAXPENDINGACK +1) -1 : 0] ldUnit_rqsts_seq;

wire ldUnit_rqsts_empty;

wire ldUnit_memAck_ = (!ldUnit_rqsts_empty && (ldUnit_rqsts_seq == dCache_m_resp_cnt));

wire ldUnit_memAck = (dCache_m_ack_o && ldUnit_memAck_);

fifo_fwft #(
	 .WIDTH (1 + 1 + CLOG2GPRCNT + (WORDBITSZ/8) + (CLOG2MAXPENDINGACK +1))
	,.DEPTH (MAXPENDINGACK)
) ldUnit_rqsts (
	 .rst_i      (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (ldUnit_stb)
	,.data_i     ({iD_isAMO, iD_func3[2], iD_rdId, dCache_m_sel_i_, dCache_m_rqst_cnt})
`ifdef PUDCACHEREGRQST
	,.near_full_o (ldUnit_rqsts_nearFull)
`endif
	,.full_o     (ldUnit_rqsts_full)
	,.clk_pop_i  (clk_i)
	,.pop_i      (ldUnit_memAck)
	,.data_o     ({ldUnit_rqsts_isAMO, ldUnit_rqsts_zxt, ldUnit_rqsts_rIdx, ldUnit_rqsts_sel, ldUnit_rqsts_seq})
	,.empty_o    (ldUnit_rqsts_empty)
);

// Hold a completed load's response (buffered in the dCache response skidbuf) while
// the pipeline is taking the WriteBack slot, so the pipeline keeps priority; the
// load retires (ldUnit_memAck fires) the cycle the pipeline yields. Only the load
// at the head of the response stream (seq == resp_cnt) is held, so store responses
// (and loads behind a not-yet-arrived one) are not blocked.
assign dCache_m_bsy_i = (rW_pipeWrites && ldUnit_memAck_);

// Precise "a completed load result is held": same head-of-stream match as ldUnit_memAck
// but using the un-gated response-available (dCache_m_ack_avail_o), so it stays true the
// whole time the response is held by dCache_m_bsy_i (ldUnit_memAck goes low while held).
// Used to gate async traps exactly while a held result exists, instead of for the whole
// load lifetime (!ldUnit_rqsts_empty).
wire ldUnit_respHeld = (dCache_m_ack_avail_o && ldUnit_memAck_);

// Store Unit.

assign iD_stUnit_bsy = __dCache_m_bsy;

// AMO Unit.

assign amoUnit_memAck = (ldUnit_memAck && ldUnit_rqsts_isAMO);

wire iD_isLr_and_insn_valid = (iD_isLr && iD_insn_valid);

always_ff @(posedge clk_i) begin
	if (rst_i || eX_JumpOrBranch || (iD_cancelLr && iD_insn_valid)) begin
		// Per spec, cancel load reservation on taken branch,
		// jump, system, fence, loads, stores instructions.
		amoUnit_lrValid <= 1'b0;
	end else if (iD_isLr_and_insn_valid) begin
		amoUnit_lrValid <= 1'b1;
	end
end

reg [WORDBITSZ -1 : 0] amoUnit_LrAddr;

always_ff @(posedge clk_i) begin
	if (iD_isLr_and_insn_valid)
		amoUnit_LrAddr <= iD_rs1;
end

// LR/SC (and all AMO) carry no immediate (iD_addrImm == 0), so dCache_m_addr_i_ == iD_rs1
// for these. Comparing iD_rs1 directly is therefore identical to comparing dCache_m_addr_i_,
// but it keeps the 32-bit address adder (iD_rs1 + iD_addrImm) off the reservation -> SC-lock
// path -- the worst, routing-bound scoreboard/AMO/dCache cone.
assign _amoUnit_lrValid = (amoUnit_lrValid && (amoUnit_LrAddr == iD_rs1));

// Qualified by _amoUnit_lrValid, exactly as the store is: dcache.pu.sv gates the
// store-conditional memory request on _amoUnit_lrValid, so a store-conditional whose
// address is not the reserved one performs no store, and must accordingly report
// failure. Reading amoUnit_lrValid here instead would report success for it.
assign eX_StoreCondOut_i = {{(WORDBITSZ-1){1'b0}}, !_amoUnit_lrValid};

`ifdef SIMULATION_MONITOR
// iD_ldUnit_bsy's ldUnit_rqsts_full term is subsumed by __dCache_m_bsy: the fifo
// depth is MAXPENDINGACK and each entry is an outstanding request, while
// dCache_m_rqst_cnt counts at presentation (the same cycle ldUnit_stb pushes) and
// dCache_m_resp_cnt counts every ack (of which pops are a subset), so
// ldUnit_rqsts.usage_o never exceeds dCache_m_pending_acks, ie: a full fifo implies
// dCache_m_max_pending. Should dCache_m_rqst_cnt ever stop counting at presentation,
// that implication would silently break, and were the full_o term then dropped from
// iD_ldUnit_bsy, fifo_fwft's "we = (push_i && !full_o)" would drop a load request,
// losing its writeback and its ldUnit_rqsts_seq slot forever -- a wedge, not a wrong
// result. Report the occupancy invariant itself (live on every run) and the drop
// (the consequence). Each is edge-reported so a stuck condition prints once, and a
// clean run prints nothing, keeping every app's output unchanged; flushed, as the
// machine can wedge right after either report.
reg ldUnit_rqstsAbovePending_r;
reg ldUnit_rqstsDropped_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		ldUnit_rqstsAbovePending_r <= 1'b0;
		ldUnit_rqstsDropped_r <= 1'b0;
	end else begin
		ldUnit_rqstsAbovePending_r <= (ldUnit_rqsts.usage_o > dCache_m_pending_acks);
		ldUnit_rqstsDropped_r <= (ldUnit_stb && ldUnit_rqsts_full);
		if ((ldUnit_rqsts.usage_o > dCache_m_pending_acks) && !ldUnit_rqstsAbovePending_r) begin
			$display("pu%0d: error: ldUnit_rqsts usage %0d above %0d pending acks, iD_pc %h",
				PUID, ldUnit_rqsts.usage_o, dCache_m_pending_acks, iD_pc);
			$fflush();
		end
		if ((ldUnit_stb && ldUnit_rqsts_full) && !ldUnit_rqstsDropped_r) begin
			$display("pu%0d: error: ldUnit_rqsts overflow, load request dropped, iD_pc %h",
				PUID, iD_pc);
			$fflush();
		end
	end
end
// The WriteBack hold above (dCache_m_bsy_i) is only honoured by a response
// holding element; the DCACHESETCNT == 0 arm of dcache.pu.sv shipped without
// one, so a bus ack colliding with rW_pipeWrites popped ldUnit_rqsts while
// the strict-priority WriteBack mux dropped the loaded value, leaving the
// destination gprRdy locked forever -- invisible to the monitors above, as
// the pop itself is legal and the register is wrongly locked rather than
// wrongly ready. Report the hold violation (an ack presented while
// dCache_m_bsy_i holds) and the drop (the consequence). Each is
// edge-reported so a stuck condition prints once, and a clean run prints
// nothing; flushed, as the machine wedges right after either report.
reg dCacheRespHoldViolated_r;
reg ldUnit_wbDropped_r;
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		dCacheRespHoldViolated_r <= 1'b0;
		ldUnit_wbDropped_r <= 1'b0;
	end else begin
		dCacheRespHoldViolated_r <= (dCache_m_bsy_i && dCache_m_ack_o);
		ldUnit_wbDropped_r <= (ldUnit_memAck && rW_pipeWrites);
		if ((dCache_m_bsy_i && dCache_m_ack_o) && !dCacheRespHoldViolated_r) begin
			$display("pu%0d: error: load response hold violated, iD_pc %h",
				PUID, iD_pc);
			$fflush();
		end
		if ((ldUnit_memAck && rW_pipeWrites) && !ldUnit_wbDropped_r) begin
			$display("pu%0d: error: load writeback dropped, iD_pc %h",
				PUID, iD_pc);
			$fflush();
		end
	end
end
`endif
