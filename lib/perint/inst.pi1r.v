// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire [2 -1 : 0]             m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
wire [ADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
wire [(ARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
wire                        m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];

wire [2 -1 : 0]             s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
wire [ADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
wire [(ARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
wire                        s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
wire [ADDRBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];

wire [(2 * PI1RMASTERCOUNT) -1 : 0]             m_pi1r_op_w_flat;
wire [(ADDRBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_addr_w_flat;
wire [(ARCHBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_data_w1_flat;
wire [(ARCHBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_data_w0_flat;
wire [((ARCHBITSZ/8) * PI1RMASTERCOUNT) -1 : 0] m_pi1r_sel_w_flat;
wire [PI1RMASTERCOUNT -1 : 0]                   m_pi1r_rdy_w_flat;

wire [(2 * PI1RSLAVECOUNT) -1 : 0]             s_pi1r_op_w_flat;
wire [(ADDRBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_addr_w_flat;
wire [(ARCHBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_data_w1_flat;
wire [(ARCHBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_data_w0_flat;
wire [((ARCHBITSZ/8) * PI1RSLAVECOUNT) -1 : 0] s_pi1r_sel_w_flat;
wire [PI1RSLAVECOUNT -1 : 0]                   s_pi1r_rdy_w_flat;
wire [(ADDRBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_mapsz_w_flat;

genvar i;

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_op_w_flat
assign m_pi1r_op_w_flat[((i+1) * 2) -1 : i * 2] = m_pi1r_op_w[i];
end endgenerate

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_addr_w_flat
assign m_pi1r_addr_w_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ] = m_pi1r_addr_w[i];
end endgenerate

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_data_w1_flat
assign m_pi1r_data_w1_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ] = m_pi1r_data_w1[i];
end endgenerate

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_data_w0
assign m_pi1r_data_w0[i] = m_pi1r_data_w0_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ];
end endgenerate

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_sel_w_flat
assign m_pi1r_sel_w_flat[((i+1) * (ARCHBITSZ/8)) -1 : i * (ARCHBITSZ/8)] = m_pi1r_sel_w[i];
end endgenerate

generate for (i = 0; i < PI1RMASTERCOUNT; i = i + 1) begin :gen_m_pi1r_rdy_w
assign m_pi1r_rdy_w[i] = m_pi1r_rdy_w_flat[((i+1) * 1) -1 : i * 1];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_op_w
assign s_pi1r_op_w[i] = s_pi1r_op_w_flat[((i+1) * 2) -1 : i * 2];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_addr_w
assign s_pi1r_addr_w[i] = s_pi1r_addr_w_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_data_w1_flat
assign s_pi1r_data_w1_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ] = s_pi1r_data_w1[i];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_data_w0
assign s_pi1r_data_w0[i] = s_pi1r_data_w0_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_sel_w
assign s_pi1r_sel_w[i] = s_pi1r_sel_w_flat[((i+1) * (ARCHBITSZ/8)) -1 : i * (ARCHBITSZ/8)];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_rdy_w_flat
assign s_pi1r_rdy_w_flat[((i+1) * 1) -1 : i * 1] = s_pi1r_rdy_w[i];
end endgenerate

generate for (i = 0; i < PI1RSLAVECOUNT; i = i + 1) begin :gen_s_pi1r_mapsz_w_flat
assign s_pi1r_mapsz_w_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ] = s_pi1r_mapsz_w[i];
end endgenerate

pi1r #(

	 .MASTERCOUNT       (PI1RMASTERCOUNT)
	,.SLAVECOUNT        (PI1RSLAVECOUNT)
	,.DEFAULTSLAVEINDEX (PI1RDEFAULTSLAVEINDEX)
	,.FIRSTSLAVEADDR    (PI1RFIRSTSLAVEADDR)
	,.ARCHBITSZ         (PI1RARCHBITSZ)

) pi1r (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.m_op_i_flat   (m_pi1r_op_w_flat)
	,.m_addr_i_flat (m_pi1r_addr_w_flat)
	,.m_data_i_flat (m_pi1r_data_w1_flat)
	,.m_data_o_flat (m_pi1r_data_w0_flat)
	,.m_sel_i_flat  (m_pi1r_sel_w_flat)
	,.m_rdy_o_flat  (m_pi1r_rdy_w_flat)

	,.s_op_o_flat    (s_pi1r_op_w_flat)
	,.s_addr_o_flat  (s_pi1r_addr_w_flat)
	,.s_data_o_flat  (s_pi1r_data_w0_flat)
	,.s_data_i_flat  (s_pi1r_data_w1_flat)
	,.s_sel_o_flat   (s_pi1r_sel_w_flat)
	,.s_rdy_i_flat   (s_pi1r_rdy_w_flat)
	,.s_mapsz_o_flat (s_pi1r_mapsz_w_flat)
);
