// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// WishBone Peripheral Interconnect instantiation.

wire                             m_wbpi_cyc_w  [WBPI_MASTERCOUNT -1 : 0];
wire                             m_wbpi_stb_w  [WBPI_MASTERCOUNT -1 : 0];
wire                             m_wbpi_we_w   [WBPI_MASTERCOUNT -1 : 0];
wire [WBPI_ADDRBITSZ -1 : 0]     m_wbpi_addr_w [WBPI_MASTERCOUNT -1 : 0];
wire [(WBPI_ARCHBITSZ/8) -1 : 0] m_wbpi_sel_w  [WBPI_MASTERCOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dati_w [WBPI_MASTERCOUNT -1 : 0];
wire                             m_wbpi_bsy_w  [WBPI_MASTERCOUNT -1 : 0];
wire                             m_wbpi_ack_w  [WBPI_MASTERCOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dato_w [WBPI_MASTERCOUNT -1 : 0];

wire                             s_wbpi_cyc_w   [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_stb_w   [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_we_w    [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ADDRBITSZ -1 : 0]     s_wbpi_addr_w  [WBPI_SLAVECOUNT -1 : 0];
wire [(WBPI_ARCHBITSZ/8) -1 : 0] s_wbpi_sel_w   [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dato_w  [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_bsy_w   [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_ack_w   [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dati_w  [WBPI_SLAVECOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]          s_wbpi_mapsz_w [WBPI_SLAVECOUNT -1 : 0];

wire [(1 * WBPI_MASTERCOUNT) -1 : 0]                  _m_wbpi_cyc_w;
wire [(1 * WBPI_MASTERCOUNT) -1 : 0]                  _m_wbpi_stb_w;
wire [(1 * WBPI_MASTERCOUNT) -1 : 0]                  _m_wbpi_we_w;
wire [(WBPI_ADDRBITSZ * WBPI_MASTERCOUNT) -1 : 0]     _m_wbpi_addr_w;
wire [((WBPI_ARCHBITSZ/8) * WBPI_MASTERCOUNT) -1 : 0] _m_wbpi_sel_w;
wire [(WBPI_ARCHBITSZ * WBPI_MASTERCOUNT) -1 : 0]     _m_wbpi_dati_w;
wire [(1 * WBPI_MASTERCOUNT) -1 : 0]                  m_wbpi_bsy_w_;
wire [(1 * WBPI_MASTERCOUNT) -1 : 0]                  m_wbpi_ack_w_;
wire [(WBPI_ARCHBITSZ * WBPI_MASTERCOUNT) -1 : 0]     m_wbpi_dato_w_;

wire [(1 * WBPI_SLAVECOUNT) -1 : 0]                  s_wbpi_cyc_w__;
wire [(1 * WBPI_SLAVECOUNT) -1 : 0]                  s_wbpi_stb_w__;
wire [(1 * WBPI_SLAVECOUNT) -1 : 0]                  s_wbpi_we_w__;
wire [(WBPI_ADDRBITSZ * WBPI_SLAVECOUNT) -1 : 0]     s_wbpi_addr_w__;
wire [((WBPI_ARCHBITSZ/8) * WBPI_SLAVECOUNT) -1 : 0] s_wbpi_sel_w__;
wire [(WBPI_ARCHBITSZ * WBPI_SLAVECOUNT) -1 : 0]     s_wbpi_dato_w__;
wire [(1 * WBPI_SLAVECOUNT) -1 : 0]                  __s_wbpi_bsy_w;
wire [(1 * WBPI_SLAVECOUNT) -1 : 0]                  __s_wbpi_ack_w;
wire [(WBPI_ARCHBITSZ * WBPI_SLAVECOUNT) -1 : 0]     __s_wbpi_dati_w;
wire [(WBPI_ARCHBITSZ * WBPI_SLAVECOUNT) -1 : 0]     __s_wbpi_mapsz_w;

wire                             s_wbpi_cyc_w_   [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_stb_w_   [WBPI_SLAVECOUNT -1 : 0];
wire                             s_wbpi_we_w_    [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ADDRBITSZ -1 : 0]     s_wbpi_addr_w_  [WBPI_SLAVECOUNT -1 : 0];
wire [(WBPI_ARCHBITSZ/8) -1 : 0] s_wbpi_sel_w_   [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dato_w_  [WBPI_SLAVECOUNT -1 : 0];
wire                             _s_wbpi_bsy_w   [WBPI_SLAVECOUNT -1 : 0];
wire                             _s_wbpi_ack_w   [WBPI_SLAVECOUNT -1 : 0];
wire [WBPI_ARCHBITSZ -1 : 0]     _s_wbpi_dati_w  [WBPI_SLAVECOUNT -1 : 0];

genvar gen_m_wbpi_idx;
generate for (
	gen_m_wbpi_idx = 0;
	gen_m_wbpi_idx < WBPI_MASTERCOUNT;
	gen_m_wbpi_idx = gen_m_wbpi_idx + 1) begin :gen_m_wbpi

assign _m_wbpi_cyc_w[gen_m_wbpi_idx] = m_wbpi_cyc_w[gen_m_wbpi_idx];

assign _m_wbpi_stb_w[gen_m_wbpi_idx] = m_wbpi_stb_w[gen_m_wbpi_idx];

assign _m_wbpi_we_w[gen_m_wbpi_idx] = m_wbpi_we_w[gen_m_wbpi_idx];

assign _m_wbpi_addr_w[((gen_m_wbpi_idx+1) * WBPI_ADDRBITSZ) -1 : (gen_m_wbpi_idx * WBPI_ADDRBITSZ)] =
	m_wbpi_addr_w[gen_m_wbpi_idx];

assign _m_wbpi_sel_w[((gen_m_wbpi_idx+1) * (WBPI_ARCHBITSZ/8)) -1 : (gen_m_wbpi_idx * (WBPI_ARCHBITSZ/8))] =
	m_wbpi_sel_w[gen_m_wbpi_idx];

assign _m_wbpi_dati_w[((gen_m_wbpi_idx+1) * WBPI_ARCHBITSZ) -1 : (gen_m_wbpi_idx * WBPI_ARCHBITSZ)] =
	m_wbpi_dati_w[gen_m_wbpi_idx];

assign m_wbpi_bsy_w[gen_m_wbpi_idx] = m_wbpi_bsy_w_[gen_m_wbpi_idx];

assign m_wbpi_ack_w[gen_m_wbpi_idx] = m_wbpi_ack_w_[gen_m_wbpi_idx];

assign m_wbpi_dato_w[gen_m_wbpi_idx] =
	m_wbpi_dato_w_[((gen_m_wbpi_idx+1) * WBPI_ARCHBITSZ) -1 : (gen_m_wbpi_idx * WBPI_ARCHBITSZ)];

end endgenerate

genvar gen_s_wbpi_idx;
generate for (
	gen_s_wbpi_idx = 0;
	gen_s_wbpi_idx < WBPI_SLAVECOUNT;
	gen_s_wbpi_idx = gen_s_wbpi_idx + 1) begin :gen_s_wbpi

assign s_wbpi_cyc_w_[gen_s_wbpi_idx] = s_wbpi_cyc_w__[gen_s_wbpi_idx];

assign s_wbpi_stb_w_[gen_s_wbpi_idx] = s_wbpi_stb_w__[gen_s_wbpi_idx];

assign s_wbpi_we_w_[gen_s_wbpi_idx] = s_wbpi_we_w__[gen_s_wbpi_idx];

assign s_wbpi_addr_w_[gen_s_wbpi_idx] =
	s_wbpi_addr_w__[((gen_s_wbpi_idx+1) * WBPI_ADDRBITSZ) -1 : (gen_s_wbpi_idx * WBPI_ADDRBITSZ)];

assign s_wbpi_sel_w_[gen_s_wbpi_idx] =
	s_wbpi_sel_w__[((gen_s_wbpi_idx+1) * (WBPI_ARCHBITSZ/8)) -1 : (gen_s_wbpi_idx * (WBPI_ARCHBITSZ/8))];

assign s_wbpi_dato_w_[gen_s_wbpi_idx] =
	s_wbpi_dato_w__[((gen_s_wbpi_idx+1) * WBPI_ARCHBITSZ) -1 : (gen_s_wbpi_idx * WBPI_ARCHBITSZ)];

assign __s_wbpi_bsy_w[gen_s_wbpi_idx] = _s_wbpi_bsy_w[gen_s_wbpi_idx];

assign __s_wbpi_ack_w[gen_s_wbpi_idx] = _s_wbpi_ack_w[gen_s_wbpi_idx];

assign __s_wbpi_dati_w[((gen_s_wbpi_idx+1) * WBPI_ARCHBITSZ) -1 : (gen_s_wbpi_idx * WBPI_ARCHBITSZ)] =
	_s_wbpi_dati_w[gen_s_wbpi_idx];

assign __s_wbpi_mapsz_w[((gen_s_wbpi_idx+1) * WBPI_ARCHBITSZ) -1 : (gen_s_wbpi_idx * WBPI_ARCHBITSZ)] =
	s_wbpi_mapsz_w[gen_s_wbpi_idx];

if (WBPI_DNSIZR[gen_s_wbpi_idx] && WBPI_ARCHBITSZ > ARCHBITSZ) begin :gen_s_wbpi_dnsizr

wb_dnsizr #(

	 .MARCHBITSZ (WBPI_ARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)

) wb_dnsizr (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.m_wb_cyc_i  (s_wbpi_cyc_w_[gen_s_wbpi_idx])
	,.m_wb_stb_i  (s_wbpi_stb_w_[gen_s_wbpi_idx])
	,.m_wb_we_i   (s_wbpi_we_w_[gen_s_wbpi_idx])
	,.m_wb_addr_i (s_wbpi_addr_w_[gen_s_wbpi_idx])
	,.m_wb_sel_i  (s_wbpi_sel_w_[gen_s_wbpi_idx])
	,.m_wb_dat_i  (s_wbpi_dato_w_[gen_s_wbpi_idx])
	,.m_wb_bsy_o  (_s_wbpi_bsy_w[gen_s_wbpi_idx])
	,.m_wb_ack_o  (_s_wbpi_ack_w[gen_s_wbpi_idx])
	,.m_wb_dat_o  (_s_wbpi_dati_w[gen_s_wbpi_idx])

	,.s_wb_cyc_o  (s_wbpi_cyc_w[gen_s_wbpi_idx])
	,.s_wb_stb_o  (s_wbpi_stb_w[gen_s_wbpi_idx])
	,.s_wb_we_o   (s_wbpi_we_w[gen_s_wbpi_idx])
	,.s_wb_addr_o (s_wbpi_addr_w[gen_s_wbpi_idx])
	,.s_wb_sel_o  (s_wbpi_sel_w[gen_s_wbpi_idx])
	,.s_wb_dat_o  (s_wbpi_dato_w[gen_s_wbpi_idx])
	,.s_wb_bsy_i  (s_wbpi_bsy_w[gen_s_wbpi_idx])
	,.s_wb_ack_i  (s_wbpi_ack_w[gen_s_wbpi_idx])
	,.s_wb_dat_i  (s_wbpi_dati_w[gen_s_wbpi_idx])
);

end else begin

assign s_wbpi_cyc_w[gen_s_wbpi_idx] = s_wbpi_cyc_w_[gen_s_wbpi_idx];
assign s_wbpi_stb_w[gen_s_wbpi_idx] = s_wbpi_stb_w_[gen_s_wbpi_idx];
assign s_wbpi_we_w[gen_s_wbpi_idx] = s_wbpi_we_w_[gen_s_wbpi_idx];
assign s_wbpi_addr_w[gen_s_wbpi_idx] = s_wbpi_addr_w_[gen_s_wbpi_idx];
assign s_wbpi_sel_w[gen_s_wbpi_idx] = s_wbpi_sel_w_[gen_s_wbpi_idx];
assign s_wbpi_dato_w[gen_s_wbpi_idx] = s_wbpi_dato_w_[gen_s_wbpi_idx];
assign _s_wbpi_bsy_w[gen_s_wbpi_idx] = s_wbpi_bsy_w[gen_s_wbpi_idx];
assign _s_wbpi_ack_w[gen_s_wbpi_idx] = s_wbpi_ack_w[gen_s_wbpi_idx];
assign _s_wbpi_dati_w[gen_s_wbpi_idx] = s_wbpi_dati_w[gen_s_wbpi_idx];

end

end endgenerate

wire                             __m_wbpi_cyc_w;
wire                             __m_wbpi_stb_w;
wire                             __m_wbpi_we_w;
wire [WBPI_ADDRBITSZ -1 : 0]     __m_wbpi_addr_w;
wire [(WBPI_ARCHBITSZ/8) -1 : 0] __m_wbpi_sel_w;
wire [WBPI_ARCHBITSZ -1 : 0]     __m_wbpi_dati_w;
wire                             m_wbpi_bsy_w__;
wire                             m_wbpi_ack_w__;
wire [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dato_w__;

wb_arbiter #(

	 .ARCHBITSZ   (WBPI_ARCHBITSZ)
	,.MASTERCOUNT (WBPI_MASTERCOUNT)

) wb_arbiter (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.m_wb_cyc_i  (_m_wbpi_cyc_w)
	,.m_wb_stb_i  (_m_wbpi_stb_w)
	,.m_wb_we_i   (_m_wbpi_we_w)
	,.m_wb_addr_i (_m_wbpi_addr_w)
	,.m_wb_sel_i  (_m_wbpi_sel_w)
	,.m_wb_dat_i  (_m_wbpi_dati_w)
	,.m_wb_bsy_o  (m_wbpi_bsy_w_)
	,.m_wb_ack_o  (m_wbpi_ack_w_)
	,.m_wb_dat_o  (m_wbpi_dato_w_)

	,.s_wb_cyc_o  (__m_wbpi_cyc_w)
	,.s_wb_stb_o  (__m_wbpi_stb_w)
	,.s_wb_we_o   (__m_wbpi_we_w)
	,.s_wb_addr_o (__m_wbpi_addr_w)
	,.s_wb_sel_o  (__m_wbpi_sel_w)
	,.s_wb_dat_o  (__m_wbpi_dati_w)
	,.s_wb_bsy_i  (m_wbpi_bsy_w__)
	,.s_wb_ack_i  (m_wbpi_ack_w__)
	,.s_wb_dat_i  (m_wbpi_dato_w__)
);

wb_mux #(

	 .ARCHBITSZ         (WBPI_ARCHBITSZ)
	,.SLAVECOUNT        (WBPI_SLAVECOUNT)
	,.DEFAULTSLAVEINDEX (WBPI_DEFAULTSLAVEINDEX)
	,.FIRSTSLAVEADDR    (WBPI_FIRSTSLAVEADDR)

) wb_mux (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.m_wb_cyc_i  (__m_wbpi_cyc_w)
	,.m_wb_stb_i  (__m_wbpi_stb_w)
	,.m_wb_we_i   (__m_wbpi_we_w)
	,.m_wb_addr_i (__m_wbpi_addr_w)
	,.m_wb_sel_i  (__m_wbpi_sel_w)
	,.m_wb_dat_i  (__m_wbpi_dati_w)
	,.m_wb_bsy_o  (m_wbpi_bsy_w__)
	,.m_wb_ack_o  (m_wbpi_ack_w__)
	,.m_wb_dat_o  (m_wbpi_dato_w__)

	,.s_wb_cyc_o   (s_wbpi_cyc_w__)
	,.s_wb_stb_o   (s_wbpi_stb_w__)
	,.s_wb_we_o    (s_wbpi_we_w__)
	,.s_wb_addr_o  (s_wbpi_addr_w__)
	,.s_wb_sel_o   (s_wbpi_sel_w__)
	,.s_wb_dat_o   (s_wbpi_dato_w__)
	,.s_wb_bsy_i   (__s_wbpi_bsy_w)
	,.s_wb_ack_i   (__s_wbpi_ack_w)
	,.s_wb_dat_i   (__s_wbpi_dati_w)
	,.s_wb_mapsz_i (__s_wbpi_mapsz_w)
);

`ifdef DEVTBL_V
wire [(ARCHBITSZ * WBPI_SLAVECOUNT) -1 : 0] devtbl_id_w;
wire [ARCHBITSZ -1 : 0]                     dev_id_w[WBPI_SLAVECOUNT -1 : 0];
wire [(ARCHBITSZ * WBPI_SLAVECOUNT) -1 : 0] devtbl_mapsz_w;
wire [WBPI_SLAVECOUNT -1 : 0]               devtbl_useirq_w;
wire [WBPI_SLAVECOUNT -1 : 0]               dev_useirq_w;
genvar gen_devtbl_idx;
generate for (
	gen_devtbl_idx = 0;
	gen_devtbl_idx < WBPI_SLAVECOUNT;
	gen_devtbl_idx = gen_devtbl_idx + 1) begin
assign devtbl_id_w[((gen_devtbl_idx+1) * ARCHBITSZ) -1 : gen_devtbl_idx * ARCHBITSZ] =
	dev_id_w[gen_devtbl_idx];
assign devtbl_mapsz_w[((gen_devtbl_idx+1) * ARCHBITSZ) -1 : gen_devtbl_idx * ARCHBITSZ] =
	s_wbpi_mapsz_w[gen_devtbl_idx];
end endgenerate
assign devtbl_useirq_w = dev_useirq_w;
`endif
