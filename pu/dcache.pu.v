// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Combinational logic that sets the dcache inputs.

always @* begin
	`ifdef PUMMU
	`ifdef PUHPTW
	hptwmemstate     = HPTWMEMSTATENONE;
	`endif
	`endif
	dcachemasterop   = MEMNOOP;
	dcachemasteraddr = 0;
	dcachemastersel  = 0;

	if (miscrdyandsequencerreadyandgprrdy12) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (isopgettlb && opgettlbrdy_
			&& !opgettlbfault__hptwddone) begin

			hptwmemstate = HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin

				dcachemasterop   = MEMREADOP;
				dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemastersel  = {(ARCHBITSZ/8){1'b1}};

			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

				dcachemasterop   = MEMREADOP;
				dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemastersel  = {(ARCHBITSZ/8){1'b1}};
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

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};
				end

			end else begin
			`endif
			`endif
				dcachemasterop   = MEMREADOP;
				dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  = dcachemastersel_;
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

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};
				end

			end else begin
			`endif
			`endif
				dcachemasterop   = MEMWRITEOP;
				dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  = dcachemastersel_;
			`ifdef PUMMU
			`ifdef PUHPTW
			end
			`endif
			`endif
		end else if (isopldst && opldstrdy_
			&& ((!opldstfault && !instrbufdato0[2]) // Should yield same signal as opldstrdy.
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

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   = MEMREADOP;
					dcachemasteraddr = hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  = {(ARCHBITSZ/8){1'b1}};
				end

			end else if (!instrbufdato0[2]) begin
			`endif
			`endif
				dcachemasterop   = MEMREADWRITEOP;
				dcachemasteraddr = {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  = dcachemastersel_;
			`ifdef PUMMU
			`ifdef PUHPTW
			end
			`endif
			`endif
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
		(!inhalt && itlb_and_instrbuf_rdy
		&& !itlbfault__hptwidone))) begin

		hptwmemstate = HPTWMEMSTATEINSTR;

		if (hptwistate_eq_HPTWSTATEPGD0) begin

			dcachemasterop   = MEMREADOP;
			dcachemasteraddr = hptwpgd_plus_hptwipgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcachemastersel  = {(ARCHBITSZ/8){1'b1}};

		end else if (hptwistate_eq_HPTWSTATEPTE0) begin

			dcachemasterop   = MEMREADOP;
			dcachemasteraddr = hptwipte_plus_hptwipteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcachemastersel  = {(ARCHBITSZ/8){1'b1}};
		end
	`endif
	`endif
	end
end

always @* begin

	if (ARCHBITSZ == 16) begin
		if (instrbufdato0[0]) begin
			dcachemastersel_ = 'b11;
			dcachemasterdati = gprdata1;
		end else begin
			if (gprdata2[0] == 0) begin
				dcachemastersel_ = 'b01;
				dcachemasterdati = {{8{1'b0}}, gprdata1[7:0]};
			end else /* if (gprdata2[0] == 1) */ begin
				dcachemastersel_ = 'b10;
				dcachemasterdati = {gprdata1[7:0], {8{1'b0}}};
			end
		end
	end else if (ARCHBITSZ == 32) begin
		if (instrbufdato0[1]) begin
			dcachemastersel_ = 'b1111;
			dcachemasterdati = gprdata1;
		end else if (instrbufdato0[0]) begin
			if (gprdata2[1]) begin
				dcachemastersel_ = 'b1100;
				dcachemasterdati = {gprdata1[15:0], {16{1'b0}}};
			end else begin
				dcachemastersel_ = 'b0011;
				dcachemasterdati = {{16{1'b0}}, gprdata1[15:0]};
			end
		end else begin
			if (gprdata2[1:0] == 0) begin
				dcachemastersel_ = 'b0001;
				dcachemasterdati = {{24{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[1:0] == 1) begin
				dcachemastersel_ = 'b0010;
				dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[1:0] == 2) begin
				dcachemastersel_ = 'b0100;
				dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else /* if (gprdata2[1:0] == 3) */ begin
				dcachemastersel_ = 'b1000;
				dcachemasterdati = {gprdata1[7:0], {24{1'b0}}};
			end
		end
	end else /* if (ARCHBITSZ == 64) */ begin
		if (&instrbufdato0[1:0]) begin
			dcachemastersel_ = 'b11111111;
			dcachemasterdati = gprdata1;
		end else if (instrbufdato0[1]) begin
			if (gprdata2[2]) begin
				dcachemastersel_ = 'b11110000;
				dcachemasterdati = {gprdata1[31:0], {32{1'b0}}};
			end else begin
				dcachemastersel_ = 'b00001111;
				dcachemasterdati = {{32{1'b0}}, gprdata1[31:0]};
			end
		end else if (instrbufdato0[0]) begin
			if (gprdata2[2:1] == 0) begin
				dcachemastersel_ = 'b00000011;
				dcachemasterdati = {{48{1'b0}}, gprdata1[15:0]};
			end else if (gprdata2[2:1] == 1) begin
				dcachemastersel_ = 'b00001100;
				dcachemasterdati = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
			end else if (gprdata2[2:1] == 2) begin
				dcachemastersel_ = 'b00110000;
				dcachemasterdati = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
			end else /* if (gprdata2[2:1] == 3) */ begin
				dcachemastersel_ = 'b11000000;
				dcachemasterdati = {gprdata1[15:0], {48{1'b0}}};
			end
		end else begin
			if (gprdata2[2:0] == 0) begin
				dcachemastersel_ = 'b00000001;
				dcachemasterdati = {{56{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[2:0] == 1) begin
				dcachemastersel_ = 'b00000010;
				dcachemasterdati = {{48{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[2:0] == 2) begin
				dcachemastersel_ = 'b00000100;
				dcachemasterdati = {{40{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else if (gprdata2[2:0] == 3) begin
				dcachemastersel_ = 'b00001000;
				dcachemasterdati = {{32{1'b0}}, gprdata1[7:0], {24{1'b0}}};
			end else if (gprdata2[2:0] == 4) begin
				dcachemastersel_ = 'b00010000;
				dcachemasterdati = {{24{1'b0}}, gprdata1[7:0], {32{1'b0}}};
			end else if (gprdata2[2:0] == 5) begin
				dcachemastersel_ = 'b00100000;
				dcachemasterdati = {{16{1'b0}}, gprdata1[7:0], {40{1'b0}}};
			end else if (gprdata2[2:0] == 6) begin
				dcachemastersel_ = 'b01000000;
				dcachemasterdati = {{8{1'b0}}, gprdata1[7:0], {48{1'b0}}};
			end else /* if (gprdata2[2:0] == 7) */ begin
				dcachemastersel_ = 'b10000000;
				dcachemasterdati = {gprdata1[7:0], {56{1'b0}}};
			end
		end
	end
end

always @* begin
	dcachemasterdato_result = {ARCHBITSZMAX{1'b0}};
	// Apropriately set dcachemasterdato_result depending on dcachemastersel_saved.
	if (dcachemastersel_saved == 'b11)
		dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[15:0]};
	else if (dcachemastersel_saved == 'b01)
		dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[7:0]};
	else if (dcachemastersel_saved == 'b10)
		dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[15:8]};
	else if (ARCHBITSZ == 32 || ARCHBITSZ == 64) begin
		if (dcachemastersel_saved == 'b1111)
			dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[31:0]};
		else if (dcachemastersel_saved == 'b1100)
			dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[31:16]};
		else if (dcachemastersel_saved == 'b0100)
			dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[23:16]};
		else if (dcachemastersel_saved == 'b1000)
			dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[31:24]};
		else if (ARCHBITSZ == 64) begin
			if (dcachemastersel_saved == 'b11111111)
				dcachemasterdato_result = dcachemasterdato;
			else if (dcachemastersel_saved == 'b11110000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-32)){1'b0}}, dcachemasterdato[63:32]};
			else if (dcachemastersel_saved == 'b00110000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[47:32]};
			else if (dcachemastersel_saved == 'b11000000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-16)){1'b0}}, dcachemasterdato[63:48]};
			else if (dcachemastersel_saved == 'b00010000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[39:32]};
			else if (dcachemastersel_saved == 'b00100000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[47:40]};
			else if (dcachemastersel_saved == 'b01000000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[55:48]};
			else if (dcachemastersel_saved == 'b10000000)
				dcachemasterdato_result = {{(ARCHBITSZMAX-(ARCHBITSZ-8)){1'b0}}, dcachemasterdato[63:56]};
		end
	end
end

always @ (posedge clk_i) begin
	if (miscrdyandsequencerreadyandgprrdy12 && dtlb_rdy) begin
		if ((isopld && dcachemasterrdy && !opldfault
			`ifdef PUMMU
			`ifdef PUHPTW
			&& opldfault__hptwddone
			`endif
			`endif
		) || (isopldst && dcachemasterrdy && !opldstfault
				`ifdef PUMMU
				`ifdef PUHPTW
				&& opldstfault__hptwddone
				`endif
				`endif
		)) dcachemastersel_saved <= dcachemastersel;
	end
end
