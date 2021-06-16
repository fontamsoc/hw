// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (miscrdyandsequencerreadyandgprrdy12) begin

	if (opldrdy) begin

		dcachemasterop = MEMREADOP;

		dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};

		dcachemasterdati = 0;

		if (instrbufferdataout0[1])
			dcachemastersel = 4'b1111;
		else if (instrbufferdataout0[0]) begin
			if (gprdata2[1])
				dcachemastersel = 4'b1100;
			else
				dcachemastersel = 4'b0011;
		end else begin
			if (gprdata2[1:0] == 0)
				dcachemastersel = 4'b0001;
			else if (gprdata2[1:0] == 1)
				dcachemastersel = 4'b0010;
			else if (gprdata2[1:0] == 2)
				dcachemastersel = 4'b0100;
			else
				dcachemastersel = 4'b1000;
		end

	end else if (opstrdy) begin

		dcachemasterop = MEMWRITEOP;

		dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};

		if (instrbufferdataout0[1]) begin
			dcachemastersel = 4'b1111;
			dcachemasterdati = gprdata1;
		end else if (instrbufferdataout0[0]) begin
			if (gprdata2[1]) begin
				dcachemastersel = 4'b1100;
				dcachemasterdati = {gprdata1[15:0], {16{1'b0}}};
			end else begin
				dcachemastersel = 4'b0011;
				dcachemasterdati = {{16{1'b0}}, gprdata1[15:0]};
			end
		end else begin
			if (gprdata2[1:0] == 0) begin
				dcachemastersel = 4'b0001;
				dcachemasterdati = {{24{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[1:0] == 1) begin
				dcachemastersel = 4'b0010;
				dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[1:0] == 2) begin
				dcachemastersel = 4'b0100;
				dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else begin
				dcachemastersel = 4'b1000;
				dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
			end
		end

	end else if (opldstrdy) begin

		dcachemasterop = MEMREADWRITEOP;

		dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};

		if (instrbufferdataout0[1]) begin
			dcachemastersel = 4'b1111;
			dcachemasterdati = gprdata1;
		end else if (instrbufferdataout0[0]) begin
			if (gprdata2[1]) begin
				dcachemastersel = 4'b1100;
				dcachemasterdati = {gprdata1[15:0], {16{1'b0}}};
			end else begin
				dcachemastersel = 4'b0011;
				dcachemasterdati = {{16{1'b0}}, gprdata1[15:0]};
			end
		end else begin
			if (gprdata2[1:0] == 0) begin
				dcachemastersel = 4'b0001;
				dcachemasterdati = {{24{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[1:0] == 1) begin
				dcachemastersel = 4'b0010;
				dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[1:0] == 2) begin
				dcachemastersel = 4'b0100;
				dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else begin
				dcachemastersel = 4'b1000;
				dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
			end
		end

	end else begin

		dcachemasterop = MEMNOOP;
		dcachemasteraddr = 0;
		dcachemasterdati = 0;
		dcachemastersel = 0;
	end

end else begin

	dcachemasterop = MEMNOOP;
	dcachemasteraddr = 0;
	dcachemasterdati = 0;
	dcachemastersel = 0;
end
