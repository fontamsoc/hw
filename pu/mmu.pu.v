// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @ (posedge clk_i)
	itlbwritten <= (rst_i || itlbwe);

always @ (posedge clk_i) begin
	if (itlbreadenable)
		itlbsetprev <= itlbset;
end

always @ (posedge clk_i)
	dtlbwritten <= (rst_i || dtlbwe);

always @ (posedge clk_i) begin
	if (dtlbreadenable)
		dtlbsetprev <= dtlbset;
end

always @ (posedge clk_i)
	isopgettlb_or_isopclrtlb_found_sampled <= isopgettlb_or_isopclrtlb_found;
