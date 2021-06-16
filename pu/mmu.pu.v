// Copyright (c) William Fonkou Tambe
// All rights reserved.

itlbwritten <= (rst_i || itlbwriteenable);

if (itlbreadenable)
	itlbsetprev <= itlbset;

dtlbwritten <= (rst_i || dtlbwriteenable);

if (dtlbreadenable)
	dtlbsetprev <= dtlbset;

isopgettlb_or_isopclrtlb_found_sampled <= isopgettlb_or_isopclrtlb_found;
