// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] wb_pending_acks;

wire wb_max_pending = (wb_pending_acks == MAXPENDINGACK);

assign _wb_bsy_i = (wb_bsy_i || wb_max_pending);

reg [CLOG2MAXPENDINGACK -1 : 0] wb_rqst_cnt;
reg [CLOG2MAXPENDINGACK -1 : 0] wb_rsp_cnt;

always @ (posedge clk_i) begin
	if (rst_i)
		wb_rqst_cnt <= 0;
	else if (wb_stb_o && !_wb_bsy_i)
		wb_rqst_cnt <= wb_rqst_cnt + 1'b1;
end

always @ (posedge clk_i) begin
	if (rst_i)
		wb_rsp_cnt <= 0;
	else if (wb_ack_i)
		wb_rsp_cnt <= wb_rsp_cnt + 1'b1;
end

always @ (posedge clk_i) begin
	if (rst_i)
		wb_pending_acks <= 0;
	else if (wb_stb_o && !_wb_bsy_i && wb_ack_i);
	else if (wb_ack_i)
		wb_pending_acks <= wb_pending_acks - 1'b1;
	else if (wb_stb_o && !_wb_bsy_i)
		wb_pending_acks <= wb_pending_acks + 1'b1;
end

reg [CLOG2MAXPENDINGACK -1 : 0] iF0_mem_seq;
reg                             iF0_mem_seq_valid;

assign dCache_s_ack_i = (wb_ack_i && (!iF0_mem_seq_valid || wb_rsp_cnt != iF0_mem_seq));

reg                      iF0_mem_stb;
reg  [XADDRBITSZ -1 : 0] iF0_mem_addr;
wire                     iF0_mem_bsy = (dCache_s_stb_o || _wb_bsy_i);
wire                     iF0_mem_ack = (wb_ack_i && iF0_mem_seq_valid && wb_rsp_cnt == iF0_mem_seq);

assign iCache_we_w   = iF0_mem_ack;
assign iCache_dati_w = wb_dat_i;
assign iCache_widx_w = iF0_mem_addr[CLOG2ICACHESETCNT-1:0];
assign iCache_wtag_w = iF0_mem_addr[(WORDBITSZ-CLOG2XWORDBITSZBY8)-1:CLOG2ICACHESETCNT];

reg iF0_mem_wait;

always @ (posedge clk_i) begin
	if (rst_i) begin
		iF0_mem_stb <= 0;
		iF0_mem_seq_valid <= 0;
		iF0_mem_wait <= 1;
	end else if (iF0_mem_stb) begin
		if (!iF0_mem_bsy) begin
			iF0_mem_seq <= wb_rqst_cnt;
			iF0_mem_seq_valid <= 1;
			iF0_mem_stb <= 0;
		end
	end else if (iF0_mem_seq_valid) begin
		if (iF0_mem_ack) begin
			iF0_mem_seq_valid <= 0;
			iF0_mem_wait <= 1;
		end
	end else if (iF0_mem_wait) begin
		if (iCache_re_w) // Wait for an icache access before checking iCache0_hit_w.
			iF0_mem_wait <= 0;
	end else if (iF0_eX0_JumpOrBranch_i) begin
		iF0_mem_wait <= 1; // Set in order to begin with an icache access on branching.
	end else if (!iCache0_hit_w) begin
		iF0_mem_stb <= iCache0_rdy_w;
		iF0_mem_addr <= iF0_pc[WORDBITSZ-1:CLOG2XWORDBITSZBY8];
	end
end

// Instruction fetching has the least priority so that load
// and store instructions can be completed as soon as possible,
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
	else if (wb_max_pending)
		wb_cyc_o = 1;
	else if (dCache_s_stb_o) begin
		wb_cyc_o = 1;
		wb_stb_o = 1;
		wb_we_o = dCache_s_we_o;
		wb_addr_o = dCache_s_addr_o;
		wb_sel_o = dCache_s_sel_o;
		wb_dat_o = dCache_s_dat_o;
	end else if (iF0_mem_stb) begin
		wb_cyc_o = 1;
		wb_stb_o = 1;
		wb_we_o = 0;
		wb_addr_o = iF0_mem_addr;
		wb_sel_o = {(XWORDBITSZ/8){1'b1}};
	end else
		wb_cyc_o = (|wb_pending_acks);
end
