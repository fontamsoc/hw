// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction fetch request has the least priority so that
// load and store instructions can be completed as soon as possible,
// and so that the next instruction in the buffer can be sequenced
// as soon as possible.
if (rst_i) begin

	instrfetchmemrqstinprogress <= 0;

end else if (dcacheslaveop != MEMNOOP) begin

	if (pi1_rdy_i || instrbufferrst)
		instrfetchmemrqstinprogress <= 0;

end else if (instrfetchmemaccesspending) begin

	if (pi1_rdy_i)
		instrfetchmemrqstinprogress <= 1;
	else if (instrbufferrst)
		instrfetchmemrqstinprogress <= 0;

end else begin

	if (pi1_rdy_i || instrbufferrst)
		instrfetchmemrqstinprogress <= 0;
end
