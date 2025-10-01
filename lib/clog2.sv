// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Function which compute the ceiling of log2().
// When the argument is 0 or 1, the return value is 1.
function automatic integer clog2;
	input integer val;
	begin
		if (val > 1) begin
			val = val - 1;
			for (clog2 = 0; val > 0; clog2 = clog2 + 1)
				val = val >> 1;
		end else clog2 = 1;
	end
endfunction
