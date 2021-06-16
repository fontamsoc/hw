// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (miscrdyandsequencerreadyandgprrdy12 && isopst && dtlb_and_dcache_rdy) begin
	if (opstfault) begin
		opstfaulted <= {1'b1, alignfault};
	end
end else
	opstfaulted <= 0;
