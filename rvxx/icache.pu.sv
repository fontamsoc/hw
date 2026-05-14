// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

localparam ICACHETAGBITSZ = ((ADDRBITSZ-MSBSZIGN) - (CLOG2ICACHESETCNT + CLOG2XWORDBITSZBY8DIFF));

wire                            iCache_invd_w;
wire                            iCache_nxtway_w;
wire                            iCache_we_w;     /* set in memctrl.pu.v */
wire [CLOG2ICACHESETCNT -1 : 0] iCache_widx_w;   /* set in memctrl.pu.v */
wire [ICACHETAGBITSZ -1 : 0]    iCache_wtag_w;   /* set in memctrl.pu.v */
wire [XWORDBITSZ -1 : 0]        iCache_dati_w;   /* set in memctrl.pu.v */
wire                            iCache_re_w;
wire [CLOG2ICACHESETCNT -1 : 0] iCache_ridx_w;
wire [ICACHETAGBITSZ -1 : 0]    iCache_rtag_w;
wire [XWORDBITSZ -1 : 0]        iCache_dato_w;
wire                            iCache_hit_w;
wire                            iCache_rdy_w;

iCache #(
	 .WAYCNT   (ICACHEWAYCNT)
	,.SETCNT   (ICACHESETCNT)
	,.TAGBITSZ (ICACHETAGBITSZ)
	,.DATBITSZ (XWORDBITSZ)
) iCache (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.invd_i   (iCache_invd_w)
	,.nxtway_i (iCache_nxtway_w)
	,.we_i     (iCache_we_w)
	,.widx_i   (iCache_widx_w)
	,.wtag_i   (iCache_wtag_w)
	,.dat_i    (iCache_dati_w)
	,.re_i     (iCache_re_w)
	,.ridx_i   (iCache_ridx_w)
	,.rtag_i   (iCache_rtag_w)
	,.dat_o    (iCache_dato_w)
	,.hit_o    (iCache_hit_w)
	,.rdy_o    (iCache_rdy_w)
);
