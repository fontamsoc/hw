// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction fetch request has the least priority so that
// load and store instructions can be completed as soon as possible,
// and so that the next instruction in the buffer can be sequenced
// as soon as possible.

always @* begin

	wb_cyc_o = 0;
	wb_stb_o = 0;
	wb_we_o = 0;
	wb_addr_o = 0;
	wb_sel_o = 0;
	wb_dat_o = 0;

	if (rst_i);
	else if (dcache_s_stb_o) begin
		wb_cyc_o = 1;
		wb_stb_o = 1;
		wb_we_o = dcache_s_we_o;
		wb_addr_o = dcache_s_addr_o;
		wb_sel_o = dcache_s_sel_o;
		wb_dat_o = dcache_s_dat_o;
	end else if (instrfetchmemaccesspending) begin
		wb_cyc_o = 1;
		wb_stb_o = 1;
		wb_we_o = 0;
		wb_addr_o = {{(XADDRBITSZ-ADDRBITSZ){1'b0}}, instrfetchppninstrfetchaddr[ADDRBITSZ -1 : CLOG2XARCHBITSZBY8DIFF]};
		wb_sel_o = {(XARCHBITSZ/8){1'b1}};
	end else
		wb_cyc_o = (|wb_pending_acks);
end

always @ (posedge clk_i) begin
	if (rst_i) begin
		instrfetchmemrqstseqvalid <= 0;
		instrfetchmemrqstabortseqvalid <= 0;
	end else if (dcache_s_stb_o) begin
		if (instrfetchmemrqstdone_ || (instrfetchmemrqstabort && wb_ack_i)) begin
			instrfetchmemrqstseqvalid <= 0;
			instrfetchmemrqstabortseqvalid <= 0;
		end else if (instrbufrst && instrfetchmemrqstseqvalid) begin
			instrfetchmemrqstseqvalid <= 0;
			instrfetchmemrqstabortseq <= instrfetchmemrqstseq;
			instrfetchmemrqstabortseqvalid <= instrfetchmemrqstseqvalid;
		end
	end else if (instrfetchmemaccesspending) begin
		if (!_wb_bsy_i) begin
			instrfetchmemrqstseq <= wb_rqst_cnt;
			instrfetchmemrqstseqvalid <= 1;
		end
	end else begin
		if (instrfetchmemrqstdone_ || (instrfetchmemrqstabort && wb_ack_i)) begin
			instrfetchmemrqstseqvalid <= 0;
			instrfetchmemrqstabortseqvalid <= 0;
		end else if (instrbufrst && instrfetchmemrqstseqvalid) begin
			instrfetchmemrqstseqvalid <= 0;
			instrfetchmemrqstabortseq <= instrfetchmemrqstseq;
			instrfetchmemrqstabortseqvalid <= instrfetchmemrqstseqvalid;
		end
	end
end

always @ (posedge clk_i) begin

	if (rst_i)
		wb_rqst_cnt <= 0;
	else if (wb_stb_o && !_wb_bsy_i)
		wb_rqst_cnt <= wb_rqst_cnt + 1'b1;

	if (rst_i)
		wb_rsp_cnt <= 0;
	else if (wb_ack_i)
		wb_rsp_cnt <= wb_rsp_cnt + 1'b1;

	if (rst_i)
		wb_pending_acks <= 0;
	else if (wb_stb_o && !_wb_bsy_i && wb_ack_i);
	else if (wb_ack_i)
		wb_pending_acks <= wb_pending_acks - 1'b1;
	else if (wb_stb_o && !_wb_bsy_i)
		wb_pending_acks <= wb_pending_acks + 1'b1;
end

always @ (posedge clk_i) begin

	if (rst_i) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		hptwmemrqst <= HPTWMEMREQNONE;
		`endif
		`endif
		dcache_m_stb_i <= 1'b0;
		dcache_m_we_i_ <= 1'b0;

	end else if (dcache_m_we_i_) begin
		// TODO: Modify to handle cldst ...
		if (!_dcache_m_bsy_o) begin
			dcache_m_we_i <= 1'b1;
			dcache_m_we_i_ <= 1'b0;
		end

	end else if (miscrdyandsequencerreadyandgprrdy12) begin
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

				if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPGD0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPTE0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else begin /* When I get here (!_dcache_m_bsy_o) is true */

					hptwmemrqst <= HPTWMEMREQNONE;

					dcache_m_stb_i <= 1'b0;
				end

			end else begin

				hptwmemrqst <= HPTWMEMREQNONE;
			`endif
			`endif
				dcache_m_stb_i <= 1'b1;
				dcache_m_we_i <= 0;
				dcache_m_addr_i <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcache_m_sel_i <= dcache_m_sel_i_;
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

				if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPGD0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPTE0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else begin /* When I get here (!_dcache_m_bsy_o) is true */

					hptwmemrqst <= HPTWMEMREQNONE;

					dcache_m_stb_i <= 1'b0;
				end

			end else begin

				hptwmemrqst <= HPTWMEMREQNONE;
			`endif
			`endif
				dcache_m_stb_i <= 1'b1;
				dcache_m_we_i <= 1;
				dcache_m_addr_i <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcache_m_sel_i <= dcache_m_sel_i_;
				dcache_m_dat_i <= dcache_m_dat_i_;
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

				if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPGD0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwpgd_plus_hptwdpgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else if (hptwmemrqst == HPTWMEMREQNONE && hptwdstate_eq_HPTWSTATEPTE0) begin

					hptwmemrqst <= HPTWMEMREQDATA;

					dcache_m_stb_i <= 1'b1;
					dcache_m_we_i <= 0;
					dcache_m_addr_i <= hptwdpte_plus_hptwdpteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
					dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
					`ifdef PUDCACHE
					dcache_cmiss_r <= 1'b1;
					`endif
				end else begin /* When I get here (!_dcache_m_bsy_o) is true */

					hptwmemrqst <= HPTWMEMREQNONE;

					dcache_m_stb_i <= 1'b0;
				end

			end else if (!instrbufdato0[2]) begin

				hptwmemrqst <= HPTWMEMREQNONE;
			`endif
			`endif
				dcache_m_stb_i <= 1'b1;
				dcache_m_we_i <= 1'b0;
				dcache_m_we_i_ <= 1'b1;
				dcache_m_addr_i <= {dppn, gprdata2[12-1:CLOG2ARCHBITSZBY8]};
				dcache_m_sel_i <= dcache_m_sel_i_;
				dcache_m_dat_i <= dcache_m_dat_i_;
				`ifdef PUDCACHE
				dcache_cmiss_r <= dcache_cmiss_r_;
				`endif
			`ifdef PUMMU
			`ifdef PUHPTW
			end
			`endif
			`endif
		end else if (!_dcache_m_bsy_o) begin
			`ifdef PUMMU
			`ifdef PUHPTW
			hptwmemrqst <= HPTWMEMREQNONE;
			`endif
			`endif
			dcache_m_stb_i <= 1'b0;
		end
	`ifdef PUMMU
	`ifdef PUHPTW
	end else if (!(rst_i) && // Generated from logic in instrctrl.pu.v .
		!(instrfetchmemrqst && !instrbufrst) &&
		!(icachecheck && !instrbufrst) &&
		((instrbufrst || !instrfetchfaulted) &&
		(!inhalt && itlb_and_instrbuf_rdy && !itlbfault__hptwidone)) &&
		(!dcache_m_stb_i || !_dcache_m_bsy_o)) begin

		if (hptwmemrqst == HPTWMEMREQNONE && hptwistate_eq_HPTWSTATEPGD0) begin

			hptwmemrqst <= HPTWMEMREQINSTR;

			dcache_m_stb_i <= 1'b1;
			dcache_m_we_i <= 0;
			dcache_m_addr_i <= hptwpgd_plus_hptwipgdoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
			`ifdef PUDCACHE
			dcache_cmiss_r <= 1'b1;
			`endif
		end else if (hptwmemrqst == HPTWMEMREQNONE && hptwistate_eq_HPTWSTATEPTE0) begin

			hptwmemrqst <= HPTWMEMREQINSTR;

			dcache_m_stb_i <= 1'b1;
			dcache_m_we_i <= 0;
			dcache_m_addr_i <= hptwipte_plus_hptwipteoffset[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];
			dcache_m_sel_i <= {(ARCHBITSZ/8){1'b1}};
			`ifdef PUDCACHE
			dcache_cmiss_r <= 1'b1;
			`endif
		end else begin /* When I get here (!_dcache_m_bsy_o) is true */

			hptwmemrqst <= HPTWMEMREQNONE;

			dcache_m_stb_i <= 1'b0;
		end
	`endif
	`endif
	end else if (!_dcache_m_bsy_o) begin
		`ifdef PUMMU
		`ifdef PUHPTW
		hptwmemrqst <= HPTWMEMREQNONE;
		`endif
		`endif
		dcache_m_stb_i <= 1'b0;
	end
end

generate if (ARCHBITSZ == 16) begin
	always @* begin
		dcache_m_sel_i_ = {(ARCHBITSZ/8){1'b0}};
		dcache_m_dat_i_ = {ARCHBITSZ{1'b0}};
		if (instrbufdato0[0]) begin
			dcache_m_sel_i_ = 2'b11;
			dcache_m_dat_i_ = gprdata1;
		end else begin
			if (gprdata2[0] == 0) begin
				dcache_m_sel_i_ = 2'b01;
				dcache_m_dat_i_ = {{8{1'b0}}, gprdata1[7:0]};
			end else /* if (gprdata2[0] == 1) */ begin
				dcache_m_sel_i_ = 2'b10;
				dcache_m_dat_i_ = {gprdata1[7:0], {8{1'b0}}};
			end
		end
	end
end endgenerate
generate if (ARCHBITSZ == 32) begin
	always @* begin
		dcache_m_sel_i_ = {(ARCHBITSZ/8){1'b0}};
		dcache_m_dat_i_ = {ARCHBITSZ{1'b0}};
		if (instrbufdato0[1]) begin
			dcache_m_sel_i_ = 4'b1111;
			dcache_m_dat_i_ = gprdata1;
		end else if (instrbufdato0[0]) begin
			if (gprdata2[1]) begin
				dcache_m_sel_i_ = 4'b1100;
				dcache_m_dat_i_ = {gprdata1[15:0], {16{1'b0}}};
			end else begin
				dcache_m_sel_i_ = 4'b0011;
				dcache_m_dat_i_ = {{16{1'b0}}, gprdata1[15:0]};
			end
		end else begin
			if (gprdata2[1:0] == 0) begin
				dcache_m_sel_i_ = 4'b0001;
				dcache_m_dat_i_ = {{24{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[1:0] == 1) begin
				dcache_m_sel_i_ = 4'b0010;
				dcache_m_dat_i_ = {{16{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[1:0] == 2) begin
				dcache_m_sel_i_ = 4'b0100;
				dcache_m_dat_i_ = {{8{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else /* if (gprdata2[1:0] == 3) */ begin
				dcache_m_sel_i_ = 4'b1000;
				dcache_m_dat_i_ = {gprdata1[7:0], {24{1'b0}}};
			end
		end
	end
end endgenerate
generate if (ARCHBITSZ == 64) begin
	always @* begin
		dcache_m_sel_i_ = {(ARCHBITSZ/8){1'b0}};
		dcache_m_dat_i_ = {ARCHBITSZ{1'b0}};
		if (&instrbufdato0[1:0]) begin
			dcache_m_sel_i_ = 8'b11111111;
			dcache_m_dat_i_ = gprdata1;
		end else if (instrbufdato0[1]) begin
			if (gprdata2[2]) begin
				dcache_m_sel_i_ = 8'b11110000;
				dcache_m_dat_i_ = {gprdata1[31:0], {32{1'b0}}};
			end else begin
				dcache_m_sel_i_ = 8'b00001111;
				dcache_m_dat_i_ = {{32{1'b0}}, gprdata1[31:0]};
			end
		end else if (instrbufdato0[0]) begin
			if (gprdata2[2:1] == 0) begin
				dcache_m_sel_i_ = 8'b00000011;
				dcache_m_dat_i_ = {{48{1'b0}}, gprdata1[15:0]};
			end else if (gprdata2[2:1] == 1) begin
				dcache_m_sel_i_ = 8'b00001100;
				dcache_m_dat_i_ = {{32{1'b0}}, gprdata1[15:0], {16{1'b0}}};
			end else if (gprdata2[2:1] == 2) begin
				dcache_m_sel_i_ = 8'b00110000;
				dcache_m_dat_i_ = {{16{1'b0}}, gprdata1[15:0], {32{1'b0}}};
			end else /* if (gprdata2[2:1] == 3) */ begin
				dcache_m_sel_i_ = 8'b11000000;
				dcache_m_dat_i_ = {gprdata1[15:0], {48{1'b0}}};
			end
		end else begin
			if (gprdata2[2:0] == 0) begin
				dcache_m_sel_i_ = 8'b00000001;
				dcache_m_dat_i_ = {{56{1'b0}}, gprdata1[7:0]};
			end else if (gprdata2[2:0] == 1) begin
				dcache_m_sel_i_ = 8'b00000010;
				dcache_m_dat_i_ = {{48{1'b0}}, gprdata1[7:0], {8{1'b0}}};
			end else if (gprdata2[2:0] == 2) begin
				dcache_m_sel_i_ = 8'b00000100;
				dcache_m_dat_i_ = {{40{1'b0}}, gprdata1[7:0], {16{1'b0}}};
			end else if (gprdata2[2:0] == 3) begin
				dcache_m_sel_i_ = 8'b00001000;
				dcache_m_dat_i_ = {{32{1'b0}}, gprdata1[7:0], {24{1'b0}}};
			end else if (gprdata2[2:0] == 4) begin
				dcache_m_sel_i_ = 8'b00010000;
				dcache_m_dat_i_ = {{24{1'b0}}, gprdata1[7:0], {32{1'b0}}};
			end else if (gprdata2[2:0] == 5) begin
				dcache_m_sel_i_ = 8'b00100000;
				dcache_m_dat_i_ = {{16{1'b0}}, gprdata1[7:0], {40{1'b0}}};
			end else if (gprdata2[2:0] == 6) begin
				dcache_m_sel_i_ = 8'b01000000;
				dcache_m_dat_i_ = {{8{1'b0}}, gprdata1[7:0], {48{1'b0}}};
			end else /* if (gprdata2[2:0] == 7) */ begin
				dcache_m_sel_i_ = 8'b10000000;
				dcache_m_dat_i_ = {gprdata1[7:0], {56{1'b0}}};
			end
		end
	end
end endgenerate
