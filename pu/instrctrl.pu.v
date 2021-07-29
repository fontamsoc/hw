// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (doicacherst) begin
	icacheactive <= 0;
	icacherstidx <= {CLOG2ICACHESETCOUNT{1'b1}};
end else if (icacheoff) begin
	if (icacherstidx)
		icacherstidx <= icacherstidx - 1'b1;
	else
		icacheactive <= 1;
end

if ((instrfetchmemrqstdone || (icachecheck && icachehit)) && !instrbufferrst) begin
	instrbuffer[instrbufferwriteindex[CLOG2INSTRBUFFERSIZE-1 : 0]] <=
		(instrfetchmemrqstdone ? pi1_data_i : icachedato);
end

if (rst_i) begin

	icachecheck <= 0;

	instrfetchmemrqst <= 0;

end else if ((instrfetchmemrqst || instrfetchmemrqstinprogress) && !instrbufferrst) begin

	if (instrfetchmemrqstdone) begin
		instrbufferwriteindex <= instrbufferwriteindex + 1'b1;
	end

	if (instrfetchmemrqstinprogress)
		instrfetchmemrqst <= 0;

end else if (icachecheck && !instrbufferrst) begin

	if (icachehit) begin
		instrbufferwriteindex <= instrbufferwriteindex + 1'b1;
	end else begin
		instrfetchmemrqst <= 1;
	end

	icachecheck <= 0;

end else if (instrbufferrst || !instrfetchfaulted) begin

	if (instrbufferrst)
		instrbufferwriteindex <= ip[CLOG2INSTRBUFFERSIZE +1 : 1];

	if (!inhalt && itlb_and_instrbuffer_rdy
		`ifdef PUMMU
		`ifdef PUHPTW
		&& itlbfault__hptwidone
		`endif
		`endif
		) begin

		if (itlbfault && !instrbufferrst_posedge) begin

			instrfetchfaulted_a <= ~instrfetchfaulted_b;

			instrfetchfaultaddr <= {instrfetchnextaddr, {CLOG2ARCHBITSZBY8{1'b0}}};

			icachecheck <= 0;

			instrfetchmemrqst <= 0;

		end else if (not_itlben_or_not_instrbufferrst_posedge) begin

			instrfetchaddr <= instrfetchnextaddr;
			instrfetchppn <= instrfetchnextppn;

			if (icacheactive) begin
				icachecheck <= 1;
				instrfetchmemrqst <= 0;
			end else begin
				instrfetchmemrqst <= 1;
				icachecheck <= 0;
			end

		end else begin

			instrfetchmemrqst <= 0;

			icachecheck <= 0;
		end

	end else begin

		instrfetchmemrqst <= 0;

		icachecheck <= 0;
	end

	if (itlb_and_instrbuffer_rdy
		`ifdef PUMMU
		`ifdef PUHPTW
		&& itlbfault__hptwidone
		`endif
		`endif
		&& not_itlben_or_not_instrbufferrst_posedge)
		instrbufferrst_b <= instrbufferrst_a; // Clearing instrbufferrst must not depend on inhalt, otherwise the sequencer will lock.

end else begin

	instrfetchmemrqst <= 0;

	icachecheck <= 0;
end

instrbufferrst_sampled <= instrbufferrst;

instrbuffernotempty_sampled <= instrbuffernotempty;
