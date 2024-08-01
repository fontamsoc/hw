// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

localparam ICACHETAGBITSZ = (ADDRBITSZ - (CLOG2ICACHESETCNT + CLOG2XWORDBITSZBY8DIFF));

wire                            iCache_nxtway_w;
wire                            iCache_we_w;     /* set in memctrl.pu.v */
wire [CLOG2ICACHESETCNT -1 : 0] iCache_widx_w;   /* set in memctrl.pu.v */
wire [ICACHETAGBITSZ -1 : 0]    iCache_wtag_w;   /* set in memctrl.pu.v */
wire [XWORDBITSZ -1 : 0]        iCache_dati_w;   /* set in memctrl.pu.v */
wire                            iCache_re_w;
wire [CLOG2ICACHESETCNT -1 : 0] iCache0_ridx_w;
wire [ICACHETAGBITSZ -1 : 0]    iCache0_rtag_w;
wire [XWORDBITSZ -1 : 0]        iCache0_dato_w;
wire                            iCache0_hit_w;
wire                            iCache0_rdy_w;

icache #(
	 .WAYCNT   (ICACHEWAYCNT)
	,.SETCNT   (ICACHESETCNT)
	,.TAGBITSZ (ICACHETAGBITSZ)
	,.DATBITSZ (XWORDBITSZ)
) iCache0 (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.invd_i   (1'b0)
	,.nxtway_i (iCache_nxtway_w)
	,.we_i     (iCache_we_w)
	,.widx_i   (iCache_widx_w)
	,.wtag_i   (iCache_wtag_w)
	,.dat_i    (iCache_dati_w)
	,.re_i     (iCache_re_w)
	,.ridx_i   (iCache0_ridx_w)
	,.rtag_i   (iCache0_rtag_w)
	,.dat_o    (iCache0_dato_w)
	,.hit_o    (iCache0_hit_w)
	,.rdy_o    (iCache0_rdy_w)
);

`ifdef PU2NDISSUE
wire [CLOG2ICACHESETCNT -1 : 0] iCache1_ridx_w;
wire [ICACHETAGBITSZ -1 : 0]    iCache1_rtag_w;
wire [XWORDBITSZ -1 : 0]        iCache1_dato_w;
wire                            iCache1_hit_w;
wire                            iCache1_rdy_w;
icache #(
	 .WAYCNT   (ICACHEWAYCNT)
	,.SETCNT   (ICACHESETCNT)
	,.TAGBITSZ (ICACHETAGBITSZ)
	,.DATBITSZ (XWORDBITSZ)
) iCache1 (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.invd_i   (1'b0)
	,.nxtway_i (iCache_nxtway_w)
	,.we_i     (iCache_we_w)
	,.widx_i   (iCache_widx_w)
	,.wtag_i   (iCache_wtag_w)
	,.dat_i    (iCache_dati_w)
	,.re_i     (iCache_re_w)
	,.ridx_i   (iCache1_ridx_w)
	,.rtag_i   (iCache1_rtag_w)
	,.dat_o    (iCache1_dato_w)
	,.hit_o    (iCache1_hit_w)
	,.rdy_o    (iCache1_rdy_w)
);
`endif
