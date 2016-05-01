// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe
/*
if (miscrdyandsequencerreadyandgprrdy12 && isopst && dtlb_rdy && (dcachemasterrdy || opstfault)
	`ifdef PUMMU
	`ifdef PUHPTW
	&& opstfault__hptwddone
	`endif
	`endif
	) begin
	if (!opstfault) begin
	end
end
*/
