// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin
	// Reset logic.

	opldstmemrqst <= 0;
	opldstdone <= 0;

end else if (gprctrlstate == GPRCTRLSTATEOPLDST) begin

	opldstdone <= 0;

end else begin

	if (opldstmemrqst) begin

		if (dcachemasterrdy) begin

			opldstresult <= dcachemasterdato_result;

			// Signal that the value of the register opldstresult can be stored in the gpr.
			opldstdone <= 1;

			opldstmemrqst <= 0;
		end

	end else if (miscrdyandsequencerreadyandgprrdy12 && dtlb_rdy && isopldst && dcachemasterrdy && !opldstfault && !instrbufdato0[2]
		`ifdef PUMMU
		`ifdef PUHPTW
		&& opldstfault__hptwddone
		`endif
		`endif
		) begin

		opldstmemrqst <= 1;

		opldstgpr <= gpridx1;
	end
end
