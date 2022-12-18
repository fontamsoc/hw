// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction buffer allows for indexing 16bits at a time,
// the ARCHBITSZ bits data fetched from memory.
// The size of the instruction buffer determines the amount
// of prefetching done.

// The instruction cache allows the pu to maintain its peak execution
// speed (1 instruction every clock cycle) for as long as possible,
// since it will stall less waiting on memory accesses to complete.
// The instruction cache is set associative.

if (doicacherst) begin
	icacheactive <= 0;
	icacherstidx <= {CLOG2ICACHESETCOUNT{1'b1}};
end else if (icacheoff) begin
	if (icacherstidx)
		icacherstidx <= icacherstidx - 1'b1;
	else
		icacheactive <= 1;
end

// Logic that set the instruction buffer.
if (instrbufwe) begin
	instrbuf[instrbufwriteidx[CLOG2INSTRBUFFERSIZE-1 : 0]] <= instrbufi;
end

// Logic that control the instruction fetching.
if (rst_i) begin
	// Reset logic.

	icachecheck <= 0;

	instrfetchmemrqst <= 0;

end else if ((instrfetchmemrqst || instrfetchmemrqstinprogress) && !instrbufrst) begin
	// Note that instrfetchmemrqstdone is 1 only for
	// 1 clock cycle and will always be caught here.
	if (instrfetchmemrqstdone) begin
		// I increment instrbufwriteidx to the index
		// within the instruction buffer where the next data
		// to fetch is to be stored.
		instrbufwriteidx <= instrbufwriteidx + 1'b1;
	end

	if (instrfetchmemrqstinprogress)
		instrfetchmemrqst <= 0;

end else if (icachecheck && !instrbufrst) begin
	// I check whether there is a valid cached data.
	if (icachehit) begin
		// I increment instrbufwriteidx to the index
		// within the instruction buffer where the next data
		// to fetch is to be stored.
		instrbufwriteidx <= instrbufwriteidx + 1'b1;

	end else begin
		// I get here, if a hit could not be found in the cache;
		// I proceed to fetching data.
		instrfetchmemrqst <= 1;
	end

	icachecheck <= 0;

end else if (instrbufrst || !instrfetchfaulted) begin
	// Empty the instruction buffer if instrbufrst is 1.
	// Note that instrbufrst is checked only within this state,
	// and the instruction fetching is not interrupted once started;
	// in fact there will be no loss because the fetched data will
	// be cached for later use.
	// Note that instrbufrst gets set whenever a branching occur,
	// and the penalty for it, is at least 2 clock cycles during
	// which the sequencer stalls.
	if (instrbufrst)
		instrbufwriteidx <= ip[(CLOG2INSTRBUFFERSIZE+((CLOG2ARCHBITSZBY8-1)+CLOG2XARCHBITSZBY8DIFF)) : (CLOG2ARCHBITSZBY8-1)+CLOG2XARCHBITSZBY8DIFF];

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

		if (itlbfault && !instrbufrst_posedge) begin
			// Setting instrfetchfaulted will stall instrfetch until the sequencer clears it.
			instrfetchfaulted_a <= ~instrfetchfaulted_b;

			instrfetchfaultaddr <= {instrfetchnextaddr, {CLOG2ARCHBITSZBY8{1'b0}}};

			// Set icachecheck to 0 in case it was still 1.
			icachecheck <= 0;

			// Set instrfetchmemrqst to 0 in case it was still 1.
			instrfetchmemrqst <= 0;

		end else if (not_itlben_or_not_instrbufrst_posedge) begin
			// instrfetchaddr and instrfetchppn must be updated
			// in the same clockcycle that icachecheck or instrfetchmemrqst
			// get set to 1, otherwise icachedato can be incorrect as
			// it is computed from instrfetchnext* signals.
			instrfetchaddr <= instrfetchnextaddr;
			instrfetchppn <= instrfetchnextppn;

			if (icacheactive) begin
				// Proceed to checking the instruction cache.
				icachecheck <= 1;
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
		&& not_itlben_or_not_instrbufrst_posedge)
		instrbufrst_b <= instrbufrst_a; // Clearing instrbufrst must not depend on inhalt, otherwise the sequencer will lock.

end else begin
	// Set instrfetchmemrqst to 0 in case it was still 1.
	instrfetchmemrqst <= 0;

	// Set icachecheck to 0 in case it was still 1.
	icachecheck <= 0;
end

instrbufrst_sampled <= instrbufrst;
