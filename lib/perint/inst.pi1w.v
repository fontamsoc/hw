// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Instantiation of PerIntW and all its signals.

wire [2 -1 : 0]                 m_pi1w_op_w    [PI1WMASTERCOUNT -1 : 0];
wire [PI1WADDRBITSZ -1 : 0]     m_pi1w_addr_w  [PI1WMASTERCOUNT -1 : 0];
wire [PI1WARCHBITSZ -1 : 0]     m_pi1w_data_w1 [PI1WMASTERCOUNT -1 : 0];
wire [PI1WARCHBITSZ -1 : 0]     m_pi1w_data_w0 [PI1WMASTERCOUNT -1 : 0];
wire [(PI1WARCHBITSZ/8) -1 : 0] m_pi1w_sel_w   [PI1WMASTERCOUNT -1 : 0];
wire                            m_pi1w_rdy_w   [PI1WMASTERCOUNT -1 : 0];

wire [2 -1 : 0]                 s_pi1w_op_w    [PI1WSLAVECOUNT -1 : 0];
wire [PI1WADDRBITSZ -1 : 0]     s_pi1w_addr_w  [PI1WSLAVECOUNT -1 : 0];
wire [PI1WARCHBITSZ -1 : 0]     s_pi1w_data_w0 [PI1WSLAVECOUNT -1 : 0];
wire [PI1WARCHBITSZ -1 : 0]     s_pi1w_data_w1 [PI1WSLAVECOUNT -1 : 0];
wire [(PI1WARCHBITSZ/8) -1 : 0] s_pi1w_sel_w   [PI1WSLAVECOUNT -1 : 0];
wire                            s_pi1w_rdy_w   [PI1WSLAVECOUNT -1 : 0];
wire [PI1WARCHBITSZ -1 : 0]     s_pi1w_mapsz_w [PI1WSLAVECOUNT -1 : 0];

wire [(2 * PI1WMASTERCOUNT) -1 : 0]                 m_pi1w_op_w_flat;
wire [(PI1WADDRBITSZ * PI1WMASTERCOUNT) -1 : 0]     m_pi1w_addr_w_flat;
wire [(PI1WARCHBITSZ * PI1WMASTERCOUNT) -1 : 0]     m_pi1w_data_w1_flat;
wire [(PI1WARCHBITSZ * PI1WMASTERCOUNT) -1 : 0]     m_pi1w_data_w0_flat;
wire [((PI1WARCHBITSZ/8) * PI1WMASTERCOUNT) -1 : 0] m_pi1w_sel_w_flat;
wire [PI1WMASTERCOUNT -1 : 0]                       m_pi1w_rdy_w_flat;

wire [(2 * PI1WSLAVECOUNT) -1 : 0]                 s_pi1w_op_w_flat;
wire [(PI1WADDRBITSZ * PI1WSLAVECOUNT) -1 : 0]     s_pi1w_addr_w_flat;
wire [(PI1WARCHBITSZ * PI1WSLAVECOUNT) -1 : 0]     s_pi1w_data_w1_flat;
wire [(PI1WARCHBITSZ * PI1WSLAVECOUNT) -1 : 0]     s_pi1w_data_w0_flat;
wire [((PI1WARCHBITSZ/8) * PI1WSLAVECOUNT) -1 : 0] s_pi1w_sel_w_flat;
wire [PI1WSLAVECOUNT -1 : 0]                       s_pi1w_rdy_w_flat;
wire [(PI1WARCHBITSZ * PI1WSLAVECOUNT) -1 : 0]     s_pi1w_mapsz_w_flat;

genvar gen_m_pi1w_op_w_flat_idx;
generate for (gen_m_pi1w_op_w_flat_idx = 0; gen_m_pi1w_op_w_flat_idx < PI1WMASTERCOUNT; gen_m_pi1w_op_w_flat_idx = gen_m_pi1w_op_w_flat_idx + 1) begin :gen_m_pi1w_op_w_flat
assign m_pi1w_op_w_flat[((gen_m_pi1w_op_w_flat_idx+1) * 2) -1 : gen_m_pi1w_op_w_flat_idx * 2] = m_pi1w_op_w[gen_m_pi1w_op_w_flat_idx];
end endgenerate

genvar gen_m_pi1w_addr_w_flat_idx;
generate for (gen_m_pi1w_addr_w_flat_idx = 0; gen_m_pi1w_addr_w_flat_idx < PI1WMASTERCOUNT; gen_m_pi1w_addr_w_flat_idx = gen_m_pi1w_addr_w_flat_idx + 1) begin :gen_m_pi1w_addr_w_flat
assign m_pi1w_addr_w_flat[((gen_m_pi1w_addr_w_flat_idx+1) * PI1WADDRBITSZ) -1 : gen_m_pi1w_addr_w_flat_idx * PI1WADDRBITSZ] = m_pi1w_addr_w[gen_m_pi1w_addr_w_flat_idx];
end endgenerate

genvar gen_m_pi1w_data_w1_flat_idx;
generate for (gen_m_pi1w_data_w1_flat_idx = 0; gen_m_pi1w_data_w1_flat_idx < PI1WMASTERCOUNT; gen_m_pi1w_data_w1_flat_idx = gen_m_pi1w_data_w1_flat_idx + 1) begin :gen_m_pi1w_data_w1_flat
assign m_pi1w_data_w1_flat[((gen_m_pi1w_data_w1_flat_idx+1) * PI1WARCHBITSZ) -1 : gen_m_pi1w_data_w1_flat_idx * PI1WARCHBITSZ] = m_pi1w_data_w1[gen_m_pi1w_data_w1_flat_idx];
end endgenerate

genvar gen_m_pi1w_data_w0_idx;
generate for (gen_m_pi1w_data_w0_idx = 0; gen_m_pi1w_data_w0_idx < PI1WMASTERCOUNT; gen_m_pi1w_data_w0_idx = gen_m_pi1w_data_w0_idx + 1) begin :gen_m_pi1w_data_w0
assign m_pi1w_data_w0[gen_m_pi1w_data_w0_idx] = m_pi1w_data_w0_flat[((gen_m_pi1w_data_w0_idx+1) * PI1WARCHBITSZ) -1 : gen_m_pi1w_data_w0_idx * PI1WARCHBITSZ];
end endgenerate

genvar gen_m_pi1w_sel_w_flat_idx;
generate for (gen_m_pi1w_sel_w_flat_idx = 0; gen_m_pi1w_sel_w_flat_idx < PI1WMASTERCOUNT; gen_m_pi1w_sel_w_flat_idx = gen_m_pi1w_sel_w_flat_idx + 1) begin :gen_m_pi1w_sel_w_flat
assign m_pi1w_sel_w_flat[((gen_m_pi1w_sel_w_flat_idx+1) * (PI1WARCHBITSZ/8)) -1 : gen_m_pi1w_sel_w_flat_idx * (PI1WARCHBITSZ/8)] = m_pi1w_sel_w[gen_m_pi1w_sel_w_flat_idx];
end endgenerate

genvar gen_m_pi1w_rdy_w_idx;
generate for (gen_m_pi1w_rdy_w_idx = 0; gen_m_pi1w_rdy_w_idx < PI1WMASTERCOUNT; gen_m_pi1w_rdy_w_idx = gen_m_pi1w_rdy_w_idx + 1) begin :gen_m_pi1w_rdy_w
assign m_pi1w_rdy_w[gen_m_pi1w_rdy_w_idx] = m_pi1w_rdy_w_flat[((gen_m_pi1w_rdy_w_idx+1) * 1) -1 : gen_m_pi1w_rdy_w_idx * 1];
end endgenerate

genvar gen_s_pi1w_op_w_idx;
generate for (gen_s_pi1w_op_w_idx = 0; gen_s_pi1w_op_w_idx < PI1WSLAVECOUNT; gen_s_pi1w_op_w_idx = gen_s_pi1w_op_w_idx + 1) begin :gen_s_pi1w_op_w
assign s_pi1w_op_w[gen_s_pi1w_op_w_idx] = s_pi1w_op_w_flat[((gen_s_pi1w_op_w_idx+1) * 2) -1 : gen_s_pi1w_op_w_idx * 2];
end endgenerate

genvar gen_s_pi1w_addr_w_idx;
generate for (gen_s_pi1w_addr_w_idx = 0; gen_s_pi1w_addr_w_idx < PI1WSLAVECOUNT; gen_s_pi1w_addr_w_idx = gen_s_pi1w_addr_w_idx + 1) begin :gen_s_pi1w_addr_w
assign s_pi1w_addr_w[gen_s_pi1w_addr_w_idx] = s_pi1w_addr_w_flat[((gen_s_pi1w_addr_w_idx+1) * PI1WADDRBITSZ) -1 : gen_s_pi1w_addr_w_idx * PI1WADDRBITSZ];
end endgenerate

genvar gen_s_pi1w_data_w1_flat_idx;
generate for (gen_s_pi1w_data_w1_flat_idx = 0; gen_s_pi1w_data_w1_flat_idx < PI1WSLAVECOUNT; gen_s_pi1w_data_w1_flat_idx = gen_s_pi1w_data_w1_flat_idx + 1) begin :gen_s_pi1w_data_w1_flat
assign s_pi1w_data_w1_flat[((gen_s_pi1w_data_w1_flat_idx+1) * PI1WARCHBITSZ) -1 : gen_s_pi1w_data_w1_flat_idx * PI1WARCHBITSZ] = s_pi1w_data_w1[gen_s_pi1w_data_w1_flat_idx];
end endgenerate

genvar gen_s_pi1w_data_w0_idx;
generate for (gen_s_pi1w_data_w0_idx = 0; gen_s_pi1w_data_w0_idx < PI1WSLAVECOUNT; gen_s_pi1w_data_w0_idx = gen_s_pi1w_data_w0_idx + 1) begin :gen_s_pi1w_data_w0
assign s_pi1w_data_w0[gen_s_pi1w_data_w0_idx] = s_pi1w_data_w0_flat[((gen_s_pi1w_data_w0_idx+1) * PI1WARCHBITSZ) -1 : gen_s_pi1w_data_w0_idx * PI1WARCHBITSZ];
end endgenerate

genvar gen_s_pi1w_sel_w_idx;
generate for (gen_s_pi1w_sel_w_idx = 0; gen_s_pi1w_sel_w_idx < PI1WSLAVECOUNT; gen_s_pi1w_sel_w_idx = gen_s_pi1w_sel_w_idx + 1) begin :gen_s_pi1w_sel_w
assign s_pi1w_sel_w[gen_s_pi1w_sel_w_idx] = s_pi1w_sel_w_flat[((gen_s_pi1w_sel_w_idx+1) * (PI1WARCHBITSZ/8)) -1 : gen_s_pi1w_sel_w_idx * (PI1WARCHBITSZ/8)];
end endgenerate

genvar gen_s_pi1w_rdy_w_flat_idx;
generate for (gen_s_pi1w_rdy_w_flat_idx = 0; gen_s_pi1w_rdy_w_flat_idx < PI1WSLAVECOUNT; gen_s_pi1w_rdy_w_flat_idx = gen_s_pi1w_rdy_w_flat_idx + 1) begin :gen_s_pi1w_rdy_w_flat
assign s_pi1w_rdy_w_flat[((gen_s_pi1w_rdy_w_flat_idx+1) * 1) -1 : gen_s_pi1w_rdy_w_flat_idx * 1] = s_pi1w_rdy_w[gen_s_pi1w_rdy_w_flat_idx];
end endgenerate

genvar gen_s_pi1w_mapsz_w_flat_idx;
generate for (gen_s_pi1w_mapsz_w_flat_idx = 0; gen_s_pi1w_mapsz_w_flat_idx < PI1WSLAVECOUNT; gen_s_pi1w_mapsz_w_flat_idx = gen_s_pi1w_mapsz_w_flat_idx + 1) begin :gen_s_pi1w_mapsz_w_flat
assign s_pi1w_mapsz_w_flat[((gen_s_pi1w_mapsz_w_flat_idx+1) * PI1WARCHBITSZ) -1 : gen_s_pi1w_mapsz_w_flat_idx * PI1WARCHBITSZ] = s_pi1w_mapsz_w[gen_s_pi1w_mapsz_w_flat_idx];
end endgenerate

pi1w #(

	 .MASTERCOUNT       (PI1WMASTERCOUNT)
	,.SLAVECOUNT        (PI1WSLAVECOUNT)
	,.DEFAULTSLAVEINDEX (PI1WDEFAULTSLAVEINDEX)
	,.FIRSTSLAVEADDR    (PI1WFIRSTSLAVEADDR)
	,.ARCHBITSZ         (PI1WARCHBITSZ)

) pi1w (

	 .rst_i (pi1w_rst_w)

	,.clk_i (pi1w_clk_w)

	,.m_op_i_flat   (m_pi1w_op_w_flat)
	,.m_addr_i_flat (m_pi1w_addr_w_flat)
	,.m_data_i_flat (m_pi1w_data_w1_flat)
	,.m_data_o_flat (m_pi1w_data_w0_flat)
	,.m_sel_i_flat  (m_pi1w_sel_w_flat)
	,.m_rdy_o_flat  (m_pi1w_rdy_w_flat)

	,.s_op_o_flat    (s_pi1w_op_w_flat)
	,.s_addr_o_flat  (s_pi1w_addr_w_flat)
	,.s_data_o_flat  (s_pi1w_data_w0_flat)
	,.s_data_i_flat  (s_pi1w_data_w1_flat)
	,.s_sel_o_flat   (s_pi1w_sel_w_flat)
	,.s_rdy_i_flat   (s_pi1w_rdy_w_flat)
	,.s_mapsz_i_flat (s_pi1w_mapsz_w_flat)
);
