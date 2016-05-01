// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Function which compute the ceiling of log2().
// When the argument is 0 or 1, the value returned is 1.
function automatic integer clog2;

	input integer value;
	integer retval;

	begin
		if (value > 1) begin

			value = value - 1;

			for (retval = 0; value > 0; retval = retval + 1)
				value = value >> 1;

		end else retval = 1;

		clog2 = retval; // return result.
	end

endfunction
