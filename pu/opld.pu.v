// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin
	// Reset logic.

	opldmemrqst <= 0;
	oplddone <= 0;

end else if (gprctrlstate == GPRCTRLSTATEOPLD) begin

	oplddone <= 0;

end else begin

	if (opldmemrqst) begin

		if (dcachemasterrdy) begin

			opldresult <= dcachemasterdato_result;

			// Signal that the value of the register opldresult can be stored in the gpr.
			oplddone <= 1;

			opldmemrqst <= 0;
		end

	end else if (miscrdyandsequencerreadyandgprrdy12 && dtlb_rdy && isopld && dcachemasterrdy && !opldfault
		`ifdef PUMMU
		`ifdef PUHPTW
		&& opldfault__hptwddone
		`endif
		`endif
		) begin

		opldmemrqst <= 1;

		opldgpr <= gpridx1;
	end
end
