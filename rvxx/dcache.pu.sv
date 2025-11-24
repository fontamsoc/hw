// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire dCache_invd_w;

wire                               dCache_m_cyc_i;
reg                                dCache_m_stb_i;
reg                                dCache_m_we_i;
reg  [(ADDRBITSZ-MSBSZIGN) -1 : 0] dCache_m_addr_i;
reg  [(WORDBITSZ/8) -1 : 0]        dCache_m_sel_i;
reg  [WORDBITSZ -1 : 0]            dCache_m_dat_i;
wire                               dCache_m_bsy_o;
wire                               dCache_m_ack_o;
wire [WORDBITSZ -1 : 0]            dCache_m_dat_o;

wire                                 dCache_s_cyc_o;
wire                                 dCache_s_stb_o;
wire                                 dCache_s_we_o;
wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] dCache_s_addr_o;
wire [(XWORDBITSZ/8) -1 : 0]         dCache_s_sel_o;
wire [XWORDBITSZ -1 : 0]             dCache_s_dat_o;
wire                                 dCache_s_bsy_i;
wire                                 dCache_s_ack_i;
wire [XWORDBITSZ -1 : 0]             dCache_s_dat_i;

wire                               skidBuf_dCache_m_cyc_o;
wire                               skidBuf_dCache_m_stb_o;
wire                               skidBuf_dCache_m_we_o;
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] skidBuf_dCache_m_addr_o;
wire [(WORDBITSZ/8) -1 : 0]        skidBuf_dCache_m_sel_o;
wire [WORDBITSZ -1 : 0]            skidBuf_dCache_m_dat_o;
wire                               skidBuf_dCache_m_bsy_i;
wire                               skidBuf_dCache_m_ack_i;
wire [WORDBITSZ -1 : 0]            skidBuf_dCache_m_dat_i;

wire _dCache_m_stb_i;

generate if (USE_DCACHE) begin: gen_skidBuf_dCache

wb_skidbuf #(
	 .WORDBITSZ     (WORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.MAXPENDINGACK (MAXPENDINGACK)
	,.USEFWFTFIFO   (1)
) skidBuf_dCache (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_wb_cyc_i  (dCache_m_cyc_i)
	,.m_wb_stb_i  (_dCache_m_stb_i)
	,.m_wb_we_i   (dCache_m_we_i)
	,.m_wb_addr_i (dCache_m_addr_i)
	,.m_wb_sel_i  (dCache_m_sel_i)
	,.m_wb_dat_i  (dCache_m_dat_i)
	,.m_wb_bsy_o  (dCache_m_bsy_o)
	,.m_wb_ack_o  (dCache_m_ack_o)
	,.m_wb_dat_o  (dCache_m_dat_o)

	,.s_wb_cyc_o  (skidBuf_dCache_m_cyc_o)
	,.s_wb_stb_o  (skidBuf_dCache_m_stb_o)
	,.s_wb_we_o   (skidBuf_dCache_m_we_o)
	,.s_wb_addr_o (skidBuf_dCache_m_addr_o)
	,.s_wb_sel_o  (skidBuf_dCache_m_sel_o)
	,.s_wb_dat_o  (skidBuf_dCache_m_dat_o)
	,.s_wb_bsy_i  (skidBuf_dCache_m_bsy_i)
	,.s_wb_ack_i  (skidBuf_dCache_m_ack_i)
	,.s_wb_dat_i  (skidBuf_dCache_m_dat_i)
);

end else begin

assign skidBuf_dCache_m_cyc_o = dCache_m_cyc_i;
assign skidBuf_dCache_m_stb_o = _dCache_m_stb_i;
assign skidBuf_dCache_m_we_o = dCache_m_we_i;
assign skidBuf_dCache_m_addr_o = dCache_m_addr_i;
assign skidBuf_dCache_m_sel_o = dCache_m_sel_i;
assign skidBuf_dCache_m_dat_o = dCache_m_dat_i;
assign dCache_m_bsy_o = skidBuf_dCache_m_bsy_i;
assign dCache_m_ack_o = skidBuf_dCache_m_ack_i;
assign dCache_m_dat_o = skidBuf_dCache_m_dat_i;

end endgenerate

wire                                 upSizr_dCache_m_cyc_o;
wire                                 upSizr_dCache_m_stb_o;
wire                                 upSizr_dCache_m_we_o;
wire [(XADDRBITSZ-XMSBSZIGN) -1 : 0] upSizr_dCache_m_addr_o;
wire [(XWORDBITSZ/8) -1 : 0]         upSizr_dCache_m_sel_o;
wire [XWORDBITSZ -1 : 0]             upSizr_dCache_m_dat_o;
wire                                 upSizr_dCache_m_bsy_i;
wire                                 upSizr_dCache_m_ack_i;
wire [XWORDBITSZ -1 : 0]             upSizr_dCache_m_dat_i;

generate if (WORDBITSZ < XWORDBITSZ) begin :gen_upSizr_dCache

wb_upsizr #(
	 .MWORDBITSZ    (WORDBITSZ)
	,.SWORDBITSZ    (XWORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.MAXPENDINGACK (MAXPENDINGACK)
	,.USEFWFTFIFO   (1)
) upSizr_dCache (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_wb_cyc_i  (skidBuf_dCache_m_cyc_o)
	,.m_wb_stb_i  (skidBuf_dCache_m_stb_o)
	,.m_wb_we_i   (skidBuf_dCache_m_we_o)
	,.m_wb_addr_i (skidBuf_dCache_m_addr_o)
	,.m_wb_sel_i  (skidBuf_dCache_m_sel_o)
	,.m_wb_dat_i  (skidBuf_dCache_m_dat_o)
	,.m_wb_bsy_o  (skidBuf_dCache_m_bsy_i)
	,.m_wb_ack_o  (skidBuf_dCache_m_ack_i)
	,.m_wb_dat_o  (skidBuf_dCache_m_dat_i)

	,.s_wb_cyc_o  (upSizr_dCache_m_cyc_o)
	,.s_wb_stb_o  (upSizr_dCache_m_stb_o)
	,.s_wb_we_o   (upSizr_dCache_m_we_o)
	,.s_wb_addr_o (upSizr_dCache_m_addr_o)
	,.s_wb_sel_o  (upSizr_dCache_m_sel_o)
	,.s_wb_dat_o  (upSizr_dCache_m_dat_o)
	,.s_wb_bsy_i  (upSizr_dCache_m_bsy_i)
	,.s_wb_ack_i  (upSizr_dCache_m_ack_i)
	,.s_wb_dat_i  (upSizr_dCache_m_dat_i)
);

end else begin

assign upSizr_dCache_m_cyc_o = skidBuf_dCache_m_cyc_o;
assign upSizr_dCache_m_stb_o = skidBuf_dCache_m_stb_o;
assign upSizr_dCache_m_we_o = skidBuf_dCache_m_we_o;
assign upSizr_dCache_m_addr_o = skidBuf_dCache_m_addr_o;
assign upSizr_dCache_m_sel_o = skidBuf_dCache_m_sel_o;
assign upSizr_dCache_m_dat_o = skidBuf_dCache_m_dat_o;
assign skidBuf_dCache_m_bsy_i = upSizr_dCache_m_bsy_i;
assign skidBuf_dCache_m_ack_i = upSizr_dCache_m_ack_i;
assign skidBuf_dCache_m_dat_i = upSizr_dCache_m_dat_i;

end endgenerate

generate if (USE_DCACHE) begin: gen_dCache

dcache #(
	 .TYPE          (DCACHETYPE)
	,.WORDBITSZ     (XWORDBITSZ)
	,.ADDRLIMIT     (ADDRLIMIT)
	,.CACHESETCNT   (DCACHESETCNT)
	,.CACHEWAYCNT   (DCACHEWAYCNT)
	,.MAXPENDINGACK (MAXPENDINGACK)
) dCache (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	//,.invd_i (dCache_invd_w) TODO: evict all dirty caches ...

	,.conly_i (1'b0)
	,.cmiss_i (dcache_miss_i)

	,.m_wb_cyc_i  (upSizr_dCache_m_cyc_o)
	,.m_wb_stb_i  (upSizr_dCache_m_stb_o)
	,.m_wb_we_i   (upSizr_dCache_m_we_o)
	,.m_wb_addr_i (upSizr_dCache_m_addr_o)
	,.m_wb_sel_i  (upSizr_dCache_m_sel_o)
	,.m_wb_dat_i  (upSizr_dCache_m_dat_o)
	,.m_wb_bsy_o  (upSizr_dCache_m_bsy_i)
	,.m_wb_ack_o  (upSizr_dCache_m_ack_i)
	,.m_wb_dat_o  (upSizr_dCache_m_dat_i)

	,.s_wb_cyc_o  (dCache_s_cyc_o)
	,.s_wb_stb_o  (dCache_s_stb_o)
	,.s_wb_we_o   (dCache_s_we_o)
	,.s_wb_addr_o (dCache_s_addr_o)
	,.s_wb_sel_o  (dCache_s_sel_o)
	,.s_wb_dat_o  (dCache_s_dat_o)
	,.s_wb_bsy_i  (dCache_s_bsy_i)
	,.s_wb_ack_i  (dCache_s_ack_i)
	,.s_wb_dat_i  (dCache_s_dat_i)
);

end else begin

assign dCache_s_cyc_o = upSizr_dCache_m_cyc_o;
assign dCache_s_stb_o = upSizr_dCache_m_stb_o;
assign dCache_s_we_o = upSizr_dCache_m_we_o;
assign dCache_s_addr_o = upSizr_dCache_m_addr_o;
assign dCache_s_sel_o = upSizr_dCache_m_sel_o;
assign dCache_s_dat_o = upSizr_dCache_m_dat_o;

assign upSizr_dCache_m_bsy_i = dCache_s_bsy_i;
assign upSizr_dCache_m_ack_i = dCache_s_ack_i;
assign upSizr_dCache_m_dat_i = dCache_s_dat_i;

end endgenerate

assign dcache_addr_o = {upSizr_dCache_m_addr_o, {CLOG2XWORDBITSZBY8{1'b0}}};

assign dCache_s_bsy_i = _wb_bsy_i;
assign dCache_s_dat_i = wb_dat_i;

reg                         dCache_m_we_i_;  // Used for atomic load-store.
reg  [(WORDBITSZ/8) -1 : 0] dCache_m_sel_i_; // ### comb-block-reg.
reg  [WORDBITSZ -1 : 0]     dCache_m_dat_i_; // ### comb-block-reg.

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] dCache_m_rqst_cnt;
reg [(CLOG2MAXPENDINGACK +1) -1 : 0] dCache_m_rsp_cnt;

wire [(CLOG2MAXPENDINGACK +1) -1 : 0] dCache_m_pending_acks = (dCache_m_rqst_cnt - dCache_m_rsp_cnt);

wire dCache_m_max_pending = dCache_m_pending_acks[CLOG2MAXPENDINGACK];

wire _dCache_m_bsy_o = (dCache_m_bsy_o || dCache_m_max_pending);

assign _dCache_m_stb_i = (dCache_m_stb_i && !dCache_m_max_pending);

wire __dCache_m_stb_i = (_dCache_m_stb_i && !dCache_m_bsy_o);

reg[(CLOG2MAXPENDINGACK +1) -1 : 0] dCache_m_breather;
// Logic used to force wb_cyc low when it has been high for too long;
// otherwise in a multi-core soc, the arbiter will not switch to other cores.
always_ff @(posedge clk_i) begin
	if (rst_i)
		dCache_m_breather <= 0;
	else if (!dCache_m_cyc_i || dCache_m_breather[CLOG2MAXPENDINGACK]) begin
		if (!dCache_m_cyc_i)
			dCache_m_breather <= 0;
	end else if (__dCache_m_stb_i)
		dCache_m_breather <= dCache_m_breather + 1'b1;
end

// Signal set to 1 when the logic setting dCache_m_stb_i cannot accept a new operation.
wire __dCache_m_bsy = ((dCache_m_stb_i && _dCache_m_bsy_o) || dCache_m_we_i_ ||
	dCache_m_breather[CLOG2MAXPENDINGACK]);

always_ff @(posedge clk_i) begin
	if (rst_i)
		dCache_m_rqst_cnt <= 0;
	else if (__dCache_m_stb_i)
		dCache_m_rqst_cnt <= dCache_m_rqst_cnt + 1'b1;
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		dCache_m_rsp_cnt <= 0;
	else if (dCache_m_ack_o)
		dCache_m_rsp_cnt <= dCache_m_rsp_cnt + 1'b1;
end

assign dCache_m_pending = (dCache_m_stb_i || dCache_m_pending_acks);

reg amoUnit_lrValid;

assign dCache_m_cyc_i = (amoUnit_lrValid || dCache_m_stb_i || dCache_m_we_i_ || (|dCache_m_pending_acks));

wire [WORDBITSZ -1 : 0] dCache_m_addr_i_ = (iD_rs1 + iD_addrImm);

wire            amoUnit_memAck;
reg  [5 -1 : 0] amoUnit_opType;

wire [(WORDBITSZ+1) -1 : 0] dCache_m_dat_i_minus_dCache_m_dat_o = (
	({1'b1, ~dCache_m_dat_o} + {1'b0, dCache_m_dat_i}) + 1'b1);
wire dCache_m_dat_i_lt_dCache_m_dat_o = (
	(dCache_m_dat_i[WORDBITSZ-1] ^ dCache_m_dat_o[WORDBITSZ-1]) ?
		dCache_m_dat_i[WORDBITSZ-1] : dCache_m_dat_i_minus_dCache_m_dat_o[WORDBITSZ]);
wire dCache_m_dat_i_ltu_dCache_m_dat_o = dCache_m_dat_i_minus_dCache_m_dat_o[WORDBITSZ];

wire _amoUnit_lrValid;

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		dCache_m_stb_i <= 1'b0;
		dCache_m_we_i_ <= 1'b0;
	end else if (dCache_m_we_i_) begin
		if (amoUnit_memAck) begin
			dCache_m_stb_i <= 1'b1;
			dCache_m_we_i <= 1'b1;
			dCache_m_we_i_ <= 1'b0;
			dCache_m_dat_i <= (
				(amoUnit_opType == 5'b00000) ? (dCache_m_dat_i + dCache_m_dat_o) :
				(amoUnit_opType == 5'b00100) ? (dCache_m_dat_i ^ dCache_m_dat_o) :
				(amoUnit_opType == 5'b01100) ? (dCache_m_dat_i & dCache_m_dat_o) :
				(amoUnit_opType == 5'b01000) ? (dCache_m_dat_i | dCache_m_dat_o) :
				(amoUnit_opType == 5'b10000) ? // amomin.w
					(dCache_m_dat_i_lt_dCache_m_dat_o ? dCache_m_dat_i : dCache_m_dat_o) :
				(amoUnit_opType == 5'b10100) ? // amomax.w
					(!dCache_m_dat_i_lt_dCache_m_dat_o ? dCache_m_dat_i : dCache_m_dat_o) :
				(amoUnit_opType == 5'b11000) ? // amominu.w
					(dCache_m_dat_i_ltu_dCache_m_dat_o ? dCache_m_dat_i : dCache_m_dat_o) :
				(amoUnit_opType == 5'b11100) ? // amomaxu.w
					(!dCache_m_dat_i_ltu_dCache_m_dat_o ? dCache_m_dat_i : dCache_m_dat_o) :
				dCache_m_dat_i);
		end else if (!_dCache_m_bsy_o)
			dCache_m_stb_i <= 1'b0;
	end else if (iD_insn_valid) begin
		if (iD_isLoadOrLr) begin
			dCache_m_stb_i <= 1'b1;
			dCache_m_we_i <= 0;
			dCache_m_addr_i <= { // MSB oring of ignored bits.
				|dCache_m_addr_i_[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
				dCache_m_addr_i_[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2WORDBITSZBY8]};
			dCache_m_sel_i <= dCache_m_sel_i_;
		end else if (iD_isStore || (iD_isSc && _amoUnit_lrValid)) begin
			dCache_m_stb_i <= 1'b1;
			dCache_m_we_i <= 1;
			dCache_m_addr_i <= { // MSB oring of ignored bits.
				|dCache_m_addr_i_[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
				dCache_m_addr_i_[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2WORDBITSZBY8]};
			dCache_m_sel_i <= dCache_m_sel_i_;
			dCache_m_dat_i <= dCache_m_dat_i_;
		end else if (iD_isAMOonly) begin
			amoUnit_opType <= iD_func5;
			dCache_m_stb_i <= 1'b1;
			dCache_m_we_i <= 1'b0;
			dCache_m_we_i_ <= 1'b1;
			dCache_m_addr_i <= { // MSB oring of ignored bits.
				|dCache_m_addr_i_[WORDBITSZ-1:(WORDBITSZ-MSBSZIGN-1)],
				dCache_m_addr_i_[(WORDBITSZ-MSBSZIGN-1)-1:CLOG2WORDBITSZBY8]};
			dCache_m_sel_i <= dCache_m_sel_i_;
			dCache_m_dat_i <= dCache_m_dat_i_;
		end else if (!_dCache_m_bsy_o) begin
			dCache_m_stb_i <= 1'b0;
		end
	end else if (!_dCache_m_bsy_o) begin
		dCache_m_stb_i <= 1'b0;
	end
end

reg dcache_m_addr_misaligned; // ### comb-block-reg.

generate if (WORDBITSZ == 32) begin
always_comb begin
	dCache_m_sel_i_ = {(WORDBITSZ/8){1'b0}};
	dCache_m_dat_i_ = {WORDBITSZ{1'b0}};
	dcache_m_addr_misaligned = 0;
	unique if (iD_func3[1:0] == 0) begin
		unique if (dCache_m_addr_i_[1:0] == 0) begin
			dCache_m_sel_i_ = 4'b0001;
			dCache_m_dat_i_ = {{24{1'b0}}, iD_rs2[7:0]};
		end else if (dCache_m_addr_i_[1:0] == 1) begin
			dCache_m_sel_i_ = 4'b0010;
			dCache_m_dat_i_ = {{16{1'b0}}, iD_rs2[7:0], {8{1'b0}}};
		end else if (dCache_m_addr_i_[1:0] == 2) begin
			dCache_m_sel_i_ = 4'b0100;
			dCache_m_dat_i_ = {{8{1'b0}}, iD_rs2[7:0], {16{1'b0}}};
		end else if (dCache_m_addr_i_[1:0] == 3) begin
			dCache_m_sel_i_ = 4'b1000;
			dCache_m_dat_i_ = {iD_rs2[7:0], {24{1'b0}}};
		end
	end else if (iD_func3[1:0] == 1) begin
		unique if (dCache_m_addr_i_[1]) begin
			dCache_m_sel_i_ = 4'b1100;
			dCache_m_dat_i_ = {iD_rs2[15:0], {16{1'b0}}};
		end else begin
			dCache_m_sel_i_ = 4'b0011;
			dCache_m_dat_i_ = {{16{1'b0}}, iD_rs2[15:0]};
		end
		dcache_m_addr_misaligned = dCache_m_addr_i_[0];
	end else if (iD_func3[1:0] == 2) begin
		dCache_m_sel_i_ = 4'b1111;
		dCache_m_dat_i_ = iD_rs2;
		dcache_m_addr_misaligned = (|dCache_m_addr_i_[1:0]);
	end else;
end
end endgenerate
generate if (WORDBITSZ == 64) begin
always_comb begin
	dCache_m_sel_i_ = {(WORDBITSZ/8){1'b0}};
	dCache_m_dat_i_ = {WORDBITSZ{1'b0}};
	dcache_m_addr_misaligned = 0;
	unique if (iD_func3[1:0] == 0) begin
		unique if (dCache_m_addr_i_[2:0] == 0) begin
			dCache_m_sel_i_ = 8'b00000001;
			dCache_m_dat_i_ = {{56{1'b0}}, iD_rs2[7:0]};
		end else if (dCache_m_addr_i_[2:0] == 1) begin
			dCache_m_sel_i_ = 8'b00000010;
			dCache_m_dat_i_ = {{48{1'b0}}, iD_rs2[7:0], {8{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 2) begin
			dCache_m_sel_i_ = 8'b00000100;
			dCache_m_dat_i_ = {{40{1'b0}}, iD_rs2[7:0], {16{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 3) begin
			dCache_m_sel_i_ = 8'b00001000;
			dCache_m_dat_i_ = {{32{1'b0}}, iD_rs2[7:0], {24{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 4) begin
			dCache_m_sel_i_ = 8'b00010000;
			dCache_m_dat_i_ = {{24{1'b0}}, iD_rs2[7:0], {32{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 5) begin
			dCache_m_sel_i_ = 8'b00100000;
			dCache_m_dat_i_ = {{16{1'b0}}, iD_rs2[7:0], {40{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 6) begin
			dCache_m_sel_i_ = 8'b01000000;
			dCache_m_dat_i_ = {{8{1'b0}}, iD_rs2[7:0], {48{1'b0}}};
		end else if (dCache_m_addr_i_[2:0] == 7) begin
			dCache_m_sel_i_ = 8'b10000000;
			dCache_m_dat_i_ = {iD_rs2[7:0], {56{1'b0}}};
		end
	end else if (iD_func3[1:0] == 1) begin
		unique if (dCache_m_addr_i_[2:1] == 0) begin
			dCache_m_sel_i_ = 8'b00000011;
			dCache_m_dat_i_ = {{48{1'b0}}, iD_rs2[15:0]};
		end else if (dCache_m_addr_i_[2:1] == 1) begin
			dCache_m_sel_i_ = 8'b00001100;
			dCache_m_dat_i_ = {{32{1'b0}}, iD_rs2[15:0], {16{1'b0}}};
		end else if (dCache_m_addr_i_[2:1] == 2) begin
			dCache_m_sel_i_ = 8'b00110000;
			dCache_m_dat_i_ = {{16{1'b0}}, iD_rs2[15:0], {32{1'b0}}};
		end else if (dCache_m_addr_i_[2:1] == 3) begin
			dCache_m_sel_i_ = 8'b11000000;
			dCache_m_dat_i_ = {iD_rs2[15:0], {48{1'b0}}};
		end
		dcache_m_addr_misaligned = dCache_m_addr_i_[0];
	end else if (iD_func3[1:0] == 2) begin
		unique if (dCache_m_addr_i_[2]) begin
			dCache_m_sel_i_ = 8'b11110000;
			dCache_m_dat_i_ = {iD_rs2[31:0], {32{1'b0}}};
		end else begin
			dCache_m_sel_i_ = 8'b00001111;
			dCache_m_dat_i_ = {{32{1'b0}}, iD_rs2[31:0]};
		end
		dcache_m_addr_misaligned = (|dCache_m_addr_i_[1:0]);
	end else if (iD_func3[1:0] == 3) begin
		dCache_m_sel_i_ = 8'b11111111;
		dCache_m_dat_i_ = iD_rs2;
		dcache_m_addr_misaligned = (|dCache_m_addr_i_[2:0]);
	end
end
end endgenerate

reg amoUnit_lrValid_r;
always_ff @(posedge clk_i)
	amoUnit_lrValid_r <= amoUnit_lrValid;
wire amoUnit_lrValid_negedge = (!amoUnit_lrValid && amoUnit_lrValid_r);

reg keep_wb_cyc_o_high; // Used by AMO and Lr instructions to keep wb_cyc_o high.
always_ff @(posedge clk_i) begin
	// Note that keep_wb_cyc_o_high is not cleared by dCache_s_ack_i because it
	// needs to be cleared when the write portion of the AMO instruction is captured.
	if (dCache_s_stb_o)
		keep_wb_cyc_o_high <= (amoUnit_lrValid || dCache_m_we_i_);
	else if (amoUnit_lrValid_negedge)
		keep_wb_cyc_o_high <= 0;
end
