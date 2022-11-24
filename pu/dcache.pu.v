// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Combinational logic that sets the dcache inputs.

always @* begin

if (miscrdyandsequencerreadyandgprrdy12) begin
	`ifdef PUMMU
	`ifdef PUHPTW
	if (isopgettlb && opgettlbrdy_ && !opgettlbfault__hptwddone) begin

		hptwmemstate = HPTWMEMSTATEDATA;

		if (hptwdstate_eq_HPTWSTATEPGD0) begin
			dcachemasterop = MEMREADOP;
			dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			// dcachemasterdati is a don't-care
			// in this state and do not need to be set.
			// ### Set so that verilog works correctly.
			dcachemasterdati = 0;
			dcachemastersel = {(ARCHBITSZ/8){1'b1}};
		end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
			dcachemasterop = MEMREADOP;
			dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			// dcachemasterdati is a don't-care
			// in this state and do not need to be set.
			// ### Set so that verilog works correctly.
			dcachemasterdati = 0;
			dcachemastersel = {(ARCHBITSZ/8){1'b1}};
		end else begin
			// Signals that are don't-care in this state and do not need to be set.
			// ### Set so that verilog works correctly.
			dcachemasterop = MEMNOOP;
			dcachemasteraddr = 0;
			dcachemasterdati = 0;
			dcachemastersel = 0;
		end

	end else
	`endif
	`endif
	if (isopld && opldrdy_
		&& (!opldfault // Should yield same signal as opldrdy.
			`ifdef PUMMU
			`ifdef PUHPTW
			|| !opldfault__hptwddone
			`endif
			`endif
		)) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opldfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				// Signals that are don't-care in this state and do not need to be set.
				// ### Set so that verilog works correctly.
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

			// dcachemasterdati is a don't-care
			// in this state and do not need to be set.
			// ### Set so that verilog works correctly.
			dcachemasterdati = 0;

			if (ARCHBITSZ == 16) begin
				if (instrbufdato0[0])
					dcachemastersel = 'b11;
				else begin
					if (gprdata2[0] == 0)
						dcachemastersel = 'b01;
					else /* if (gprdata2[0] == 1) */
						dcachemastersel = 'b10;
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufdato0[1])
					dcachemastersel = 'b1111;
				else if (instrbufdato0[0]) begin
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
					else /* if (gprdata2[1:0] == 3) */
						dcachemastersel = 'b1000;
				end
			end else begin
				if (&instrbufdato0[1:0])
					dcachemastersel = 'b11111111;
				else if (instrbufdato0[1]) begin
					if (gprdata2[2])
						dcachemastersel = 'b11110000;
					else
						dcachemastersel = 'b00001111;
				end else if (instrbufdato0[0]) begin
					if (gprdata2[2:1] == 0)
						dcachemastersel = 'b00000011;
					else if (gprdata2[2:1] == 1)
						dcachemastersel = 'b00001100;
					else if (gprdata2[2:1] == 2)
						dcachemastersel = 'b00110000;
					else /* if (gprdata2[2:1] == 3) */
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
					else /* if (gprdata2[2:0] == 7) */
						dcachemastersel = 'b10000000;
				end
			end
		`ifdef PUMMU
		`ifdef PUHPTW
		end
		`endif
		`endif

	end else if (isopst && opstrdy_
		&& (!opstfault // Should yield same signal as opstrdy.
			`ifdef PUMMU
			`ifdef PUHPTW
			|| !opstfault__hptwddone
			`endif
			`endif
		)) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opstfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				// Signals that are don't-care in this state and do not need to be set.
				// ### Set so that verilog works correctly.
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
				if (instrbufdato0[0]) begin
					dcachemastersel = 'b11;
					dcachemasterdati = gprdata1;
				end else begin
					if (gprdata2[0] == 0) begin
						dcachemastersel = 'b01;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0]};
					end else /* if (gprdata2[0] == 1) */ begin
						dcachemastersel = 'b10;
						dcachemasterdati = {gprdata1[7:0], {8{1'b0}}};
					end
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufdato0[1]) begin
					dcachemastersel = 'b1111;
					dcachemasterdati = gprdata1;
				end else if (instrbufdato0[0]) begin
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
					end else /* if (gprdata2[1:0] == 3) */ begin
						dcachemastersel = 'b1000;
						dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
					end
				end
			end else begin
				if (&instrbufdato0[1:0]) begin
					dcachemastersel = 'b11111111;
					dcachemasterdati = gprdata1;
				end else if (instrbufdato0[1]) begin
					if (gprdata2[2]) begin
						dcachemastersel = 'b11110000;
						dcachemasterdati = {gprdata1[31:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b00001111;
						dcachemasterdati = {{32{1'b0}}, gprdata1[31:0]};
					end
				end else if (instrbufdato0[0]) begin
					if (gprdata2[2:1] == 0) begin
						dcachemastersel = 'b00000011;
						dcachemasterdati = {{48{1'b0}}, gprdata1[15:0]};
					end else if (gprdata2[2:1] == 1) begin
						dcachemastersel = 'b00001100;
						dcachemasterdati = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
					end else if (gprdata2[2:1] == 2) begin
						dcachemastersel = 'b00110000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
					end else /* if (gprdata2[2:1] == 3) */ begin
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
					end else /* if (gprdata2[2:0] == 7) */ begin
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
		&& (!opldstfault && !instrbufdato0[2] // Should yield same signal as opldstrdy.
			`ifdef PUMMU
			`ifdef PUHPTW
			|| !opldstfault__hptwddone
			`endif
			`endif
		)) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (!opldstfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin
				dcachemasterop = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				// dcachemasterdati is a don't-care
				// in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterdati = 0;
				dcachemastersel = {(ARCHBITSZ/8){1'b1}};
			end else begin
				// Signals that are don't-care in this state and do not need to be set.
				// ### Set so that verilog works correctly.
				dcachemasterop = MEMNOOP;
				dcachemasteraddr = 0;
				dcachemasterdati = 0;
				dcachemastersel = 0;
			end

		end else if (!instrbufdato0[2]) begin

			hptwmemstate = HPTWMEMSTATENONE;
		`endif
		`endif
			dcachemasterop = MEMREADWRITEOP;

			dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};

			if (ARCHBITSZ == 16) begin
				if (instrbufdato0[0]) begin
					dcachemastersel = 'b11;
					dcachemasterdati = gprdata1;
				end else begin
					if (gprdata2[0] == 0) begin
						dcachemastersel = 'b01;
						dcachemasterdati = {{8{1'b0}}, gprdata1[7:0]};
					end else /* if (gprdata2[0] == 1) */ begin
						dcachemastersel = 'b10;
						dcachemasterdati = {gprdata1[7:0], {8{1'b0}}};
					end
				end
			end else if (ARCHBITSZ == 32) begin
				if (instrbufdato0[1]) begin
					dcachemastersel = 'b1111;
					dcachemasterdati = gprdata1;
				end else if (instrbufdato0[0]) begin
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
					end else /* if (gprdata2[1:0] == 3) */ begin
						dcachemastersel = 'b1000;
						dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
					end
				end
			end else begin
				if (&instrbufdato0[1:0]) begin
					dcachemastersel = 'b11111111;
					dcachemasterdati = gprdata1;
				end else if (instrbufdato0[1]) begin
					if (gprdata2[2]) begin
						dcachemastersel = 'b11110000;
						dcachemasterdati = {gprdata1[31:0], {32{1'b0}}};
					end else begin
						dcachemastersel = 'b00001111;
						dcachemasterdati = {{32{1'b0}}, gprdata1[31:0]};
					end
				end else if (instrbufdato0[0]) begin
					if (gprdata2[2:1] == 0) begin
						dcachemastersel = 'b00000011;
						dcachemasterdati = {{48{1'b0}}, gprdata1[15:0]};
					end else if (gprdata2[2:1] == 1) begin
						dcachemastersel = 'b00001100;
						dcachemasterdati = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
					end else if (gprdata2[2:1] == 2) begin
						dcachemastersel = 'b00110000;
						dcachemasterdati = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
					end else /* if (gprdata2[2:1] == 3) */ begin
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
					end else /* if (gprdata2[2:0] == 7) */ begin
						dcachemastersel = 'b10000000;
						dcachemasterdati = {gprdata1[7:0], {56{1'b0}}};
					end
				end
			end
		`ifdef PUMMU
		`ifdef PUHPTW
		end else begin
			// Signals that are don't-care in this state and do not need to be set.
			// ### Set so that verilog works correctly.
			hptwmemstate = HPTWMEMSTATENONE;
			dcachemasterop = MEMNOOP;
			dcachemasteraddr = 0;
			dcachemasterdati = 0;
			dcachemastersel = 0;
		end
		`endif
		`endif

	end else begin
		// Signals that are don't-care in this state and do not need to be set.
		// ### Set so that verilog works correctly.
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
// Just like in memctrl, the instruction fetch request has the least priority
// so that load and store instructions can be completed as soon as possible, and
// so that the next instruction in the buffer can be sequenced as soon as possible.
end else if (!(rst_i) && // Generated from logic in instrctrl.pu.v .
	!((instrfetchmemrqst || instrfetchmemrqstinprogress) && !instrbufrst) &&
	!(icachecheck && !instrbufrst) &&
	((instrbufrst || !instrfetchfaulted) &&
	(!inhalt && itlb_and_instrbuf_rdy && !itlbfault__hptwidone))) begin

	hptwmemstate = HPTWMEMSTATEINSTR;

	if (hptwistate_eq_HPTWSTATEPGD0) begin
		dcachemasterop = MEMREADOP;
		dcachemasteraddr = hptwpgd_plus_hptwipgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
		// dcachemasterdati is a don't-care
		// in this state and do not need to be set.
		// ### Set so that verilog works correctly.
		dcachemasterdati = 0;
		dcachemastersel = {(ARCHBITSZ/8){1'b1}};
	end else if (hptwistate_eq_HPTWSTATEPTE0) begin
		dcachemasterop = MEMREADOP;
		dcachemasteraddr = hptwipte_plus_hptwipteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
		// dcachemasterdati is a don't-care
		// in this state and do not need to be set.
		// ### Set so that verilog works correctly.
		dcachemasterdati = 0;
		dcachemastersel = {(ARCHBITSZ/8){1'b1}};
	end else begin
		// Signals that are don't-care in this state and do not need to be set.
		// ### Set so that verilog works correctly.
		dcachemasterop = MEMNOOP;
		dcachemasteraddr = 0;
		dcachemasterdati = 0;
		dcachemastersel = 0;
	end
`endif
`endif
end else begin
	// Signals that are don't-care in this state and do not need to be set.
	// ### Set so that verilog works correctly.
	// ### Set so that verilog works correctly.
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

end
