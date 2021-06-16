// Copyright (c) William Fonkou Tambe
// All rights reserved.

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
