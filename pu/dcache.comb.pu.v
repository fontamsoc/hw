// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

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

			if (ARCHBITSZ == 16) begin
				if (instrbufferdataout0[0])
					dcachemastersel = 'b11;
				else begin
					if (gprdata2[0] == 0)
						dcachemastersel = 'b01;
					else
						dcachemastersel = 'b10;
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufferdataout0[1])
					dcachemastersel = 'b1111;
				else if (instrbufferdataout0[0]) begin
					if (gprdata2[1])
						dcachemastersel = 'b1100;
					else
						dcachemastersel = 'b0011;
				end else begin
					if (gprdata2[1:0] == 0)
						dcachemastersel = 'b0001;
					else if (gprdata2[1:0] == 1)
						dcachemastersel = 'b0010;
					else if (gprdata2[1:0] == 2)
						dcachemastersel = 'b0100;
					else
						dcachemastersel = 'b1000;
				end
			end else begin
				if (&instrbufferdataout0[1:0])
					dcachemastersel = 'b11111111;
				else if (instrbufferdataout0[1]) begin
					if (gprdata2[2])
						dcachemastersel = 'b11110000;
					else
						dcachemastersel = 'b00001111;
				end else if (instrbufferdataout0[0]) begin
					if (gprdata2[2:1] == 0)
						dcachemastersel = 'b00000011;
					else if (gprdata2[2:1] == 1)
						dcachemastersel = 'b00001100;
					else if (gprdata2[2:1] == 2)
						dcachemastersel = 'b00110000;
					else
						dcachemastersel = 'b11000000;
				end else begin
					if (gprdata2[2:0] == 0)
						dcachemastersel = 'b00000001;
					else if (gprdata2[2:0] == 1)
						dcachemastersel = 'b00000010;
					else if (gprdata2[2:0] == 2)
						dcachemastersel = 'b00000100;
					else if (gprdata2[2:0] == 3)
						dcachemastersel = 'b00001000;
					else if (gprdata2[2:0] == 4)
						dcachemastersel = 'b00010000;
					else if (gprdata2[2:0] == 5)
						dcachemastersel = 'b00100000;
					else if (gprdata2[2:0] == 6)
						dcachemastersel = 'b01000000;
					else
						dcachemastersel = 'b10000000;
				end
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

			if (ARCHBITSZ == 16) begin
				if (instrbufferdataout0[0]) begin
					dcachemastersel = 'b11;
					dcachemasterdati = gprdata1;
				end else begin
					if (gprdata2[0] == 0) begin
						dcachemastersel = 'b01;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0]};
					end else begin
						dcachemastersel = 'b10;
						dcachemasterdati = {gprdata1[7:0], {8{1'b0}}};
					end
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufferdataout0[1]) begin
					dcachemastersel = 'b1111;
					dcachemasterdati = gprdata1;
				end else if (instrbufferdataout0[0]) begin
					if (gprdata2[1]) begin
						dcachemastersel = 'b1100;
						dcachemasterdati = {gprdata1[15:0], {16{1'b0}}};
					end else begin
						dcachemastersel = 'b0011;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0]};
					end
				end else begin
					if (gprdata2[1:0] == 0) begin
						dcachemastersel = 'b0001;
						dcachemasterdati = {{24{1'b0}}, gprdata1[7:0]};
					end else if (gprdata2[1:0] == 1) begin
						dcachemastersel = 'b0010;
						dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
					end else if (gprdata2[1:0] == 2) begin
						dcachemastersel = 'b0100;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
					end else begin
						dcachemastersel = 'b1000;
						dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
					end
				end
			end else begin
				if (&instrbufferdataout0[1:0]) begin
					dcachemastersel = 'b11111111;
					dcachemasterdati = gprdata1;
				end else if (instrbufferdataout0[1]) begin
					if (gprdata2[2]) begin
						dcachemastersel = 'b11110000;
						dcachemasterdati = {gprdata1[31:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b00001111;
						dcachemasterdati = {{32{1'b0}}, gprdata1[31:0]};
					end
				end else if (instrbufferdataout0[0]) begin
					if (gprdata2[2:1] == 0) begin
						dcachemastersel = 'b00000011;
						dcachemasterdati = {{48{1'b0}}, gprdata1[15:0]};
					end else if (gprdata2[2:1] == 1) begin
						dcachemastersel = 'b00001100;
						dcachemasterdati = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
					end else if (gprdata2[2:1] == 2) begin
						dcachemastersel = 'b00110000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b11000000;
						dcachemasterdati = {gprdata1[15:0], {48{1'b0}}};
					end
				end else begin
					if (gprdata2[2:0] == 0) begin
						dcachemastersel = 'b00000001;
						dcachemasterdati = {{56{1'b0}}, gprdata1[7:0]};
					end else if (gprdata2[2:0] == 1) begin
						dcachemastersel = 'b00000010;
						dcachemasterdati = {{48{1'b0}}, gprdata1[7:0], {8{1'b0}}};
					end else if (gprdata2[2:0] == 2) begin
						dcachemastersel = 'b00000100;
						dcachemasterdati = {{40{1'b0}}, gprdata1[7:0], {16{1'b0}}};
					end else if (gprdata2[2:0] == 3) begin
						dcachemastersel = 'b00001000;
						dcachemasterdati = {{32{1'b0}}, gprdata1[7:0], {24{1'b0}}};
					end else if (gprdata2[2:0] == 4) begin
						dcachemastersel = 'b00010000;
						dcachemasterdati = {{24{1'b0}}, gprdata1[7:0], {32{1'b0}}};
					end else if (gprdata2[2:0] == 5) begin
						dcachemastersel = 'b00100000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {40{1'b0}}};
					end else if (gprdata2[2:0] == 6) begin
						dcachemastersel = 'b01000000;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {48{1'b0}}};
					end else begin
						dcachemastersel = 'b10000000;
						dcachemasterdati = {gprdata1[7:0], {56{1'b0}}};
					end
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

			if (ARCHBITSZ == 16) begin
				if (instrbufferdataout0[0]) begin
					dcachemastersel = 'b11;
					dcachemasterdati = gprdata1;
				end else begin
					if (gprdata2[0] == 0) begin
						dcachemastersel = 'b01;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0]};
					end else begin
						dcachemastersel = 'b10;
						dcachemasterdati = {gprdata1[7:0], {8{1'b0}}};
					end
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufferdataout0[1]) begin
					dcachemastersel = 'b1111;
					dcachemasterdati = gprdata1;
				end else if (instrbufferdataout0[0]) begin
					if (gprdata2[1]) begin
						dcachemastersel = 'b1100;
						dcachemasterdati = {gprdata1[15:0], {16{1'b0}}};
					end else begin
						dcachemastersel = 'b0011;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0]};
					end
				end else begin
					if (gprdata2[1:0] == 0) begin
						dcachemastersel = 'b0001;
						dcachemasterdati = {{24{1'b0}}, gprdata1[7:0]};
					end else if (gprdata2[1:0] == 1) begin
						dcachemastersel = 'b0010;
						dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
					end else if (gprdata2[1:0] == 2) begin
						dcachemastersel = 'b0100;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
					end else begin
						dcachemastersel = 'b1000;
						dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
					end
				end
			end else begin
				if (&instrbufferdataout0[1:0]) begin
					dcachemastersel = 'b11111111;
					dcachemasterdati = gprdata1;
				end else if (instrbufferdataout0[1]) begin
					if (gprdata2[2]) begin
						dcachemastersel = 'b11110000;
						dcachemasterdati = {gprdata1[31:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b00001111;
						dcachemasterdati = {{32{1'b0}}, gprdata1[31:0]};
					end
				end else if (instrbufferdataout0[0]) begin
					if (gprdata2[2:1] == 0) begin
						dcachemastersel = 'b00000011;
						dcachemasterdati = {{48{1'b0}}, gprdata1[15:0]};
					end else if (gprdata2[2:1] == 1) begin
						dcachemastersel = 'b00001100;
						dcachemasterdati = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
					end else if (gprdata2[2:1] == 2) begin
						dcachemastersel = 'b00110000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b11000000;
						dcachemasterdati = {gprdata1[15:0], {48{1'b0}}};
					end
				end else begin
					if (gprdata2[2:0] == 0) begin
						dcachemastersel = 'b00000001;
						dcachemasterdati = {{56{1'b0}}, gprdata1[7:0]};
					end else if (gprdata2[2:0] == 1) begin
						dcachemastersel = 'b00000010;
						dcachemasterdati = {{48{1'b0}}, gprdata1[7:0], {8{1'b0}}};
					end else if (gprdata2[2:0] == 2) begin
						dcachemastersel = 'b00000100;
						dcachemasterdati = {{40{1'b0}}, gprdata1[7:0], {16{1'b0}}};
					end else if (gprdata2[2:0] == 3) begin
						dcachemastersel = 'b00001000;
						dcachemasterdati = {{32{1'b0}}, gprdata1[7:0], {24{1'b0}}};
					end else if (gprdata2[2:0] == 4) begin
						dcachemastersel = 'b00010000;
						dcachemasterdati = {{24{1'b0}}, gprdata1[7:0], {32{1'b0}}};
					end else if (gprdata2[2:0] == 5) begin
						dcachemastersel = 'b00100000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {40{1'b0}}};
					end else if (gprdata2[2:0] == 6) begin
						dcachemastersel = 'b01000000;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {48{1'b0}}};
					end else begin
						dcachemastersel = 'b10000000;
						dcachemasterdati = {gprdata1[7:0], {56{1'b0}}};
					end
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
