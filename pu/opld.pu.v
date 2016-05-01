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
			// Apropriately set opldresult depending on opldbyteselect.
			if (opldbyteselect == 'b11)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[15:0]};
			else if (opldbyteselect == 'b01)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[7:0]};
			else if (opldbyteselect == 'b10)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[15:8]};
			else if (opldbyteselect == 'b1111)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[31:0]};
			else if (opldbyteselect == 'b1100)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[31:16]};
			else if (opldbyteselect == 'b0100)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[23:16]};
			else if (opldbyteselect == 'b1000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[31:24]};
			else if (opldbyteselect == 'b11111111)
				opldresult <= dcachemasterdato;
			else if (opldbyteselect == 'b11110000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[63:32]};
			else if (opldbyteselect == 'b00110000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[47:32]};
			else if (opldbyteselect == 'b11000000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[63:48]};
			else if (opldbyteselect == 'b00010000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[39:32]};
			else if (opldbyteselect == 'b00100000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[47:40]};
			else if (opldbyteselect == 'b01000000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[55:48]};
			else if (opldbyteselect == 'b10000000)
				opldresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[63:56]};

			// Signal that the value of the register opldresult can be stored in the gpr.
			oplddone <= 1;

			opldmemrqst <= 0;
		end

	end else begin

		if (miscrdyandsequencerreadyandgprrdy12 && isopld && dtlb_rdy && (dcachemasterrdy || opldfault)
			`ifdef PUMMU
			`ifdef PUHPTW
			&& opldfault__hptwddone
			`endif
			`endif
			) begin

			if (!opldfault)
				opldmemrqst <= 1;

			opldgpr <= gprindex1;

			opldbyteselect <= dcachemastersel;
		end
	end
end
