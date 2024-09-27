// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Load Unit.

wire ldUnit_memAck;

wire ldUnit_rqsts_empty;
reg ldUnit_rqsts_empty_r;
always @ (posedge clk_i) begin
	if (rst_i)
		ldUnit_rqsts_empty_r <= 1'b1;
	else if (ldUnit_rqsts_empty_r || ldUnit_memAck)
		ldUnit_rqsts_empty_r <= ldUnit_rqsts_empty;
end

wire [WORDBITSZ -1 : 0]     ldUnit_rqsts_dato;
wire [(WORDBITSZ/8) -1 : 0] ldUnit_rqsts_sel;
wire                        ldUnit_rqsts_zxt;
// Apropriately set ldUnit_rqsts_dato depending on ldUnit_rqsts_sel.
generate if (WORDBITSZ == 32) begin
assign ldUnit_rqsts_dato = (
	(ldUnit_rqsts_sel == 4'b1100) ?
		{{16{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:16]} :
	(ldUnit_rqsts_sel == 4'b0011) ?
		{{16{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:0]} :
	(ldUnit_rqsts_sel == 4'b1000) ?
		{{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:24]} :
	(ldUnit_rqsts_sel == 4'b0100) ?
		{{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[23]}}, dCache_m_dat_o[23:16]} :
	(ldUnit_rqsts_sel == 4'b0010) ?
		{{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:8]} :
	(ldUnit_rqsts_sel == 4'b0001) ?
		{{24{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[7]}},  dCache_m_dat_o[7:0]} :
		                                                     dCache_m_dat_o);
end endgenerate
generate if (WORDBITSZ == 64) begin
assign ldUnit_rqsts_dato =
	(ldUnit_rqsts_sel == 8'b11110000) ?
		{{32{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:32]} :
	(ldUnit_rqsts_sel == 8'b00001111) ?
		{{32{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:0]} :
	(ldUnit_rqsts_sel == 8'b11000000) ?
		{{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:48]} :
	(ldUnit_rqsts_sel == 8'b00110000) ?
		{{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[47]}}, dCache_m_dat_o[47:32]} :
	(ldUnit_rqsts_sel == 8'b00001100) ?
		{{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:16]} :
	(ldUnit_rqsts_sel == 8'b00000011) ?
		{{48{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:0]} :
	(ldUnit_rqsts_sel == 8'b10000000) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[63]}}, dCache_m_dat_o[63:56]} :
	(ldUnit_rqsts_sel == 8'b01000000) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[55]}}, dCache_m_dat_o[55:48]} :
	(ldUnit_rqsts_sel == 8'b00100000) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[47]}}, dCache_m_dat_o[47:40]} :
	(ldUnit_rqsts_sel == 8'b00010000) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[39]}}, dCache_m_dat_o[39:32]} :
	(ldUnit_rqsts_sel == 8'b00001000) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[31]}}, dCache_m_dat_o[31:24]} :
	(ldUnit_rqsts_sel == 8'b00000100) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[23]}}, dCache_m_dat_o[23:16]} :
	(ldUnit_rqsts_sel == 8'b00000010) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[15]}}, dCache_m_dat_o[15:8]} :
	(ldUnit_rqsts_sel == 8'b00000001) ?
		{{56{ldUnit_rqsts_zxt ? 1'b0 : dCache_m_dat_o[7]}},  dCache_m_dat_o[7:0]} :
		                                                     dCache_m_dat_o;
end endgenerate

// This signal is connected to ldUnit_rqsts.near_full_o instead
// of ldUnit_rqsts.full_o because ldUnit_rqstSeqs will become full
// before ldUnit_rqsts.
wire ldUnit_rqsts_full;

assign iD_ldUnit_bsy = (ldUnit_rqsts_full || __dCache_m_bsy);

wire ldUnit_stb = (iD_ldUnit_stb && iD_insn_valid);

wire [CLOG2GPRCNT -1 : 0] ldUnit_rqsts_rIdx;
wire                      ldUnit_rqsts_isAMO;

fifo #(
	 .WIDTH (1 + 1 + CLOG2GPRCNT + (WORDBITSZ/8))
	,.DEPTH (MAXPENDINGACK)
) ldUnit_rqsts (
	 .rst_i       (rst_i)
	,.clk_write_i (clk_i)
	,.write_i     (ldUnit_stb)
	,.data_i      ({iD_isAMO, iD_func3[2], iD_rdId, dCache_m_sel_i_})
	,.near_full_o (ldUnit_rqsts_full)
	,.clk_read_i  (clk_i)
	,.read_i      (ldUnit_rqsts_empty_r || ldUnit_memAck)
	,.data_o      ({ldUnit_rqsts_isAMO, ldUnit_rqsts_zxt, ldUnit_rqsts_rIdx, ldUnit_rqsts_sel})
	,.empty_o     (ldUnit_rqsts_empty)
);

wire [CLOG2MAXPENDINGACK -1 : 0] ldUnit_rqstSeqs_seq;

wire ldUnit_rqstSeqs_empty;

fifo_fwft #(
	 .WIDTH (CLOG2MAXPENDINGACK)
	,.DEPTH (MAXPENDINGACK)
) ldUnit_rqstSeqs (
	 .rst_i      (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (_dCache_m_stb_i && !dCache_m_we_i)
	,.data_i     (dCache_m_rqst_cnt)
	,.clk_pop_i  (clk_i)
	,.pop_i      (ldUnit_memAck)
	,.data_o     (ldUnit_rqstSeqs_seq)
	,.empty_o    (ldUnit_rqstSeqs_empty)
);

assign ldUnit_memAck = (
	dCache_m_ack_o && !ldUnit_rqstSeqs_empty &&
	ldUnit_rqstSeqs_seq == dCache_m_rsp_cnt);

// Store Unit.

assign iD_stUnit_bsy = __dCache_m_bsy;

// AMO Unit.

assign amoUnit_memAck = (ldUnit_memAck && ldUnit_rqsts_isAMO);

wire iD_isLr_and_insn_valid = (iD_isLr && iD_insn_valid);

always @ (posedge clk_i) begin
	if (rst_i || eX_JumpOrBranch || (iD_cancelLr && iD_insn_valid)) begin
		// Per spec, cancel load reservation on taken branch,
		// jump, system, fence, loads, stores instructions.
		amoUnit_lrValid <= 1'b0;
	end else if (iD_isLr_and_insn_valid) begin
		amoUnit_lrValid <= 1'b1;
	end
end

reg [WORDBITSZ -1 : 0] amoUnit_LrAddr;

always @ (posedge clk_i) begin
	if (iD_isLr_and_insn_valid)
		amoUnit_LrAddr <= dCache_m_addr_i_;
end

assign _amoUnit_lrValid = (amoUnit_lrValid && (amoUnit_LrAddr == dCache_m_addr_i_));

assign eX_StoreCondOut_i = {{(WORDBITSZ-1){1'b0}}, !amoUnit_lrValid};
