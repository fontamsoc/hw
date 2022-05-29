// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Instantiation of PerIntR and all its signals.

wire [2 -1 : 0]                 m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
wire [PI1RADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
wire [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
wire [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
wire [(PI1RARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
wire                            m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];

wire [2 -1 : 0]                 s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
wire [PI1RADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
wire [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
wire [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
wire [(PI1RARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
wire                            s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
wire [PI1RARCHBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];

wire [(2 * PI1RMASTERCOUNT) -1 : 0]                 m_pi1r_op_w_flat;
wire [(PI1RADDRBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_addr_w_flat;
wire [(PI1RARCHBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_data_w1_flat;
wire [(PI1RARCHBITSZ * PI1RMASTERCOUNT) -1 : 0]     m_pi1r_data_w0_flat;
wire [((PI1RARCHBITSZ/8) * PI1RMASTERCOUNT) -1 : 0] m_pi1r_sel_w_flat;
wire [PI1RMASTERCOUNT -1 : 0]                       m_pi1r_rdy_w_flat;

wire [(2 * PI1RSLAVECOUNT) -1 : 0]                 s_pi1r_op_w_flat;
wire [(PI1RADDRBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_addr_w_flat;
wire [(PI1RARCHBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_data_w1_flat;
wire [(PI1RARCHBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_data_w0_flat;
wire [((PI1RARCHBITSZ/8) * PI1RSLAVECOUNT) -1 : 0] s_pi1r_sel_w_flat;
wire [PI1RSLAVECOUNT -1 : 0]                       s_pi1r_rdy_w_flat;
wire [(PI1RARCHBITSZ * PI1RSLAVECOUNT) -1 : 0]     s_pi1r_mapsz_w_flat;

genvar gen_m_pi1r_op_w_flat_idx;
generate for (gen_m_pi1r_op_w_flat_idx = 0; gen_m_pi1r_op_w_flat_idx < PI1RMASTERCOUNT; gen_m_pi1r_op_w_flat_idx = gen_m_pi1r_op_w_flat_idx + 1) begin :gen_m_pi1r_op_w_flat
assign m_pi1r_op_w_flat[((gen_m_pi1r_op_w_flat_idx+1) * 2) -1 : gen_m_pi1r_op_w_flat_idx * 2] = m_pi1r_op_w[gen_m_pi1r_op_w_flat_idx];
end endgenerate

genvar gen_m_pi1r_addr_w_flat_idx;
generate for (gen_m_pi1r_addr_w_flat_idx = 0; gen_m_pi1r_addr_w_flat_idx < PI1RMASTERCOUNT; gen_m_pi1r_addr_w_flat_idx = gen_m_pi1r_addr_w_flat_idx + 1) begin :gen_m_pi1r_addr_w_flat
assign m_pi1r_addr_w_flat[((gen_m_pi1r_addr_w_flat_idx+1) * PI1RADDRBITSZ) -1 : gen_m_pi1r_addr_w_flat_idx * PI1RADDRBITSZ] = m_pi1r_addr_w[gen_m_pi1r_addr_w_flat_idx];
end endgenerate

genvar gen_m_pi1r_data_w1_flat_idx;
generate for (gen_m_pi1r_data_w1_flat_idx = 0; gen_m_pi1r_data_w1_flat_idx < PI1RMASTERCOUNT; gen_m_pi1r_data_w1_flat_idx = gen_m_pi1r_data_w1_flat_idx + 1) begin :gen_m_pi1r_data_w1_flat
assign m_pi1r_data_w1_flat[((gen_m_pi1r_data_w1_flat_idx+1) * PI1RARCHBITSZ) -1 : gen_m_pi1r_data_w1_flat_idx * PI1RARCHBITSZ] = m_pi1r_data_w1[gen_m_pi1r_data_w1_flat_idx];
end endgenerate

genvar gen_m_pi1r_data_w0_idx;
generate for (gen_m_pi1r_data_w0_idx = 0; gen_m_pi1r_data_w0_idx < PI1RMASTERCOUNT; gen_m_pi1r_data_w0_idx = gen_m_pi1r_data_w0_idx + 1) begin :gen_m_pi1r_data_w0
assign m_pi1r_data_w0[gen_m_pi1r_data_w0_idx] = m_pi1r_data_w0_flat[((gen_m_pi1r_data_w0_idx+1) * PI1RARCHBITSZ) -1 : gen_m_pi1r_data_w0_idx * PI1RARCHBITSZ];
end endgenerate

genvar gen_m_pi1r_sel_w_flat_idx;
generate for (gen_m_pi1r_sel_w_flat_idx = 0; gen_m_pi1r_sel_w_flat_idx < PI1RMASTERCOUNT; gen_m_pi1r_sel_w_flat_idx = gen_m_pi1r_sel_w_flat_idx + 1) begin :gen_m_pi1r_sel_w_flat
assign m_pi1r_sel_w_flat[((gen_m_pi1r_sel_w_flat_idx+1) * (PI1RARCHBITSZ/8)) -1 : gen_m_pi1r_sel_w_flat_idx * (PI1RARCHBITSZ/8)] = m_pi1r_sel_w[gen_m_pi1r_sel_w_flat_idx];
end endgenerate

genvar gen_m_pi1r_rdy_w_idx;
generate for (gen_m_pi1r_rdy_w_idx = 0; gen_m_pi1r_rdy_w_idx < PI1RMASTERCOUNT; gen_m_pi1r_rdy_w_idx = gen_m_pi1r_rdy_w_idx + 1) begin :gen_m_pi1r_rdy_w
assign m_pi1r_rdy_w[gen_m_pi1r_rdy_w_idx] = m_pi1r_rdy_w_flat[((gen_m_pi1r_rdy_w_idx+1) * 1) -1 : gen_m_pi1r_rdy_w_idx * 1];
end endgenerate

genvar gen_s_pi1r_op_w_idx;
generate for (gen_s_pi1r_op_w_idx = 0; gen_s_pi1r_op_w_idx < PI1RSLAVECOUNT; gen_s_pi1r_op_w_idx = gen_s_pi1r_op_w_idx + 1) begin :gen_s_pi1r_op_w
assign s_pi1r_op_w[gen_s_pi1r_op_w_idx] = s_pi1r_op_w_flat[((gen_s_pi1r_op_w_idx+1) * 2) -1 : gen_s_pi1r_op_w_idx * 2];
end endgenerate

genvar gen_s_pi1r_addr_w_idx;
generate for (gen_s_pi1r_addr_w_idx = 0; gen_s_pi1r_addr_w_idx < PI1RSLAVECOUNT; gen_s_pi1r_addr_w_idx = gen_s_pi1r_addr_w_idx + 1) begin :gen_s_pi1r_addr_w
assign s_pi1r_addr_w[gen_s_pi1r_addr_w_idx] = s_pi1r_addr_w_flat[((gen_s_pi1r_addr_w_idx+1) * PI1RADDRBITSZ) -1 : gen_s_pi1r_addr_w_idx * PI1RADDRBITSZ];
end endgenerate

genvar gen_s_pi1r_data_w1_flat_idx;
generate for (gen_s_pi1r_data_w1_flat_idx = 0; gen_s_pi1r_data_w1_flat_idx < PI1RSLAVECOUNT; gen_s_pi1r_data_w1_flat_idx = gen_s_pi1r_data_w1_flat_idx + 1) begin :gen_s_pi1r_data_w1_flat
assign s_pi1r_data_w1_flat[((gen_s_pi1r_data_w1_flat_idx+1) * PI1RARCHBITSZ) -1 : gen_s_pi1r_data_w1_flat_idx * PI1RARCHBITSZ] = s_pi1r_data_w1[gen_s_pi1r_data_w1_flat_idx];
end endgenerate

genvar gen_s_pi1r_data_w0_idx;
generate for (gen_s_pi1r_data_w0_idx = 0; gen_s_pi1r_data_w0_idx < PI1RSLAVECOUNT; gen_s_pi1r_data_w0_idx = gen_s_pi1r_data_w0_idx + 1) begin :gen_s_pi1r_data_w0
assign s_pi1r_data_w0[gen_s_pi1r_data_w0_idx] = s_pi1r_data_w0_flat[((gen_s_pi1r_data_w0_idx+1) * PI1RARCHBITSZ) -1 : gen_s_pi1r_data_w0_idx * PI1RARCHBITSZ];
end endgenerate

genvar gen_s_pi1r_sel_w_idx;
generate for (gen_s_pi1r_sel_w_idx = 0; gen_s_pi1r_sel_w_idx < PI1RSLAVECOUNT; gen_s_pi1r_sel_w_idx = gen_s_pi1r_sel_w_idx + 1) begin :gen_s_pi1r_sel_w
assign s_pi1r_sel_w[gen_s_pi1r_sel_w_idx] = s_pi1r_sel_w_flat[((gen_s_pi1r_sel_w_idx+1) * (PI1RARCHBITSZ/8)) -1 : gen_s_pi1r_sel_w_idx * (PI1RARCHBITSZ/8)];
end endgenerate

genvar gen_s_pi1r_rdy_w_flat_idx;
generate for (gen_s_pi1r_rdy_w_flat_idx = 0; gen_s_pi1r_rdy_w_flat_idx < PI1RSLAVECOUNT; gen_s_pi1r_rdy_w_flat_idx = gen_s_pi1r_rdy_w_flat_idx + 1) begin :gen_s_pi1r_rdy_w_flat
assign s_pi1r_rdy_w_flat[((gen_s_pi1r_rdy_w_flat_idx+1) * 1) -1 : gen_s_pi1r_rdy_w_flat_idx * 1] = s_pi1r_rdy_w[gen_s_pi1r_rdy_w_flat_idx];
end endgenerate

genvar gen_s_pi1r_mapsz_w_flat_idx;
generate for (gen_s_pi1r_mapsz_w_flat_idx = 0; gen_s_pi1r_mapsz_w_flat_idx < PI1RSLAVECOUNT; gen_s_pi1r_mapsz_w_flat_idx = gen_s_pi1r_mapsz_w_flat_idx + 1) begin :gen_s_pi1r_mapsz_w_flat
assign s_pi1r_mapsz_w_flat[((gen_s_pi1r_mapsz_w_flat_idx+1) * PI1RARCHBITSZ) -1 : gen_s_pi1r_mapsz_w_flat_idx * PI1RARCHBITSZ] = s_pi1r_mapsz_w[gen_s_pi1r_mapsz_w_flat_idx];
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
	,.s_mapsz_i_flat (s_pi1r_mapsz_w_flat)
);
