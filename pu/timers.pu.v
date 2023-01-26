// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @ (posedge clk_i) begin
	if (rst_i)
		clkcyclecnt <= 0;
	else
		clkcyclecnt <= clkcyclecnt + 1'b1;
end

always @ (posedge clk_i) begin
	if (miscrdyandsequencerreadyandgprrdy1 && isopsettimer && (inkernelmode || isflagsettimer))
		timer <= gprdata1;
	else if (!(&timer) && timer)
		timer <= timer - 1'b1;
end
