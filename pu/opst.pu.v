// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (miscrdyandsequencerreadyandgprrdy12 && isopst && dtlb_rdy && (dcachemasterrdy || opstfault)
	`ifdef PUMMU
	`ifdef PUHPTW
	&& opstfault__hptwddone
	`endif
	`endif
	) begin
	if (opstfault) begin
		opstfaulted <= {1'b1, alignfault};
	end
end else
	opstfaulted <= 0;
