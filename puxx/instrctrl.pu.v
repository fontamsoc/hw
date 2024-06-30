// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction buffer allows for indexing 16bits at a time,
// the ARCHBITSZ bits data fetched from memory.
// The size of the instruction buffer determines the amount
// of prefetching done.

always @ (posedge clk_i) begin
	// Logic that set the instruction buffer.
	if (instrbufwe) begin
		instrbuf[instrbufwriteidx[CLOG2INSTRBUFFERSIZE-1 : 0]] <= instrbufi;
	end
end

always @ (posedge clk_i) begin
	// Logic that control the instruction fetching.
	if (rst_i) begin
		// Reset logic.

		icachecheck <= 0;

		instrfetchmemrqst <= 0;

	end else if (instrfetchmemrqst && !instrbufrst) begin

		if (!dcache_s_stb_o && instrfetchmemaccesspending && !_wb_bsy_i)
			instrfetchmemrqst <= 0;

	end else if (icachecheck && !instrbufrst) begin
		`ifdef PUREGICACHEHIT
		if (icachebsy) // 1 clock cycle needed to compute cachehit.
			icachebsy <= 0;
		else
		`endif
		begin
			// I check whether there is a valid cached data.
			if (icachehit) begin

				if (instrbufnotfull) begin
					// I increment instrbufwriteidx to the index
					// within the instruction buffer where the next data
					// to fetch is to be stored.
					instrbufwriteidx <= instrbufwriteidx + 1'b1;

					icachecheck <= 0;
				end

			end else begin
				// I get here, if a hit could not be found in the cache;
				// I proceed to fetching data.
				instrfetchmemrqst <= 1;

				icachecheck <= 0;
			end
		end

	end else if (instrbufrst || !instrfetchfaulted) begin
		// Empty the instruction buffer if instrbufrst is 1.
		// Note that instrbufrst gets set whenever a branching occur,
		// and the penalty for it, is at least 2 clock cycles during
		// which the sequencer stalls.
		if (instrbufrst)
			instrbufwriteidx <= ip[(CLOG2INSTRBUFFERSIZE+((CLOG2ARCHBITSZBY8-1)+CLOG2XARCHBITSZBY8DIFF)) : (CLOG2ARCHBITSZBY8-1)+CLOG2XARCHBITSZBY8DIFF];
		else if (instrfetchmemrqstdone_) begin // Note that instrfetchmemrqstdone is 1 for 1 clock cycle.
			// I increment instrbufwriteidx to the index
			// within the instruction buffer where the next data
			// to fetch is to be stored.
			instrbufwriteidx <= instrbufwriteidx + 1'b1;
		end

		// Instructions get fetched only if the pu is not halted.
		// When the pu resumes from being halted (due to an interrupt),
		// instrbufrst get set to 1; it would a waist to fill up
		// the instruction buffer, to reset it right afterward.
		// Checking inhalt is necessary to use hptw only when not halted.
		if (!inhalt && itlb_and_instrbuf_rdy
			`ifdef PUMMU
			`ifdef PUHPTW
			&& itlbfault__hptwidone
			`endif
			`endif
			) begin

			if (itlbfault && itlbrdy && !inkernelmode_kmodepaging) begin
				// Setting instrfetchfaulted will stall instrfetch until the sequencer clears it.
				instrfetchfaulted_a <= ~instrfetchfaulted_b;

				instrfetchfaultaddr <= {instrfetchnextaddr, {CLOG2ARCHBITSZBY8{1'b0}}};

				// Set icachecheck to 0 in case it was still 1.
				icachecheck <= 0;

				// Set instrfetchmemrqst to 0 in case it was still 1.
				instrfetchmemrqst <= 0;

			end else if (itlbrdy &&
				(instrbufrst || instrfetchmemrqstdone_ || !instrfetchmemrqstseqvalid)) begin
				// instrfetchaddr and instrfetchppn must be updated
				// in the same clockcycle that icachecheck or instrfetchmemrqst
				// get set to 1, otherwise icachedato can be incorrect as
				// it is computed from instrfetchnext* signals.
				instrfetchaddr <= instrfetchnextaddr;
				instrfetchppn <= instrfetchnextppn;

				if (icacheactive) begin
					// Proceed to checking the instruction cache.
					icachecheck <= 1;
					`ifdef PUREGICACHEHIT
					icachebsy <= 1;
					`endif
					// Set instrfetchmemrqst to 0 in case it was still 1.
					instrfetchmemrqst <= 0;

				end else begin

					instrfetchmemrqst <= 1;
					// Set icachecheck to 0 in case it was still 1.
					icachecheck <= 0;
				end

			end else begin
				// Set instrfetchmemrqst to 0 in case it was still 1.
				instrfetchmemrqst <= 0;

				// Set icachecheck to 0 in case it was still 1.
				icachecheck <= 0;
			end

		end else begin
			// Set instrfetchmemrqst to 0 in case it was still 1.
			instrfetchmemrqst <= 0;

			// Set icachecheck to 0 in case it was still 1.
			icachecheck <= 0;
		end

		if (itlb_and_instrbuf_rdy
			`ifdef PUMMU
			`ifdef PUHPTW
			&& itlbfault__hptwidone
			`endif
			`endif
			&& itlbrdy && instrbufrst)
			instrbufrst_b <= instrbufrst_a; // Clearing instrbufrst must not depend on inhalt, otherwise the sequencer will lock.

	end else begin
		// Set instrfetchmemrqst to 0 in case it was still 1.
		instrfetchmemrqst <= 0;

		// Set icachecheck to 0 in case it was still 1.
		icachecheck <= 0;
	end
end

always @ (posedge clk_i)
	instrbufrst_sampled <= instrbufrst;
