// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction fetch request has the least priority so that
// load and store instructions can be completed as soon as possible,
// and so that the next instruction in the buffer can be sequenced
// as soon as possible.

always @* begin

	pi1_op_o   = MEMNOOP;
	pi1_addr_o = 0;
	pi1_sel_o  = 0;
	pi1_data_o = 0;

	if (rst_i) begin
	end else if (dcacheslaveop != MEMNOOP) begin

		pi1_op_o   = dcacheslaveop;
		pi1_addr_o = dcacheslaveaddr;
		pi1_sel_o  = dcacheslavesel;
		pi1_data_o = dcacheslavedato;

	end else if (instrfetchmemaccesspending) begin

		pi1_op_o   = MEMREADOP;
		pi1_addr_o = {{(XADDRBITSZ-ADDRBITSZ){1'b0}}, instrfetchppninstrfetchaddr[ADDRBITSZ -1 : CLOG2XARCHBITSZBY8DIFF]};
		pi1_sel_o  = {(XARCHBITSZ/8){1'b1}};

	end else begin
	end
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		instrfetchmemrqstinprogress <= 0;

	end else if (dcacheslaveop != MEMNOOP) begin

		if (pi1_rdy_i || instrbufrst)
			instrfetchmemrqstinprogress <= 0;

	end else if (instrfetchmemaccesspending) begin

		if (pi1_rdy_i)
			instrfetchmemrqstinprogress <= 1;
		else if (instrbufrst)
			instrfetchmemrqstinprogress <= 0;

	end else begin

		if (pi1_rdy_i || instrbufrst)
			instrfetchmemrqstinprogress <= 0;
	end
end

// Combinational logic that sets the dcache inputs.

always @ (posedge clk_i) begin

	if (rst_i) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		hptwmemstate <= HPTWMEMSTATENONE;
		`endif
		`endif
		dcachemasterop <= MEMNOOP;
		dcache_m_cyc_i <= 1'b0;
		dcache_m_stb_i <= 1'b0;

	end else if (dcache_m_stb_i) begin

		if (/* ~dcache_m_bsy_o TODO: use instead with Wishbone */ dcache_m_ack_o) begin
			dcachemasterop <= MEMNOOP;
			dcache_m_stb_i <= 1'b0;
		end

	end else if (dcache_m_cyc_i) begin

		if (dcache_m_ack_o) begin
			`ifdef PUMMU
			`ifdef PUHPTW
			hptwmemstate <= HPTWMEMSTATENONE;
			`endif
			`endif
			dcache_m_cyc_i <= 1'b0;
		end

	end else if (miscrdyandsequencerreadyandgprrdy12) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		if (isopgettlb && opgettlbrdy_
			&& !opgettlbfault__hptwddone) begin

			hptwmemstate <= HPTWMEMSTATEDATA;

			if (hptwdstate_eq_HPTWSTATEPGD0) begin

				dcachemasterop   <= MEMREADOP;
				dcachemasteraddr <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
				dcache_m_cyc_i <= 1'b1;
				dcache_m_stb_i <= 1'b1;
				`ifdef PUDCACHE
				dcache_cmiss_r <= 1'b1;
				`endif

			end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

				dcachemasterop   <= MEMREADOP;
				dcachemasteraddr <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
				dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
				dcache_m_cyc_i <= 1'b1;
				dcache_m_stb_i <= 1'b1;
				`ifdef PUDCACHE
				dcache_cmiss_r <= 1'b1;
				`endif
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

				hptwmemstate <= HPTWMEMSTATEDATA;

				if (hptwdstate_eq_HPTWSTATEPGD0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end

			end else begin
			`endif
			`endif
				dcachemasterop   <= MEMREADOP;
				dcachemasteraddr <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  <= dcachemastersel_;
				dcache_m_cyc_i <= 1'b1;
				dcache_m_stb_i <= 1'b1;
				`ifdef PUDCACHE
				dcache_cmiss_r <= dcache_cmiss_r_;
				`endif

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

				hptwmemstate <= HPTWMEMSTATEDATA;

				if (hptwdstate_eq_HPTWSTATEPGD0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end

			end else begin
			`endif
			`endif
				dcachemasterop   <= MEMWRITEOP;
				dcachemasteraddr <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  <= dcachemastersel_;
				dcachemasterdati <= dcachemasterdati_;
				dcache_m_cyc_i <= 1'b1;
				dcache_m_stb_i <= 1'b1;
				`ifdef PUDCACHE
				dcache_cmiss_r <= dcache_cmiss_r_;
				`endif

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

				hptwmemstate <= HPTWMEMSTATEDATA;

				if (hptwdstate_eq_HPTWSTATEPGD0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif

				end else if (hptwdstate_eq_HPTWSTATEPTE0) begin

					dcachemasterop   <= MEMREADOP;
					dcachemasteraddr <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
					dcache_m_cyc_i <= 1'b1;
					dcache_m_stb_i <= 1'b1;
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end

			end else if (!instrbufdato0[2]) begin
			`endif
			`endif
				dcachemasterop   <= MEMREADWRITEOP;
				dcachemasteraddr <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcachemastersel  <= dcachemastersel_;
				dcachemasterdati <= dcachemasterdati_;
				dcache_m_cyc_i <= 1'b1;
				dcache_m_stb_i <= 1'b1;
				`ifdef PUDCACHE
				dcache_cmiss_r <= dcache_cmiss_r_;
				`endif

			`ifdef PUMMU
			`ifdef PUHPTW
			end
			`endif
			`endif
		end
	`ifdef PUMMU
	`ifdef PUHPTW
	// Just like in memctrl (TODO: review), the instruction fetch request has the least priority
	// so that load and store instructions can be completed as soon as possible, and
	// so that the next instruction in the buffer can be sequenced as soon as possible.
	end else if (!(rst_i) && // Generated from logic in instrctrl.pu.v .
		!((instrfetchmemrqst || instrfetchmemrqstinprogress) && !instrbufrst) &&
		!(icachecheck && !instrbufrst) &&
		((instrbufrst || !instrfetchfaulted) &&
		(!inhalt && itlb_and_instrbuf_rdy
		&& !itlbfault__hptwidone))) begin

		hptwmemstate <= HPTWMEMSTATEINSTR;

		if (hptwistate_eq_HPTWSTATEPGD0) begin

			dcachemasterop   <= MEMREADOP;
			dcachemasteraddr <= hptwpgd_plus_hptwipgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
			dcache_m_cyc_i <= 1'b1;
			dcache_m_stb_i <= 1'b1;
			`ifdef PUDCACHE
			dcache_cmiss_r <= 1'b1;
			`endif

		end else if (hptwistate_eq_HPTWSTATEPTE0) begin

			dcachemasterop   <= MEMREADOP;
			dcachemasteraddr <= hptwipte_plus_hptwipteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcachemastersel  <= {(ARCHBITSZ/8){1'b1}};
			dcache_m_cyc_i <= 1'b1;
			dcache_m_stb_i <= 1'b1;
			`ifdef PUDCACHE
			dcache_cmiss_r <= 1'b1;
			`endif
		end
	`endif
	`endif
	end
end

generate if (ARCHBITSZ == 16) begin
	always @* begin
		dcachemastersel_ = {(ARCHBITSZ/8){1'b0}};
		dcachemasterdati_ = {ARCHBITSZ{1'b0}};
		if (instrbufdato0[0]) begin
			dcachemastersel_ = 2'b11;
			dcachemasterdati_ = gprdata1;
		end else begin
			if (gprdata2[0] == 0) begin
				dcachemastersel_ = 2'b01;
				dcachemasterdati_ = {{8{1'b0}}, gprdata1[7:0]};
			end else /* if (gprdata2[0] == 1) */ begin
				dcachemastersel_ = 2'b10;
				dcachemasterdati_ = {gprdata1[7:0], {8{1'b0}}};
			end
		end
	end
end endgenerate
generate if (ARCHBITSZ == 32) begin
	always @* begin
		dcachemastersel_ = {(ARCHBITSZ/8){1'b0}};
		dcachemasterdati_ = {ARCHBITSZ{1'b0}};
		if (instrbufdato0[1]) begin
			dcachemastersel_ = 4'b1111;
			dcachemasterdati_ = gprdata1;
		end else if (instrbufdato0[0]) begin
			if (gprdata2[1]) begin
				dcachemastersel_ = 4'b1100;
				dcachemasterdati_ = {gprdata1[15:0], {16{1'b0}}};
			end else begin
				dcachemastersel_ = 4'b0011;
				dcachemasterdati_ = {{16{1'b0}}, gprdata1[15:0]};
			end
		end else begin
			if (gprdata2[1:0] == 0) begin
				dcachemastersel_ = 4'b0001;
				dcachemasterdati_ = {{24{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[1:0] == 1) begin
				dcachemastersel_ = 4'b0010;
				dcachemasterdati_ = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[1:0] == 2) begin
				dcachemastersel_ = 4'b0100;
				dcachemasterdati_ = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else /* if (gprdata2[1:0] == 3) */ begin
				dcachemastersel_ = 4'b1000;
				dcachemasterdati_ = {gprdata1[7:0], {24{1'b0}}};
			end
		end
	end
end endgenerate
generate if (ARCHBITSZ == 64) begin
	always @* begin
		dcachemastersel_ = {(ARCHBITSZ/8){1'b0}};
		dcachemasterdati_ = {ARCHBITSZ{1'b0}};
		if (&instrbufdato0[1:0]) begin
			dcachemastersel_ = 8'b11111111;
			dcachemasterdati_ = gprdata1;
		end else if (instrbufdato0[1]) begin
			if (gprdata2[2]) begin
				dcachemastersel_ = 8'b11110000;
				dcachemasterdati_ = {gprdata1[31:0], {32{1'b0}}};
			end else begin
				dcachemastersel_ = 8'b00001111;
				dcachemasterdati_ = {{32{1'b0}}, gprdata1[31:0]};
			end
		end else if (instrbufdato0[0]) begin
			if (gprdata2[2:1] == 0) begin
				dcachemastersel_ = 8'b00000011;
				dcachemasterdati_ = {{48{1'b0}}, gprdata1[15:0]};
			end else if (gprdata2[2:1] == 1) begin
				dcachemastersel_ = 8'b00001100;
				dcachemasterdati_ = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
			end else if (gprdata2[2:1] == 2) begin
				dcachemastersel_ = 8'b00110000;
				dcachemasterdati_ = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
			end else /* if (gprdata2[2:1] == 3) */ begin
				dcachemastersel_ = 8'b11000000;
				dcachemasterdati_ = {gprdata1[15:0], {48{1'b0}}};
			end
		end else begin
			if (gprdata2[2:0] == 0) begin
				dcachemastersel_ = 8'b00000001;
				dcachemasterdati_ = {{56{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[2:0] == 1) begin
				dcachemastersel_ = 8'b00000010;
				dcachemasterdati_ = {{48{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[2:0] == 2) begin
				dcachemastersel_ = 8'b00000100;
				dcachemasterdati_ = {{40{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else if (gprdata2[2:0] == 3) begin
				dcachemastersel_ = 8'b00001000;
				dcachemasterdati_ = {{32{1'b0}}, gprdata1[7:0], {24{1'b0}}};
			end else if (gprdata2[2:0] == 4) begin
				dcachemastersel_ = 8'b00010000;
				dcachemasterdati_ = {{24{1'b0}}, gprdata1[7:0], {32{1'b0}}};
			end else if (gprdata2[2:0] == 5) begin
				dcachemastersel_ = 8'b00100000;
				dcachemasterdati_ = {{16{1'b0}}, gprdata1[7:0], {40{1'b0}}};
			end else if (gprdata2[2:0] == 6) begin
				dcachemastersel_ = 8'b01000000;
				dcachemasterdati_ = {{8{1'b0}}, gprdata1[7:0], {48{1'b0}}};
			end else /* if (gprdata2[2:0] == 7) */ begin
				dcachemastersel_ = 8'b10000000;
				dcachemasterdati_ = {gprdata1[7:0], {56{1'b0}}};
			end
		end
	end
end endgenerate

// Apropriately set dcachemasterdato_result depending on dcachemastersel.
generate if (ARCHBITSZ == 16) begin
	assign dcachemasterdato_result =
		(dcachemastersel == 2'b10) ? {{8{1'b0}}, dcachemasterdato[15:8]} :
		(dcachemastersel == 2'b01) ? {{8{1'b0}}, dcachemasterdato[7:0]} :
		                                   dcachemasterdato;
end endgenerate
generate if (ARCHBITSZ == 32) begin
	assign dcachemasterdato_result =
		(dcachemastersel == 4'b1100) ? {{16{1'b0}}, dcachemasterdato[31:16]} :
		(dcachemastersel == 4'b0011) ? {{16{1'b0}}, dcachemasterdato[15:0]} :
		(dcachemastersel == 4'b1000) ? {{24{1'b0}}, dcachemasterdato[31:24]} :
		(dcachemastersel == 4'b0100) ? {{24{1'b0}}, dcachemasterdato[23:16]} :
		(dcachemastersel == 4'b0010) ? {{24{1'b0}}, dcachemasterdato[15:8]} :
		(dcachemastersel == 4'b0001) ? {{24{1'b0}}, dcachemasterdato[7:0]} :
		                                     dcachemasterdato;
end endgenerate
generate if (ARCHBITSZ == 64) begin
	assign dcachemasterdato_result =
		(dcachemastersel == 8'b11110000) ? {{32{1'b0}}, dcachemasterdato[63:32]} :
		(dcachemastersel == 8'b00001111) ? {{32{1'b0}}, dcachemasterdato[31:0]} :
		(dcachemastersel == 8'b11000000) ? {{16{1'b0}}, dcachemasterdato[63:48]} :
		(dcachemastersel == 8'b00110000) ? {{16{1'b0}}, dcachemasterdato[47:32]} :
		(dcachemastersel == 8'b00001100) ? {{16{1'b0}}, dcachemasterdato[31:16]} :
		(dcachemastersel == 8'b00000011) ? {{16{1'b0}}, dcachemasterdato[15:0]} :
		(dcachemastersel == 8'b10000000) ? {{24{1'b0}}, dcachemasterdato[63:56]} :
		(dcachemastersel == 8'b01000000) ? {{24{1'b0}}, dcachemasterdato[55:48]} :
		(dcachemastersel == 8'b00100000) ? {{24{1'b0}}, dcachemasterdato[47:40]} :
		(dcachemastersel == 8'b00010000) ? {{24{1'b0}}, dcachemasterdato[39:32]} :
		(dcachemastersel == 8'b00001000) ? {{24{1'b0}}, dcachemasterdato[31:24]} :
		(dcachemastersel == 8'b00000100) ? {{24{1'b0}}, dcachemasterdato[23:16]} :
		(dcachemastersel == 8'b00000010) ? {{24{1'b0}}, dcachemasterdato[15:8]} :
		(dcachemastersel == 8'b00000001) ? {{24{1'b0}}, dcachemasterdato[7:0]} :
		                                         dcachemasterdato;
end endgenerate
