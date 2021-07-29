// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire [2 -1 : 0]             m_pi1q_op_w    [PI1QMASTERCOUNT -1 : 0];
wire [ADDRBITSZ -1 : 0]     m_pi1q_addr_w  [PI1QMASTERCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     m_pi1q_data_w1 [PI1QMASTERCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     m_pi1q_data_w0 [PI1QMASTERCOUNT -1 : 0];
wire [(ARCHBITSZ/8) -1 : 0] m_pi1q_sel_w   [PI1QMASTERCOUNT -1 : 0];
wire                        m_pi1q_rdy_w   [PI1QMASTERCOUNT -1 : 0];

wire [2 -1 : 0]             s_pi1q_op_w;
wire [ADDRBITSZ -1 : 0]     s_pi1q_addr_w;
wire [ARCHBITSZ -1 : 0]     s_pi1q_data_w0;
wire [ARCHBITSZ -1 : 0]     s_pi1q_data_w1;
wire [(ARCHBITSZ/8) -1 : 0] s_pi1q_sel_w;
wire                        s_pi1q_rdy_w;

localparam PI1QMASTERCOUNT_ = (1 << clog2(PI1QMASTERCOUNT));

wire [(2 * PI1QMASTERCOUNT_) -1 : 0]            m_pi1q_op_w_flat;
wire [(ADDRBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_addr_w_flat;
wire [(ARCHBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_data_w1_flat;
wire [(ARCHBITSZ * PI1QMASTERCOUNT) -1 : 0]     m_pi1q_data_w0_flat;
wire [((ARCHBITSZ/8) * PI1QMASTERCOUNT) -1 : 0] m_pi1q_sel_w_flat;
wire [PI1QMASTERCOUNT -1 : 0]                   m_pi1q_rdy_w_flat;

genvar i;

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_op_w_flat_0
assign m_pi1q_op_w_flat[((i+1) * 2) -1 : i * 2] = m_pi1q_op_w[i];
end endgenerate
generate for (i = PI1QMASTERCOUNT; i < PI1QMASTERCOUNT_; i = i + 1) begin :gen_m_pi1q_op_w_flat_1
assign m_pi1q_op_w_flat[((i+1) * 2) -1 : i * 2] = 2'b00;
end endgenerate

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_addr_w_flat
assign m_pi1q_addr_w_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ] = m_pi1q_addr_w[i];
end endgenerate

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_data_w1_flat
assign m_pi1q_data_w1_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ] = m_pi1q_data_w1[i];
end endgenerate

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_data_w0
assign m_pi1q_data_w0[i] = m_pi1q_data_w0_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ];
end endgenerate

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_sel_w_flat
assign m_pi1q_sel_w_flat[((i+1) * (ARCHBITSZ/8)) -1 : i * (ARCHBITSZ/8)] = m_pi1q_sel_w[i];
end endgenerate

generate for (i = 0; i < PI1QMASTERCOUNT; i = i + 1) begin :gen_m_pi1q_rdy_w
assign m_pi1q_rdy_w[i] = m_pi1q_rdy_w_flat[((i+1) * 1) -1 : i * 1];
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
