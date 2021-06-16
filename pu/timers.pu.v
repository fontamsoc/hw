// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i)
	clkcyclecnt <= 0;
else
	clkcyclecnt <= clkcyclecnt + 1'b1;

if (miscrdyandsequencerreadyandgprrdy1 && isopsettimer && (inkernelmode || isflagsettimer))
	timer <= gprdata1;
else if (!(&timer) && timer)
	timer <= timer - 1'b1;
