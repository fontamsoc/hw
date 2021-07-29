// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (miscrdyandsequencerreadyandgprrdy12) begin

	if (isopld && opldrdy_
		`ifndef PUHPTW
		&& !opldfault
		`endif
		) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opldfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				dcachemasterop = MEMNOOP;
				dcachemasteraddr = 0;
				dcachemasterdati = 0;
				dcachemastersel = 0;
			end

		end else begin

			hptwmemstate = HPTWMEMSTATENONE;
		`endif
		`endif
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
		`ifdef PUMMU
		`ifdef PUHPTW
		end
		`endif
		`endif

	end else if (isopst && opstrdy_
		`ifndef PUHPTW
		&& !opstfault
		`endif
		) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opstfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				dcachemasterop = MEMNOOP;
				dcachemasteraddr = 0;
				dcachemasterdati = 0;
				dcachemastersel = 0;
			end

		end else begin

			hptwmemstate = HPTWMEMSTATENONE;
		`endif
		`endif
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
		`ifdef PUMMU
		`ifdef PUHPTW
		end
		`endif
		`endif

	end else if (isopldst && opldstrdy_
		`ifndef PUHPTW
		&& !opldstfault && !instrbufferdataout0[2]
		`endif
		) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opldstfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				dcachemasterop = MEMNOOP;
				dcachemasteraddr = 0;
				dcachemasterdati = 0;
				dcachemastersel = 0;
			end

		end else if (!instrbufferdataout0[2]) begin

			hptwmemstate = HPTWMEMSTATENONE;
		`endif
		`endif
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
		`ifdef PUMMU
		`ifdef PUHPTW
		end else begin
			hptwmemstate = HPTWMEMSTATENONE;
			dcachemasterop = MEMNOOP;
			dcachemasteraddr = 0;
			dcachemasterdati = 0;
			dcachemastersel = 0;
		end
		`endif
		`endif

	end else begin
		`ifdef PUMMU
		`ifdef PUHPTW
		hptwmemstate = HPTWMEMSTATENONE;
		`endif
		`endif
		dcachemasterop = MEMNOOP;
		dcachemasteraddr = 0;
		dcachemasterdati = 0;
		dcachemastersel = 0;
	end
`ifdef PUMMU
`ifdef PUHPTW
end else if (!(rst_i) &&
	!((instrfetchmemrqst || instrfetchmemrqstinprogress) && !instrbufferrst) &&
	!(icachecheck && !instrbufferrst) &&
	((instrbufferrst || !instrfetchfaulted) &&
	(!inhalt && itlb_and_instrbuffer_rdy && !itlbfault__hptwidone))) begin

	hptwmemstate = HPTWMEMSTATEINSTR;

	if (hptwistate_eq_HPTWSTATEPGD0) begin
		dcachemasterop = MEMREADOP;
		dcachemasteraddr = hptwpgd_plus_hptwipgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
		dcachemasterdati = 0;
		dcachemastersel = {(ARCHBITSZ/8){1'b1}};
	end else if (hptwistate_eq_HPTWSTATEPTE0) begin
		dcachemasterop = MEMREADOP;
		dcachemasteraddr = hptwipte_plus_hptwipteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
		dcachemasterdati = 0;
		dcachemastersel = {(ARCHBITSZ/8){1'b1}};
	end else begin
		dcachemasterop = MEMNOOP;
		dcachemasteraddr = 0;
		dcachemasterdati = 0;
		dcachemastersel = 0;
	end
`endif
`endif
end else begin
	`ifdef PUMMU
	`ifdef PUHPTW
	hptwmemstate = HPTWMEMSTATENONE;
	`endif
	`endif
	dcachemasterop = MEMNOOP;
	dcachemasteraddr = 0;
	dcachemasterdati = 0;
	dcachemastersel = 0;
end
