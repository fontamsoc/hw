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
			// Apropriately set opldstresult depending on opldstbyteselect.
			if (opldstbyteselect == 'b11)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[15:0]};
			else if (opldstbyteselect == 'b01)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[7:0]};
			else if (opldstbyteselect == 'b10)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[15:8]};
			else if (opldstbyteselect == 'b1111)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[31:0]};
			else if (opldstbyteselect == 'b1100)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[31:16]};
			else if (opldstbyteselect == 'b0100)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[23:16]};
			else if (opldstbyteselect == 'b1000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[31:24]};
			else if (opldstbyteselect == 'b11111111)
				opldstresult <= dcachemasterdato;
			else if (opldstbyteselect == 'b11110000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[63:32]};
			else if (opldstbyteselect == 'b00110000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[47:32]};
			else if (opldstbyteselect == 'b11000000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[63:48]};
			else if (opldstbyteselect == 'b00010000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[39:32]};
			else if (opldstbyteselect == 'b00100000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[47:40]};
			else if (opldstbyteselect == 'b01000000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[55:48]};
			else if (opldstbyteselect == 'b10000000)
				opldstresult <= {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[63:56]};

			// Signal that the value of the register opldstresult can be stored in the gpr.
			opldstdone <= 1;

			opldstmemrqst <= 0;
		end

	end else begin

		if (miscrdyandsequencerreadyandgprrdy12 && isopldst && dtlb_rdy && (dcachemasterrdy || opldstfault)
			`ifdef PUMMU
			`ifdef PUHPTW
			&& opldstfault__hptwddone
			`endif
			`endif
			) begin

			if (!opldstfault && !instrbufdato0[2])
				opldstmemrqst <= 1;

			opldstgpr <= gpridx1;

			opldstbyteselect <= dcachemastersel;
		end
	end
end
