// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Instantiation of PerIntQ and all its signals.

wire [2 -1 : 0]                 m_pi1q_op_w    [PI1QMASTERCOUNT -1 : 0];
wire [PI1QADDRBITSZ -1 : 0]     m_pi1q_addr_w  [PI1QMASTERCOUNT -1 : 0];
wire [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w1 [PI1QMASTERCOUNT -1 : 0];
wire [PI1QARCHBITSZ -1 : 0]     m_pi1q_data_w0 [PI1QMASTERCOUNT -1 : 0];
wire [(PI1QARCHBITSZ/8) -1 : 0] m_pi1q_sel_w   [PI1QMASTERCOUNT -1 : 0];
wire                            m_pi1q_rdy_w   [PI1QMASTERCOUNT -1 : 0];

wire [2 -1 : 0]                 s_pi1q_op_w;
wire [PI1QADDRBITSZ -1 : 0]     s_pi1q_addr_w;
wire [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w0;
wire [PI1QARCHBITSZ -1 : 0]     s_pi1q_data_w1;
wire [(PI1QARCHBITSZ/8) -1 : 0] s_pi1q_sel_w;
wire                            s_pi1q_rdy_w;

localparam PI1QMASTERCOUNT_ = (1 << clog2(PI1QMASTERCOUNT));

wire [(2 * PI1QMASTERCOUNT_) -1 : 0]                m_pi1q_op_w_flat;
wire [(PI1QADDRBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_addr_w_flat;
wire [(PI1QARCHBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_data_w1_flat;
wire [(PI1QARCHBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_data_w0_flat;
wire [((PI1QARCHBITSZ/8) * PI1QMASTERCOUNT) -1 : 0] m_pi1q_sel_w_flat;
wire [PI1QMASTERCOUNT -1 : 0]                       m_pi1q_rdy_w_flat;

genvar gen_m_pi1q_op_w_flat_0_idx;
generate for (gen_m_pi1q_op_w_flat_0_idx = 0; gen_m_pi1q_op_w_flat_0_idx < PI1QMASTERCOUNT; gen_m_pi1q_op_w_flat_0_idx = gen_m_pi1q_op_w_flat_0_idx + 1) begin :gen_m_pi1q_op_w_flat_0
assign m_pi1q_op_w_flat[((gen_m_pi1q_op_w_flat_0_idx+1) * 2) -1 : gen_m_pi1q_op_w_flat_0_idx * 2] = m_pi1q_op_w[gen_m_pi1q_op_w_flat_0_idx];
end endgenerate
genvar gen_m_pi1q_op_w_flat_1_idx;
generate for (gen_m_pi1q_op_w_flat_1_idx = PI1QMASTERCOUNT; gen_m_pi1q_op_w_flat_1_idx < PI1QMASTERCOUNT_; gen_m_pi1q_op_w_flat_1_idx = gen_m_pi1q_op_w_flat_1_idx + 1) begin :gen_m_pi1q_op_w_flat_1
assign m_pi1q_op_w_flat[((gen_m_pi1q_op_w_flat_1_idx+1) * 2) -1 : gen_m_pi1q_op_w_flat_1_idx * 2] = 2'b00;
end endgenerate

genvar gen_m_pi1q_addr_w_flat_idx;
generate for (gen_m_pi1q_addr_w_flat_idx = 0; gen_m_pi1q_addr_w_flat_idx < PI1QMASTERCOUNT; gen_m_pi1q_addr_w_flat_idx = gen_m_pi1q_addr_w_flat_idx + 1) begin :gen_m_pi1q_addr_w_flat
assign m_pi1q_addr_w_flat[((gen_m_pi1q_addr_w_flat_idx+1) * PI1QADDRBITSZ) -1 : gen_m_pi1q_addr_w_flat_idx * PI1QADDRBITSZ] = m_pi1q_addr_w[gen_m_pi1q_addr_w_flat_idx];
end endgenerate

genvar gen_m_pi1q_data_w1_flat_idx;
generate for (gen_m_pi1q_data_w1_flat_idx = 0; gen_m_pi1q_data_w1_flat_idx < PI1QMASTERCOUNT; gen_m_pi1q_data_w1_flat_idx = gen_m_pi1q_data_w1_flat_idx + 1) begin :gen_m_pi1q_data_w1_flat
assign m_pi1q_data_w1_flat[((gen_m_pi1q_data_w1_flat_idx+1) * PI1QARCHBITSZ) -1 : gen_m_pi1q_data_w1_flat_idx * PI1QARCHBITSZ] = m_pi1q_data_w1[gen_m_pi1q_data_w1_flat_idx];
end endgenerate

genvar gen_m_pi1q_data_w0_idx;
generate for (gen_m_pi1q_data_w0_idx = 0; gen_m_pi1q_data_w0_idx < PI1QMASTERCOUNT; gen_m_pi1q_data_w0_idx = gen_m_pi1q_data_w0_idx + 1) begin :gen_m_pi1q_data_w0
assign m_pi1q_data_w0[gen_m_pi1q_data_w0_idx] = m_pi1q_data_w0_flat[((gen_m_pi1q_data_w0_idx+1) * PI1QARCHBITSZ) -1 : gen_m_pi1q_data_w0_idx * PI1QARCHBITSZ];
end endgenerate

genvar gen_m_pi1q_sel_w_flat_idx;
generate for (gen_m_pi1q_sel_w_flat_idx = 0; gen_m_pi1q_sel_w_flat_idx < PI1QMASTERCOUNT; gen_m_pi1q_sel_w_flat_idx = gen_m_pi1q_sel_w_flat_idx + 1) begin :gen_m_pi1q_sel_w_flat
assign m_pi1q_sel_w_flat[((gen_m_pi1q_sel_w_flat_idx+1) * (PI1QARCHBITSZ/8)) -1 : gen_m_pi1q_sel_w_flat_idx * (PI1QARCHBITSZ/8)] = m_pi1q_sel_w[gen_m_pi1q_sel_w_flat_idx];
end endgenerate

genvar gen_m_pi1q_rdy_w_idx;
generate for (gen_m_pi1q_rdy_w_idx = 0; gen_m_pi1q_rdy_w_idx < PI1QMASTERCOUNT; gen_m_pi1q_rdy_w_idx = gen_m_pi1q_rdy_w_idx + 1) begin :gen_m_pi1q_rdy_w
assign m_pi1q_rdy_w[gen_m_pi1q_rdy_w_idx] = m_pi1q_rdy_w_flat[((gen_m_pi1q_rdy_w_idx+1) * 1) -1 : gen_m_pi1q_rdy_w_idx * 1];
end endgenerate

pi1q #(

	 .MASTERCOUNT (PI1QMASTERCOUNT_)
	,.ARCHBITSZ   (PI1QARCHBITSZ)

) pi1q (

	 .rst_i (pi1q_rst_w)

	,.m_clk_i (m_pi1q_clk_w)
	,.s_clk_i (s_pi1q_clk_w)

	,.m_op_i_flat   (m_pi1q_op_w_flat)
	,.m_addr_i_flat (m_pi1q_addr_w_flat)
	,.m_data_i_flat (m_pi1q_data_w1_flat)
	,.m_data_o_flat (m_pi1q_data_w0_flat)
	,.m_sel_i_flat  (m_pi1q_sel_w_flat)
	,.m_rdy_o_flat  (m_pi1q_rdy_w_flat)

	,.s_op_o   (s_pi1q_op_w)
	,.s_addr_o (s_pi1q_addr_w)
	,.s_data_o (s_pi1q_data_w0)
	,.s_data_i (s_pi1q_data_w1)
	,.s_sel_o  (s_pi1q_sel_w)
	,.s_rdy_i  (s_pi1q_rdy_w)
);
