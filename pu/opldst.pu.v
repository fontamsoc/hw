// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin

	opldstmemrqst <= 0;

end else if (!opldstdone) begin

	if (opldstmemrqst) begin

		if (dcachemasterrdy) begin
			if (opldstbyteselect == 4'b1111)
				opldstresult <= dcachemasterdato;
			else if (opldstbyteselect == 4'b0011)
				opldstresult <= {{16{1'b0}}, dcachemasterdato[15:0]};
			else if (opldstbyteselect == 4'b1100)
				opldstresult <= {{16{1'b0}}, dcachemasterdato[31:16]};
			else if (opldstbyteselect == 4'b0001)
				opldstresult <= {{24{1'b0}}, dcachemasterdato[7:0]};
			else if (opldstbyteselect == 4'b0010)
				opldstresult <= {{24{1'b0}}, dcachemasterdato[15:8]};
			else if (opldstbyteselect == 4'b0100)
				opldstresult <= {{24{1'b0}}, dcachemasterdato[23:16]};
			else if (opldstbyteselect == 4'b1000)
				opldstresult <= {{24{1'b0}}, dcachemasterdato[31:24]};

			opldstdone_a <= ~opldstdone_b;

			opldstmemrqst <= 0;
		end

	end else begin

		if (miscrdyandsequencerreadyandgprrdy12 && isopldst && dtlb_and_dcache_rdy) begin

			if (opldstfault) begin
				opldstfaulted <= {{dtlbmiss ? 2'b11 : {dtlbnotreadable, dtlbnotwritable}}, alignfault};
			end else if (!instrbufferdataout0[2]) begin
				opldstmemrqst <= 1;
			end

			opldstgpr <= gprindex1;

			opldstbyteselect <= dcachemastersel;

		end else
			opldstfaulted <= 0;
	end
end
