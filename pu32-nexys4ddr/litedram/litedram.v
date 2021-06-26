module litedram (
	input wire clk,
	input wire rst,
	output wire pll_locked,
	output wire [12:0] ddram_a,
	output wire [2:0] ddram_ba,
	output wire ddram_ras_n,
	output wire ddram_cas_n,
	output wire ddram_we_n,
	output wire ddram_cs_n,
	output wire [1:0] ddram_dm,
	inout wire [15:0] ddram_dq,
	inout wire [1:0] ddram_dqs_p,
	inout wire [1:0] ddram_dqs_n,
	output wire ddram_clk_p,
	output wire ddram_clk_n,
	output wire ddram_cke,
	output wire ddram_odt,
	output wire ddram_reset_n,
	output wire init_done,
	output wire init_error,
	input wire [29:0] wb_ctrl_adr,
	input wire [31:0] wb_ctrl_dat_w,
	output wire [31:0] wb_ctrl_dat_r,
	input wire [3:0] wb_ctrl_sel,
	input wire wb_ctrl_cyc,
	input wire wb_ctrl_stb,
	output wire wb_ctrl_ack,
	input wire wb_ctrl_we,
	input wire [2:0] wb_ctrl_cti,
	input wire [1:0] wb_ctrl_bte,
	output wire wb_ctrl_err,
	output wire user_clk,
	output wire user_rst,
	input wire [23:0] user_port_wishbone_0_adr,
	input wire [63:0] user_port_wishbone_0_dat_w,
	output wire [63:0] user_port_wishbone_0_dat_r,
	input wire [7:0] user_port_wishbone_0_sel,
	input wire user_port_wishbone_0_cyc,
	input wire user_port_wishbone_0_stb,
	output wire user_port_wishbone_0_ack,
	input wire user_port_wishbone_0_we,
	output wire user_port_wishbone_0_err
);

wire sys_clk;
wire sys_rst;
wire sys2x_clk;
wire sys2x_dqs_clk;
wire iodelay_clk;
wire iodelay_rst;
wire main_reset;
wire main_locked;
wire main_clkin;
wire main_clkout0;
wire main_clkout_buf0;
wire main_clkout1;
wire main_clkout_buf1;
wire main_clkout2;
wire main_clkout_buf2;
wire main_clkout3;
wire main_clkout_buf3;
reg [3:0] main_reset_counter = 4'd15;
reg main_ic_reset = 1'd1;
reg main_a7ddrphy_rst_storage = 1'd0;
reg main_a7ddrphy_rst_re = 1'd0;
reg [4:0] main_a7ddrphy_half_sys8x_taps_storage = 5'd16;
reg main_a7ddrphy_half_sys8x_taps_re = 1'd0;
reg main_a7ddrphy_wlevel_en_storage = 1'd0;
reg main_a7ddrphy_wlevel_en_re = 1'd0;
reg main_a7ddrphy_wlevel_strobe_re = 1'd0;
wire main_a7ddrphy_wlevel_strobe_r;
reg main_a7ddrphy_wlevel_strobe_we = 1'd0;
reg main_a7ddrphy_wlevel_strobe_w = 1'd0;
reg [1:0] main_a7ddrphy_dly_sel_storage = 2'd0;
reg main_a7ddrphy_dly_sel_re = 1'd0;
reg main_a7ddrphy_rdly_dq_rst_re = 1'd0;
wire main_a7ddrphy_rdly_dq_rst_r;
reg main_a7ddrphy_rdly_dq_rst_we = 1'd0;
reg main_a7ddrphy_rdly_dq_rst_w = 1'd0;
reg main_a7ddrphy_rdly_dq_inc_re = 1'd0;
wire main_a7ddrphy_rdly_dq_inc_r;
reg main_a7ddrphy_rdly_dq_inc_we = 1'd0;
reg main_a7ddrphy_rdly_dq_inc_w = 1'd0;
reg main_a7ddrphy_rdly_dq_bitslip_rst_re = 1'd0;
wire main_a7ddrphy_rdly_dq_bitslip_rst_r;
reg main_a7ddrphy_rdly_dq_bitslip_rst_we = 1'd0;
reg main_a7ddrphy_rdly_dq_bitslip_rst_w = 1'd0;
reg main_a7ddrphy_rdly_dq_bitslip_re = 1'd0;
wire main_a7ddrphy_rdly_dq_bitslip_r;
reg main_a7ddrphy_rdly_dq_bitslip_we = 1'd0;
reg main_a7ddrphy_rdly_dq_bitslip_w = 1'd0;
reg main_a7ddrphy_wdly_dq_bitslip_rst_re = 1'd0;
wire main_a7ddrphy_wdly_dq_bitslip_rst_r;
reg main_a7ddrphy_wdly_dq_bitslip_rst_we = 1'd0;
reg main_a7ddrphy_wdly_dq_bitslip_rst_w = 1'd0;
reg main_a7ddrphy_wdly_dq_bitslip_re = 1'd0;
wire main_a7ddrphy_wdly_dq_bitslip_r;
reg main_a7ddrphy_wdly_dq_bitslip_we = 1'd0;
reg main_a7ddrphy_wdly_dq_bitslip_w = 1'd0;
reg main_a7ddrphy_rdphase_storage = 1'd1;
reg main_a7ddrphy_rdphase_re = 1'd0;
reg main_a7ddrphy_wrphase_storage = 1'd0;
reg main_a7ddrphy_wrphase_re = 1'd0;
wire [12:0] main_a7ddrphy_dfi_p0_address;
wire [2:0] main_a7ddrphy_dfi_p0_bank;
wire main_a7ddrphy_dfi_p0_cas_n;
wire main_a7ddrphy_dfi_p0_cs_n;
wire main_a7ddrphy_dfi_p0_ras_n;
wire main_a7ddrphy_dfi_p0_we_n;
wire main_a7ddrphy_dfi_p0_cke;
wire main_a7ddrphy_dfi_p0_odt;
wire main_a7ddrphy_dfi_p0_reset_n;
wire main_a7ddrphy_dfi_p0_act_n;
wire [31:0] main_a7ddrphy_dfi_p0_wrdata;
wire main_a7ddrphy_dfi_p0_wrdata_en;
wire [3:0] main_a7ddrphy_dfi_p0_wrdata_mask;
wire main_a7ddrphy_dfi_p0_rddata_en;
reg [31:0] main_a7ddrphy_dfi_p0_rddata = 32'd0;
wire main_a7ddrphy_dfi_p0_rddata_valid;
wire [12:0] main_a7ddrphy_dfi_p1_address;
wire [2:0] main_a7ddrphy_dfi_p1_bank;
wire main_a7ddrphy_dfi_p1_cas_n;
wire main_a7ddrphy_dfi_p1_cs_n;
wire main_a7ddrphy_dfi_p1_ras_n;
wire main_a7ddrphy_dfi_p1_we_n;
wire main_a7ddrphy_dfi_p1_cke;
wire main_a7ddrphy_dfi_p1_odt;
wire main_a7ddrphy_dfi_p1_reset_n;
wire main_a7ddrphy_dfi_p1_act_n;
wire [31:0] main_a7ddrphy_dfi_p1_wrdata;
wire main_a7ddrphy_dfi_p1_wrdata_en;
wire [3:0] main_a7ddrphy_dfi_p1_wrdata_mask;
wire main_a7ddrphy_dfi_p1_rddata_en;
reg [31:0] main_a7ddrphy_dfi_p1_rddata = 32'd0;
wire main_a7ddrphy_dfi_p1_rddata_valid;
reg [12:0] main_a7ddrphy_dfi_p2_address = 13'd0;
reg [2:0] main_a7ddrphy_dfi_p2_bank = 3'd0;
reg main_a7ddrphy_dfi_p2_cas_n = 1'd1;
reg main_a7ddrphy_dfi_p2_cs_n = 1'd1;
reg main_a7ddrphy_dfi_p2_ras_n = 1'd1;
reg main_a7ddrphy_dfi_p2_we_n = 1'd1;
reg main_a7ddrphy_dfi_p2_cke = 1'd0;
reg main_a7ddrphy_dfi_p2_odt = 1'd0;
reg main_a7ddrphy_dfi_p2_reset_n = 1'd0;
reg [31:0] main_a7ddrphy_dfi_p2_wrdata = 32'd0;
reg [3:0] main_a7ddrphy_dfi_p2_wrdata_mask = 4'd0;
reg [31:0] main_a7ddrphy_dfi_p2_rddata = 32'd0;
wire main_a7ddrphy_dfi_p2_rddata_valid;
reg [12:0] main_a7ddrphy_dfi_p3_address = 13'd0;
reg [2:0] main_a7ddrphy_dfi_p3_bank = 3'd0;
reg main_a7ddrphy_dfi_p3_cas_n = 1'd1;
reg main_a7ddrphy_dfi_p3_cs_n = 1'd1;
reg main_a7ddrphy_dfi_p3_ras_n = 1'd1;
reg main_a7ddrphy_dfi_p3_we_n = 1'd1;
reg main_a7ddrphy_dfi_p3_cke = 1'd0;
reg main_a7ddrphy_dfi_p3_odt = 1'd0;
reg main_a7ddrphy_dfi_p3_reset_n = 1'd0;
reg [31:0] main_a7ddrphy_dfi_p3_wrdata = 32'd0;
reg [3:0] main_a7ddrphy_dfi_p3_wrdata_mask = 4'd0;
reg [31:0] main_a7ddrphy_dfi_p3_rddata = 32'd0;
wire main_a7ddrphy_dfi_p3_rddata_valid;
wire main_a7ddrphy_sd_clk_se_nodelay;
reg main_a7ddrphy_dqs_oe = 1'd0;
wire main_a7ddrphy_dqs_preamble;
wire main_a7ddrphy_dqs_postamble;
wire main_a7ddrphy_dqs_oe_delay_tappeddelayline;
reg main_a7ddrphy_dqs_oe_delay_tappeddelayline_tappeddelayline = 1'd0;
reg main_a7ddrphy_dqspattern0 = 1'd0;
reg main_a7ddrphy_dqspattern1 = 1'd0;
reg [7:0] main_a7ddrphy_dqspattern_o0 = 8'd0;
reg [7:0] main_a7ddrphy_dqspattern_o1 = 8'd0;
wire main_a7ddrphy_dqs_o_no_delay0;
wire main_a7ddrphy_dqs_t0;
reg [7:0] main_a7ddrphy_bitslip00 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip0_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip0_r0 = 16'd0;
wire main_a7ddrphy0;
wire main_a7ddrphy_dqs_o_no_delay1;
wire main_a7ddrphy_dqs_t1;
reg [7:0] main_a7ddrphy_bitslip10 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip1_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip1_r0 = 16'd0;
wire main_a7ddrphy1;
reg [7:0] main_a7ddrphy_bitslip01 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip0_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip0_r1 = 16'd0;
reg [7:0] main_a7ddrphy_bitslip11 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip1_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip1_r1 = 16'd0;
wire main_a7ddrphy_dq_oe;
wire main_a7ddrphy_dq_oe_delay_tappeddelayline;
reg main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline = 1'd0;
wire main_a7ddrphy_dq_o_nodelay0;
wire main_a7ddrphy_dq_i_nodelay0;
wire main_a7ddrphy_dq_i_delayed0;
wire main_a7ddrphy_dq_t0;
reg [7:0] main_a7ddrphy_bitslip02 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip0_value2 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip0_r2 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip03;
reg [7:0] main_a7ddrphy_bitslip04 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip0_value3 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip0_r3 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay1;
wire main_a7ddrphy_dq_i_nodelay1;
wire main_a7ddrphy_dq_i_delayed1;
wire main_a7ddrphy_dq_t1;
reg [7:0] main_a7ddrphy_bitslip12 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip1_value2 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip1_r2 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip13;
reg [7:0] main_a7ddrphy_bitslip14 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip1_value3 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip1_r3 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay2;
wire main_a7ddrphy_dq_i_nodelay2;
wire main_a7ddrphy_dq_i_delayed2;
wire main_a7ddrphy_dq_t2;
reg [7:0] main_a7ddrphy_bitslip20 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip2_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip2_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip21;
reg [7:0] main_a7ddrphy_bitslip22 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip2_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip2_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay3;
wire main_a7ddrphy_dq_i_nodelay3;
wire main_a7ddrphy_dq_i_delayed3;
wire main_a7ddrphy_dq_t3;
reg [7:0] main_a7ddrphy_bitslip30 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip3_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip3_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip31;
reg [7:0] main_a7ddrphy_bitslip32 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip3_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip3_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay4;
wire main_a7ddrphy_dq_i_nodelay4;
wire main_a7ddrphy_dq_i_delayed4;
wire main_a7ddrphy_dq_t4;
reg [7:0] main_a7ddrphy_bitslip40 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip4_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip4_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip41;
reg [7:0] main_a7ddrphy_bitslip42 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip4_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip4_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay5;
wire main_a7ddrphy_dq_i_nodelay5;
wire main_a7ddrphy_dq_i_delayed5;
wire main_a7ddrphy_dq_t5;
reg [7:0] main_a7ddrphy_bitslip50 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip5_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip5_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip51;
reg [7:0] main_a7ddrphy_bitslip52 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip5_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip5_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay6;
wire main_a7ddrphy_dq_i_nodelay6;
wire main_a7ddrphy_dq_i_delayed6;
wire main_a7ddrphy_dq_t6;
reg [7:0] main_a7ddrphy_bitslip60 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip6_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip6_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip61;
reg [7:0] main_a7ddrphy_bitslip62 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip6_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip6_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay7;
wire main_a7ddrphy_dq_i_nodelay7;
wire main_a7ddrphy_dq_i_delayed7;
wire main_a7ddrphy_dq_t7;
reg [7:0] main_a7ddrphy_bitslip70 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip7_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip7_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip71;
reg [7:0] main_a7ddrphy_bitslip72 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip7_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip7_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay8;
wire main_a7ddrphy_dq_i_nodelay8;
wire main_a7ddrphy_dq_i_delayed8;
wire main_a7ddrphy_dq_t8;
reg [7:0] main_a7ddrphy_bitslip80 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip8_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip8_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip81;
reg [7:0] main_a7ddrphy_bitslip82 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip8_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip8_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay9;
wire main_a7ddrphy_dq_i_nodelay9;
wire main_a7ddrphy_dq_i_delayed9;
wire main_a7ddrphy_dq_t9;
reg [7:0] main_a7ddrphy_bitslip90 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip9_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip9_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip91;
reg [7:0] main_a7ddrphy_bitslip92 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip9_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip9_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay10;
wire main_a7ddrphy_dq_i_nodelay10;
wire main_a7ddrphy_dq_i_delayed10;
wire main_a7ddrphy_dq_t10;
reg [7:0] main_a7ddrphy_bitslip100 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip10_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip10_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip101;
reg [7:0] main_a7ddrphy_bitslip102 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip10_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip10_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay11;
wire main_a7ddrphy_dq_i_nodelay11;
wire main_a7ddrphy_dq_i_delayed11;
wire main_a7ddrphy_dq_t11;
reg [7:0] main_a7ddrphy_bitslip110 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip11_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip11_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip111;
reg [7:0] main_a7ddrphy_bitslip112 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip11_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip11_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay12;
wire main_a7ddrphy_dq_i_nodelay12;
wire main_a7ddrphy_dq_i_delayed12;
wire main_a7ddrphy_dq_t12;
reg [7:0] main_a7ddrphy_bitslip120 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip12_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip12_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip121;
reg [7:0] main_a7ddrphy_bitslip122 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip12_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip12_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay13;
wire main_a7ddrphy_dq_i_nodelay13;
wire main_a7ddrphy_dq_i_delayed13;
wire main_a7ddrphy_dq_t13;
reg [7:0] main_a7ddrphy_bitslip130 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip13_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip13_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip131;
reg [7:0] main_a7ddrphy_bitslip132 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip13_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip13_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay14;
wire main_a7ddrphy_dq_i_nodelay14;
wire main_a7ddrphy_dq_i_delayed14;
wire main_a7ddrphy_dq_t14;
reg [7:0] main_a7ddrphy_bitslip140 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip14_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip14_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip141;
reg [7:0] main_a7ddrphy_bitslip142 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip14_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip14_r1 = 16'd0;
wire main_a7ddrphy_dq_o_nodelay15;
wire main_a7ddrphy_dq_i_nodelay15;
wire main_a7ddrphy_dq_i_delayed15;
wire main_a7ddrphy_dq_t15;
reg [7:0] main_a7ddrphy_bitslip150 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip15_value0 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip15_r0 = 16'd0;
wire [7:0] main_a7ddrphy_bitslip151;
reg [7:0] main_a7ddrphy_bitslip152 = 8'd0;
reg [2:0] main_a7ddrphy_bitslip15_value1 = 3'd7;
reg [15:0] main_a7ddrphy_bitslip15_r1 = 16'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline0 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline1 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline2 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline3 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline4 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline5 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline6 = 1'd0;
reg main_a7ddrphy_rddata_en_tappeddelayline7 = 1'd0;
reg main_a7ddrphy_wrdata_en_tappeddelayline0 = 1'd0;
reg main_a7ddrphy_wrdata_en_tappeddelayline1 = 1'd0;
wire [12:0] main_litedramcore_inti_p0_address;
wire [2:0] main_litedramcore_inti_p0_bank;
reg main_litedramcore_inti_p0_cas_n = 1'd1;
reg main_litedramcore_inti_p0_cs_n = 1'd1;
reg main_litedramcore_inti_p0_ras_n = 1'd1;
reg main_litedramcore_inti_p0_we_n = 1'd1;
wire main_litedramcore_inti_p0_cke;
wire main_litedramcore_inti_p0_odt;
wire main_litedramcore_inti_p0_reset_n;
reg main_litedramcore_inti_p0_act_n = 1'd1;
wire [31:0] main_litedramcore_inti_p0_wrdata;
wire main_litedramcore_inti_p0_wrdata_en;
wire [3:0] main_litedramcore_inti_p0_wrdata_mask;
wire main_litedramcore_inti_p0_rddata_en;
reg [31:0] main_litedramcore_inti_p0_rddata = 32'd0;
reg main_litedramcore_inti_p0_rddata_valid = 1'd0;
wire [12:0] main_litedramcore_inti_p1_address;
wire [2:0] main_litedramcore_inti_p1_bank;
reg main_litedramcore_inti_p1_cas_n = 1'd1;
reg main_litedramcore_inti_p1_cs_n = 1'd1;
reg main_litedramcore_inti_p1_ras_n = 1'd1;
reg main_litedramcore_inti_p1_we_n = 1'd1;
wire main_litedramcore_inti_p1_cke;
wire main_litedramcore_inti_p1_odt;
wire main_litedramcore_inti_p1_reset_n;
reg main_litedramcore_inti_p1_act_n = 1'd1;
wire [31:0] main_litedramcore_inti_p1_wrdata;
wire main_litedramcore_inti_p1_wrdata_en;
wire [3:0] main_litedramcore_inti_p1_wrdata_mask;
wire main_litedramcore_inti_p1_rddata_en;
reg [31:0] main_litedramcore_inti_p1_rddata = 32'd0;
reg main_litedramcore_inti_p1_rddata_valid = 1'd0;
wire [12:0] main_litedramcore_slave_p0_address;
wire [2:0] main_litedramcore_slave_p0_bank;
wire main_litedramcore_slave_p0_cas_n;
wire main_litedramcore_slave_p0_cs_n;
wire main_litedramcore_slave_p0_ras_n;
wire main_litedramcore_slave_p0_we_n;
wire main_litedramcore_slave_p0_cke;
wire main_litedramcore_slave_p0_odt;
wire main_litedramcore_slave_p0_reset_n;
wire main_litedramcore_slave_p0_act_n;
wire [31:0] main_litedramcore_slave_p0_wrdata;
wire main_litedramcore_slave_p0_wrdata_en;
wire [3:0] main_litedramcore_slave_p0_wrdata_mask;
wire main_litedramcore_slave_p0_rddata_en;
reg [31:0] main_litedramcore_slave_p0_rddata = 32'd0;
reg main_litedramcore_slave_p0_rddata_valid = 1'd0;
wire [12:0] main_litedramcore_slave_p1_address;
wire [2:0] main_litedramcore_slave_p1_bank;
wire main_litedramcore_slave_p1_cas_n;
wire main_litedramcore_slave_p1_cs_n;
wire main_litedramcore_slave_p1_ras_n;
wire main_litedramcore_slave_p1_we_n;
wire main_litedramcore_slave_p1_cke;
wire main_litedramcore_slave_p1_odt;
wire main_litedramcore_slave_p1_reset_n;
wire main_litedramcore_slave_p1_act_n;
wire [31:0] main_litedramcore_slave_p1_wrdata;
wire main_litedramcore_slave_p1_wrdata_en;
wire [3:0] main_litedramcore_slave_p1_wrdata_mask;
wire main_litedramcore_slave_p1_rddata_en;
reg [31:0] main_litedramcore_slave_p1_rddata = 32'd0;
reg main_litedramcore_slave_p1_rddata_valid = 1'd0;
reg [12:0] main_litedramcore_master_p0_address = 13'd0;
reg [2:0] main_litedramcore_master_p0_bank = 3'd0;
reg main_litedramcore_master_p0_cas_n = 1'd1;
reg main_litedramcore_master_p0_cs_n = 1'd1;
reg main_litedramcore_master_p0_ras_n = 1'd1;
reg main_litedramcore_master_p0_we_n = 1'd1;
reg main_litedramcore_master_p0_cke = 1'd0;
reg main_litedramcore_master_p0_odt = 1'd0;
reg main_litedramcore_master_p0_reset_n = 1'd0;
reg main_litedramcore_master_p0_act_n = 1'd1;
reg [31:0] main_litedramcore_master_p0_wrdata = 32'd0;
reg main_litedramcore_master_p0_wrdata_en = 1'd0;
reg [3:0] main_litedramcore_master_p0_wrdata_mask = 4'd0;
reg main_litedramcore_master_p0_rddata_en = 1'd0;
wire [31:0] main_litedramcore_master_p0_rddata;
wire main_litedramcore_master_p0_rddata_valid;
reg [12:0] main_litedramcore_master_p1_address = 13'd0;
reg [2:0] main_litedramcore_master_p1_bank = 3'd0;
reg main_litedramcore_master_p1_cas_n = 1'd1;
reg main_litedramcore_master_p1_cs_n = 1'd1;
reg main_litedramcore_master_p1_ras_n = 1'd1;
reg main_litedramcore_master_p1_we_n = 1'd1;
reg main_litedramcore_master_p1_cke = 1'd0;
reg main_litedramcore_master_p1_odt = 1'd0;
reg main_litedramcore_master_p1_reset_n = 1'd0;
reg main_litedramcore_master_p1_act_n = 1'd1;
reg [31:0] main_litedramcore_master_p1_wrdata = 32'd0;
reg main_litedramcore_master_p1_wrdata_en = 1'd0;
reg [3:0] main_litedramcore_master_p1_wrdata_mask = 4'd0;
reg main_litedramcore_master_p1_rddata_en = 1'd0;
wire [31:0] main_litedramcore_master_p1_rddata;
wire main_litedramcore_master_p1_rddata_valid;
wire main_litedramcore_sel;
wire main_litedramcore_cke;
wire main_litedramcore_odt;
wire main_litedramcore_reset_n;
reg [3:0] main_litedramcore_storage = 4'd1;
reg main_litedramcore_re = 1'd0;
reg [5:0] main_litedramcore_phaseinjector0_command_storage = 6'd0;
reg main_litedramcore_phaseinjector0_command_re = 1'd0;
reg main_litedramcore_phaseinjector0_command_issue_re = 1'd0;
wire main_litedramcore_phaseinjector0_command_issue_r;
reg main_litedramcore_phaseinjector0_command_issue_we = 1'd0;
reg main_litedramcore_phaseinjector0_command_issue_w = 1'd0;
reg [12:0] main_litedramcore_phaseinjector0_address_storage = 13'd0;
reg main_litedramcore_phaseinjector0_address_re = 1'd0;
reg [2:0] main_litedramcore_phaseinjector0_baddress_storage = 3'd0;
reg main_litedramcore_phaseinjector0_baddress_re = 1'd0;
reg [31:0] main_litedramcore_phaseinjector0_wrdata_storage = 32'd0;
reg main_litedramcore_phaseinjector0_wrdata_re = 1'd0;
reg [31:0] main_litedramcore_phaseinjector0_rddata_status = 32'd0;
wire main_litedramcore_phaseinjector0_rddata_we;
reg main_litedramcore_phaseinjector0_rddata_re = 1'd0;
reg [5:0] main_litedramcore_phaseinjector1_command_storage = 6'd0;
reg main_litedramcore_phaseinjector1_command_re = 1'd0;
reg main_litedramcore_phaseinjector1_command_issue_re = 1'd0;
wire main_litedramcore_phaseinjector1_command_issue_r;
reg main_litedramcore_phaseinjector1_command_issue_we = 1'd0;
reg main_litedramcore_phaseinjector1_command_issue_w = 1'd0;
reg [12:0] main_litedramcore_phaseinjector1_address_storage = 13'd0;
reg main_litedramcore_phaseinjector1_address_re = 1'd0;
reg [2:0] main_litedramcore_phaseinjector1_baddress_storage = 3'd0;
reg main_litedramcore_phaseinjector1_baddress_re = 1'd0;
reg [31:0] main_litedramcore_phaseinjector1_wrdata_storage = 32'd0;
reg main_litedramcore_phaseinjector1_wrdata_re = 1'd0;
reg [31:0] main_litedramcore_phaseinjector1_rddata_status = 32'd0;
wire main_litedramcore_phaseinjector1_rddata_we;
reg main_litedramcore_phaseinjector1_rddata_re = 1'd0;
wire main_litedramcore_interface_bank0_valid;
wire main_litedramcore_interface_bank0_ready;
wire main_litedramcore_interface_bank0_we;
wire [20:0] main_litedramcore_interface_bank0_addr;
wire main_litedramcore_interface_bank0_lock;
wire main_litedramcore_interface_bank0_wdata_ready;
wire main_litedramcore_interface_bank0_rdata_valid;
wire main_litedramcore_interface_bank1_valid;
wire main_litedramcore_interface_bank1_ready;
wire main_litedramcore_interface_bank1_we;
wire [20:0] main_litedramcore_interface_bank1_addr;
wire main_litedramcore_interface_bank1_lock;
wire main_litedramcore_interface_bank1_wdata_ready;
wire main_litedramcore_interface_bank1_rdata_valid;
wire main_litedramcore_interface_bank2_valid;
wire main_litedramcore_interface_bank2_ready;
wire main_litedramcore_interface_bank2_we;
wire [20:0] main_litedramcore_interface_bank2_addr;
wire main_litedramcore_interface_bank2_lock;
wire main_litedramcore_interface_bank2_wdata_ready;
wire main_litedramcore_interface_bank2_rdata_valid;
wire main_litedramcore_interface_bank3_valid;
wire main_litedramcore_interface_bank3_ready;
wire main_litedramcore_interface_bank3_we;
wire [20:0] main_litedramcore_interface_bank3_addr;
wire main_litedramcore_interface_bank3_lock;
wire main_litedramcore_interface_bank3_wdata_ready;
wire main_litedramcore_interface_bank3_rdata_valid;
wire main_litedramcore_interface_bank4_valid;
wire main_litedramcore_interface_bank4_ready;
wire main_litedramcore_interface_bank4_we;
wire [20:0] main_litedramcore_interface_bank4_addr;
wire main_litedramcore_interface_bank4_lock;
wire main_litedramcore_interface_bank4_wdata_ready;
wire main_litedramcore_interface_bank4_rdata_valid;
wire main_litedramcore_interface_bank5_valid;
wire main_litedramcore_interface_bank5_ready;
wire main_litedramcore_interface_bank5_we;
wire [20:0] main_litedramcore_interface_bank5_addr;
wire main_litedramcore_interface_bank5_lock;
wire main_litedramcore_interface_bank5_wdata_ready;
wire main_litedramcore_interface_bank5_rdata_valid;
wire main_litedramcore_interface_bank6_valid;
wire main_litedramcore_interface_bank6_ready;
wire main_litedramcore_interface_bank6_we;
wire [20:0] main_litedramcore_interface_bank6_addr;
wire main_litedramcore_interface_bank6_lock;
wire main_litedramcore_interface_bank6_wdata_ready;
wire main_litedramcore_interface_bank6_rdata_valid;
wire main_litedramcore_interface_bank7_valid;
wire main_litedramcore_interface_bank7_ready;
wire main_litedramcore_interface_bank7_we;
wire [20:0] main_litedramcore_interface_bank7_addr;
wire main_litedramcore_interface_bank7_lock;
wire main_litedramcore_interface_bank7_wdata_ready;
wire main_litedramcore_interface_bank7_rdata_valid;
reg [63:0] main_litedramcore_interface_wdata = 64'd0;
reg [7:0] main_litedramcore_interface_wdata_we = 8'd0;
wire [63:0] main_litedramcore_interface_rdata;
reg [12:0] main_litedramcore_dfi_p0_address = 13'd0;
reg [2:0] main_litedramcore_dfi_p0_bank = 3'd0;
reg main_litedramcore_dfi_p0_cas_n = 1'd1;
reg main_litedramcore_dfi_p0_cs_n = 1'd1;
reg main_litedramcore_dfi_p0_ras_n = 1'd1;
reg main_litedramcore_dfi_p0_we_n = 1'd1;
wire main_litedramcore_dfi_p0_cke;
wire main_litedramcore_dfi_p0_odt;
wire main_litedramcore_dfi_p0_reset_n;
reg main_litedramcore_dfi_p0_act_n = 1'd1;
wire [31:0] main_litedramcore_dfi_p0_wrdata;
reg main_litedramcore_dfi_p0_wrdata_en = 1'd0;
wire [3:0] main_litedramcore_dfi_p0_wrdata_mask;
reg main_litedramcore_dfi_p0_rddata_en = 1'd0;
wire [31:0] main_litedramcore_dfi_p0_rddata;
wire main_litedramcore_dfi_p0_rddata_valid;
reg [12:0] main_litedramcore_dfi_p1_address = 13'd0;
reg [2:0] main_litedramcore_dfi_p1_bank = 3'd0;
reg main_litedramcore_dfi_p1_cas_n = 1'd1;
reg main_litedramcore_dfi_p1_cs_n = 1'd1;
reg main_litedramcore_dfi_p1_ras_n = 1'd1;
reg main_litedramcore_dfi_p1_we_n = 1'd1;
wire main_litedramcore_dfi_p1_cke;
wire main_litedramcore_dfi_p1_odt;
wire main_litedramcore_dfi_p1_reset_n;
reg main_litedramcore_dfi_p1_act_n = 1'd1;
wire [31:0] main_litedramcore_dfi_p1_wrdata;
reg main_litedramcore_dfi_p1_wrdata_en = 1'd0;
wire [3:0] main_litedramcore_dfi_p1_wrdata_mask;
reg main_litedramcore_dfi_p1_rddata_en = 1'd0;
wire [31:0] main_litedramcore_dfi_p1_rddata;
wire main_litedramcore_dfi_p1_rddata_valid;
reg main_litedramcore_cmd_valid = 1'd0;
reg main_litedramcore_cmd_ready = 1'd0;
reg main_litedramcore_cmd_last = 1'd0;
reg [12:0] main_litedramcore_cmd_payload_a = 13'd0;
reg [2:0] main_litedramcore_cmd_payload_ba = 3'd0;
reg main_litedramcore_cmd_payload_cas = 1'd0;
reg main_litedramcore_cmd_payload_ras = 1'd0;
reg main_litedramcore_cmd_payload_we = 1'd0;
reg main_litedramcore_cmd_payload_is_read = 1'd0;
reg main_litedramcore_cmd_payload_is_write = 1'd0;
wire main_litedramcore_wants_refresh;
wire main_litedramcore_timer_wait;
wire main_litedramcore_timer_done0;
wire [9:0] main_litedramcore_timer_count0;
wire main_litedramcore_timer_done1;
reg [9:0] main_litedramcore_timer_count1 = 10'd781;
wire main_litedramcore_postponer_req_i;
reg main_litedramcore_postponer_req_o = 1'd0;
reg main_litedramcore_postponer_count = 1'd0;
reg main_litedramcore_sequencer_start0 = 1'd0;
wire main_litedramcore_sequencer_done0;
wire main_litedramcore_sequencer_start1;
reg main_litedramcore_sequencer_done1 = 1'd0;
reg [4:0] main_litedramcore_sequencer_counter = 5'd0;
reg main_litedramcore_sequencer_count = 1'd0;
wire main_litedramcore_bankmachine0_req_valid;
wire main_litedramcore_bankmachine0_req_ready;
wire main_litedramcore_bankmachine0_req_we;
wire [20:0] main_litedramcore_bankmachine0_req_addr;
wire main_litedramcore_bankmachine0_req_lock;
reg main_litedramcore_bankmachine0_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine0_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine0_refresh_req;
reg main_litedramcore_bankmachine0_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine0_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine0_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine0_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine0_cmd_payload_ba;
reg main_litedramcore_bankmachine0_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine0_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine0_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine0_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine0_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine0_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine0_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_we;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_re;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_readable;
wire [23:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_din;
wire [23:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout;
reg [4:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine0_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine0_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine0_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine0_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine0_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine0_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine0_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine0_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine0_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine0_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine0_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine0_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine0_row = 13'd0;
reg main_litedramcore_bankmachine0_row_opened = 1'd0;
wire main_litedramcore_bankmachine0_row_hit;
reg main_litedramcore_bankmachine0_row_open = 1'd0;
reg main_litedramcore_bankmachine0_row_close = 1'd0;
reg main_litedramcore_bankmachine0_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine0_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine0_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine0_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine0_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine0_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine0_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine0_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine1_req_valid;
wire main_litedramcore_bankmachine1_req_ready;
wire main_litedramcore_bankmachine1_req_we;
wire [20:0] main_litedramcore_bankmachine1_req_addr;
wire main_litedramcore_bankmachine1_req_lock;
reg main_litedramcore_bankmachine1_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine1_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine1_refresh_req;
reg main_litedramcore_bankmachine1_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine1_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine1_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine1_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine1_cmd_payload_ba;
reg main_litedramcore_bankmachine1_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine1_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine1_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine1_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine1_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine1_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine1_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_we;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_re;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_readable;
wire [23:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_din;
wire [23:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout;
reg [4:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine1_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine1_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine1_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine1_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine1_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine1_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine1_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine1_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine1_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine1_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine1_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine1_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine1_row = 13'd0;
reg main_litedramcore_bankmachine1_row_opened = 1'd0;
wire main_litedramcore_bankmachine1_row_hit;
reg main_litedramcore_bankmachine1_row_open = 1'd0;
reg main_litedramcore_bankmachine1_row_close = 1'd0;
reg main_litedramcore_bankmachine1_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine1_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine1_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine1_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine1_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine1_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine1_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine1_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine2_req_valid;
wire main_litedramcore_bankmachine2_req_ready;
wire main_litedramcore_bankmachine2_req_we;
wire [20:0] main_litedramcore_bankmachine2_req_addr;
wire main_litedramcore_bankmachine2_req_lock;
reg main_litedramcore_bankmachine2_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine2_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine2_refresh_req;
reg main_litedramcore_bankmachine2_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine2_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine2_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine2_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine2_cmd_payload_ba;
reg main_litedramcore_bankmachine2_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine2_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine2_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine2_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine2_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine2_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine2_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_we;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_re;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_readable;
wire [23:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_din;
wire [23:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout;
reg [4:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine2_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine2_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine2_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine2_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine2_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine2_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine2_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine2_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine2_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine2_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine2_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine2_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine2_row = 13'd0;
reg main_litedramcore_bankmachine2_row_opened = 1'd0;
wire main_litedramcore_bankmachine2_row_hit;
reg main_litedramcore_bankmachine2_row_open = 1'd0;
reg main_litedramcore_bankmachine2_row_close = 1'd0;
reg main_litedramcore_bankmachine2_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine2_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine2_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine2_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine2_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine2_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine2_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine2_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine3_req_valid;
wire main_litedramcore_bankmachine3_req_ready;
wire main_litedramcore_bankmachine3_req_we;
wire [20:0] main_litedramcore_bankmachine3_req_addr;
wire main_litedramcore_bankmachine3_req_lock;
reg main_litedramcore_bankmachine3_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine3_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine3_refresh_req;
reg main_litedramcore_bankmachine3_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine3_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine3_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine3_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine3_cmd_payload_ba;
reg main_litedramcore_bankmachine3_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine3_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine3_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine3_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine3_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine3_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine3_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_we;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_re;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_readable;
wire [23:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_din;
wire [23:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout;
reg [4:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine3_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine3_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine3_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine3_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine3_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine3_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine3_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine3_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine3_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine3_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine3_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine3_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine3_row = 13'd0;
reg main_litedramcore_bankmachine3_row_opened = 1'd0;
wire main_litedramcore_bankmachine3_row_hit;
reg main_litedramcore_bankmachine3_row_open = 1'd0;
reg main_litedramcore_bankmachine3_row_close = 1'd0;
reg main_litedramcore_bankmachine3_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine3_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine3_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine3_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine3_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine3_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine3_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine3_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine4_req_valid;
wire main_litedramcore_bankmachine4_req_ready;
wire main_litedramcore_bankmachine4_req_we;
wire [20:0] main_litedramcore_bankmachine4_req_addr;
wire main_litedramcore_bankmachine4_req_lock;
reg main_litedramcore_bankmachine4_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine4_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine4_refresh_req;
reg main_litedramcore_bankmachine4_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine4_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine4_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine4_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine4_cmd_payload_ba;
reg main_litedramcore_bankmachine4_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine4_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine4_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine4_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine4_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine4_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine4_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_we;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_re;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_readable;
wire [23:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_din;
wire [23:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout;
reg [4:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine4_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine4_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine4_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine4_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine4_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine4_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine4_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine4_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine4_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine4_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine4_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine4_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine4_row = 13'd0;
reg main_litedramcore_bankmachine4_row_opened = 1'd0;
wire main_litedramcore_bankmachine4_row_hit;
reg main_litedramcore_bankmachine4_row_open = 1'd0;
reg main_litedramcore_bankmachine4_row_close = 1'd0;
reg main_litedramcore_bankmachine4_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine4_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine4_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine4_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine4_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine4_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine4_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine4_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine5_req_valid;
wire main_litedramcore_bankmachine5_req_ready;
wire main_litedramcore_bankmachine5_req_we;
wire [20:0] main_litedramcore_bankmachine5_req_addr;
wire main_litedramcore_bankmachine5_req_lock;
reg main_litedramcore_bankmachine5_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine5_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine5_refresh_req;
reg main_litedramcore_bankmachine5_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine5_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine5_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine5_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine5_cmd_payload_ba;
reg main_litedramcore_bankmachine5_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine5_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine5_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine5_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine5_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine5_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine5_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_we;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_re;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_readable;
wire [23:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_din;
wire [23:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout;
reg [4:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine5_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine5_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine5_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine5_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine5_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine5_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine5_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine5_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine5_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine5_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine5_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine5_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine5_row = 13'd0;
reg main_litedramcore_bankmachine5_row_opened = 1'd0;
wire main_litedramcore_bankmachine5_row_hit;
reg main_litedramcore_bankmachine5_row_open = 1'd0;
reg main_litedramcore_bankmachine5_row_close = 1'd0;
reg main_litedramcore_bankmachine5_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine5_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine5_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine5_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine5_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine5_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine5_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine5_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine6_req_valid;
wire main_litedramcore_bankmachine6_req_ready;
wire main_litedramcore_bankmachine6_req_we;
wire [20:0] main_litedramcore_bankmachine6_req_addr;
wire main_litedramcore_bankmachine6_req_lock;
reg main_litedramcore_bankmachine6_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine6_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine6_refresh_req;
reg main_litedramcore_bankmachine6_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine6_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine6_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine6_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine6_cmd_payload_ba;
reg main_litedramcore_bankmachine6_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine6_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine6_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine6_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine6_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine6_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine6_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_we;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_re;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_readable;
wire [23:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_din;
wire [23:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout;
reg [4:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine6_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine6_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine6_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine6_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine6_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine6_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine6_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine6_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine6_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine6_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine6_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine6_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine6_row = 13'd0;
reg main_litedramcore_bankmachine6_row_opened = 1'd0;
wire main_litedramcore_bankmachine6_row_hit;
reg main_litedramcore_bankmachine6_row_open = 1'd0;
reg main_litedramcore_bankmachine6_row_close = 1'd0;
reg main_litedramcore_bankmachine6_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine6_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine6_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine6_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine6_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine6_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine6_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine6_trascon_ready = 1'd1;
wire main_litedramcore_bankmachine7_req_valid;
wire main_litedramcore_bankmachine7_req_ready;
wire main_litedramcore_bankmachine7_req_we;
wire [20:0] main_litedramcore_bankmachine7_req_addr;
wire main_litedramcore_bankmachine7_req_lock;
reg main_litedramcore_bankmachine7_req_wdata_ready = 1'd0;
reg main_litedramcore_bankmachine7_req_rdata_valid = 1'd0;
wire main_litedramcore_bankmachine7_refresh_req;
reg main_litedramcore_bankmachine7_refresh_gnt = 1'd0;
reg main_litedramcore_bankmachine7_cmd_valid = 1'd0;
reg main_litedramcore_bankmachine7_cmd_ready = 1'd0;
reg [12:0] main_litedramcore_bankmachine7_cmd_payload_a = 13'd0;
wire [2:0] main_litedramcore_bankmachine7_cmd_payload_ba;
reg main_litedramcore_bankmachine7_cmd_payload_cas = 1'd0;
reg main_litedramcore_bankmachine7_cmd_payload_ras = 1'd0;
reg main_litedramcore_bankmachine7_cmd_payload_we = 1'd0;
reg main_litedramcore_bankmachine7_cmd_payload_is_cmd = 1'd0;
reg main_litedramcore_bankmachine7_cmd_payload_is_read = 1'd0;
reg main_litedramcore_bankmachine7_cmd_payload_is_write = 1'd0;
reg main_litedramcore_bankmachine7_auto_precharge = 1'd0;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_valid;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_ready;
reg main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_first = 1'd0;
reg main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_last = 1'd0;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_addr;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_valid;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_ready;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_first;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_last;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_we;
wire [20:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_addr;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_we;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_re;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_readable;
wire [23:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_din;
wire [23:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout;
reg [4:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_level = 5'd0;
reg main_litedramcore_bankmachine7_cmd_buffer_lookahead_replace = 1'd0;
reg [3:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce = 4'd0;
reg [3:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_consume = 4'd0;
reg [3:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr = 4'd0;
wire [23:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_dat_r;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_we;
wire [23:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_dat_w;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_do_read;
wire [3:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_adr;
wire [23:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_dat_r;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_we;
wire [20:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_addr;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_first;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_last;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we;
wire [20:0] main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first;
wire main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last;
wire main_litedramcore_bankmachine7_cmd_buffer_sink_valid;
wire main_litedramcore_bankmachine7_cmd_buffer_sink_ready;
wire main_litedramcore_bankmachine7_cmd_buffer_sink_first;
wire main_litedramcore_bankmachine7_cmd_buffer_sink_last;
wire main_litedramcore_bankmachine7_cmd_buffer_sink_payload_we;
wire [20:0] main_litedramcore_bankmachine7_cmd_buffer_sink_payload_addr;
reg main_litedramcore_bankmachine7_cmd_buffer_source_valid = 1'd0;
wire main_litedramcore_bankmachine7_cmd_buffer_source_ready;
reg main_litedramcore_bankmachine7_cmd_buffer_source_first = 1'd0;
reg main_litedramcore_bankmachine7_cmd_buffer_source_last = 1'd0;
reg main_litedramcore_bankmachine7_cmd_buffer_source_payload_we = 1'd0;
reg [20:0] main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr = 21'd0;
reg [12:0] main_litedramcore_bankmachine7_row = 13'd0;
reg main_litedramcore_bankmachine7_row_opened = 1'd0;
wire main_litedramcore_bankmachine7_row_hit;
reg main_litedramcore_bankmachine7_row_open = 1'd0;
reg main_litedramcore_bankmachine7_row_close = 1'd0;
reg main_litedramcore_bankmachine7_row_col_n_addr_sel = 1'd0;
wire main_litedramcore_bankmachine7_twtpcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine7_twtpcon_ready = 1'd0;
reg [1:0] main_litedramcore_bankmachine7_twtpcon_count = 2'd0;
wire main_litedramcore_bankmachine7_trccon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine7_trccon_ready = 1'd1;
wire main_litedramcore_bankmachine7_trascon_valid;
(* dont_touch = "true" *) reg main_litedramcore_bankmachine7_trascon_ready = 1'd1;
wire main_litedramcore_ras_allowed;
wire main_litedramcore_cas_allowed;
wire main_litedramcore_rdcmdphase;
wire main_litedramcore_wrcmdphase;
reg main_litedramcore_choose_cmd_want_reads = 1'd0;
reg main_litedramcore_choose_cmd_want_writes = 1'd0;
reg main_litedramcore_choose_cmd_want_cmds = 1'd0;
reg main_litedramcore_choose_cmd_want_activates = 1'd0;
wire main_litedramcore_choose_cmd_cmd_valid;
reg main_litedramcore_choose_cmd_cmd_ready = 1'd0;
wire [12:0] main_litedramcore_choose_cmd_cmd_payload_a;
wire [2:0] main_litedramcore_choose_cmd_cmd_payload_ba;
reg main_litedramcore_choose_cmd_cmd_payload_cas = 1'd0;
reg main_litedramcore_choose_cmd_cmd_payload_ras = 1'd0;
reg main_litedramcore_choose_cmd_cmd_payload_we = 1'd0;
wire main_litedramcore_choose_cmd_cmd_payload_is_cmd;
wire main_litedramcore_choose_cmd_cmd_payload_is_read;
wire main_litedramcore_choose_cmd_cmd_payload_is_write;
reg [7:0] main_litedramcore_choose_cmd_valids = 8'd0;
wire [7:0] main_litedramcore_choose_cmd_request;
reg [2:0] main_litedramcore_choose_cmd_grant = 3'd0;
wire main_litedramcore_choose_cmd_ce;
reg main_litedramcore_choose_req_want_reads = 1'd0;
reg main_litedramcore_choose_req_want_writes = 1'd0;
reg main_litedramcore_choose_req_want_cmds = 1'd0;
reg main_litedramcore_choose_req_want_activates = 1'd0;
wire main_litedramcore_choose_req_cmd_valid;
reg main_litedramcore_choose_req_cmd_ready = 1'd0;
wire [12:0] main_litedramcore_choose_req_cmd_payload_a;
wire [2:0] main_litedramcore_choose_req_cmd_payload_ba;
reg main_litedramcore_choose_req_cmd_payload_cas = 1'd0;
reg main_litedramcore_choose_req_cmd_payload_ras = 1'd0;
reg main_litedramcore_choose_req_cmd_payload_we = 1'd0;
wire main_litedramcore_choose_req_cmd_payload_is_cmd;
wire main_litedramcore_choose_req_cmd_payload_is_read;
wire main_litedramcore_choose_req_cmd_payload_is_write;
reg [7:0] main_litedramcore_choose_req_valids = 8'd0;
wire [7:0] main_litedramcore_choose_req_request;
reg [2:0] main_litedramcore_choose_req_grant = 3'd0;
wire main_litedramcore_choose_req_ce;
reg [12:0] main_litedramcore_nop_a = 13'd0;
reg [2:0] main_litedramcore_nop_ba = 3'd0;
reg [1:0] main_litedramcore_steerer_sel0 = 2'd0;
reg [1:0] main_litedramcore_steerer_sel1 = 2'd0;
reg main_litedramcore_steerer0 = 1'd1;
reg main_litedramcore_steerer1 = 1'd1;
reg main_litedramcore_steerer2 = 1'd1;
reg main_litedramcore_steerer3 = 1'd1;
wire main_litedramcore_trrdcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_trrdcon_ready = 1'd1;
wire main_litedramcore_tfawcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_tfawcon_ready = 1'd1;
wire main_litedramcore_tccdcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_tccdcon_ready = 1'd0;
reg main_litedramcore_tccdcon_count = 1'd0;
wire main_litedramcore_twtrcon_valid;
(* dont_touch = "true" *) reg main_litedramcore_twtrcon_ready = 1'd0;
reg [1:0] main_litedramcore_twtrcon_count = 2'd0;
wire main_litedramcore_read_available;
wire main_litedramcore_write_available;
reg main_litedramcore_en0 = 1'd0;
wire main_litedramcore_max_time0;
reg [4:0] main_litedramcore_time0 = 5'd0;
reg main_litedramcore_en1 = 1'd0;
wire main_litedramcore_max_time1;
reg [3:0] main_litedramcore_time1 = 4'd0;
wire main_litedramcore_go_to_refresh;
reg main_init_done_storage = 1'd0;
reg main_init_done_re = 1'd0;
reg main_init_error_storage = 1'd0;
reg main_init_error_re = 1'd0;
wire [29:0] main_wb_bus_adr;
wire [31:0] main_wb_bus_dat_w;
wire [31:0] main_wb_bus_dat_r;
wire [3:0] main_wb_bus_sel;
wire main_wb_bus_cyc;
wire main_wb_bus_stb;
wire main_wb_bus_ack;
wire main_wb_bus_we;
wire [2:0] main_wb_bus_cti;
wire [1:0] main_wb_bus_bte;
wire main_wb_bus_err;
wire main_user_port_flush;
wire main_user_port_cmd_valid;
wire main_user_port_cmd_ready;
wire main_user_port_cmd_last;
wire main_user_port_cmd_payload_we;
wire [23:0] main_user_port_cmd_payload_addr;
wire main_user_port_wdata_valid;
wire main_user_port_wdata_ready;
wire [63:0] main_user_port_wdata_payload_data;
wire [7:0] main_user_port_wdata_payload_we;
wire main_user_port_rdata_valid;
wire main_user_port_rdata_ready;
wire [63:0] main_user_port_rdata_payload_data;
wire [23:0] main_wb_port_adr;
wire [63:0] main_wb_port_dat_w;
wire [63:0] main_wb_port_dat_r;
wire [7:0] main_wb_port_sel;
wire main_wb_port_cyc;
wire main_wb_port_stb;
wire main_wb_port_ack;
wire main_wb_port_we;
reg main_wb_port_err = 1'd0;
reg main_cmd_consumed = 1'd0;
reg main_wdata_consumed = 1'd0;
wire main_ack_cmd;
wire main_ack_wdata;
wire main_ack_rdata;
wire builder_reset0;
wire builder_reset1;
wire builder_reset2;
wire builder_reset3;
wire builder_reset4;
wire builder_reset5;
wire builder_reset6;
wire builder_reset7;
wire builder_pll_fb;
reg [1:0] builder_refresher_state = 2'd0;
reg [1:0] builder_refresher_next_state = 2'd0;
reg [2:0] builder_bankmachine0_state = 3'd0;
reg [2:0] builder_bankmachine0_next_state = 3'd0;
reg [2:0] builder_bankmachine1_state = 3'd0;
reg [2:0] builder_bankmachine1_next_state = 3'd0;
reg [2:0] builder_bankmachine2_state = 3'd0;
reg [2:0] builder_bankmachine2_next_state = 3'd0;
reg [2:0] builder_bankmachine3_state = 3'd0;
reg [2:0] builder_bankmachine3_next_state = 3'd0;
reg [2:0] builder_bankmachine4_state = 3'd0;
reg [2:0] builder_bankmachine4_next_state = 3'd0;
reg [2:0] builder_bankmachine5_state = 3'd0;
reg [2:0] builder_bankmachine5_next_state = 3'd0;
reg [2:0] builder_bankmachine6_state = 3'd0;
reg [2:0] builder_bankmachine6_next_state = 3'd0;
reg [2:0] builder_bankmachine7_state = 3'd0;
reg [2:0] builder_bankmachine7_next_state = 3'd0;
reg [3:0] builder_multiplexer_state = 4'd0;
reg [3:0] builder_multiplexer_next_state = 4'd0;
wire builder_roundrobin0_request;
wire builder_roundrobin0_grant;
wire builder_roundrobin0_ce;
wire builder_roundrobin1_request;
wire builder_roundrobin1_grant;
wire builder_roundrobin1_ce;
wire builder_roundrobin2_request;
wire builder_roundrobin2_grant;
wire builder_roundrobin2_ce;
wire builder_roundrobin3_request;
wire builder_roundrobin3_grant;
wire builder_roundrobin3_ce;
wire builder_roundrobin4_request;
wire builder_roundrobin4_grant;
wire builder_roundrobin4_ce;
wire builder_roundrobin5_request;
wire builder_roundrobin5_grant;
wire builder_roundrobin5_ce;
wire builder_roundrobin6_request;
wire builder_roundrobin6_grant;
wire builder_roundrobin6_ce;
wire builder_roundrobin7_request;
wire builder_roundrobin7_grant;
wire builder_roundrobin7_ce;
reg builder_locked0 = 1'd0;
reg builder_locked1 = 1'd0;
reg builder_locked2 = 1'd0;
reg builder_locked3 = 1'd0;
reg builder_locked4 = 1'd0;
reg builder_locked5 = 1'd0;
reg builder_locked6 = 1'd0;
reg builder_locked7 = 1'd0;
reg builder_new_master_wdata_ready = 1'd0;
reg builder_new_master_rdata_valid0 = 1'd0;
reg builder_new_master_rdata_valid1 = 1'd0;
reg builder_new_master_rdata_valid2 = 1'd0;
reg builder_new_master_rdata_valid3 = 1'd0;
reg builder_new_master_rdata_valid4 = 1'd0;
reg builder_new_master_rdata_valid5 = 1'd0;
reg builder_new_master_rdata_valid6 = 1'd0;
reg builder_new_master_rdata_valid7 = 1'd0;
reg builder_new_master_rdata_valid8 = 1'd0;
reg [13:0] builder_litedramcore_adr = 14'd0;
reg builder_litedramcore_we = 1'd0;
reg [7:0] builder_litedramcore_dat_w = 8'd0;
wire [7:0] builder_litedramcore_dat_r;
wire [29:0] builder_litedramcore_wishbone_adr;
wire [31:0] builder_litedramcore_wishbone_dat_w;
reg [31:0] builder_litedramcore_wishbone_dat_r = 32'd0;
wire [3:0] builder_litedramcore_wishbone_sel;
wire builder_litedramcore_wishbone_cyc;
wire builder_litedramcore_wishbone_stb;
reg builder_litedramcore_wishbone_ack = 1'd0;
wire builder_litedramcore_wishbone_we;
wire [2:0] builder_litedramcore_wishbone_cti;
wire [1:0] builder_litedramcore_wishbone_bte;
reg builder_litedramcore_wishbone_err = 1'd0;
wire [13:0] builder_interface0_bank_bus_adr;
wire builder_interface0_bank_bus_we;
wire [7:0] builder_interface0_bank_bus_dat_w;
reg [7:0] builder_interface0_bank_bus_dat_r = 8'd0;
reg builder_csrbank0_init_done0_re = 1'd0;
wire builder_csrbank0_init_done0_r;
reg builder_csrbank0_init_done0_we = 1'd0;
wire builder_csrbank0_init_done0_w;
reg builder_csrbank0_init_error0_re = 1'd0;
wire builder_csrbank0_init_error0_r;
reg builder_csrbank0_init_error0_we = 1'd0;
wire builder_csrbank0_init_error0_w;
wire builder_csrbank0_sel;
wire [13:0] builder_interface1_bank_bus_adr;
wire builder_interface1_bank_bus_we;
wire [7:0] builder_interface1_bank_bus_dat_w;
reg [7:0] builder_interface1_bank_bus_dat_r = 8'd0;
reg builder_csrbank1_rst0_re = 1'd0;
wire builder_csrbank1_rst0_r;
reg builder_csrbank1_rst0_we = 1'd0;
wire builder_csrbank1_rst0_w;
reg builder_csrbank1_half_sys8x_taps0_re = 1'd0;
wire [4:0] builder_csrbank1_half_sys8x_taps0_r;
reg builder_csrbank1_half_sys8x_taps0_we = 1'd0;
wire [4:0] builder_csrbank1_half_sys8x_taps0_w;
reg builder_csrbank1_wlevel_en0_re = 1'd0;
wire builder_csrbank1_wlevel_en0_r;
reg builder_csrbank1_wlevel_en0_we = 1'd0;
wire builder_csrbank1_wlevel_en0_w;
reg builder_csrbank1_dly_sel0_re = 1'd0;
wire [1:0] builder_csrbank1_dly_sel0_r;
reg builder_csrbank1_dly_sel0_we = 1'd0;
wire [1:0] builder_csrbank1_dly_sel0_w;
reg builder_csrbank1_rdphase0_re = 1'd0;
wire builder_csrbank1_rdphase0_r;
reg builder_csrbank1_rdphase0_we = 1'd0;
wire builder_csrbank1_rdphase0_w;
reg builder_csrbank1_wrphase0_re = 1'd0;
wire builder_csrbank1_wrphase0_r;
reg builder_csrbank1_wrphase0_we = 1'd0;
wire builder_csrbank1_wrphase0_w;
wire builder_csrbank1_sel;
wire [13:0] builder_interface2_bank_bus_adr;
wire builder_interface2_bank_bus_we;
wire [7:0] builder_interface2_bank_bus_dat_w;
reg [7:0] builder_interface2_bank_bus_dat_r = 8'd0;
reg builder_csrbank2_dfii_control0_re = 1'd0;
wire [3:0] builder_csrbank2_dfii_control0_r;
reg builder_csrbank2_dfii_control0_we = 1'd0;
wire [3:0] builder_csrbank2_dfii_control0_w;
reg builder_csrbank2_dfii_pi0_command0_re = 1'd0;
wire [5:0] builder_csrbank2_dfii_pi0_command0_r;
reg builder_csrbank2_dfii_pi0_command0_we = 1'd0;
wire [5:0] builder_csrbank2_dfii_pi0_command0_w;
reg builder_csrbank2_dfii_pi0_address1_re = 1'd0;
wire [4:0] builder_csrbank2_dfii_pi0_address1_r;
reg builder_csrbank2_dfii_pi0_address1_we = 1'd0;
wire [4:0] builder_csrbank2_dfii_pi0_address1_w;
reg builder_csrbank2_dfii_pi0_address0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_address0_r;
reg builder_csrbank2_dfii_pi0_address0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_address0_w;
reg builder_csrbank2_dfii_pi0_baddress0_re = 1'd0;
wire [2:0] builder_csrbank2_dfii_pi0_baddress0_r;
reg builder_csrbank2_dfii_pi0_baddress0_we = 1'd0;
wire [2:0] builder_csrbank2_dfii_pi0_baddress0_w;
reg builder_csrbank2_dfii_pi0_wrdata3_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata3_r;
reg builder_csrbank2_dfii_pi0_wrdata3_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata3_w;
reg builder_csrbank2_dfii_pi0_wrdata2_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata2_r;
reg builder_csrbank2_dfii_pi0_wrdata2_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata2_w;
reg builder_csrbank2_dfii_pi0_wrdata1_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata1_r;
reg builder_csrbank2_dfii_pi0_wrdata1_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata1_w;
reg builder_csrbank2_dfii_pi0_wrdata0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata0_r;
reg builder_csrbank2_dfii_pi0_wrdata0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_wrdata0_w;
reg builder_csrbank2_dfii_pi0_rddata3_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata3_r;
reg builder_csrbank2_dfii_pi0_rddata3_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata3_w;
reg builder_csrbank2_dfii_pi0_rddata2_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata2_r;
reg builder_csrbank2_dfii_pi0_rddata2_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata2_w;
reg builder_csrbank2_dfii_pi0_rddata1_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata1_r;
reg builder_csrbank2_dfii_pi0_rddata1_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata1_w;
reg builder_csrbank2_dfii_pi0_rddata0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata0_r;
reg builder_csrbank2_dfii_pi0_rddata0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi0_rddata0_w;
reg builder_csrbank2_dfii_pi1_command0_re = 1'd0;
wire [5:0] builder_csrbank2_dfii_pi1_command0_r;
reg builder_csrbank2_dfii_pi1_command0_we = 1'd0;
wire [5:0] builder_csrbank2_dfii_pi1_command0_w;
reg builder_csrbank2_dfii_pi1_address1_re = 1'd0;
wire [4:0] builder_csrbank2_dfii_pi1_address1_r;
reg builder_csrbank2_dfii_pi1_address1_we = 1'd0;
wire [4:0] builder_csrbank2_dfii_pi1_address1_w;
reg builder_csrbank2_dfii_pi1_address0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_address0_r;
reg builder_csrbank2_dfii_pi1_address0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_address0_w;
reg builder_csrbank2_dfii_pi1_baddress0_re = 1'd0;
wire [2:0] builder_csrbank2_dfii_pi1_baddress0_r;
reg builder_csrbank2_dfii_pi1_baddress0_we = 1'd0;
wire [2:0] builder_csrbank2_dfii_pi1_baddress0_w;
reg builder_csrbank2_dfii_pi1_wrdata3_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata3_r;
reg builder_csrbank2_dfii_pi1_wrdata3_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata3_w;
reg builder_csrbank2_dfii_pi1_wrdata2_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata2_r;
reg builder_csrbank2_dfii_pi1_wrdata2_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata2_w;
reg builder_csrbank2_dfii_pi1_wrdata1_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata1_r;
reg builder_csrbank2_dfii_pi1_wrdata1_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata1_w;
reg builder_csrbank2_dfii_pi1_wrdata0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata0_r;
reg builder_csrbank2_dfii_pi1_wrdata0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_wrdata0_w;
reg builder_csrbank2_dfii_pi1_rddata3_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata3_r;
reg builder_csrbank2_dfii_pi1_rddata3_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata3_w;
reg builder_csrbank2_dfii_pi1_rddata2_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata2_r;
reg builder_csrbank2_dfii_pi1_rddata2_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata2_w;
reg builder_csrbank2_dfii_pi1_rddata1_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata1_r;
reg builder_csrbank2_dfii_pi1_rddata1_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata1_w;
reg builder_csrbank2_dfii_pi1_rddata0_re = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata0_r;
reg builder_csrbank2_dfii_pi1_rddata0_we = 1'd0;
wire [7:0] builder_csrbank2_dfii_pi1_rddata0_w;
wire builder_csrbank2_sel;
wire [13:0] builder_csr_interconnect_adr;
wire builder_csr_interconnect_we;
wire [7:0] builder_csr_interconnect_dat_w;
wire [7:0] builder_csr_interconnect_dat_r;
reg [1:0] builder_state = 2'd0;
reg [1:0] builder_next_state = 2'd0;
reg [7:0] builder_litedramcore_dat_w_next_value0 = 8'd0;
reg builder_litedramcore_dat_w_next_value_ce0 = 1'd0;
reg [13:0] builder_litedramcore_adr_next_value1 = 14'd0;
reg builder_litedramcore_adr_next_value_ce1 = 1'd0;
reg builder_litedramcore_we_next_value2 = 1'd0;
reg builder_litedramcore_we_next_value_ce2 = 1'd0;
reg builder_rhs_array_muxed0 = 1'd0;
reg [12:0] builder_rhs_array_muxed1 = 13'd0;
reg [2:0] builder_rhs_array_muxed2 = 3'd0;
reg builder_rhs_array_muxed3 = 1'd0;
reg builder_rhs_array_muxed4 = 1'd0;
reg builder_rhs_array_muxed5 = 1'd0;
reg builder_t_array_muxed0 = 1'd0;
reg builder_t_array_muxed1 = 1'd0;
reg builder_t_array_muxed2 = 1'd0;
reg builder_rhs_array_muxed6 = 1'd0;
reg [12:0] builder_rhs_array_muxed7 = 13'd0;
reg [2:0] builder_rhs_array_muxed8 = 3'd0;
reg builder_rhs_array_muxed9 = 1'd0;
reg builder_rhs_array_muxed10 = 1'd0;
reg builder_rhs_array_muxed11 = 1'd0;
reg builder_t_array_muxed3 = 1'd0;
reg builder_t_array_muxed4 = 1'd0;
reg builder_t_array_muxed5 = 1'd0;
reg [20:0] builder_rhs_array_muxed12 = 21'd0;
reg builder_rhs_array_muxed13 = 1'd0;
reg builder_rhs_array_muxed14 = 1'd0;
reg [20:0] builder_rhs_array_muxed15 = 21'd0;
reg builder_rhs_array_muxed16 = 1'd0;
reg builder_rhs_array_muxed17 = 1'd0;
reg [20:0] builder_rhs_array_muxed18 = 21'd0;
reg builder_rhs_array_muxed19 = 1'd0;
reg builder_rhs_array_muxed20 = 1'd0;
reg [20:0] builder_rhs_array_muxed21 = 21'd0;
reg builder_rhs_array_muxed22 = 1'd0;
reg builder_rhs_array_muxed23 = 1'd0;
reg [20:0] builder_rhs_array_muxed24 = 21'd0;
reg builder_rhs_array_muxed25 = 1'd0;
reg builder_rhs_array_muxed26 = 1'd0;
reg [20:0] builder_rhs_array_muxed27 = 21'd0;
reg builder_rhs_array_muxed28 = 1'd0;
reg builder_rhs_array_muxed29 = 1'd0;
reg [20:0] builder_rhs_array_muxed30 = 21'd0;
reg builder_rhs_array_muxed31 = 1'd0;
reg builder_rhs_array_muxed32 = 1'd0;
reg [20:0] builder_rhs_array_muxed33 = 21'd0;
reg builder_rhs_array_muxed34 = 1'd0;
reg builder_rhs_array_muxed35 = 1'd0;
reg [2:0] builder_array_muxed0 = 3'd0;
reg [12:0] builder_array_muxed1 = 13'd0;
reg builder_array_muxed2 = 1'd0;
reg builder_array_muxed3 = 1'd0;
reg builder_array_muxed4 = 1'd0;
reg builder_array_muxed5 = 1'd0;
reg builder_array_muxed6 = 1'd0;
reg [2:0] builder_array_muxed7 = 3'd0;
reg [12:0] builder_array_muxed8 = 13'd0;
reg builder_array_muxed9 = 1'd0;
reg builder_array_muxed10 = 1'd0;
reg builder_array_muxed11 = 1'd0;
reg builder_array_muxed12 = 1'd0;
reg builder_array_muxed13 = 1'd0;
wire builder_xilinxasyncresetsynchronizerimpl0;
wire builder_xilinxasyncresetsynchronizerimpl0_rst_meta;
wire builder_xilinxasyncresetsynchronizerimpl1;
wire builder_xilinxasyncresetsynchronizerimpl1_rst_meta;
wire builder_xilinxasyncresetsynchronizerimpl2;
wire builder_xilinxasyncresetsynchronizerimpl2_rst_meta;
wire builder_xilinxasyncresetsynchronizerimpl2_expr;
wire builder_xilinxasyncresetsynchronizerimpl3;
wire builder_xilinxasyncresetsynchronizerimpl3_rst_meta;
wire builder_xilinxasyncresetsynchronizerimpl3_expr;

// synthesis translate_off
reg dummy_s;
initial dummy_s <= 1'd0;
// synthesis translate_on
assign init_done = main_init_done_storage;
assign init_error = main_init_error_storage;
assign main_wb_bus_adr = wb_ctrl_adr;
assign main_wb_bus_dat_w = wb_ctrl_dat_w;
assign wb_ctrl_dat_r = main_wb_bus_dat_r;
assign main_wb_bus_sel = wb_ctrl_sel;
assign main_wb_bus_cyc = wb_ctrl_cyc;
assign main_wb_bus_stb = wb_ctrl_stb;
assign wb_ctrl_ack = main_wb_bus_ack;
assign main_wb_bus_we = wb_ctrl_we;
assign main_wb_bus_cti = wb_ctrl_cti;
assign main_wb_bus_bte = wb_ctrl_bte;
assign wb_ctrl_err = main_wb_bus_err;
assign user_clk = sys_clk;
assign user_rst = sys_rst;
assign main_wb_port_adr = user_port_wishbone_0_adr;
assign main_wb_port_dat_w = user_port_wishbone_0_dat_w;
assign user_port_wishbone_0_dat_r = main_wb_port_dat_r;
assign main_wb_port_sel = user_port_wishbone_0_sel;
assign main_wb_port_cyc = user_port_wishbone_0_cyc;
assign main_wb_port_stb = user_port_wishbone_0_stb;
assign user_port_wishbone_0_ack = main_wb_port_ack;
assign main_wb_port_we = user_port_wishbone_0_we;
assign user_port_wishbone_0_err = main_wb_port_err;
assign main_reset = rst;
assign pll_locked = main_locked;
assign main_clkin = clk;
assign iodelay_clk = main_clkout_buf0;
assign sys_clk = main_clkout_buf1;
assign sys2x_clk = main_clkout_buf2;
assign sys2x_dqs_clk = main_clkout_buf3;
assign main_a7ddrphy_dqs_oe_delay_tappeddelayline = ((main_a7ddrphy_dqs_preamble | main_a7ddrphy_dqs_oe) | main_a7ddrphy_dqs_postamble);
assign main_a7ddrphy_dq_oe_delay_tappeddelayline = ((main_a7ddrphy_dqs_preamble | main_a7ddrphy_dq_oe) | main_a7ddrphy_dqs_postamble);

// synthesis translate_off
reg dummy_d;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dfi_p0_rddata <= 32'd0;
	main_a7ddrphy_dfi_p0_rddata[0] <= main_a7ddrphy_bitslip04[0];
	main_a7ddrphy_dfi_p0_rddata[16] <= main_a7ddrphy_bitslip04[1];
	main_a7ddrphy_dfi_p0_rddata[1] <= main_a7ddrphy_bitslip14[0];
	main_a7ddrphy_dfi_p0_rddata[17] <= main_a7ddrphy_bitslip14[1];
	main_a7ddrphy_dfi_p0_rddata[2] <= main_a7ddrphy_bitslip22[0];
	main_a7ddrphy_dfi_p0_rddata[18] <= main_a7ddrphy_bitslip22[1];
	main_a7ddrphy_dfi_p0_rddata[3] <= main_a7ddrphy_bitslip32[0];
	main_a7ddrphy_dfi_p0_rddata[19] <= main_a7ddrphy_bitslip32[1];
	main_a7ddrphy_dfi_p0_rddata[4] <= main_a7ddrphy_bitslip42[0];
	main_a7ddrphy_dfi_p0_rddata[20] <= main_a7ddrphy_bitslip42[1];
	main_a7ddrphy_dfi_p0_rddata[5] <= main_a7ddrphy_bitslip52[0];
	main_a7ddrphy_dfi_p0_rddata[21] <= main_a7ddrphy_bitslip52[1];
	main_a7ddrphy_dfi_p0_rddata[6] <= main_a7ddrphy_bitslip62[0];
	main_a7ddrphy_dfi_p0_rddata[22] <= main_a7ddrphy_bitslip62[1];
	main_a7ddrphy_dfi_p0_rddata[7] <= main_a7ddrphy_bitslip72[0];
	main_a7ddrphy_dfi_p0_rddata[23] <= main_a7ddrphy_bitslip72[1];
	main_a7ddrphy_dfi_p0_rddata[8] <= main_a7ddrphy_bitslip82[0];
	main_a7ddrphy_dfi_p0_rddata[24] <= main_a7ddrphy_bitslip82[1];
	main_a7ddrphy_dfi_p0_rddata[9] <= main_a7ddrphy_bitslip92[0];
	main_a7ddrphy_dfi_p0_rddata[25] <= main_a7ddrphy_bitslip92[1];
	main_a7ddrphy_dfi_p0_rddata[10] <= main_a7ddrphy_bitslip102[0];
	main_a7ddrphy_dfi_p0_rddata[26] <= main_a7ddrphy_bitslip102[1];
	main_a7ddrphy_dfi_p0_rddata[11] <= main_a7ddrphy_bitslip112[0];
	main_a7ddrphy_dfi_p0_rddata[27] <= main_a7ddrphy_bitslip112[1];
	main_a7ddrphy_dfi_p0_rddata[12] <= main_a7ddrphy_bitslip122[0];
	main_a7ddrphy_dfi_p0_rddata[28] <= main_a7ddrphy_bitslip122[1];
	main_a7ddrphy_dfi_p0_rddata[13] <= main_a7ddrphy_bitslip132[0];
	main_a7ddrphy_dfi_p0_rddata[29] <= main_a7ddrphy_bitslip132[1];
	main_a7ddrphy_dfi_p0_rddata[14] <= main_a7ddrphy_bitslip142[0];
	main_a7ddrphy_dfi_p0_rddata[30] <= main_a7ddrphy_bitslip142[1];
	main_a7ddrphy_dfi_p0_rddata[15] <= main_a7ddrphy_bitslip152[0];
	main_a7ddrphy_dfi_p0_rddata[31] <= main_a7ddrphy_bitslip152[1];
// synthesis translate_off
	dummy_d = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_1;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dfi_p1_rddata <= 32'd0;
	main_a7ddrphy_dfi_p1_rddata[0] <= main_a7ddrphy_bitslip04[2];
	main_a7ddrphy_dfi_p1_rddata[16] <= main_a7ddrphy_bitslip04[3];
	main_a7ddrphy_dfi_p1_rddata[1] <= main_a7ddrphy_bitslip14[2];
	main_a7ddrphy_dfi_p1_rddata[17] <= main_a7ddrphy_bitslip14[3];
	main_a7ddrphy_dfi_p1_rddata[2] <= main_a7ddrphy_bitslip22[2];
	main_a7ddrphy_dfi_p1_rddata[18] <= main_a7ddrphy_bitslip22[3];
	main_a7ddrphy_dfi_p1_rddata[3] <= main_a7ddrphy_bitslip32[2];
	main_a7ddrphy_dfi_p1_rddata[19] <= main_a7ddrphy_bitslip32[3];
	main_a7ddrphy_dfi_p1_rddata[4] <= main_a7ddrphy_bitslip42[2];
	main_a7ddrphy_dfi_p1_rddata[20] <= main_a7ddrphy_bitslip42[3];
	main_a7ddrphy_dfi_p1_rddata[5] <= main_a7ddrphy_bitslip52[2];
	main_a7ddrphy_dfi_p1_rddata[21] <= main_a7ddrphy_bitslip52[3];
	main_a7ddrphy_dfi_p1_rddata[6] <= main_a7ddrphy_bitslip62[2];
	main_a7ddrphy_dfi_p1_rddata[22] <= main_a7ddrphy_bitslip62[3];
	main_a7ddrphy_dfi_p1_rddata[7] <= main_a7ddrphy_bitslip72[2];
	main_a7ddrphy_dfi_p1_rddata[23] <= main_a7ddrphy_bitslip72[3];
	main_a7ddrphy_dfi_p1_rddata[8] <= main_a7ddrphy_bitslip82[2];
	main_a7ddrphy_dfi_p1_rddata[24] <= main_a7ddrphy_bitslip82[3];
	main_a7ddrphy_dfi_p1_rddata[9] <= main_a7ddrphy_bitslip92[2];
	main_a7ddrphy_dfi_p1_rddata[25] <= main_a7ddrphy_bitslip92[3];
	main_a7ddrphy_dfi_p1_rddata[10] <= main_a7ddrphy_bitslip102[2];
	main_a7ddrphy_dfi_p1_rddata[26] <= main_a7ddrphy_bitslip102[3];
	main_a7ddrphy_dfi_p1_rddata[11] <= main_a7ddrphy_bitslip112[2];
	main_a7ddrphy_dfi_p1_rddata[27] <= main_a7ddrphy_bitslip112[3];
	main_a7ddrphy_dfi_p1_rddata[12] <= main_a7ddrphy_bitslip122[2];
	main_a7ddrphy_dfi_p1_rddata[28] <= main_a7ddrphy_bitslip122[3];
	main_a7ddrphy_dfi_p1_rddata[13] <= main_a7ddrphy_bitslip132[2];
	main_a7ddrphy_dfi_p1_rddata[29] <= main_a7ddrphy_bitslip132[3];
	main_a7ddrphy_dfi_p1_rddata[14] <= main_a7ddrphy_bitslip142[2];
	main_a7ddrphy_dfi_p1_rddata[30] <= main_a7ddrphy_bitslip142[3];
	main_a7ddrphy_dfi_p1_rddata[15] <= main_a7ddrphy_bitslip152[2];
	main_a7ddrphy_dfi_p1_rddata[31] <= main_a7ddrphy_bitslip152[3];
// synthesis translate_off
	dummy_d_1 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_2;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dfi_p2_rddata <= 32'd0;
	main_a7ddrphy_dfi_p2_rddata[0] <= main_a7ddrphy_bitslip04[4];
	main_a7ddrphy_dfi_p2_rddata[16] <= main_a7ddrphy_bitslip04[5];
	main_a7ddrphy_dfi_p2_rddata[1] <= main_a7ddrphy_bitslip14[4];
	main_a7ddrphy_dfi_p2_rddata[17] <= main_a7ddrphy_bitslip14[5];
	main_a7ddrphy_dfi_p2_rddata[2] <= main_a7ddrphy_bitslip22[4];
	main_a7ddrphy_dfi_p2_rddata[18] <= main_a7ddrphy_bitslip22[5];
	main_a7ddrphy_dfi_p2_rddata[3] <= main_a7ddrphy_bitslip32[4];
	main_a7ddrphy_dfi_p2_rddata[19] <= main_a7ddrphy_bitslip32[5];
	main_a7ddrphy_dfi_p2_rddata[4] <= main_a7ddrphy_bitslip42[4];
	main_a7ddrphy_dfi_p2_rddata[20] <= main_a7ddrphy_bitslip42[5];
	main_a7ddrphy_dfi_p2_rddata[5] <= main_a7ddrphy_bitslip52[4];
	main_a7ddrphy_dfi_p2_rddata[21] <= main_a7ddrphy_bitslip52[5];
	main_a7ddrphy_dfi_p2_rddata[6] <= main_a7ddrphy_bitslip62[4];
	main_a7ddrphy_dfi_p2_rddata[22] <= main_a7ddrphy_bitslip62[5];
	main_a7ddrphy_dfi_p2_rddata[7] <= main_a7ddrphy_bitslip72[4];
	main_a7ddrphy_dfi_p2_rddata[23] <= main_a7ddrphy_bitslip72[5];
	main_a7ddrphy_dfi_p2_rddata[8] <= main_a7ddrphy_bitslip82[4];
	main_a7ddrphy_dfi_p2_rddata[24] <= main_a7ddrphy_bitslip82[5];
	main_a7ddrphy_dfi_p2_rddata[9] <= main_a7ddrphy_bitslip92[4];
	main_a7ddrphy_dfi_p2_rddata[25] <= main_a7ddrphy_bitslip92[5];
	main_a7ddrphy_dfi_p2_rddata[10] <= main_a7ddrphy_bitslip102[4];
	main_a7ddrphy_dfi_p2_rddata[26] <= main_a7ddrphy_bitslip102[5];
	main_a7ddrphy_dfi_p2_rddata[11] <= main_a7ddrphy_bitslip112[4];
	main_a7ddrphy_dfi_p2_rddata[27] <= main_a7ddrphy_bitslip112[5];
	main_a7ddrphy_dfi_p2_rddata[12] <= main_a7ddrphy_bitslip122[4];
	main_a7ddrphy_dfi_p2_rddata[28] <= main_a7ddrphy_bitslip122[5];
	main_a7ddrphy_dfi_p2_rddata[13] <= main_a7ddrphy_bitslip132[4];
	main_a7ddrphy_dfi_p2_rddata[29] <= main_a7ddrphy_bitslip132[5];
	main_a7ddrphy_dfi_p2_rddata[14] <= main_a7ddrphy_bitslip142[4];
	main_a7ddrphy_dfi_p2_rddata[30] <= main_a7ddrphy_bitslip142[5];
	main_a7ddrphy_dfi_p2_rddata[15] <= main_a7ddrphy_bitslip152[4];
	main_a7ddrphy_dfi_p2_rddata[31] <= main_a7ddrphy_bitslip152[5];
// synthesis translate_off
	dummy_d_2 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_3;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dfi_p3_rddata <= 32'd0;
	main_a7ddrphy_dfi_p3_rddata[0] <= main_a7ddrphy_bitslip04[6];
	main_a7ddrphy_dfi_p3_rddata[16] <= main_a7ddrphy_bitslip04[7];
	main_a7ddrphy_dfi_p3_rddata[1] <= main_a7ddrphy_bitslip14[6];
	main_a7ddrphy_dfi_p3_rddata[17] <= main_a7ddrphy_bitslip14[7];
	main_a7ddrphy_dfi_p3_rddata[2] <= main_a7ddrphy_bitslip22[6];
	main_a7ddrphy_dfi_p3_rddata[18] <= main_a7ddrphy_bitslip22[7];
	main_a7ddrphy_dfi_p3_rddata[3] <= main_a7ddrphy_bitslip32[6];
	main_a7ddrphy_dfi_p3_rddata[19] <= main_a7ddrphy_bitslip32[7];
	main_a7ddrphy_dfi_p3_rddata[4] <= main_a7ddrphy_bitslip42[6];
	main_a7ddrphy_dfi_p3_rddata[20] <= main_a7ddrphy_bitslip42[7];
	main_a7ddrphy_dfi_p3_rddata[5] <= main_a7ddrphy_bitslip52[6];
	main_a7ddrphy_dfi_p3_rddata[21] <= main_a7ddrphy_bitslip52[7];
	main_a7ddrphy_dfi_p3_rddata[6] <= main_a7ddrphy_bitslip62[6];
	main_a7ddrphy_dfi_p3_rddata[22] <= main_a7ddrphy_bitslip62[7];
	main_a7ddrphy_dfi_p3_rddata[7] <= main_a7ddrphy_bitslip72[6];
	main_a7ddrphy_dfi_p3_rddata[23] <= main_a7ddrphy_bitslip72[7];
	main_a7ddrphy_dfi_p3_rddata[8] <= main_a7ddrphy_bitslip82[6];
	main_a7ddrphy_dfi_p3_rddata[24] <= main_a7ddrphy_bitslip82[7];
	main_a7ddrphy_dfi_p3_rddata[9] <= main_a7ddrphy_bitslip92[6];
	main_a7ddrphy_dfi_p3_rddata[25] <= main_a7ddrphy_bitslip92[7];
	main_a7ddrphy_dfi_p3_rddata[10] <= main_a7ddrphy_bitslip102[6];
	main_a7ddrphy_dfi_p3_rddata[26] <= main_a7ddrphy_bitslip102[7];
	main_a7ddrphy_dfi_p3_rddata[11] <= main_a7ddrphy_bitslip112[6];
	main_a7ddrphy_dfi_p3_rddata[27] <= main_a7ddrphy_bitslip112[7];
	main_a7ddrphy_dfi_p3_rddata[12] <= main_a7ddrphy_bitslip122[6];
	main_a7ddrphy_dfi_p3_rddata[28] <= main_a7ddrphy_bitslip122[7];
	main_a7ddrphy_dfi_p3_rddata[13] <= main_a7ddrphy_bitslip132[6];
	main_a7ddrphy_dfi_p3_rddata[29] <= main_a7ddrphy_bitslip132[7];
	main_a7ddrphy_dfi_p3_rddata[14] <= main_a7ddrphy_bitslip142[6];
	main_a7ddrphy_dfi_p3_rddata[30] <= main_a7ddrphy_bitslip142[7];
	main_a7ddrphy_dfi_p3_rddata[15] <= main_a7ddrphy_bitslip152[6];
	main_a7ddrphy_dfi_p3_rddata[31] <= main_a7ddrphy_bitslip152[7];
// synthesis translate_off
	dummy_d_3 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_dfi_p0_rddata_valid = (main_a7ddrphy_rddata_en_tappeddelayline7 | main_a7ddrphy_wlevel_en_storage);
assign main_a7ddrphy_dfi_p1_rddata_valid = (main_a7ddrphy_rddata_en_tappeddelayline7 | main_a7ddrphy_wlevel_en_storage);
assign main_a7ddrphy_dfi_p2_rddata_valid = (main_a7ddrphy_rddata_en_tappeddelayline7 | main_a7ddrphy_wlevel_en_storage);
assign main_a7ddrphy_dfi_p3_rddata_valid = (main_a7ddrphy_rddata_en_tappeddelayline7 | main_a7ddrphy_wlevel_en_storage);
assign main_a7ddrphy_dq_oe = main_a7ddrphy_wrdata_en_tappeddelayline0;

// synthesis translate_off
reg dummy_d_4;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dqs_oe <= 1'd0;
	if (main_a7ddrphy_wlevel_en_storage) begin
		main_a7ddrphy_dqs_oe <= 1'd1;
	end else begin
		main_a7ddrphy_dqs_oe <= main_a7ddrphy_dq_oe;
	end
// synthesis translate_off
	dummy_d_4 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_dqs_preamble = (main_a7ddrphy_wrdata_en_tappeddelayline1 & (~main_a7ddrphy_wrdata_en_tappeddelayline0));
assign main_a7ddrphy_dqs_postamble = (main_a7ddrphy_wrdata_en_tappeddelayline1 & (~main_a7ddrphy_wrdata_en_tappeddelayline0));

// synthesis translate_off
reg dummy_d_5;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_dqspattern_o0 <= 8'd0;
	main_a7ddrphy_dqspattern_o0 <= 7'd85;
	if (main_a7ddrphy_dqspattern0) begin
		main_a7ddrphy_dqspattern_o0 <= 5'd21;
	end
	if (main_a7ddrphy_dqspattern1) begin
		main_a7ddrphy_dqspattern_o0 <= 7'd84;
	end
	if (main_a7ddrphy_wlevel_en_storage) begin
		main_a7ddrphy_dqspattern_o0 <= 1'd0;
		if (main_a7ddrphy_wlevel_strobe_re) begin
			main_a7ddrphy_dqspattern_o0 <= 1'd1;
		end
	end
// synthesis translate_off
	dummy_d_5 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_6;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip00 <= 8'd0;
	case (main_a7ddrphy_bitslip0_value0)
		1'd0: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip00 <= main_a7ddrphy_bitslip0_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_6 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_7;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip10 <= 8'd0;
	case (main_a7ddrphy_bitslip1_value0)
		1'd0: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip10 <= main_a7ddrphy_bitslip1_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_7 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_8;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip01 <= 8'd0;
	case (main_a7ddrphy_bitslip0_value1)
		1'd0: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip01 <= main_a7ddrphy_bitslip0_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_8 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_9;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip11 <= 8'd0;
	case (main_a7ddrphy_bitslip1_value1)
		1'd0: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip11 <= main_a7ddrphy_bitslip1_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_9 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_10;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip02 <= 8'd0;
	case (main_a7ddrphy_bitslip0_value2)
		1'd0: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip02 <= main_a7ddrphy_bitslip0_r2[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_10 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_11;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip04 <= 8'd0;
	case (main_a7ddrphy_bitslip0_value3)
		1'd0: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip04 <= main_a7ddrphy_bitslip0_r3[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_11 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_12;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip12 <= 8'd0;
	case (main_a7ddrphy_bitslip1_value2)
		1'd0: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip12 <= main_a7ddrphy_bitslip1_r2[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_12 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_13;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip14 <= 8'd0;
	case (main_a7ddrphy_bitslip1_value3)
		1'd0: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip14 <= main_a7ddrphy_bitslip1_r3[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_13 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_14;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip20 <= 8'd0;
	case (main_a7ddrphy_bitslip2_value0)
		1'd0: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip20 <= main_a7ddrphy_bitslip2_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_14 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_15;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip22 <= 8'd0;
	case (main_a7ddrphy_bitslip2_value1)
		1'd0: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip22 <= main_a7ddrphy_bitslip2_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_15 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_16;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip30 <= 8'd0;
	case (main_a7ddrphy_bitslip3_value0)
		1'd0: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip30 <= main_a7ddrphy_bitslip3_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_16 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_17;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip32 <= 8'd0;
	case (main_a7ddrphy_bitslip3_value1)
		1'd0: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip32 <= main_a7ddrphy_bitslip3_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_17 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_18;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip40 <= 8'd0;
	case (main_a7ddrphy_bitslip4_value0)
		1'd0: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip40 <= main_a7ddrphy_bitslip4_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_18 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_19;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip42 <= 8'd0;
	case (main_a7ddrphy_bitslip4_value1)
		1'd0: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip42 <= main_a7ddrphy_bitslip4_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_19 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_20;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip50 <= 8'd0;
	case (main_a7ddrphy_bitslip5_value0)
		1'd0: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip50 <= main_a7ddrphy_bitslip5_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_20 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_21;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip52 <= 8'd0;
	case (main_a7ddrphy_bitslip5_value1)
		1'd0: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip52 <= main_a7ddrphy_bitslip5_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_21 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_22;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip60 <= 8'd0;
	case (main_a7ddrphy_bitslip6_value0)
		1'd0: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip60 <= main_a7ddrphy_bitslip6_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_22 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_23;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip62 <= 8'd0;
	case (main_a7ddrphy_bitslip6_value1)
		1'd0: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip62 <= main_a7ddrphy_bitslip6_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_23 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_24;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip70 <= 8'd0;
	case (main_a7ddrphy_bitslip7_value0)
		1'd0: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip70 <= main_a7ddrphy_bitslip7_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_24 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_25;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip72 <= 8'd0;
	case (main_a7ddrphy_bitslip7_value1)
		1'd0: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip72 <= main_a7ddrphy_bitslip7_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_25 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_26;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip80 <= 8'd0;
	case (main_a7ddrphy_bitslip8_value0)
		1'd0: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip80 <= main_a7ddrphy_bitslip8_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_26 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_27;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip82 <= 8'd0;
	case (main_a7ddrphy_bitslip8_value1)
		1'd0: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip82 <= main_a7ddrphy_bitslip8_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_27 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_28;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip90 <= 8'd0;
	case (main_a7ddrphy_bitslip9_value0)
		1'd0: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip90 <= main_a7ddrphy_bitslip9_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_28 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_29;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip92 <= 8'd0;
	case (main_a7ddrphy_bitslip9_value1)
		1'd0: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip92 <= main_a7ddrphy_bitslip9_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_29 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_30;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip100 <= 8'd0;
	case (main_a7ddrphy_bitslip10_value0)
		1'd0: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip100 <= main_a7ddrphy_bitslip10_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_30 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_31;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip102 <= 8'd0;
	case (main_a7ddrphy_bitslip10_value1)
		1'd0: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip102 <= main_a7ddrphy_bitslip10_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_31 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_32;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip110 <= 8'd0;
	case (main_a7ddrphy_bitslip11_value0)
		1'd0: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip110 <= main_a7ddrphy_bitslip11_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_32 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_33;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip112 <= 8'd0;
	case (main_a7ddrphy_bitslip11_value1)
		1'd0: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip112 <= main_a7ddrphy_bitslip11_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_33 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_34;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip120 <= 8'd0;
	case (main_a7ddrphy_bitslip12_value0)
		1'd0: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip120 <= main_a7ddrphy_bitslip12_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_34 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_35;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip122 <= 8'd0;
	case (main_a7ddrphy_bitslip12_value1)
		1'd0: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip122 <= main_a7ddrphy_bitslip12_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_35 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_36;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip130 <= 8'd0;
	case (main_a7ddrphy_bitslip13_value0)
		1'd0: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip130 <= main_a7ddrphy_bitslip13_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_36 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_37;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip132 <= 8'd0;
	case (main_a7ddrphy_bitslip13_value1)
		1'd0: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip132 <= main_a7ddrphy_bitslip13_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_37 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_38;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip140 <= 8'd0;
	case (main_a7ddrphy_bitslip14_value0)
		1'd0: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip140 <= main_a7ddrphy_bitslip14_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_38 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_39;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip142 <= 8'd0;
	case (main_a7ddrphy_bitslip14_value1)
		1'd0: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip142 <= main_a7ddrphy_bitslip14_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_39 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_40;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip150 <= 8'd0;
	case (main_a7ddrphy_bitslip15_value0)
		1'd0: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip150 <= main_a7ddrphy_bitslip15_r0[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_40 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_41;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_bitslip152 <= 8'd0;
	case (main_a7ddrphy_bitslip15_value1)
		1'd0: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[8:1];
		end
		1'd1: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[9:2];
		end
		2'd2: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[10:3];
		end
		2'd3: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[11:4];
		end
		3'd4: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[12:5];
		end
		3'd5: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[13:6];
		end
		3'd6: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[14:7];
		end
		3'd7: begin
			main_a7ddrphy_bitslip152 <= main_a7ddrphy_bitslip15_r1[15:8];
		end
	endcase
// synthesis translate_off
	dummy_d_41 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_dfi_p0_address = main_litedramcore_master_p0_address;
assign main_a7ddrphy_dfi_p0_bank = main_litedramcore_master_p0_bank;
assign main_a7ddrphy_dfi_p0_cas_n = main_litedramcore_master_p0_cas_n;
assign main_a7ddrphy_dfi_p0_cs_n = main_litedramcore_master_p0_cs_n;
assign main_a7ddrphy_dfi_p0_ras_n = main_litedramcore_master_p0_ras_n;
assign main_a7ddrphy_dfi_p0_we_n = main_litedramcore_master_p0_we_n;
assign main_a7ddrphy_dfi_p0_cke = main_litedramcore_master_p0_cke;
assign main_a7ddrphy_dfi_p0_odt = main_litedramcore_master_p0_odt;
assign main_a7ddrphy_dfi_p0_reset_n = main_litedramcore_master_p0_reset_n;
assign main_a7ddrphy_dfi_p0_act_n = main_litedramcore_master_p0_act_n;
assign main_a7ddrphy_dfi_p0_wrdata = main_litedramcore_master_p0_wrdata;
assign main_a7ddrphy_dfi_p0_wrdata_en = main_litedramcore_master_p0_wrdata_en;
assign main_a7ddrphy_dfi_p0_wrdata_mask = main_litedramcore_master_p0_wrdata_mask;
assign main_a7ddrphy_dfi_p0_rddata_en = main_litedramcore_master_p0_rddata_en;
assign main_litedramcore_master_p0_rddata = main_a7ddrphy_dfi_p0_rddata;
assign main_litedramcore_master_p0_rddata_valid = main_a7ddrphy_dfi_p0_rddata_valid;
assign main_a7ddrphy_dfi_p1_address = main_litedramcore_master_p1_address;
assign main_a7ddrphy_dfi_p1_bank = main_litedramcore_master_p1_bank;
assign main_a7ddrphy_dfi_p1_cas_n = main_litedramcore_master_p1_cas_n;
assign main_a7ddrphy_dfi_p1_cs_n = main_litedramcore_master_p1_cs_n;
assign main_a7ddrphy_dfi_p1_ras_n = main_litedramcore_master_p1_ras_n;
assign main_a7ddrphy_dfi_p1_we_n = main_litedramcore_master_p1_we_n;
assign main_a7ddrphy_dfi_p1_cke = main_litedramcore_master_p1_cke;
assign main_a7ddrphy_dfi_p1_odt = main_litedramcore_master_p1_odt;
assign main_a7ddrphy_dfi_p1_reset_n = main_litedramcore_master_p1_reset_n;
assign main_a7ddrphy_dfi_p1_act_n = main_litedramcore_master_p1_act_n;
assign main_a7ddrphy_dfi_p1_wrdata = main_litedramcore_master_p1_wrdata;
assign main_a7ddrphy_dfi_p1_wrdata_en = main_litedramcore_master_p1_wrdata_en;
assign main_a7ddrphy_dfi_p1_wrdata_mask = main_litedramcore_master_p1_wrdata_mask;
assign main_a7ddrphy_dfi_p1_rddata_en = main_litedramcore_master_p1_rddata_en;
assign main_litedramcore_master_p1_rddata = main_a7ddrphy_dfi_p1_rddata;
assign main_litedramcore_master_p1_rddata_valid = main_a7ddrphy_dfi_p1_rddata_valid;
assign main_litedramcore_slave_p0_address = main_litedramcore_dfi_p0_address;
assign main_litedramcore_slave_p0_bank = main_litedramcore_dfi_p0_bank;
assign main_litedramcore_slave_p0_cas_n = main_litedramcore_dfi_p0_cas_n;
assign main_litedramcore_slave_p0_cs_n = main_litedramcore_dfi_p0_cs_n;
assign main_litedramcore_slave_p0_ras_n = main_litedramcore_dfi_p0_ras_n;
assign main_litedramcore_slave_p0_we_n = main_litedramcore_dfi_p0_we_n;
assign main_litedramcore_slave_p0_cke = main_litedramcore_dfi_p0_cke;
assign main_litedramcore_slave_p0_odt = main_litedramcore_dfi_p0_odt;
assign main_litedramcore_slave_p0_reset_n = main_litedramcore_dfi_p0_reset_n;
assign main_litedramcore_slave_p0_act_n = main_litedramcore_dfi_p0_act_n;
assign main_litedramcore_slave_p0_wrdata = main_litedramcore_dfi_p0_wrdata;
assign main_litedramcore_slave_p0_wrdata_en = main_litedramcore_dfi_p0_wrdata_en;
assign main_litedramcore_slave_p0_wrdata_mask = main_litedramcore_dfi_p0_wrdata_mask;
assign main_litedramcore_slave_p0_rddata_en = main_litedramcore_dfi_p0_rddata_en;
assign main_litedramcore_dfi_p0_rddata = main_litedramcore_slave_p0_rddata;
assign main_litedramcore_dfi_p0_rddata_valid = main_litedramcore_slave_p0_rddata_valid;
assign main_litedramcore_slave_p1_address = main_litedramcore_dfi_p1_address;
assign main_litedramcore_slave_p1_bank = main_litedramcore_dfi_p1_bank;
assign main_litedramcore_slave_p1_cas_n = main_litedramcore_dfi_p1_cas_n;
assign main_litedramcore_slave_p1_cs_n = main_litedramcore_dfi_p1_cs_n;
assign main_litedramcore_slave_p1_ras_n = main_litedramcore_dfi_p1_ras_n;
assign main_litedramcore_slave_p1_we_n = main_litedramcore_dfi_p1_we_n;
assign main_litedramcore_slave_p1_cke = main_litedramcore_dfi_p1_cke;
assign main_litedramcore_slave_p1_odt = main_litedramcore_dfi_p1_odt;
assign main_litedramcore_slave_p1_reset_n = main_litedramcore_dfi_p1_reset_n;
assign main_litedramcore_slave_p1_act_n = main_litedramcore_dfi_p1_act_n;
assign main_litedramcore_slave_p1_wrdata = main_litedramcore_dfi_p1_wrdata;
assign main_litedramcore_slave_p1_wrdata_en = main_litedramcore_dfi_p1_wrdata_en;
assign main_litedramcore_slave_p1_wrdata_mask = main_litedramcore_dfi_p1_wrdata_mask;
assign main_litedramcore_slave_p1_rddata_en = main_litedramcore_dfi_p1_rddata_en;
assign main_litedramcore_dfi_p1_rddata = main_litedramcore_slave_p1_rddata;
assign main_litedramcore_dfi_p1_rddata_valid = main_litedramcore_slave_p1_rddata_valid;

// synthesis translate_off
reg dummy_d_42;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_reset_n <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_reset_n <= main_litedramcore_slave_p1_reset_n;
	end else begin
		main_litedramcore_master_p1_reset_n <= main_litedramcore_inti_p1_reset_n;
	end
// synthesis translate_off
	dummy_d_42 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_43;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_act_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_act_n <= main_litedramcore_slave_p1_act_n;
	end else begin
		main_litedramcore_master_p1_act_n <= main_litedramcore_inti_p1_act_n;
	end
// synthesis translate_off
	dummy_d_43 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_44;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_wrdata <= 32'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_wrdata <= main_litedramcore_slave_p1_wrdata;
	end else begin
		main_litedramcore_master_p1_wrdata <= main_litedramcore_inti_p1_wrdata;
	end
// synthesis translate_off
	dummy_d_44 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_45;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_wrdata_en <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_wrdata_en <= main_litedramcore_slave_p1_wrdata_en;
	end else begin
		main_litedramcore_master_p1_wrdata_en <= main_litedramcore_inti_p1_wrdata_en;
	end
// synthesis translate_off
	dummy_d_45 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_46;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_wrdata_mask <= 4'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_wrdata_mask <= main_litedramcore_slave_p1_wrdata_mask;
	end else begin
		main_litedramcore_master_p1_wrdata_mask <= main_litedramcore_inti_p1_wrdata_mask;
	end
// synthesis translate_off
	dummy_d_46 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_47;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_rddata_en <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_rddata_en <= main_litedramcore_slave_p1_rddata_en;
	end else begin
		main_litedramcore_master_p1_rddata_en <= main_litedramcore_inti_p1_rddata_en;
	end
// synthesis translate_off
	dummy_d_47 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_48;
// synthesis translate_on
always @(*) begin
	main_litedramcore_slave_p0_rddata <= 32'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_slave_p0_rddata <= main_litedramcore_master_p0_rddata;
	end else begin
	end
// synthesis translate_off
	dummy_d_48 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_49;
// synthesis translate_on
always @(*) begin
	main_litedramcore_slave_p0_rddata_valid <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_slave_p0_rddata_valid <= main_litedramcore_master_p0_rddata_valid;
	end else begin
	end
// synthesis translate_off
	dummy_d_49 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_50;
// synthesis translate_on
always @(*) begin
	main_litedramcore_slave_p1_rddata <= 32'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_slave_p1_rddata <= main_litedramcore_master_p1_rddata;
	end else begin
	end
// synthesis translate_off
	dummy_d_50 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_51;
// synthesis translate_on
always @(*) begin
	main_litedramcore_slave_p1_rddata_valid <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_slave_p1_rddata_valid <= main_litedramcore_master_p1_rddata_valid;
	end else begin
	end
// synthesis translate_off
	dummy_d_51 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_52;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_address <= 13'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_address <= main_litedramcore_slave_p0_address;
	end else begin
		main_litedramcore_master_p0_address <= main_litedramcore_inti_p0_address;
	end
// synthesis translate_off
	dummy_d_52 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_53;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_rddata <= 32'd0;
	if (main_litedramcore_sel) begin
	end else begin
		main_litedramcore_inti_p1_rddata <= main_litedramcore_master_p1_rddata;
	end
// synthesis translate_off
	dummy_d_53 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_54;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_bank <= 3'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_bank <= main_litedramcore_slave_p0_bank;
	end else begin
		main_litedramcore_master_p0_bank <= main_litedramcore_inti_p0_bank;
	end
// synthesis translate_off
	dummy_d_54 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_55;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_cas_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_cas_n <= main_litedramcore_slave_p0_cas_n;
	end else begin
		main_litedramcore_master_p0_cas_n <= main_litedramcore_inti_p0_cas_n;
	end
// synthesis translate_off
	dummy_d_55 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_56;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_cs_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_cs_n <= main_litedramcore_slave_p0_cs_n;
	end else begin
		main_litedramcore_master_p0_cs_n <= main_litedramcore_inti_p0_cs_n;
	end
// synthesis translate_off
	dummy_d_56 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_57;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_ras_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_ras_n <= main_litedramcore_slave_p0_ras_n;
	end else begin
		main_litedramcore_master_p0_ras_n <= main_litedramcore_inti_p0_ras_n;
	end
// synthesis translate_off
	dummy_d_57 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_58;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_rddata <= 32'd0;
	if (main_litedramcore_sel) begin
	end else begin
		main_litedramcore_inti_p0_rddata <= main_litedramcore_master_p0_rddata;
	end
// synthesis translate_off
	dummy_d_58 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_59;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_we_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_we_n <= main_litedramcore_slave_p0_we_n;
	end else begin
		main_litedramcore_master_p0_we_n <= main_litedramcore_inti_p0_we_n;
	end
// synthesis translate_off
	dummy_d_59 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_60;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_rddata_valid <= 1'd0;
	if (main_litedramcore_sel) begin
	end else begin
		main_litedramcore_inti_p0_rddata_valid <= main_litedramcore_master_p0_rddata_valid;
	end
// synthesis translate_off
	dummy_d_60 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_61;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_cke <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_cke <= main_litedramcore_slave_p0_cke;
	end else begin
		main_litedramcore_master_p0_cke <= main_litedramcore_inti_p0_cke;
	end
// synthesis translate_off
	dummy_d_61 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_62;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_rddata_valid <= 1'd0;
	if (main_litedramcore_sel) begin
	end else begin
		main_litedramcore_inti_p1_rddata_valid <= main_litedramcore_master_p1_rddata_valid;
	end
// synthesis translate_off
	dummy_d_62 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_63;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_odt <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_odt <= main_litedramcore_slave_p0_odt;
	end else begin
		main_litedramcore_master_p0_odt <= main_litedramcore_inti_p0_odt;
	end
// synthesis translate_off
	dummy_d_63 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_64;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_reset_n <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_reset_n <= main_litedramcore_slave_p0_reset_n;
	end else begin
		main_litedramcore_master_p0_reset_n <= main_litedramcore_inti_p0_reset_n;
	end
// synthesis translate_off
	dummy_d_64 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_65;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_act_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_act_n <= main_litedramcore_slave_p0_act_n;
	end else begin
		main_litedramcore_master_p0_act_n <= main_litedramcore_inti_p0_act_n;
	end
// synthesis translate_off
	dummy_d_65 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_66;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_wrdata <= 32'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_wrdata <= main_litedramcore_slave_p0_wrdata;
	end else begin
		main_litedramcore_master_p0_wrdata <= main_litedramcore_inti_p0_wrdata;
	end
// synthesis translate_off
	dummy_d_66 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_67;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_wrdata_en <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_wrdata_en <= main_litedramcore_slave_p0_wrdata_en;
	end else begin
		main_litedramcore_master_p0_wrdata_en <= main_litedramcore_inti_p0_wrdata_en;
	end
// synthesis translate_off
	dummy_d_67 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_68;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_wrdata_mask <= 4'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_wrdata_mask <= main_litedramcore_slave_p0_wrdata_mask;
	end else begin
		main_litedramcore_master_p0_wrdata_mask <= main_litedramcore_inti_p0_wrdata_mask;
	end
// synthesis translate_off
	dummy_d_68 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_69;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p0_rddata_en <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p0_rddata_en <= main_litedramcore_slave_p0_rddata_en;
	end else begin
		main_litedramcore_master_p0_rddata_en <= main_litedramcore_inti_p0_rddata_en;
	end
// synthesis translate_off
	dummy_d_69 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_70;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_address <= 13'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_address <= main_litedramcore_slave_p1_address;
	end else begin
		main_litedramcore_master_p1_address <= main_litedramcore_inti_p1_address;
	end
// synthesis translate_off
	dummy_d_70 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_71;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_bank <= 3'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_bank <= main_litedramcore_slave_p1_bank;
	end else begin
		main_litedramcore_master_p1_bank <= main_litedramcore_inti_p1_bank;
	end
// synthesis translate_off
	dummy_d_71 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_72;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_cas_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_cas_n <= main_litedramcore_slave_p1_cas_n;
	end else begin
		main_litedramcore_master_p1_cas_n <= main_litedramcore_inti_p1_cas_n;
	end
// synthesis translate_off
	dummy_d_72 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_73;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_cs_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_cs_n <= main_litedramcore_slave_p1_cs_n;
	end else begin
		main_litedramcore_master_p1_cs_n <= main_litedramcore_inti_p1_cs_n;
	end
// synthesis translate_off
	dummy_d_73 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_74;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_ras_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_ras_n <= main_litedramcore_slave_p1_ras_n;
	end else begin
		main_litedramcore_master_p1_ras_n <= main_litedramcore_inti_p1_ras_n;
	end
// synthesis translate_off
	dummy_d_74 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_75;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_we_n <= 1'd1;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_we_n <= main_litedramcore_slave_p1_we_n;
	end else begin
		main_litedramcore_master_p1_we_n <= main_litedramcore_inti_p1_we_n;
	end
// synthesis translate_off
	dummy_d_75 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_76;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_cke <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_cke <= main_litedramcore_slave_p1_cke;
	end else begin
		main_litedramcore_master_p1_cke <= main_litedramcore_inti_p1_cke;
	end
// synthesis translate_off
	dummy_d_76 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_77;
// synthesis translate_on
always @(*) begin
	main_litedramcore_master_p1_odt <= 1'd0;
	if (main_litedramcore_sel) begin
		main_litedramcore_master_p1_odt <= main_litedramcore_slave_p1_odt;
	end else begin
		main_litedramcore_master_p1_odt <= main_litedramcore_inti_p1_odt;
	end
// synthesis translate_off
	dummy_d_77 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_inti_p0_cke = main_litedramcore_cke;
assign main_litedramcore_inti_p1_cke = main_litedramcore_cke;
assign main_litedramcore_inti_p0_odt = main_litedramcore_odt;
assign main_litedramcore_inti_p1_odt = main_litedramcore_odt;
assign main_litedramcore_inti_p0_reset_n = main_litedramcore_reset_n;
assign main_litedramcore_inti_p1_reset_n = main_litedramcore_reset_n;

// synthesis translate_off
reg dummy_d_78;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_cas_n <= 1'd1;
	if (main_litedramcore_phaseinjector0_command_issue_re) begin
		main_litedramcore_inti_p0_cas_n <= (~main_litedramcore_phaseinjector0_command_storage[2]);
	end else begin
		main_litedramcore_inti_p0_cas_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_78 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_79;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_cs_n <= 1'd1;
	if (main_litedramcore_phaseinjector0_command_issue_re) begin
		main_litedramcore_inti_p0_cs_n <= {1{(~main_litedramcore_phaseinjector0_command_storage[0])}};
	end else begin
		main_litedramcore_inti_p0_cs_n <= {1{1'd1}};
	end
// synthesis translate_off
	dummy_d_79 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_80;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_ras_n <= 1'd1;
	if (main_litedramcore_phaseinjector0_command_issue_re) begin
		main_litedramcore_inti_p0_ras_n <= (~main_litedramcore_phaseinjector0_command_storage[3]);
	end else begin
		main_litedramcore_inti_p0_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_80 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_81;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p0_we_n <= 1'd1;
	if (main_litedramcore_phaseinjector0_command_issue_re) begin
		main_litedramcore_inti_p0_we_n <= (~main_litedramcore_phaseinjector0_command_storage[1]);
	end else begin
		main_litedramcore_inti_p0_we_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_81 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_inti_p0_address = main_litedramcore_phaseinjector0_address_storage;
assign main_litedramcore_inti_p0_bank = main_litedramcore_phaseinjector0_baddress_storage;
assign main_litedramcore_inti_p0_wrdata_en = (main_litedramcore_phaseinjector0_command_issue_re & main_litedramcore_phaseinjector0_command_storage[4]);
assign main_litedramcore_inti_p0_rddata_en = (main_litedramcore_phaseinjector0_command_issue_re & main_litedramcore_phaseinjector0_command_storage[5]);
assign main_litedramcore_inti_p0_wrdata = main_litedramcore_phaseinjector0_wrdata_storage;
assign main_litedramcore_inti_p0_wrdata_mask = 1'd0;

// synthesis translate_off
reg dummy_d_82;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_cas_n <= 1'd1;
	if (main_litedramcore_phaseinjector1_command_issue_re) begin
		main_litedramcore_inti_p1_cas_n <= (~main_litedramcore_phaseinjector1_command_storage[2]);
	end else begin
		main_litedramcore_inti_p1_cas_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_82 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_83;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_cs_n <= 1'd1;
	if (main_litedramcore_phaseinjector1_command_issue_re) begin
		main_litedramcore_inti_p1_cs_n <= {1{(~main_litedramcore_phaseinjector1_command_storage[0])}};
	end else begin
		main_litedramcore_inti_p1_cs_n <= {1{1'd1}};
	end
// synthesis translate_off
	dummy_d_83 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_84;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_ras_n <= 1'd1;
	if (main_litedramcore_phaseinjector1_command_issue_re) begin
		main_litedramcore_inti_p1_ras_n <= (~main_litedramcore_phaseinjector1_command_storage[3]);
	end else begin
		main_litedramcore_inti_p1_ras_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_84 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_85;
// synthesis translate_on
always @(*) begin
	main_litedramcore_inti_p1_we_n <= 1'd1;
	if (main_litedramcore_phaseinjector1_command_issue_re) begin
		main_litedramcore_inti_p1_we_n <= (~main_litedramcore_phaseinjector1_command_storage[1]);
	end else begin
		main_litedramcore_inti_p1_we_n <= 1'd1;
	end
// synthesis translate_off
	dummy_d_85 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_inti_p1_address = main_litedramcore_phaseinjector1_address_storage;
assign main_litedramcore_inti_p1_bank = main_litedramcore_phaseinjector1_baddress_storage;
assign main_litedramcore_inti_p1_wrdata_en = (main_litedramcore_phaseinjector1_command_issue_re & main_litedramcore_phaseinjector1_command_storage[4]);
assign main_litedramcore_inti_p1_rddata_en = (main_litedramcore_phaseinjector1_command_issue_re & main_litedramcore_phaseinjector1_command_storage[5]);
assign main_litedramcore_inti_p1_wrdata = main_litedramcore_phaseinjector1_wrdata_storage;
assign main_litedramcore_inti_p1_wrdata_mask = 1'd0;
assign main_litedramcore_bankmachine0_req_valid = main_litedramcore_interface_bank0_valid;
assign main_litedramcore_interface_bank0_ready = main_litedramcore_bankmachine0_req_ready;
assign main_litedramcore_bankmachine0_req_we = main_litedramcore_interface_bank0_we;
assign main_litedramcore_bankmachine0_req_addr = main_litedramcore_interface_bank0_addr;
assign main_litedramcore_interface_bank0_lock = main_litedramcore_bankmachine0_req_lock;
assign main_litedramcore_interface_bank0_wdata_ready = main_litedramcore_bankmachine0_req_wdata_ready;
assign main_litedramcore_interface_bank0_rdata_valid = main_litedramcore_bankmachine0_req_rdata_valid;
assign main_litedramcore_bankmachine1_req_valid = main_litedramcore_interface_bank1_valid;
assign main_litedramcore_interface_bank1_ready = main_litedramcore_bankmachine1_req_ready;
assign main_litedramcore_bankmachine1_req_we = main_litedramcore_interface_bank1_we;
assign main_litedramcore_bankmachine1_req_addr = main_litedramcore_interface_bank1_addr;
assign main_litedramcore_interface_bank1_lock = main_litedramcore_bankmachine1_req_lock;
assign main_litedramcore_interface_bank1_wdata_ready = main_litedramcore_bankmachine1_req_wdata_ready;
assign main_litedramcore_interface_bank1_rdata_valid = main_litedramcore_bankmachine1_req_rdata_valid;
assign main_litedramcore_bankmachine2_req_valid = main_litedramcore_interface_bank2_valid;
assign main_litedramcore_interface_bank2_ready = main_litedramcore_bankmachine2_req_ready;
assign main_litedramcore_bankmachine2_req_we = main_litedramcore_interface_bank2_we;
assign main_litedramcore_bankmachine2_req_addr = main_litedramcore_interface_bank2_addr;
assign main_litedramcore_interface_bank2_lock = main_litedramcore_bankmachine2_req_lock;
assign main_litedramcore_interface_bank2_wdata_ready = main_litedramcore_bankmachine2_req_wdata_ready;
assign main_litedramcore_interface_bank2_rdata_valid = main_litedramcore_bankmachine2_req_rdata_valid;
assign main_litedramcore_bankmachine3_req_valid = main_litedramcore_interface_bank3_valid;
assign main_litedramcore_interface_bank3_ready = main_litedramcore_bankmachine3_req_ready;
assign main_litedramcore_bankmachine3_req_we = main_litedramcore_interface_bank3_we;
assign main_litedramcore_bankmachine3_req_addr = main_litedramcore_interface_bank3_addr;
assign main_litedramcore_interface_bank3_lock = main_litedramcore_bankmachine3_req_lock;
assign main_litedramcore_interface_bank3_wdata_ready = main_litedramcore_bankmachine3_req_wdata_ready;
assign main_litedramcore_interface_bank3_rdata_valid = main_litedramcore_bankmachine3_req_rdata_valid;
assign main_litedramcore_bankmachine4_req_valid = main_litedramcore_interface_bank4_valid;
assign main_litedramcore_interface_bank4_ready = main_litedramcore_bankmachine4_req_ready;
assign main_litedramcore_bankmachine4_req_we = main_litedramcore_interface_bank4_we;
assign main_litedramcore_bankmachine4_req_addr = main_litedramcore_interface_bank4_addr;
assign main_litedramcore_interface_bank4_lock = main_litedramcore_bankmachine4_req_lock;
assign main_litedramcore_interface_bank4_wdata_ready = main_litedramcore_bankmachine4_req_wdata_ready;
assign main_litedramcore_interface_bank4_rdata_valid = main_litedramcore_bankmachine4_req_rdata_valid;
assign main_litedramcore_bankmachine5_req_valid = main_litedramcore_interface_bank5_valid;
assign main_litedramcore_interface_bank5_ready = main_litedramcore_bankmachine5_req_ready;
assign main_litedramcore_bankmachine5_req_we = main_litedramcore_interface_bank5_we;
assign main_litedramcore_bankmachine5_req_addr = main_litedramcore_interface_bank5_addr;
assign main_litedramcore_interface_bank5_lock = main_litedramcore_bankmachine5_req_lock;
assign main_litedramcore_interface_bank5_wdata_ready = main_litedramcore_bankmachine5_req_wdata_ready;
assign main_litedramcore_interface_bank5_rdata_valid = main_litedramcore_bankmachine5_req_rdata_valid;
assign main_litedramcore_bankmachine6_req_valid = main_litedramcore_interface_bank6_valid;
assign main_litedramcore_interface_bank6_ready = main_litedramcore_bankmachine6_req_ready;
assign main_litedramcore_bankmachine6_req_we = main_litedramcore_interface_bank6_we;
assign main_litedramcore_bankmachine6_req_addr = main_litedramcore_interface_bank6_addr;
assign main_litedramcore_interface_bank6_lock = main_litedramcore_bankmachine6_req_lock;
assign main_litedramcore_interface_bank6_wdata_ready = main_litedramcore_bankmachine6_req_wdata_ready;
assign main_litedramcore_interface_bank6_rdata_valid = main_litedramcore_bankmachine6_req_rdata_valid;
assign main_litedramcore_bankmachine7_req_valid = main_litedramcore_interface_bank7_valid;
assign main_litedramcore_interface_bank7_ready = main_litedramcore_bankmachine7_req_ready;
assign main_litedramcore_bankmachine7_req_we = main_litedramcore_interface_bank7_we;
assign main_litedramcore_bankmachine7_req_addr = main_litedramcore_interface_bank7_addr;
assign main_litedramcore_interface_bank7_lock = main_litedramcore_bankmachine7_req_lock;
assign main_litedramcore_interface_bank7_wdata_ready = main_litedramcore_bankmachine7_req_wdata_ready;
assign main_litedramcore_interface_bank7_rdata_valid = main_litedramcore_bankmachine7_req_rdata_valid;
assign main_litedramcore_timer_wait = (~main_litedramcore_timer_done0);
assign main_litedramcore_postponer_req_i = main_litedramcore_timer_done0;
assign main_litedramcore_wants_refresh = main_litedramcore_postponer_req_o;
assign main_litedramcore_timer_done1 = (main_litedramcore_timer_count1 == 1'd0);
assign main_litedramcore_timer_done0 = main_litedramcore_timer_done1;
assign main_litedramcore_timer_count0 = main_litedramcore_timer_count1;
assign main_litedramcore_sequencer_start1 = (main_litedramcore_sequencer_start0 | (main_litedramcore_sequencer_count != 1'd0));
assign main_litedramcore_sequencer_done0 = (main_litedramcore_sequencer_done1 & (main_litedramcore_sequencer_count == 1'd0));

// synthesis translate_off
reg dummy_d_86;
// synthesis translate_on
always @(*) begin
	builder_refresher_next_state <= 2'd0;
	builder_refresher_next_state <= builder_refresher_state;
	case (builder_refresher_state)
		1'd1: begin
			if (main_litedramcore_cmd_ready) begin
				builder_refresher_next_state <= 2'd2;
			end
		end
		2'd2: begin
			if (main_litedramcore_sequencer_done0) begin
				builder_refresher_next_state <= 1'd0;
			end
		end
		default: begin
			if (1'd1) begin
				if (main_litedramcore_wants_refresh) begin
					builder_refresher_next_state <= 1'd1;
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_86 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_87;
// synthesis translate_on
always @(*) begin
	main_litedramcore_cmd_valid <= 1'd0;
	case (builder_refresher_state)
		1'd1: begin
			main_litedramcore_cmd_valid <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_cmd_valid <= 1'd1;
			if (main_litedramcore_sequencer_done0) begin
				main_litedramcore_cmd_valid <= 1'd0;
			end
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_87 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_88;
// synthesis translate_on
always @(*) begin
	main_litedramcore_sequencer_start0 <= 1'd0;
	case (builder_refresher_state)
		1'd1: begin
			if (main_litedramcore_cmd_ready) begin
				main_litedramcore_sequencer_start0 <= 1'd1;
			end
		end
		2'd2: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_88 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_89;
// synthesis translate_on
always @(*) begin
	main_litedramcore_cmd_last <= 1'd0;
	case (builder_refresher_state)
		1'd1: begin
		end
		2'd2: begin
			if (main_litedramcore_sequencer_done0) begin
				main_litedramcore_cmd_last <= 1'd1;
			end
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_89 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine0_req_valid;
assign main_litedramcore_bankmachine0_req_ready = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine0_req_we;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine0_req_addr;
assign main_litedramcore_bankmachine0_cmd_buffer_sink_valid = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine0_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine0_cmd_buffer_sink_first = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine0_cmd_buffer_sink_last = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine0_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine0_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine0_cmd_buffer_source_ready = (main_litedramcore_bankmachine0_req_wdata_ready | main_litedramcore_bankmachine0_req_rdata_valid);
assign main_litedramcore_bankmachine0_req_lock = (main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine0_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine0_row_hit = (main_litedramcore_bankmachine0_row == main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine0_cmd_payload_ba = 1'd0;

// synthesis translate_off
reg dummy_d_90;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine0_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine0_cmd_payload_a <= main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine0_cmd_payload_a <= ((main_litedramcore_bankmachine0_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_90 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine0_twtpcon_valid = ((main_litedramcore_bankmachine0_cmd_valid & main_litedramcore_bankmachine0_cmd_ready) & main_litedramcore_bankmachine0_cmd_payload_is_write);
assign main_litedramcore_bankmachine0_trccon_valid = ((main_litedramcore_bankmachine0_cmd_valid & main_litedramcore_bankmachine0_cmd_ready) & main_litedramcore_bankmachine0_row_open);
assign main_litedramcore_bankmachine0_trascon_valid = ((main_litedramcore_bankmachine0_cmd_valid & main_litedramcore_bankmachine0_cmd_ready) & main_litedramcore_bankmachine0_row_open);

// synthesis translate_off
reg dummy_d_91;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine0_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine0_auto_precharge <= (main_litedramcore_bankmachine0_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_91 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_din = {main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout;
assign {main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout;
assign {main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout;
assign {main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_we = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine0_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_readable;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine0_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_re = main_litedramcore_bankmachine0_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_92;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine0_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_92 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_din;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_we & (main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable | main_litedramcore_bankmachine0_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_readable & main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_re);
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine0_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_dout = main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable = (main_litedramcore_bankmachine0_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_readable = (main_litedramcore_bankmachine0_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine0_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine0_cmd_buffer_source_valid) | main_litedramcore_bankmachine0_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_93;
// synthesis translate_on
always @(*) begin
	builder_bankmachine0_next_state <= 3'd0;
	builder_bankmachine0_next_state <= builder_bankmachine0_state;
	case (builder_bankmachine0_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				if (main_litedramcore_bankmachine0_cmd_ready) begin
					builder_bankmachine0_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				builder_bankmachine0_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				if (main_litedramcore_bankmachine0_cmd_ready) begin
					builder_bankmachine0_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine0_refresh_req)) begin
				builder_bankmachine0_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine0_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine0_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
				builder_bankmachine0_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if ((main_litedramcore_bankmachine0_cmd_ready & main_litedramcore_bankmachine0_auto_precharge)) begin
								builder_bankmachine0_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine0_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine0_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_93 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_94;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_req_wdata_ready <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if (main_litedramcore_bankmachine0_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine0_req_wdata_ready <= main_litedramcore_bankmachine0_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_94 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_95;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_req_rdata_valid <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if (main_litedramcore_bankmachine0_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine0_req_rdata_valid <= main_litedramcore_bankmachine0_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_95 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_96;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_refresh_gnt <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine0_twtpcon_ready) begin
				main_litedramcore_bankmachine0_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_96 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_97;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_valid <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				main_litedramcore_bankmachine0_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				main_litedramcore_bankmachine0_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							main_litedramcore_bankmachine0_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_97 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_98;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				main_litedramcore_bankmachine0_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_98 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_99;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_row_open <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				main_litedramcore_bankmachine0_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_99 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_100;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_row_close <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
			main_litedramcore_bankmachine0_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine0_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine0_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_100 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_101;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							main_litedramcore_bankmachine0_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_101 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_102;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				main_litedramcore_bankmachine0_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				main_litedramcore_bankmachine0_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_102 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_103;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_we <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				main_litedramcore_bankmachine0_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if (main_litedramcore_bankmachine0_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine0_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_103 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_104;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine0_twtpcon_ready & main_litedramcore_bankmachine0_trascon_ready)) begin
				main_litedramcore_bankmachine0_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine0_trccon_ready) begin
				main_litedramcore_bankmachine0_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine0_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_104 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_105;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if (main_litedramcore_bankmachine0_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine0_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_105 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_106;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine0_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine0_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine0_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine0_row_opened) begin
						if (main_litedramcore_bankmachine0_row_hit) begin
							if (main_litedramcore_bankmachine0_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine0_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_106 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine1_req_valid;
assign main_litedramcore_bankmachine1_req_ready = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine1_req_we;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine1_req_addr;
assign main_litedramcore_bankmachine1_cmd_buffer_sink_valid = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine1_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine1_cmd_buffer_sink_first = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine1_cmd_buffer_sink_last = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine1_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine1_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine1_cmd_buffer_source_ready = (main_litedramcore_bankmachine1_req_wdata_ready | main_litedramcore_bankmachine1_req_rdata_valid);
assign main_litedramcore_bankmachine1_req_lock = (main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine1_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine1_row_hit = (main_litedramcore_bankmachine1_row == main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine1_cmd_payload_ba = 1'd1;

// synthesis translate_off
reg dummy_d_107;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine1_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine1_cmd_payload_a <= main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine1_cmd_payload_a <= ((main_litedramcore_bankmachine1_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_107 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine1_twtpcon_valid = ((main_litedramcore_bankmachine1_cmd_valid & main_litedramcore_bankmachine1_cmd_ready) & main_litedramcore_bankmachine1_cmd_payload_is_write);
assign main_litedramcore_bankmachine1_trccon_valid = ((main_litedramcore_bankmachine1_cmd_valid & main_litedramcore_bankmachine1_cmd_ready) & main_litedramcore_bankmachine1_row_open);
assign main_litedramcore_bankmachine1_trascon_valid = ((main_litedramcore_bankmachine1_cmd_valid & main_litedramcore_bankmachine1_cmd_ready) & main_litedramcore_bankmachine1_row_open);

// synthesis translate_off
reg dummy_d_108;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine1_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine1_auto_precharge <= (main_litedramcore_bankmachine1_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_108 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_din = {main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout;
assign {main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout;
assign {main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout;
assign {main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_we = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine1_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_readable;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine1_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_re = main_litedramcore_bankmachine1_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_109;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine1_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_109 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_din;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_we & (main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable | main_litedramcore_bankmachine1_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_readable & main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_re);
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine1_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_dout = main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable = (main_litedramcore_bankmachine1_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_readable = (main_litedramcore_bankmachine1_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine1_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine1_cmd_buffer_source_valid) | main_litedramcore_bankmachine1_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_110;
// synthesis translate_on
always @(*) begin
	builder_bankmachine1_next_state <= 3'd0;
	builder_bankmachine1_next_state <= builder_bankmachine1_state;
	case (builder_bankmachine1_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				if (main_litedramcore_bankmachine1_cmd_ready) begin
					builder_bankmachine1_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				builder_bankmachine1_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				if (main_litedramcore_bankmachine1_cmd_ready) begin
					builder_bankmachine1_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine1_refresh_req)) begin
				builder_bankmachine1_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine1_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine1_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
				builder_bankmachine1_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if ((main_litedramcore_bankmachine1_cmd_ready & main_litedramcore_bankmachine1_auto_precharge)) begin
								builder_bankmachine1_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine1_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine1_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_110 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_111;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_we <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				main_litedramcore_bankmachine1_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if (main_litedramcore_bankmachine1_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine1_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_111 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_112;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				main_litedramcore_bankmachine1_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_112 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_113;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				main_litedramcore_bankmachine1_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				main_litedramcore_bankmachine1_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine1_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_113 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_114;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if (main_litedramcore_bankmachine1_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine1_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_114 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_115;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if (main_litedramcore_bankmachine1_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine1_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_115 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_116;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_req_wdata_ready <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if (main_litedramcore_bankmachine1_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine1_req_wdata_ready <= main_litedramcore_bankmachine1_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_116 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_117;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_req_rdata_valid <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							if (main_litedramcore_bankmachine1_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine1_req_rdata_valid <= main_litedramcore_bankmachine1_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_117 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_118;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_refresh_gnt <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine1_twtpcon_ready) begin
				main_litedramcore_bankmachine1_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_118 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_119;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_valid <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				main_litedramcore_bankmachine1_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				main_litedramcore_bankmachine1_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							main_litedramcore_bankmachine1_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_119 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_120;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_row_open <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				main_litedramcore_bankmachine1_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_120 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_121;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_row_close <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
			main_litedramcore_bankmachine1_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine1_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine1_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_121 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_122;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine1_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine1_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine1_row_opened) begin
						if (main_litedramcore_bankmachine1_row_hit) begin
							main_litedramcore_bankmachine1_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_122 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_123;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine1_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine1_twtpcon_ready & main_litedramcore_bankmachine1_trascon_ready)) begin
				main_litedramcore_bankmachine1_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine1_trccon_ready) begin
				main_litedramcore_bankmachine1_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_123 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine2_req_valid;
assign main_litedramcore_bankmachine2_req_ready = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine2_req_we;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine2_req_addr;
assign main_litedramcore_bankmachine2_cmd_buffer_sink_valid = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine2_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine2_cmd_buffer_sink_first = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine2_cmd_buffer_sink_last = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine2_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine2_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine2_cmd_buffer_source_ready = (main_litedramcore_bankmachine2_req_wdata_ready | main_litedramcore_bankmachine2_req_rdata_valid);
assign main_litedramcore_bankmachine2_req_lock = (main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine2_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine2_row_hit = (main_litedramcore_bankmachine2_row == main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine2_cmd_payload_ba = 2'd2;

// synthesis translate_off
reg dummy_d_124;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine2_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine2_cmd_payload_a <= main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine2_cmd_payload_a <= ((main_litedramcore_bankmachine2_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_124 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine2_twtpcon_valid = ((main_litedramcore_bankmachine2_cmd_valid & main_litedramcore_bankmachine2_cmd_ready) & main_litedramcore_bankmachine2_cmd_payload_is_write);
assign main_litedramcore_bankmachine2_trccon_valid = ((main_litedramcore_bankmachine2_cmd_valid & main_litedramcore_bankmachine2_cmd_ready) & main_litedramcore_bankmachine2_row_open);
assign main_litedramcore_bankmachine2_trascon_valid = ((main_litedramcore_bankmachine2_cmd_valid & main_litedramcore_bankmachine2_cmd_ready) & main_litedramcore_bankmachine2_row_open);

// synthesis translate_off
reg dummy_d_125;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine2_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine2_auto_precharge <= (main_litedramcore_bankmachine2_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_125 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_din = {main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout;
assign {main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout;
assign {main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout;
assign {main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_we = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine2_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_readable;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine2_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_re = main_litedramcore_bankmachine2_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_126;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine2_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_126 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_din;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_we & (main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable | main_litedramcore_bankmachine2_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_readable & main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_re);
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine2_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_dout = main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable = (main_litedramcore_bankmachine2_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_readable = (main_litedramcore_bankmachine2_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine2_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine2_cmd_buffer_source_valid) | main_litedramcore_bankmachine2_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_127;
// synthesis translate_on
always @(*) begin
	builder_bankmachine2_next_state <= 3'd0;
	builder_bankmachine2_next_state <= builder_bankmachine2_state;
	case (builder_bankmachine2_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				if (main_litedramcore_bankmachine2_cmd_ready) begin
					builder_bankmachine2_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				builder_bankmachine2_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				if (main_litedramcore_bankmachine2_cmd_ready) begin
					builder_bankmachine2_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine2_refresh_req)) begin
				builder_bankmachine2_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine2_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine2_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
				builder_bankmachine2_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if ((main_litedramcore_bankmachine2_cmd_ready & main_litedramcore_bankmachine2_auto_precharge)) begin
								builder_bankmachine2_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine2_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine2_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_127 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_128;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_row_open <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				main_litedramcore_bankmachine2_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_128 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_129;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_row_close <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
			main_litedramcore_bankmachine2_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine2_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine2_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_129 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_130;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							main_litedramcore_bankmachine2_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_130 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_131;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				main_litedramcore_bankmachine2_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				main_litedramcore_bankmachine2_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_131 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_132;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_we <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				main_litedramcore_bankmachine2_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if (main_litedramcore_bankmachine2_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine2_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_132 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_133;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				main_litedramcore_bankmachine2_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_133 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_134;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				main_litedramcore_bankmachine2_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				main_litedramcore_bankmachine2_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine2_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_134 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_135;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if (main_litedramcore_bankmachine2_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine2_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_135 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_136;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if (main_litedramcore_bankmachine2_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine2_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_136 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_137;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_req_wdata_ready <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if (main_litedramcore_bankmachine2_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine2_req_wdata_ready <= main_litedramcore_bankmachine2_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_137 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_138;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_req_rdata_valid <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							if (main_litedramcore_bankmachine2_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine2_req_rdata_valid <= main_litedramcore_bankmachine2_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_138 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_139;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_refresh_gnt <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine2_twtpcon_ready) begin
				main_litedramcore_bankmachine2_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_139 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_140;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_valid <= 1'd0;
	case (builder_bankmachine2_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine2_twtpcon_ready & main_litedramcore_bankmachine2_trascon_ready)) begin
				main_litedramcore_bankmachine2_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine2_trccon_ready) begin
				main_litedramcore_bankmachine2_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine2_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine2_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine2_row_opened) begin
						if (main_litedramcore_bankmachine2_row_hit) begin
							main_litedramcore_bankmachine2_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_140 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine3_req_valid;
assign main_litedramcore_bankmachine3_req_ready = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine3_req_we;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine3_req_addr;
assign main_litedramcore_bankmachine3_cmd_buffer_sink_valid = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine3_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine3_cmd_buffer_sink_first = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine3_cmd_buffer_sink_last = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine3_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine3_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine3_cmd_buffer_source_ready = (main_litedramcore_bankmachine3_req_wdata_ready | main_litedramcore_bankmachine3_req_rdata_valid);
assign main_litedramcore_bankmachine3_req_lock = (main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine3_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine3_row_hit = (main_litedramcore_bankmachine3_row == main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine3_cmd_payload_ba = 2'd3;

// synthesis translate_off
reg dummy_d_141;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine3_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine3_cmd_payload_a <= main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine3_cmd_payload_a <= ((main_litedramcore_bankmachine3_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_141 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine3_twtpcon_valid = ((main_litedramcore_bankmachine3_cmd_valid & main_litedramcore_bankmachine3_cmd_ready) & main_litedramcore_bankmachine3_cmd_payload_is_write);
assign main_litedramcore_bankmachine3_trccon_valid = ((main_litedramcore_bankmachine3_cmd_valid & main_litedramcore_bankmachine3_cmd_ready) & main_litedramcore_bankmachine3_row_open);
assign main_litedramcore_bankmachine3_trascon_valid = ((main_litedramcore_bankmachine3_cmd_valid & main_litedramcore_bankmachine3_cmd_ready) & main_litedramcore_bankmachine3_row_open);

// synthesis translate_off
reg dummy_d_142;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine3_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine3_auto_precharge <= (main_litedramcore_bankmachine3_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_142 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_din = {main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout;
assign {main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout;
assign {main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout;
assign {main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_we = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine3_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_readable;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine3_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_re = main_litedramcore_bankmachine3_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_143;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine3_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_143 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_din;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_we & (main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable | main_litedramcore_bankmachine3_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_readable & main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_re);
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine3_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_dout = main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable = (main_litedramcore_bankmachine3_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_readable = (main_litedramcore_bankmachine3_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine3_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine3_cmd_buffer_source_valid) | main_litedramcore_bankmachine3_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_144;
// synthesis translate_on
always @(*) begin
	builder_bankmachine3_next_state <= 3'd0;
	builder_bankmachine3_next_state <= builder_bankmachine3_state;
	case (builder_bankmachine3_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				if (main_litedramcore_bankmachine3_cmd_ready) begin
					builder_bankmachine3_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				builder_bankmachine3_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				if (main_litedramcore_bankmachine3_cmd_ready) begin
					builder_bankmachine3_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine3_refresh_req)) begin
				builder_bankmachine3_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine3_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine3_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
				builder_bankmachine3_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if ((main_litedramcore_bankmachine3_cmd_ready & main_litedramcore_bankmachine3_auto_precharge)) begin
								builder_bankmachine3_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine3_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine3_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_144 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_145;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_valid <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				main_litedramcore_bankmachine3_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				main_litedramcore_bankmachine3_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							main_litedramcore_bankmachine3_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_145 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_146;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_row_open <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				main_litedramcore_bankmachine3_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_146 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_147;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_row_close <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
			main_litedramcore_bankmachine3_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine3_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine3_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_147 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_148;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							main_litedramcore_bankmachine3_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_148 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_149;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				main_litedramcore_bankmachine3_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				main_litedramcore_bankmachine3_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_149 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_150;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_we <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				main_litedramcore_bankmachine3_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if (main_litedramcore_bankmachine3_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine3_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_150 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_151;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				main_litedramcore_bankmachine3_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_151 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_152;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine3_twtpcon_ready & main_litedramcore_bankmachine3_trascon_ready)) begin
				main_litedramcore_bankmachine3_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine3_trccon_ready) begin
				main_litedramcore_bankmachine3_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine3_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_152 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_153;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if (main_litedramcore_bankmachine3_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine3_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_153 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_154;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if (main_litedramcore_bankmachine3_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine3_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_154 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_155;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_req_wdata_ready <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if (main_litedramcore_bankmachine3_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine3_req_wdata_ready <= main_litedramcore_bankmachine3_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_155 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_156;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_req_rdata_valid <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine3_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine3_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine3_row_opened) begin
						if (main_litedramcore_bankmachine3_row_hit) begin
							if (main_litedramcore_bankmachine3_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine3_req_rdata_valid <= main_litedramcore_bankmachine3_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_156 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_157;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_refresh_gnt <= 1'd0;
	case (builder_bankmachine3_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine3_twtpcon_ready) begin
				main_litedramcore_bankmachine3_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_157 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine4_req_valid;
assign main_litedramcore_bankmachine4_req_ready = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine4_req_we;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine4_req_addr;
assign main_litedramcore_bankmachine4_cmd_buffer_sink_valid = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine4_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine4_cmd_buffer_sink_first = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine4_cmd_buffer_sink_last = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine4_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine4_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine4_cmd_buffer_source_ready = (main_litedramcore_bankmachine4_req_wdata_ready | main_litedramcore_bankmachine4_req_rdata_valid);
assign main_litedramcore_bankmachine4_req_lock = (main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine4_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine4_row_hit = (main_litedramcore_bankmachine4_row == main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine4_cmd_payload_ba = 3'd4;

// synthesis translate_off
reg dummy_d_158;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine4_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine4_cmd_payload_a <= main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine4_cmd_payload_a <= ((main_litedramcore_bankmachine4_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_158 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine4_twtpcon_valid = ((main_litedramcore_bankmachine4_cmd_valid & main_litedramcore_bankmachine4_cmd_ready) & main_litedramcore_bankmachine4_cmd_payload_is_write);
assign main_litedramcore_bankmachine4_trccon_valid = ((main_litedramcore_bankmachine4_cmd_valid & main_litedramcore_bankmachine4_cmd_ready) & main_litedramcore_bankmachine4_row_open);
assign main_litedramcore_bankmachine4_trascon_valid = ((main_litedramcore_bankmachine4_cmd_valid & main_litedramcore_bankmachine4_cmd_ready) & main_litedramcore_bankmachine4_row_open);

// synthesis translate_off
reg dummy_d_159;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine4_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine4_auto_precharge <= (main_litedramcore_bankmachine4_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_159 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_din = {main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout;
assign {main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout;
assign {main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout;
assign {main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_we = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine4_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_readable;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine4_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_re = main_litedramcore_bankmachine4_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_160;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine4_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_160 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_din;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_we & (main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable | main_litedramcore_bankmachine4_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_readable & main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_re);
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine4_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_dout = main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable = (main_litedramcore_bankmachine4_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_readable = (main_litedramcore_bankmachine4_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine4_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine4_cmd_buffer_source_valid) | main_litedramcore_bankmachine4_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_161;
// synthesis translate_on
always @(*) begin
	builder_bankmachine4_next_state <= 3'd0;
	builder_bankmachine4_next_state <= builder_bankmachine4_state;
	case (builder_bankmachine4_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				if (main_litedramcore_bankmachine4_cmd_ready) begin
					builder_bankmachine4_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				builder_bankmachine4_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				if (main_litedramcore_bankmachine4_cmd_ready) begin
					builder_bankmachine4_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine4_refresh_req)) begin
				builder_bankmachine4_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine4_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine4_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
				builder_bankmachine4_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if ((main_litedramcore_bankmachine4_cmd_ready & main_litedramcore_bankmachine4_auto_precharge)) begin
								builder_bankmachine4_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine4_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine4_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_161 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_162;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_req_wdata_ready <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if (main_litedramcore_bankmachine4_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine4_req_wdata_ready <= main_litedramcore_bankmachine4_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_162 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_163;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_req_rdata_valid <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if (main_litedramcore_bankmachine4_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine4_req_rdata_valid <= main_litedramcore_bankmachine4_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_163 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_164;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_refresh_gnt <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine4_twtpcon_ready) begin
				main_litedramcore_bankmachine4_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_164 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_165;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_valid <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				main_litedramcore_bankmachine4_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				main_litedramcore_bankmachine4_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							main_litedramcore_bankmachine4_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_165 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_166;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				main_litedramcore_bankmachine4_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_166 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_167;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_row_open <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				main_litedramcore_bankmachine4_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_167 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_168;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_row_close <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
			main_litedramcore_bankmachine4_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine4_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine4_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_168 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_169;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							main_litedramcore_bankmachine4_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_169 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_170;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				main_litedramcore_bankmachine4_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				main_litedramcore_bankmachine4_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_170 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_171;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_we <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				main_litedramcore_bankmachine4_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if (main_litedramcore_bankmachine4_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine4_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_171 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_172;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine4_twtpcon_ready & main_litedramcore_bankmachine4_trascon_ready)) begin
				main_litedramcore_bankmachine4_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine4_trccon_ready) begin
				main_litedramcore_bankmachine4_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine4_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_172 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_173;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if (main_litedramcore_bankmachine4_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine4_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_173 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_174;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine4_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine4_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine4_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine4_row_opened) begin
						if (main_litedramcore_bankmachine4_row_hit) begin
							if (main_litedramcore_bankmachine4_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine4_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_174 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine5_req_valid;
assign main_litedramcore_bankmachine5_req_ready = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine5_req_we;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine5_req_addr;
assign main_litedramcore_bankmachine5_cmd_buffer_sink_valid = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine5_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine5_cmd_buffer_sink_first = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine5_cmd_buffer_sink_last = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine5_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine5_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine5_cmd_buffer_source_ready = (main_litedramcore_bankmachine5_req_wdata_ready | main_litedramcore_bankmachine5_req_rdata_valid);
assign main_litedramcore_bankmachine5_req_lock = (main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine5_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine5_row_hit = (main_litedramcore_bankmachine5_row == main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine5_cmd_payload_ba = 3'd5;

// synthesis translate_off
reg dummy_d_175;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine5_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine5_cmd_payload_a <= main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine5_cmd_payload_a <= ((main_litedramcore_bankmachine5_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_175 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine5_twtpcon_valid = ((main_litedramcore_bankmachine5_cmd_valid & main_litedramcore_bankmachine5_cmd_ready) & main_litedramcore_bankmachine5_cmd_payload_is_write);
assign main_litedramcore_bankmachine5_trccon_valid = ((main_litedramcore_bankmachine5_cmd_valid & main_litedramcore_bankmachine5_cmd_ready) & main_litedramcore_bankmachine5_row_open);
assign main_litedramcore_bankmachine5_trascon_valid = ((main_litedramcore_bankmachine5_cmd_valid & main_litedramcore_bankmachine5_cmd_ready) & main_litedramcore_bankmachine5_row_open);

// synthesis translate_off
reg dummy_d_176;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine5_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine5_auto_precharge <= (main_litedramcore_bankmachine5_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_176 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_din = {main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout;
assign {main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout;
assign {main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout;
assign {main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_we = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine5_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_readable;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine5_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_re = main_litedramcore_bankmachine5_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_177;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine5_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_177 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_din;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_we & (main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable | main_litedramcore_bankmachine5_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_readable & main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_re);
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine5_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_dout = main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable = (main_litedramcore_bankmachine5_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_readable = (main_litedramcore_bankmachine5_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine5_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine5_cmd_buffer_source_valid) | main_litedramcore_bankmachine5_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_178;
// synthesis translate_on
always @(*) begin
	builder_bankmachine5_next_state <= 3'd0;
	builder_bankmachine5_next_state <= builder_bankmachine5_state;
	case (builder_bankmachine5_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				if (main_litedramcore_bankmachine5_cmd_ready) begin
					builder_bankmachine5_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				builder_bankmachine5_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				if (main_litedramcore_bankmachine5_cmd_ready) begin
					builder_bankmachine5_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine5_refresh_req)) begin
				builder_bankmachine5_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine5_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine5_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
				builder_bankmachine5_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if ((main_litedramcore_bankmachine5_cmd_ready & main_litedramcore_bankmachine5_auto_precharge)) begin
								builder_bankmachine5_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine5_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine5_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_178 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_179;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_we <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				main_litedramcore_bankmachine5_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if (main_litedramcore_bankmachine5_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine5_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_179 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_180;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				main_litedramcore_bankmachine5_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_180 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_181;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				main_litedramcore_bankmachine5_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				main_litedramcore_bankmachine5_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine5_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_181 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_182;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if (main_litedramcore_bankmachine5_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine5_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_182 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_183;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if (main_litedramcore_bankmachine5_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine5_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_183 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_184;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_req_wdata_ready <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if (main_litedramcore_bankmachine5_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine5_req_wdata_ready <= main_litedramcore_bankmachine5_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_184 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_185;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_req_rdata_valid <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							if (main_litedramcore_bankmachine5_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine5_req_rdata_valid <= main_litedramcore_bankmachine5_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_185 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_186;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_refresh_gnt <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine5_twtpcon_ready) begin
				main_litedramcore_bankmachine5_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_186 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_187;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_valid <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				main_litedramcore_bankmachine5_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				main_litedramcore_bankmachine5_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							main_litedramcore_bankmachine5_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_187 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_188;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_row_open <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				main_litedramcore_bankmachine5_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_188 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_189;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_row_close <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
			main_litedramcore_bankmachine5_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine5_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine5_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_189 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_190;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine5_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine5_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine5_row_opened) begin
						if (main_litedramcore_bankmachine5_row_hit) begin
							main_litedramcore_bankmachine5_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_190 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_191;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine5_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine5_twtpcon_ready & main_litedramcore_bankmachine5_trascon_ready)) begin
				main_litedramcore_bankmachine5_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine5_trccon_ready) begin
				main_litedramcore_bankmachine5_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_191 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine6_req_valid;
assign main_litedramcore_bankmachine6_req_ready = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine6_req_we;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine6_req_addr;
assign main_litedramcore_bankmachine6_cmd_buffer_sink_valid = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine6_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine6_cmd_buffer_sink_first = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine6_cmd_buffer_sink_last = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine6_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine6_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine6_cmd_buffer_source_ready = (main_litedramcore_bankmachine6_req_wdata_ready | main_litedramcore_bankmachine6_req_rdata_valid);
assign main_litedramcore_bankmachine6_req_lock = (main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine6_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine6_row_hit = (main_litedramcore_bankmachine6_row == main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine6_cmd_payload_ba = 3'd6;

// synthesis translate_off
reg dummy_d_192;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine6_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine6_cmd_payload_a <= main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine6_cmd_payload_a <= ((main_litedramcore_bankmachine6_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_192 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine6_twtpcon_valid = ((main_litedramcore_bankmachine6_cmd_valid & main_litedramcore_bankmachine6_cmd_ready) & main_litedramcore_bankmachine6_cmd_payload_is_write);
assign main_litedramcore_bankmachine6_trccon_valid = ((main_litedramcore_bankmachine6_cmd_valid & main_litedramcore_bankmachine6_cmd_ready) & main_litedramcore_bankmachine6_row_open);
assign main_litedramcore_bankmachine6_trascon_valid = ((main_litedramcore_bankmachine6_cmd_valid & main_litedramcore_bankmachine6_cmd_ready) & main_litedramcore_bankmachine6_row_open);

// synthesis translate_off
reg dummy_d_193;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine6_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine6_auto_precharge <= (main_litedramcore_bankmachine6_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_193 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_din = {main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout;
assign {main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout;
assign {main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout;
assign {main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_we = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine6_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_readable;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine6_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_re = main_litedramcore_bankmachine6_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_194;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine6_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_194 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_din;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_we & (main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable | main_litedramcore_bankmachine6_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_readable & main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_re);
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine6_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_dout = main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable = (main_litedramcore_bankmachine6_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_readable = (main_litedramcore_bankmachine6_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine6_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine6_cmd_buffer_source_valid) | main_litedramcore_bankmachine6_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_195;
// synthesis translate_on
always @(*) begin
	builder_bankmachine6_next_state <= 3'd0;
	builder_bankmachine6_next_state <= builder_bankmachine6_state;
	case (builder_bankmachine6_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				if (main_litedramcore_bankmachine6_cmd_ready) begin
					builder_bankmachine6_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				builder_bankmachine6_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				if (main_litedramcore_bankmachine6_cmd_ready) begin
					builder_bankmachine6_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine6_refresh_req)) begin
				builder_bankmachine6_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine6_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine6_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
				builder_bankmachine6_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if ((main_litedramcore_bankmachine6_cmd_ready & main_litedramcore_bankmachine6_auto_precharge)) begin
								builder_bankmachine6_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine6_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine6_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_195 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_196;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_row_open <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				main_litedramcore_bankmachine6_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_196 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_197;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_row_close <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
			main_litedramcore_bankmachine6_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine6_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine6_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_197 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_198;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							main_litedramcore_bankmachine6_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_198 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_199;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				main_litedramcore_bankmachine6_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				main_litedramcore_bankmachine6_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_199 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_200;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_we <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				main_litedramcore_bankmachine6_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if (main_litedramcore_bankmachine6_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine6_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_200 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_201;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				main_litedramcore_bankmachine6_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_201 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_202;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				main_litedramcore_bankmachine6_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				main_litedramcore_bankmachine6_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine6_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_202 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_203;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if (main_litedramcore_bankmachine6_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine6_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_203 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_204;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if (main_litedramcore_bankmachine6_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine6_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_204 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_205;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_req_wdata_ready <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if (main_litedramcore_bankmachine6_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine6_req_wdata_ready <= main_litedramcore_bankmachine6_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_205 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_206;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_req_rdata_valid <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							if (main_litedramcore_bankmachine6_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine6_req_rdata_valid <= main_litedramcore_bankmachine6_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_206 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_207;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_refresh_gnt <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine6_twtpcon_ready) begin
				main_litedramcore_bankmachine6_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_207 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_208;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_valid <= 1'd0;
	case (builder_bankmachine6_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine6_twtpcon_ready & main_litedramcore_bankmachine6_trascon_ready)) begin
				main_litedramcore_bankmachine6_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine6_trccon_ready) begin
				main_litedramcore_bankmachine6_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine6_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine6_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine6_row_opened) begin
						if (main_litedramcore_bankmachine6_row_hit) begin
							main_litedramcore_bankmachine6_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_208 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_valid = main_litedramcore_bankmachine7_req_valid;
assign main_litedramcore_bankmachine7_req_ready = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_ready;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_we = main_litedramcore_bankmachine7_req_we;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_addr = main_litedramcore_bankmachine7_req_addr;
assign main_litedramcore_bankmachine7_cmd_buffer_sink_valid = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_valid;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_ready = main_litedramcore_bankmachine7_cmd_buffer_sink_ready;
assign main_litedramcore_bankmachine7_cmd_buffer_sink_first = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_first;
assign main_litedramcore_bankmachine7_cmd_buffer_sink_last = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_last;
assign main_litedramcore_bankmachine7_cmd_buffer_sink_payload_we = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_we;
assign main_litedramcore_bankmachine7_cmd_buffer_sink_payload_addr = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_addr;
assign main_litedramcore_bankmachine7_cmd_buffer_source_ready = (main_litedramcore_bankmachine7_req_wdata_ready | main_litedramcore_bankmachine7_req_rdata_valid);
assign main_litedramcore_bankmachine7_req_lock = (main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_valid | main_litedramcore_bankmachine7_cmd_buffer_source_valid);
assign main_litedramcore_bankmachine7_row_hit = (main_litedramcore_bankmachine7_row == main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr[20:8]);
assign main_litedramcore_bankmachine7_cmd_payload_ba = 3'd7;

// synthesis translate_off
reg dummy_d_209;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_a <= 13'd0;
	if (main_litedramcore_bankmachine7_row_col_n_addr_sel) begin
		main_litedramcore_bankmachine7_cmd_payload_a <= main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr[20:8];
	end else begin
		main_litedramcore_bankmachine7_cmd_payload_a <= ((main_litedramcore_bankmachine7_auto_precharge <<< 4'd10) | {main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr[7:0], {2{1'd0}}});
	end
// synthesis translate_off
	dummy_d_209 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine7_twtpcon_valid = ((main_litedramcore_bankmachine7_cmd_valid & main_litedramcore_bankmachine7_cmd_ready) & main_litedramcore_bankmachine7_cmd_payload_is_write);
assign main_litedramcore_bankmachine7_trccon_valid = ((main_litedramcore_bankmachine7_cmd_valid & main_litedramcore_bankmachine7_cmd_ready) & main_litedramcore_bankmachine7_row_open);
assign main_litedramcore_bankmachine7_trascon_valid = ((main_litedramcore_bankmachine7_cmd_valid & main_litedramcore_bankmachine7_cmd_ready) & main_litedramcore_bankmachine7_row_open);

// synthesis translate_off
reg dummy_d_210;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_auto_precharge <= 1'd0;
	if ((main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_valid & main_litedramcore_bankmachine7_cmd_buffer_source_valid)) begin
		if ((main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_addr[20:8] != main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr[20:8])) begin
			main_litedramcore_bankmachine7_auto_precharge <= (main_litedramcore_bankmachine7_row_close == 1'd0);
		end
	end
// synthesis translate_off
	dummy_d_210 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_din = {main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_last, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_first, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_addr, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_we};
assign {main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout;
assign {main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout;
assign {main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout;
assign {main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr, main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we} = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_ready = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_we = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_valid;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_first = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_first;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_last = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_last;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_we = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_we;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_in_payload_addr = main_litedramcore_bankmachine7_cmd_buffer_lookahead_sink_payload_addr;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_valid = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_readable;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_first = main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_first;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_last = main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_last;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_we = main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_we;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_payload_addr = main_litedramcore_bankmachine7_cmd_buffer_lookahead_fifo_out_payload_addr;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_re = main_litedramcore_bankmachine7_cmd_buffer_lookahead_source_ready;

// synthesis translate_off
reg dummy_d_211;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr <= 4'd0;
	if (main_litedramcore_bankmachine7_cmd_buffer_lookahead_replace) begin
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr <= (main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce - 1'd1);
	end else begin
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr <= main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce;
	end
// synthesis translate_off
	dummy_d_211 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_dat_w = main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_din;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_we = (main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_we & (main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable | main_litedramcore_bankmachine7_cmd_buffer_lookahead_replace));
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_do_read = (main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_readable & main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_re);
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_adr = main_litedramcore_bankmachine7_cmd_buffer_lookahead_consume;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_dout = main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_dat_r;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable = (main_litedramcore_bankmachine7_cmd_buffer_lookahead_level != 5'd16);
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_readable = (main_litedramcore_bankmachine7_cmd_buffer_lookahead_level != 1'd0);
assign main_litedramcore_bankmachine7_cmd_buffer_sink_ready = ((~main_litedramcore_bankmachine7_cmd_buffer_source_valid) | main_litedramcore_bankmachine7_cmd_buffer_source_ready);

// synthesis translate_off
reg dummy_d_212;
// synthesis translate_on
always @(*) begin
	builder_bankmachine7_next_state <= 3'd0;
	builder_bankmachine7_next_state <= builder_bankmachine7_state;
	case (builder_bankmachine7_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				if (main_litedramcore_bankmachine7_cmd_ready) begin
					builder_bankmachine7_next_state <= 3'd5;
				end
			end
		end
		2'd2: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				builder_bankmachine7_next_state <= 3'd5;
			end
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				if (main_litedramcore_bankmachine7_cmd_ready) begin
					builder_bankmachine7_next_state <= 3'd6;
				end
			end
		end
		3'd4: begin
			if ((~main_litedramcore_bankmachine7_refresh_req)) begin
				builder_bankmachine7_next_state <= 1'd0;
			end
		end
		3'd5: begin
			builder_bankmachine7_next_state <= 2'd3;
		end
		3'd6: begin
			builder_bankmachine7_next_state <= 1'd0;
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
				builder_bankmachine7_next_state <= 3'd4;
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if ((main_litedramcore_bankmachine7_cmd_ready & main_litedramcore_bankmachine7_auto_precharge)) begin
								builder_bankmachine7_next_state <= 2'd2;
							end
						end else begin
							builder_bankmachine7_next_state <= 1'd1;
						end
					end else begin
						builder_bankmachine7_next_state <= 2'd3;
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_212 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_213;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_valid <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				main_litedramcore_bankmachine7_cmd_valid <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				main_litedramcore_bankmachine7_cmd_valid <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							main_litedramcore_bankmachine7_cmd_valid <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_213 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_214;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_row_open <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				main_litedramcore_bankmachine7_row_open <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_214 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_215;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_row_close <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
			main_litedramcore_bankmachine7_row_close <= 1'd1;
		end
		2'd2: begin
			main_litedramcore_bankmachine7_row_close <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
			main_litedramcore_bankmachine7_row_close <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_215 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_216;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_cas <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							main_litedramcore_bankmachine7_cmd_payload_cas <= 1'd1;
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_216 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_217;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_ras <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				main_litedramcore_bankmachine7_cmd_payload_ras <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				main_litedramcore_bankmachine7_cmd_payload_ras <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_217 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_218;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_we <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				main_litedramcore_bankmachine7_cmd_payload_we <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if (main_litedramcore_bankmachine7_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine7_cmd_payload_we <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_218 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_219;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_row_col_n_addr_sel <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				main_litedramcore_bankmachine7_row_col_n_addr_sel <= 1'd1;
			end
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_219 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_220;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_is_cmd <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
			if ((main_litedramcore_bankmachine7_twtpcon_ready & main_litedramcore_bankmachine7_trascon_ready)) begin
				main_litedramcore_bankmachine7_cmd_payload_is_cmd <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
			if (main_litedramcore_bankmachine7_trccon_ready) begin
				main_litedramcore_bankmachine7_cmd_payload_is_cmd <= 1'd1;
			end
		end
		3'd4: begin
			main_litedramcore_bankmachine7_cmd_payload_is_cmd <= 1'd1;
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_220 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_221;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_is_read <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if (main_litedramcore_bankmachine7_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine7_cmd_payload_is_read <= 1'd1;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_221 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_222;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_payload_is_write <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if (main_litedramcore_bankmachine7_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine7_cmd_payload_is_write <= 1'd1;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_222 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_223;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_req_wdata_ready <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if (main_litedramcore_bankmachine7_cmd_buffer_source_payload_we) begin
								main_litedramcore_bankmachine7_req_wdata_ready <= main_litedramcore_bankmachine7_cmd_ready;
							end else begin
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_223 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_224;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_req_rdata_valid <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
			if (main_litedramcore_bankmachine7_refresh_req) begin
			end else begin
				if (main_litedramcore_bankmachine7_cmd_buffer_source_valid) begin
					if (main_litedramcore_bankmachine7_row_opened) begin
						if (main_litedramcore_bankmachine7_row_hit) begin
							if (main_litedramcore_bankmachine7_cmd_buffer_source_payload_we) begin
							end else begin
								main_litedramcore_bankmachine7_req_rdata_valid <= main_litedramcore_bankmachine7_cmd_ready;
							end
						end else begin
						end
					end else begin
					end
				end
			end
		end
	endcase
// synthesis translate_off
	dummy_d_224 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_225;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_refresh_gnt <= 1'd0;
	case (builder_bankmachine7_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
			if (main_litedramcore_bankmachine7_twtpcon_ready) begin
				main_litedramcore_bankmachine7_refresh_gnt <= 1'd1;
			end
		end
		3'd5: begin
		end
		3'd6: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_225 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_rdcmdphase = (main_a7ddrphy_rdphase_storage - 1'd1);
assign main_litedramcore_wrcmdphase = (main_a7ddrphy_wrphase_storage - 1'd1);
assign main_litedramcore_trrdcon_valid = ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & ((main_litedramcore_choose_cmd_cmd_payload_ras & (~main_litedramcore_choose_cmd_cmd_payload_cas)) & (~main_litedramcore_choose_cmd_cmd_payload_we)));
assign main_litedramcore_tfawcon_valid = ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & ((main_litedramcore_choose_cmd_cmd_payload_ras & (~main_litedramcore_choose_cmd_cmd_payload_cas)) & (~main_litedramcore_choose_cmd_cmd_payload_we)));
assign main_litedramcore_ras_allowed = (main_litedramcore_trrdcon_ready & main_litedramcore_tfawcon_ready);
assign main_litedramcore_tccdcon_valid = ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_cmd_payload_is_write | main_litedramcore_choose_req_cmd_payload_is_read));
assign main_litedramcore_cas_allowed = main_litedramcore_tccdcon_ready;
assign main_litedramcore_twtrcon_valid = ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_is_write);
assign main_litedramcore_read_available = ((((((((main_litedramcore_bankmachine0_cmd_valid & main_litedramcore_bankmachine0_cmd_payload_is_read) | (main_litedramcore_bankmachine1_cmd_valid & main_litedramcore_bankmachine1_cmd_payload_is_read)) | (main_litedramcore_bankmachine2_cmd_valid & main_litedramcore_bankmachine2_cmd_payload_is_read)) | (main_litedramcore_bankmachine3_cmd_valid & main_litedramcore_bankmachine3_cmd_payload_is_read)) | (main_litedramcore_bankmachine4_cmd_valid & main_litedramcore_bankmachine4_cmd_payload_is_read)) | (main_litedramcore_bankmachine5_cmd_valid & main_litedramcore_bankmachine5_cmd_payload_is_read)) | (main_litedramcore_bankmachine6_cmd_valid & main_litedramcore_bankmachine6_cmd_payload_is_read)) | (main_litedramcore_bankmachine7_cmd_valid & main_litedramcore_bankmachine7_cmd_payload_is_read));
assign main_litedramcore_write_available = ((((((((main_litedramcore_bankmachine0_cmd_valid & main_litedramcore_bankmachine0_cmd_payload_is_write) | (main_litedramcore_bankmachine1_cmd_valid & main_litedramcore_bankmachine1_cmd_payload_is_write)) | (main_litedramcore_bankmachine2_cmd_valid & main_litedramcore_bankmachine2_cmd_payload_is_write)) | (main_litedramcore_bankmachine3_cmd_valid & main_litedramcore_bankmachine3_cmd_payload_is_write)) | (main_litedramcore_bankmachine4_cmd_valid & main_litedramcore_bankmachine4_cmd_payload_is_write)) | (main_litedramcore_bankmachine5_cmd_valid & main_litedramcore_bankmachine5_cmd_payload_is_write)) | (main_litedramcore_bankmachine6_cmd_valid & main_litedramcore_bankmachine6_cmd_payload_is_write)) | (main_litedramcore_bankmachine7_cmd_valid & main_litedramcore_bankmachine7_cmd_payload_is_write));
assign main_litedramcore_max_time0 = (main_litedramcore_time0 == 1'd0);
assign main_litedramcore_max_time1 = (main_litedramcore_time1 == 1'd0);
assign main_litedramcore_bankmachine0_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine1_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine2_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine3_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine4_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine5_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine6_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_bankmachine7_refresh_req = main_litedramcore_cmd_valid;
assign main_litedramcore_go_to_refresh = (((((((main_litedramcore_bankmachine0_refresh_gnt & main_litedramcore_bankmachine1_refresh_gnt) & main_litedramcore_bankmachine2_refresh_gnt) & main_litedramcore_bankmachine3_refresh_gnt) & main_litedramcore_bankmachine4_refresh_gnt) & main_litedramcore_bankmachine5_refresh_gnt) & main_litedramcore_bankmachine6_refresh_gnt) & main_litedramcore_bankmachine7_refresh_gnt);
assign main_litedramcore_interface_rdata = {main_litedramcore_dfi_p1_rddata, main_litedramcore_dfi_p0_rddata};
assign {main_litedramcore_dfi_p1_wrdata, main_litedramcore_dfi_p0_wrdata} = main_litedramcore_interface_wdata;
assign {main_litedramcore_dfi_p1_wrdata, main_litedramcore_dfi_p0_wrdata} = main_litedramcore_interface_wdata;
assign {main_litedramcore_dfi_p1_wrdata_mask, main_litedramcore_dfi_p0_wrdata_mask} = (~main_litedramcore_interface_wdata_we);
assign {main_litedramcore_dfi_p1_wrdata_mask, main_litedramcore_dfi_p0_wrdata_mask} = (~main_litedramcore_interface_wdata_we);

// synthesis translate_off
reg dummy_d_226;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_valids <= 8'd0;
	main_litedramcore_choose_cmd_valids[0] <= (main_litedramcore_bankmachine0_cmd_valid & (((main_litedramcore_bankmachine0_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine0_cmd_payload_ras & (~main_litedramcore_bankmachine0_cmd_payload_cas)) & (~main_litedramcore_bankmachine0_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine0_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine0_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[1] <= (main_litedramcore_bankmachine1_cmd_valid & (((main_litedramcore_bankmachine1_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine1_cmd_payload_ras & (~main_litedramcore_bankmachine1_cmd_payload_cas)) & (~main_litedramcore_bankmachine1_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine1_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine1_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[2] <= (main_litedramcore_bankmachine2_cmd_valid & (((main_litedramcore_bankmachine2_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine2_cmd_payload_ras & (~main_litedramcore_bankmachine2_cmd_payload_cas)) & (~main_litedramcore_bankmachine2_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine2_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine2_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[3] <= (main_litedramcore_bankmachine3_cmd_valid & (((main_litedramcore_bankmachine3_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine3_cmd_payload_ras & (~main_litedramcore_bankmachine3_cmd_payload_cas)) & (~main_litedramcore_bankmachine3_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine3_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine3_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[4] <= (main_litedramcore_bankmachine4_cmd_valid & (((main_litedramcore_bankmachine4_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine4_cmd_payload_ras & (~main_litedramcore_bankmachine4_cmd_payload_cas)) & (~main_litedramcore_bankmachine4_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine4_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine4_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[5] <= (main_litedramcore_bankmachine5_cmd_valid & (((main_litedramcore_bankmachine5_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine5_cmd_payload_ras & (~main_litedramcore_bankmachine5_cmd_payload_cas)) & (~main_litedramcore_bankmachine5_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine5_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine5_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[6] <= (main_litedramcore_bankmachine6_cmd_valid & (((main_litedramcore_bankmachine6_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine6_cmd_payload_ras & (~main_litedramcore_bankmachine6_cmd_payload_cas)) & (~main_litedramcore_bankmachine6_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine6_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine6_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
	main_litedramcore_choose_cmd_valids[7] <= (main_litedramcore_bankmachine7_cmd_valid & (((main_litedramcore_bankmachine7_cmd_payload_is_cmd & main_litedramcore_choose_cmd_want_cmds) & ((~((main_litedramcore_bankmachine7_cmd_payload_ras & (~main_litedramcore_bankmachine7_cmd_payload_cas)) & (~main_litedramcore_bankmachine7_cmd_payload_we))) | main_litedramcore_choose_cmd_want_activates)) | ((main_litedramcore_bankmachine7_cmd_payload_is_read == main_litedramcore_choose_cmd_want_reads) & (main_litedramcore_bankmachine7_cmd_payload_is_write == main_litedramcore_choose_cmd_want_writes))));
// synthesis translate_off
	dummy_d_226 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_choose_cmd_request = main_litedramcore_choose_cmd_valids;
assign main_litedramcore_choose_cmd_cmd_valid = builder_rhs_array_muxed0;
assign main_litedramcore_choose_cmd_cmd_payload_a = builder_rhs_array_muxed1;
assign main_litedramcore_choose_cmd_cmd_payload_ba = builder_rhs_array_muxed2;
assign main_litedramcore_choose_cmd_cmd_payload_is_read = builder_rhs_array_muxed3;
assign main_litedramcore_choose_cmd_cmd_payload_is_write = builder_rhs_array_muxed4;
assign main_litedramcore_choose_cmd_cmd_payload_is_cmd = builder_rhs_array_muxed5;

// synthesis translate_off
reg dummy_d_227;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_cmd_payload_cas <= 1'd0;
	if (main_litedramcore_choose_cmd_cmd_valid) begin
		main_litedramcore_choose_cmd_cmd_payload_cas <= builder_t_array_muxed0;
	end
// synthesis translate_off
	dummy_d_227 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_228;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_cmd_payload_ras <= 1'd0;
	if (main_litedramcore_choose_cmd_cmd_valid) begin
		main_litedramcore_choose_cmd_cmd_payload_ras <= builder_t_array_muxed1;
	end
// synthesis translate_off
	dummy_d_228 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_229;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_cmd_payload_we <= 1'd0;
	if (main_litedramcore_choose_cmd_cmd_valid) begin
		main_litedramcore_choose_cmd_cmd_payload_we <= builder_t_array_muxed2;
	end
// synthesis translate_off
	dummy_d_229 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_230;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine0_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 1'd0))) begin
		main_litedramcore_bankmachine0_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 1'd0))) begin
		main_litedramcore_bankmachine0_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_230 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_231;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine1_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 1'd1))) begin
		main_litedramcore_bankmachine1_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 1'd1))) begin
		main_litedramcore_bankmachine1_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_231 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_232;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine2_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 2'd2))) begin
		main_litedramcore_bankmachine2_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 2'd2))) begin
		main_litedramcore_bankmachine2_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_232 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_233;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine3_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 2'd3))) begin
		main_litedramcore_bankmachine3_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 2'd3))) begin
		main_litedramcore_bankmachine3_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_233 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_234;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine4_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 3'd4))) begin
		main_litedramcore_bankmachine4_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 3'd4))) begin
		main_litedramcore_bankmachine4_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_234 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_235;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine5_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 3'd5))) begin
		main_litedramcore_bankmachine5_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 3'd5))) begin
		main_litedramcore_bankmachine5_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_235 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_236;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine6_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 3'd6))) begin
		main_litedramcore_bankmachine6_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 3'd6))) begin
		main_litedramcore_bankmachine6_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_236 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_237;
// synthesis translate_on
always @(*) begin
	main_litedramcore_bankmachine7_cmd_ready <= 1'd0;
	if (((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & (main_litedramcore_choose_cmd_grant == 3'd7))) begin
		main_litedramcore_bankmachine7_cmd_ready <= 1'd1;
	end
	if (((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & (main_litedramcore_choose_req_grant == 3'd7))) begin
		main_litedramcore_bankmachine7_cmd_ready <= 1'd1;
	end
// synthesis translate_off
	dummy_d_237 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_choose_cmd_ce = (main_litedramcore_choose_cmd_cmd_ready | (~main_litedramcore_choose_cmd_cmd_valid));

// synthesis translate_off
reg dummy_d_238;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_valids <= 8'd0;
	main_litedramcore_choose_req_valids[0] <= (main_litedramcore_bankmachine0_cmd_valid & (((main_litedramcore_bankmachine0_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine0_cmd_payload_ras & (~main_litedramcore_bankmachine0_cmd_payload_cas)) & (~main_litedramcore_bankmachine0_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine0_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine0_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[1] <= (main_litedramcore_bankmachine1_cmd_valid & (((main_litedramcore_bankmachine1_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine1_cmd_payload_ras & (~main_litedramcore_bankmachine1_cmd_payload_cas)) & (~main_litedramcore_bankmachine1_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine1_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine1_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[2] <= (main_litedramcore_bankmachine2_cmd_valid & (((main_litedramcore_bankmachine2_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine2_cmd_payload_ras & (~main_litedramcore_bankmachine2_cmd_payload_cas)) & (~main_litedramcore_bankmachine2_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine2_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine2_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[3] <= (main_litedramcore_bankmachine3_cmd_valid & (((main_litedramcore_bankmachine3_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine3_cmd_payload_ras & (~main_litedramcore_bankmachine3_cmd_payload_cas)) & (~main_litedramcore_bankmachine3_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine3_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine3_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[4] <= (main_litedramcore_bankmachine4_cmd_valid & (((main_litedramcore_bankmachine4_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine4_cmd_payload_ras & (~main_litedramcore_bankmachine4_cmd_payload_cas)) & (~main_litedramcore_bankmachine4_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine4_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine4_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[5] <= (main_litedramcore_bankmachine5_cmd_valid & (((main_litedramcore_bankmachine5_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine5_cmd_payload_ras & (~main_litedramcore_bankmachine5_cmd_payload_cas)) & (~main_litedramcore_bankmachine5_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine5_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine5_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[6] <= (main_litedramcore_bankmachine6_cmd_valid & (((main_litedramcore_bankmachine6_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine6_cmd_payload_ras & (~main_litedramcore_bankmachine6_cmd_payload_cas)) & (~main_litedramcore_bankmachine6_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine6_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine6_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
	main_litedramcore_choose_req_valids[7] <= (main_litedramcore_bankmachine7_cmd_valid & (((main_litedramcore_bankmachine7_cmd_payload_is_cmd & main_litedramcore_choose_req_want_cmds) & ((~((main_litedramcore_bankmachine7_cmd_payload_ras & (~main_litedramcore_bankmachine7_cmd_payload_cas)) & (~main_litedramcore_bankmachine7_cmd_payload_we))) | main_litedramcore_choose_req_want_activates)) | ((main_litedramcore_bankmachine7_cmd_payload_is_read == main_litedramcore_choose_req_want_reads) & (main_litedramcore_bankmachine7_cmd_payload_is_write == main_litedramcore_choose_req_want_writes))));
// synthesis translate_off
	dummy_d_238 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_choose_req_request = main_litedramcore_choose_req_valids;
assign main_litedramcore_choose_req_cmd_valid = builder_rhs_array_muxed6;
assign main_litedramcore_choose_req_cmd_payload_a = builder_rhs_array_muxed7;
assign main_litedramcore_choose_req_cmd_payload_ba = builder_rhs_array_muxed8;
assign main_litedramcore_choose_req_cmd_payload_is_read = builder_rhs_array_muxed9;
assign main_litedramcore_choose_req_cmd_payload_is_write = builder_rhs_array_muxed10;
assign main_litedramcore_choose_req_cmd_payload_is_cmd = builder_rhs_array_muxed11;

// synthesis translate_off
reg dummy_d_239;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_cmd_payload_cas <= 1'd0;
	if (main_litedramcore_choose_req_cmd_valid) begin
		main_litedramcore_choose_req_cmd_payload_cas <= builder_t_array_muxed3;
	end
// synthesis translate_off
	dummy_d_239 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_240;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_cmd_payload_ras <= 1'd0;
	if (main_litedramcore_choose_req_cmd_valid) begin
		main_litedramcore_choose_req_cmd_payload_ras <= builder_t_array_muxed4;
	end
// synthesis translate_off
	dummy_d_240 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_241;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_cmd_payload_we <= 1'd0;
	if (main_litedramcore_choose_req_cmd_valid) begin
		main_litedramcore_choose_req_cmd_payload_we <= builder_t_array_muxed5;
	end
// synthesis translate_off
	dummy_d_241 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_choose_req_ce = (main_litedramcore_choose_req_cmd_ready | (~main_litedramcore_choose_req_cmd_valid));
assign main_litedramcore_dfi_p0_reset_n = 1'd1;
assign main_litedramcore_dfi_p0_cke = {1{main_litedramcore_steerer0}};
assign main_litedramcore_dfi_p0_odt = {1{main_litedramcore_steerer1}};
assign main_litedramcore_dfi_p1_reset_n = 1'd1;
assign main_litedramcore_dfi_p1_cke = {1{main_litedramcore_steerer2}};
assign main_litedramcore_dfi_p1_odt = {1{main_litedramcore_steerer3}};

// synthesis translate_off
reg dummy_d_242;
// synthesis translate_on
always @(*) begin
	builder_multiplexer_next_state <= 4'd0;
	builder_multiplexer_next_state <= builder_multiplexer_state;
	case (builder_multiplexer_state)
		1'd1: begin
			if (main_litedramcore_read_available) begin
				if (((~main_litedramcore_write_available) | main_litedramcore_max_time1)) begin
					builder_multiplexer_next_state <= 2'd3;
				end
			end
			if (main_litedramcore_go_to_refresh) begin
				builder_multiplexer_next_state <= 2'd2;
			end
		end
		2'd2: begin
			if (main_litedramcore_cmd_last) begin
				builder_multiplexer_next_state <= 1'd0;
			end
		end
		2'd3: begin
			if (main_litedramcore_twtrcon_ready) begin
				builder_multiplexer_next_state <= 1'd0;
			end
		end
		3'd4: begin
			builder_multiplexer_next_state <= 3'd5;
		end
		3'd5: begin
			builder_multiplexer_next_state <= 3'd6;
		end
		3'd6: begin
			builder_multiplexer_next_state <= 3'd7;
		end
		3'd7: begin
			builder_multiplexer_next_state <= 4'd8;
		end
		4'd8: begin
			builder_multiplexer_next_state <= 4'd9;
		end
		4'd9: begin
			builder_multiplexer_next_state <= 4'd10;
		end
		4'd10: begin
			builder_multiplexer_next_state <= 1'd1;
		end
		default: begin
			if (main_litedramcore_write_available) begin
				if (((~main_litedramcore_read_available) | main_litedramcore_max_time0)) begin
					builder_multiplexer_next_state <= 3'd4;
				end
			end
			if (main_litedramcore_go_to_refresh) begin
				builder_multiplexer_next_state <= 2'd2;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_242 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_243;
// synthesis translate_on
always @(*) begin
	main_litedramcore_en1 <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			main_litedramcore_en1 <= 1'd1;
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_243 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_244;
// synthesis translate_on
always @(*) begin
	main_litedramcore_steerer_sel0 <= 2'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			main_litedramcore_steerer_sel0 <= 1'd0;
			if ((main_a7ddrphy_wrphase_storage == 1'd0)) begin
				main_litedramcore_steerer_sel0 <= 2'd2;
			end
			if ((main_litedramcore_wrcmdphase == 1'd0)) begin
				main_litedramcore_steerer_sel0 <= 1'd1;
			end
		end
		2'd2: begin
			main_litedramcore_steerer_sel0 <= 2'd3;
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			main_litedramcore_steerer_sel0 <= 1'd0;
			if ((main_a7ddrphy_rdphase_storage == 1'd0)) begin
				main_litedramcore_steerer_sel0 <= 2'd2;
			end
			if ((main_litedramcore_rdcmdphase == 1'd0)) begin
				main_litedramcore_steerer_sel0 <= 1'd1;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_244 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_245;
// synthesis translate_on
always @(*) begin
	main_litedramcore_steerer_sel1 <= 2'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			main_litedramcore_steerer_sel1 <= 1'd0;
			if ((main_a7ddrphy_wrphase_storage == 1'd1)) begin
				main_litedramcore_steerer_sel1 <= 2'd2;
			end
			if ((main_litedramcore_wrcmdphase == 1'd1)) begin
				main_litedramcore_steerer_sel1 <= 1'd1;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			main_litedramcore_steerer_sel1 <= 1'd0;
			if ((main_a7ddrphy_rdphase_storage == 1'd1)) begin
				main_litedramcore_steerer_sel1 <= 2'd2;
			end
			if ((main_litedramcore_rdcmdphase == 1'd1)) begin
				main_litedramcore_steerer_sel1 <= 1'd1;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_245 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_246;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_want_activates <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			if (1'd0) begin
			end else begin
				main_litedramcore_choose_cmd_want_activates <= main_litedramcore_ras_allowed;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			if (1'd0) begin
			end else begin
				main_litedramcore_choose_cmd_want_activates <= main_litedramcore_ras_allowed;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_246 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_247;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_cmd_cmd_ready <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			if (1'd0) begin
			end else begin
				main_litedramcore_choose_cmd_cmd_ready <= ((~((main_litedramcore_choose_cmd_cmd_payload_ras & (~main_litedramcore_choose_cmd_cmd_payload_cas)) & (~main_litedramcore_choose_cmd_cmd_payload_we))) | main_litedramcore_ras_allowed);
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			if (1'd0) begin
			end else begin
				main_litedramcore_choose_cmd_cmd_ready <= ((~((main_litedramcore_choose_cmd_cmd_payload_ras & (~main_litedramcore_choose_cmd_cmd_payload_cas)) & (~main_litedramcore_choose_cmd_cmd_payload_we))) | main_litedramcore_ras_allowed);
			end
		end
	endcase
// synthesis translate_off
	dummy_d_247 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_248;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_want_reads <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			main_litedramcore_choose_req_want_reads <= 1'd1;
		end
	endcase
// synthesis translate_off
	dummy_d_248 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_249;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_want_writes <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			main_litedramcore_choose_req_want_writes <= 1'd1;
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_249 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_250;
// synthesis translate_on
always @(*) begin
	main_litedramcore_en0 <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			main_litedramcore_en0 <= 1'd1;
		end
	endcase
// synthesis translate_off
	dummy_d_250 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_251;
// synthesis translate_on
always @(*) begin
	main_litedramcore_choose_req_cmd_ready <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
			if (1'd0) begin
				main_litedramcore_choose_req_cmd_ready <= (main_litedramcore_cas_allowed & ((~((main_litedramcore_choose_req_cmd_payload_ras & (~main_litedramcore_choose_req_cmd_payload_cas)) & (~main_litedramcore_choose_req_cmd_payload_we))) | main_litedramcore_ras_allowed));
			end else begin
				main_litedramcore_choose_req_cmd_ready <= main_litedramcore_cas_allowed;
			end
		end
		2'd2: begin
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
			if (1'd0) begin
				main_litedramcore_choose_req_cmd_ready <= (main_litedramcore_cas_allowed & ((~((main_litedramcore_choose_req_cmd_payload_ras & (~main_litedramcore_choose_req_cmd_payload_cas)) & (~main_litedramcore_choose_req_cmd_payload_we))) | main_litedramcore_ras_allowed));
			end else begin
				main_litedramcore_choose_req_cmd_ready <= main_litedramcore_cas_allowed;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_251 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_252;
// synthesis translate_on
always @(*) begin
	main_litedramcore_cmd_ready <= 1'd0;
	case (builder_multiplexer_state)
		1'd1: begin
		end
		2'd2: begin
			main_litedramcore_cmd_ready <= 1'd1;
		end
		2'd3: begin
		end
		3'd4: begin
		end
		3'd5: begin
		end
		3'd6: begin
		end
		3'd7: begin
		end
		4'd8: begin
		end
		4'd9: begin
		end
		4'd10: begin
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_252 = dummy_s;
// synthesis translate_on
end
assign builder_roundrobin0_request = {(((main_user_port_cmd_payload_addr[10:8] == 1'd0) & (~(((((((builder_locked0 | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin0_ce = ((~main_litedramcore_interface_bank0_valid) & (~main_litedramcore_interface_bank0_lock));
assign main_litedramcore_interface_bank0_addr = builder_rhs_array_muxed12;
assign main_litedramcore_interface_bank0_we = builder_rhs_array_muxed13;
assign main_litedramcore_interface_bank0_valid = builder_rhs_array_muxed14;
assign builder_roundrobin1_request = {(((main_user_port_cmd_payload_addr[10:8] == 1'd1) & (~(((((((builder_locked1 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin1_ce = ((~main_litedramcore_interface_bank1_valid) & (~main_litedramcore_interface_bank1_lock));
assign main_litedramcore_interface_bank1_addr = builder_rhs_array_muxed15;
assign main_litedramcore_interface_bank1_we = builder_rhs_array_muxed16;
assign main_litedramcore_interface_bank1_valid = builder_rhs_array_muxed17;
assign builder_roundrobin2_request = {(((main_user_port_cmd_payload_addr[10:8] == 2'd2) & (~(((((((builder_locked2 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin2_ce = ((~main_litedramcore_interface_bank2_valid) & (~main_litedramcore_interface_bank2_lock));
assign main_litedramcore_interface_bank2_addr = builder_rhs_array_muxed18;
assign main_litedramcore_interface_bank2_we = builder_rhs_array_muxed19;
assign main_litedramcore_interface_bank2_valid = builder_rhs_array_muxed20;
assign builder_roundrobin3_request = {(((main_user_port_cmd_payload_addr[10:8] == 2'd3) & (~(((((((builder_locked3 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin3_ce = ((~main_litedramcore_interface_bank3_valid) & (~main_litedramcore_interface_bank3_lock));
assign main_litedramcore_interface_bank3_addr = builder_rhs_array_muxed21;
assign main_litedramcore_interface_bank3_we = builder_rhs_array_muxed22;
assign main_litedramcore_interface_bank3_valid = builder_rhs_array_muxed23;
assign builder_roundrobin4_request = {(((main_user_port_cmd_payload_addr[10:8] == 3'd4) & (~(((((((builder_locked4 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin4_ce = ((~main_litedramcore_interface_bank4_valid) & (~main_litedramcore_interface_bank4_lock));
assign main_litedramcore_interface_bank4_addr = builder_rhs_array_muxed24;
assign main_litedramcore_interface_bank4_we = builder_rhs_array_muxed25;
assign main_litedramcore_interface_bank4_valid = builder_rhs_array_muxed26;
assign builder_roundrobin5_request = {(((main_user_port_cmd_payload_addr[10:8] == 3'd5) & (~(((((((builder_locked5 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin5_ce = ((~main_litedramcore_interface_bank5_valid) & (~main_litedramcore_interface_bank5_lock));
assign main_litedramcore_interface_bank5_addr = builder_rhs_array_muxed27;
assign main_litedramcore_interface_bank5_we = builder_rhs_array_muxed28;
assign main_litedramcore_interface_bank5_valid = builder_rhs_array_muxed29;
assign builder_roundrobin6_request = {(((main_user_port_cmd_payload_addr[10:8] == 3'd6) & (~(((((((builder_locked6 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin6_ce = ((~main_litedramcore_interface_bank6_valid) & (~main_litedramcore_interface_bank6_lock));
assign main_litedramcore_interface_bank6_addr = builder_rhs_array_muxed30;
assign main_litedramcore_interface_bank6_we = builder_rhs_array_muxed31;
assign main_litedramcore_interface_bank6_valid = builder_rhs_array_muxed32;
assign builder_roundrobin7_request = {(((main_user_port_cmd_payload_addr[10:8] == 3'd7) & (~(((((((builder_locked7 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))))) & main_user_port_cmd_valid)};
assign builder_roundrobin7_ce = ((~main_litedramcore_interface_bank7_valid) & (~main_litedramcore_interface_bank7_lock));
assign main_litedramcore_interface_bank7_addr = builder_rhs_array_muxed33;
assign main_litedramcore_interface_bank7_we = builder_rhs_array_muxed34;
assign main_litedramcore_interface_bank7_valid = builder_rhs_array_muxed35;
assign main_user_port_cmd_ready = ((((((((1'd0 | (((builder_roundrobin0_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 1'd0) & (~(((((((builder_locked0 | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank0_ready)) | (((builder_roundrobin1_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 1'd1) & (~(((((((builder_locked1 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank1_ready)) | (((builder_roundrobin2_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 2'd2) & (~(((((((builder_locked2 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank2_ready)) | (((builder_roundrobin3_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 2'd3) & (~(((((((builder_locked3 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank3_ready)) | (((builder_roundrobin4_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 3'd4) & (~(((((((builder_locked4 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank4_ready)) | (((builder_roundrobin5_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 3'd5) & (~(((((((builder_locked5 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank5_ready)) | (((builder_roundrobin6_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 3'd6) & (~(((((((builder_locked6 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0)))))) & main_litedramcore_interface_bank6_ready)) | (((builder_roundrobin7_grant == 1'd0) & ((main_user_port_cmd_payload_addr[10:8] == 3'd7) & (~(((((((builder_locked7 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0)))))) & main_litedramcore_interface_bank7_ready));
assign main_user_port_wdata_ready = builder_new_master_wdata_ready;
assign main_user_port_rdata_valid = builder_new_master_rdata_valid8;

// synthesis translate_off
reg dummy_d_253;
// synthesis translate_on
always @(*) begin
	main_litedramcore_interface_wdata <= 64'd0;
	case ({builder_new_master_wdata_ready})
		1'd1: begin
			main_litedramcore_interface_wdata <= main_user_port_wdata_payload_data;
		end
		default: begin
			main_litedramcore_interface_wdata <= 1'd0;
		end
	endcase
// synthesis translate_off
	dummy_d_253 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_254;
// synthesis translate_on
always @(*) begin
	main_litedramcore_interface_wdata_we <= 8'd0;
	case ({builder_new_master_wdata_ready})
		1'd1: begin
			main_litedramcore_interface_wdata_we <= main_user_port_wdata_payload_we;
		end
		default: begin
			main_litedramcore_interface_wdata_we <= 1'd0;
		end
	endcase
// synthesis translate_off
	dummy_d_254 = dummy_s;
// synthesis translate_on
end
assign main_user_port_rdata_payload_data = main_litedramcore_interface_rdata;
assign builder_roundrobin0_grant = 1'd0;
assign builder_roundrobin1_grant = 1'd0;
assign builder_roundrobin2_grant = 1'd0;
assign builder_roundrobin3_grant = 1'd0;
assign builder_roundrobin4_grant = 1'd0;
assign builder_roundrobin5_grant = 1'd0;
assign builder_roundrobin6_grant = 1'd0;
assign builder_roundrobin7_grant = 1'd0;
assign main_user_port_cmd_payload_addr = (main_wb_port_adr - 1'd0);
assign main_user_port_cmd_payload_we = main_wb_port_we;
assign main_user_port_wdata_payload_data = main_wb_port_dat_w;
assign main_user_port_wdata_payload_we = main_wb_port_sel;
assign main_wb_port_dat_r = main_user_port_rdata_payload_data;
assign main_user_port_flush = (~main_wb_port_cyc);
assign main_user_port_cmd_last = (~main_wb_port_we);
assign main_user_port_cmd_valid = ((main_wb_port_cyc & main_wb_port_stb) & (~main_cmd_consumed));
assign main_user_port_wdata_valid = (((main_user_port_cmd_valid | main_cmd_consumed) & main_user_port_cmd_payload_we) & (~main_wdata_consumed));
assign main_user_port_rdata_ready = ((main_user_port_cmd_valid | main_cmd_consumed) & (~main_user_port_cmd_payload_we));
assign main_wb_port_ack = (main_ack_cmd & ((main_wb_port_we & main_ack_wdata) | ((~main_wb_port_we) & main_ack_rdata)));
assign main_ack_cmd = ((main_user_port_cmd_valid & main_user_port_cmd_ready) | main_cmd_consumed);
assign main_ack_wdata = ((main_user_port_wdata_valid & main_user_port_wdata_ready) | main_wdata_consumed);
assign main_ack_rdata = (main_user_port_rdata_valid & main_user_port_rdata_ready);

// synthesis translate_off
reg dummy_d_255;
// synthesis translate_on
always @(*) begin
	builder_next_state <= 2'd0;
	builder_next_state <= builder_state;
	case (builder_state)
		1'd1: begin
			builder_next_state <= 2'd2;
		end
		2'd2: begin
			builder_next_state <= 1'd0;
		end
		default: begin
			if ((builder_litedramcore_wishbone_cyc & builder_litedramcore_wishbone_stb)) begin
				builder_next_state <= 1'd1;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_255 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_256;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_wishbone_ack <= 1'd0;
	case (builder_state)
		1'd1: begin
		end
		2'd2: begin
			builder_litedramcore_wishbone_ack <= 1'd1;
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_256 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_257;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_dat_w_next_value0 <= 8'd0;
	case (builder_state)
		1'd1: begin
		end
		2'd2: begin
		end
		default: begin
			builder_litedramcore_dat_w_next_value0 <= builder_litedramcore_wishbone_dat_w;
		end
	endcase
// synthesis translate_off
	dummy_d_257 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_258;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_dat_w_next_value_ce0 <= 1'd0;
	case (builder_state)
		1'd1: begin
		end
		2'd2: begin
		end
		default: begin
			builder_litedramcore_dat_w_next_value_ce0 <= 1'd1;
		end
	endcase
// synthesis translate_off
	dummy_d_258 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_259;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_wishbone_dat_r <= 32'd0;
	case (builder_state)
		1'd1: begin
		end
		2'd2: begin
			builder_litedramcore_wishbone_dat_r <= builder_litedramcore_dat_r;
		end
		default: begin
		end
	endcase
// synthesis translate_off
	dummy_d_259 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_260;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_adr_next_value1 <= 14'd0;
	case (builder_state)
		1'd1: begin
			builder_litedramcore_adr_next_value1 <= 1'd0;
		end
		2'd2: begin
		end
		default: begin
			if ((builder_litedramcore_wishbone_cyc & builder_litedramcore_wishbone_stb)) begin
				builder_litedramcore_adr_next_value1 <= builder_litedramcore_wishbone_adr;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_260 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_261;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_adr_next_value_ce1 <= 1'd0;
	case (builder_state)
		1'd1: begin
			builder_litedramcore_adr_next_value_ce1 <= 1'd1;
		end
		2'd2: begin
		end
		default: begin
			if ((builder_litedramcore_wishbone_cyc & builder_litedramcore_wishbone_stb)) begin
				builder_litedramcore_adr_next_value_ce1 <= 1'd1;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_261 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_262;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_we_next_value2 <= 1'd0;
	case (builder_state)
		1'd1: begin
			builder_litedramcore_we_next_value2 <= 1'd0;
		end
		2'd2: begin
		end
		default: begin
			if ((builder_litedramcore_wishbone_cyc & builder_litedramcore_wishbone_stb)) begin
				builder_litedramcore_we_next_value2 <= (builder_litedramcore_wishbone_we & (builder_litedramcore_wishbone_sel != 1'd0));
			end
		end
	endcase
// synthesis translate_off
	dummy_d_262 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_263;
// synthesis translate_on
always @(*) begin
	builder_litedramcore_we_next_value_ce2 <= 1'd0;
	case (builder_state)
		1'd1: begin
			builder_litedramcore_we_next_value_ce2 <= 1'd1;
		end
		2'd2: begin
		end
		default: begin
			if ((builder_litedramcore_wishbone_cyc & builder_litedramcore_wishbone_stb)) begin
				builder_litedramcore_we_next_value_ce2 <= 1'd1;
			end
		end
	endcase
// synthesis translate_off
	dummy_d_263 = dummy_s;
// synthesis translate_on
end
assign builder_litedramcore_wishbone_adr = main_wb_bus_adr;
assign builder_litedramcore_wishbone_dat_w = main_wb_bus_dat_w;
assign main_wb_bus_dat_r = builder_litedramcore_wishbone_dat_r;
assign builder_litedramcore_wishbone_sel = main_wb_bus_sel;
assign builder_litedramcore_wishbone_cyc = main_wb_bus_cyc;
assign builder_litedramcore_wishbone_stb = main_wb_bus_stb;
assign main_wb_bus_ack = builder_litedramcore_wishbone_ack;
assign builder_litedramcore_wishbone_we = main_wb_bus_we;
assign builder_litedramcore_wishbone_cti = main_wb_bus_cti;
assign builder_litedramcore_wishbone_bte = main_wb_bus_bte;
assign main_wb_bus_err = builder_litedramcore_wishbone_err;
assign builder_csrbank0_sel = (builder_interface0_bank_bus_adr[13:9] == 2'd2);
assign builder_csrbank0_init_done0_r = builder_interface0_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_264;
// synthesis translate_on
always @(*) begin
	builder_csrbank0_init_done0_we <= 1'd0;
	if ((builder_csrbank0_sel & (builder_interface0_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank0_init_done0_we <= (~builder_interface0_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_264 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_265;
// synthesis translate_on
always @(*) begin
	builder_csrbank0_init_done0_re <= 1'd0;
	if ((builder_csrbank0_sel & (builder_interface0_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank0_init_done0_re <= builder_interface0_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_265 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank0_init_error0_r = builder_interface0_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_266;
// synthesis translate_on
always @(*) begin
	builder_csrbank0_init_error0_re <= 1'd0;
	if ((builder_csrbank0_sel & (builder_interface0_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank0_init_error0_re <= builder_interface0_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_266 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_267;
// synthesis translate_on
always @(*) begin
	builder_csrbank0_init_error0_we <= 1'd0;
	if ((builder_csrbank0_sel & (builder_interface0_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank0_init_error0_we <= (~builder_interface0_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_267 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank0_init_done0_w = main_init_done_storage;
assign builder_csrbank0_init_error0_w = main_init_error_storage;
assign builder_csrbank1_sel = (builder_interface1_bank_bus_adr[13:9] == 1'd0);
assign builder_csrbank1_rst0_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_268;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_rst0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank1_rst0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_268 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_269;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_rst0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank1_rst0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_269 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_half_sys8x_taps0_r = builder_interface1_bank_bus_dat_w[4:0];

// synthesis translate_off
reg dummy_d_270;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_half_sys8x_taps0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank1_half_sys8x_taps0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_270 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_271;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_half_sys8x_taps0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank1_half_sys8x_taps0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_271 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_wlevel_en0_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_272;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_wlevel_en0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 2'd2))) begin
		builder_csrbank1_wlevel_en0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_272 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_273;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_wlevel_en0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 2'd2))) begin
		builder_csrbank1_wlevel_en0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_273 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_wlevel_strobe_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_274;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wlevel_strobe_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 2'd3))) begin
		main_a7ddrphy_wlevel_strobe_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_274 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_275;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wlevel_strobe_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 2'd3))) begin
		main_a7ddrphy_wlevel_strobe_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_275 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_dly_sel0_r = builder_interface1_bank_bus_dat_w[1:0];

// synthesis translate_off
reg dummy_d_276;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_dly_sel0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd4))) begin
		builder_csrbank1_dly_sel0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_276 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_277;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_dly_sel0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd4))) begin
		builder_csrbank1_dly_sel0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_277 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_rdly_dq_rst_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_278;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_rst_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd5))) begin
		main_a7ddrphy_rdly_dq_rst_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_278 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_279;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_rst_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd5))) begin
		main_a7ddrphy_rdly_dq_rst_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_279 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_rdly_dq_inc_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_280;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_inc_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd6))) begin
		main_a7ddrphy_rdly_dq_inc_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_280 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_281;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_inc_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd6))) begin
		main_a7ddrphy_rdly_dq_inc_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_281 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_rdly_dq_bitslip_rst_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_282;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_bitslip_rst_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd7))) begin
		main_a7ddrphy_rdly_dq_bitslip_rst_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_282 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_283;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_bitslip_rst_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 3'd7))) begin
		main_a7ddrphy_rdly_dq_bitslip_rst_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_283 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_rdly_dq_bitslip_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_284;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_bitslip_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd8))) begin
		main_a7ddrphy_rdly_dq_bitslip_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_284 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_285;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_rdly_dq_bitslip_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd8))) begin
		main_a7ddrphy_rdly_dq_bitslip_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_285 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_wdly_dq_bitslip_rst_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_286;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wdly_dq_bitslip_rst_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd9))) begin
		main_a7ddrphy_wdly_dq_bitslip_rst_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_286 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_287;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wdly_dq_bitslip_rst_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd9))) begin
		main_a7ddrphy_wdly_dq_bitslip_rst_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_287 = dummy_s;
// synthesis translate_on
end
assign main_a7ddrphy_wdly_dq_bitslip_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_288;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wdly_dq_bitslip_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd10))) begin
		main_a7ddrphy_wdly_dq_bitslip_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_288 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_289;
// synthesis translate_on
always @(*) begin
	main_a7ddrphy_wdly_dq_bitslip_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd10))) begin
		main_a7ddrphy_wdly_dq_bitslip_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_289 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_rdphase0_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_290;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_rdphase0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd11))) begin
		builder_csrbank1_rdphase0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_290 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_291;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_rdphase0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd11))) begin
		builder_csrbank1_rdphase0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_291 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_wrphase0_r = builder_interface1_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_292;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_wrphase0_re <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd12))) begin
		builder_csrbank1_wrphase0_re <= builder_interface1_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_292 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_293;
// synthesis translate_on
always @(*) begin
	builder_csrbank1_wrphase0_we <= 1'd0;
	if ((builder_csrbank1_sel & (builder_interface1_bank_bus_adr[8:0] == 4'd12))) begin
		builder_csrbank1_wrphase0_we <= (~builder_interface1_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_293 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank1_rst0_w = main_a7ddrphy_rst_storage;
assign builder_csrbank1_half_sys8x_taps0_w = main_a7ddrphy_half_sys8x_taps_storage[4:0];
assign builder_csrbank1_wlevel_en0_w = main_a7ddrphy_wlevel_en_storage;
assign builder_csrbank1_dly_sel0_w = main_a7ddrphy_dly_sel_storage[1:0];
assign builder_csrbank1_rdphase0_w = main_a7ddrphy_rdphase_storage;
assign builder_csrbank1_wrphase0_w = main_a7ddrphy_wrphase_storage;
assign builder_csrbank2_sel = (builder_interface2_bank_bus_adr[13:9] == 1'd1);
assign builder_csrbank2_dfii_control0_r = builder_interface2_bank_bus_dat_w[3:0];

// synthesis translate_off
reg dummy_d_294;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_control0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank2_dfii_control0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_294 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_295;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_control0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 1'd0))) begin
		builder_csrbank2_dfii_control0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_295 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_command0_r = builder_interface2_bank_bus_dat_w[5:0];

// synthesis translate_off
reg dummy_d_296;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_command0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank2_dfii_pi0_command0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_296 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_297;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_command0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 1'd1))) begin
		builder_csrbank2_dfii_pi0_command0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_297 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_phaseinjector0_command_issue_r = builder_interface2_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_298;
// synthesis translate_on
always @(*) begin
	main_litedramcore_phaseinjector0_command_issue_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 2'd2))) begin
		main_litedramcore_phaseinjector0_command_issue_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_298 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_299;
// synthesis translate_on
always @(*) begin
	main_litedramcore_phaseinjector0_command_issue_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 2'd2))) begin
		main_litedramcore_phaseinjector0_command_issue_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_299 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_address1_r = builder_interface2_bank_bus_dat_w[4:0];

// synthesis translate_off
reg dummy_d_300;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_address1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 2'd3))) begin
		builder_csrbank2_dfii_pi0_address1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_300 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_301;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_address1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 2'd3))) begin
		builder_csrbank2_dfii_pi0_address1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_301 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_address0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_302;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_address0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd4))) begin
		builder_csrbank2_dfii_pi0_address0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_302 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_303;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_address0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd4))) begin
		builder_csrbank2_dfii_pi0_address0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_303 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_baddress0_r = builder_interface2_bank_bus_dat_w[2:0];

// synthesis translate_off
reg dummy_d_304;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_baddress0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd5))) begin
		builder_csrbank2_dfii_pi0_baddress0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_304 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_305;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_baddress0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd5))) begin
		builder_csrbank2_dfii_pi0_baddress0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_305 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_wrdata3_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_306;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata3_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd6))) begin
		builder_csrbank2_dfii_pi0_wrdata3_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_306 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_307;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata3_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd6))) begin
		builder_csrbank2_dfii_pi0_wrdata3_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_307 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_wrdata2_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_308;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata2_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd7))) begin
		builder_csrbank2_dfii_pi0_wrdata2_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_308 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_309;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata2_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 3'd7))) begin
		builder_csrbank2_dfii_pi0_wrdata2_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_309 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_wrdata1_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_310;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd8))) begin
		builder_csrbank2_dfii_pi0_wrdata1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_310 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_311;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd8))) begin
		builder_csrbank2_dfii_pi0_wrdata1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_311 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_wrdata0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_312;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd9))) begin
		builder_csrbank2_dfii_pi0_wrdata0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_312 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_313;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_wrdata0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd9))) begin
		builder_csrbank2_dfii_pi0_wrdata0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_313 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_rddata3_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_314;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata3_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd10))) begin
		builder_csrbank2_dfii_pi0_rddata3_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_314 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_315;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata3_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd10))) begin
		builder_csrbank2_dfii_pi0_rddata3_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_315 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_rddata2_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_316;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata2_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd11))) begin
		builder_csrbank2_dfii_pi0_rddata2_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_316 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_317;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata2_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd11))) begin
		builder_csrbank2_dfii_pi0_rddata2_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_317 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_rddata1_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_318;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd12))) begin
		builder_csrbank2_dfii_pi0_rddata1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_318 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_319;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd12))) begin
		builder_csrbank2_dfii_pi0_rddata1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_319 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi0_rddata0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_320;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd13))) begin
		builder_csrbank2_dfii_pi0_rddata0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_320 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_321;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi0_rddata0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd13))) begin
		builder_csrbank2_dfii_pi0_rddata0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_321 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_command0_r = builder_interface2_bank_bus_dat_w[5:0];

// synthesis translate_off
reg dummy_d_322;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_command0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd14))) begin
		builder_csrbank2_dfii_pi1_command0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_322 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_323;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_command0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd14))) begin
		builder_csrbank2_dfii_pi1_command0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_323 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_phaseinjector1_command_issue_r = builder_interface2_bank_bus_dat_w[0];

// synthesis translate_off
reg dummy_d_324;
// synthesis translate_on
always @(*) begin
	main_litedramcore_phaseinjector1_command_issue_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd15))) begin
		main_litedramcore_phaseinjector1_command_issue_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_324 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_325;
// synthesis translate_on
always @(*) begin
	main_litedramcore_phaseinjector1_command_issue_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 4'd15))) begin
		main_litedramcore_phaseinjector1_command_issue_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_325 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_address1_r = builder_interface2_bank_bus_dat_w[4:0];

// synthesis translate_off
reg dummy_d_326;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_address1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd16))) begin
		builder_csrbank2_dfii_pi1_address1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_326 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_327;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_address1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd16))) begin
		builder_csrbank2_dfii_pi1_address1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_327 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_address0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_328;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_address0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd17))) begin
		builder_csrbank2_dfii_pi1_address0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_328 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_329;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_address0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd17))) begin
		builder_csrbank2_dfii_pi1_address0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_329 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_baddress0_r = builder_interface2_bank_bus_dat_w[2:0];

// synthesis translate_off
reg dummy_d_330;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_baddress0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd18))) begin
		builder_csrbank2_dfii_pi1_baddress0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_330 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_331;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_baddress0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd18))) begin
		builder_csrbank2_dfii_pi1_baddress0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_331 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_wrdata3_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_332;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata3_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd19))) begin
		builder_csrbank2_dfii_pi1_wrdata3_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_332 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_333;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata3_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd19))) begin
		builder_csrbank2_dfii_pi1_wrdata3_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_333 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_wrdata2_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_334;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata2_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd20))) begin
		builder_csrbank2_dfii_pi1_wrdata2_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_334 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_335;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata2_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd20))) begin
		builder_csrbank2_dfii_pi1_wrdata2_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_335 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_wrdata1_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_336;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd21))) begin
		builder_csrbank2_dfii_pi1_wrdata1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_336 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_337;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd21))) begin
		builder_csrbank2_dfii_pi1_wrdata1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_337 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_wrdata0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_338;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd22))) begin
		builder_csrbank2_dfii_pi1_wrdata0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_338 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_339;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_wrdata0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd22))) begin
		builder_csrbank2_dfii_pi1_wrdata0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_339 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_rddata3_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_340;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata3_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd23))) begin
		builder_csrbank2_dfii_pi1_rddata3_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_340 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_341;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata3_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd23))) begin
		builder_csrbank2_dfii_pi1_rddata3_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_341 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_rddata2_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_342;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata2_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd24))) begin
		builder_csrbank2_dfii_pi1_rddata2_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_342 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_343;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata2_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd24))) begin
		builder_csrbank2_dfii_pi1_rddata2_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_343 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_rddata1_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_344;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata1_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd25))) begin
		builder_csrbank2_dfii_pi1_rddata1_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_344 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_345;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata1_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd25))) begin
		builder_csrbank2_dfii_pi1_rddata1_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_345 = dummy_s;
// synthesis translate_on
end
assign builder_csrbank2_dfii_pi1_rddata0_r = builder_interface2_bank_bus_dat_w[7:0];

// synthesis translate_off
reg dummy_d_346;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata0_we <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd26))) begin
		builder_csrbank2_dfii_pi1_rddata0_we <= (~builder_interface2_bank_bus_we);
	end
// synthesis translate_off
	dummy_d_346 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_347;
// synthesis translate_on
always @(*) begin
	builder_csrbank2_dfii_pi1_rddata0_re <= 1'd0;
	if ((builder_csrbank2_sel & (builder_interface2_bank_bus_adr[8:0] == 5'd26))) begin
		builder_csrbank2_dfii_pi1_rddata0_re <= builder_interface2_bank_bus_we;
	end
// synthesis translate_off
	dummy_d_347 = dummy_s;
// synthesis translate_on
end
assign main_litedramcore_sel = main_litedramcore_storage[0];
assign main_litedramcore_cke = main_litedramcore_storage[1];
assign main_litedramcore_odt = main_litedramcore_storage[2];
assign main_litedramcore_reset_n = main_litedramcore_storage[3];
assign builder_csrbank2_dfii_control0_w = main_litedramcore_storage[3:0];
assign builder_csrbank2_dfii_pi0_command0_w = main_litedramcore_phaseinjector0_command_storage[5:0];
assign builder_csrbank2_dfii_pi0_address1_w = main_litedramcore_phaseinjector0_address_storage[12:8];
assign builder_csrbank2_dfii_pi0_address0_w = main_litedramcore_phaseinjector0_address_storage[7:0];
assign builder_csrbank2_dfii_pi0_baddress0_w = main_litedramcore_phaseinjector0_baddress_storage[2:0];
assign builder_csrbank2_dfii_pi0_wrdata3_w = main_litedramcore_phaseinjector0_wrdata_storage[31:24];
assign builder_csrbank2_dfii_pi0_wrdata2_w = main_litedramcore_phaseinjector0_wrdata_storage[23:16];
assign builder_csrbank2_dfii_pi0_wrdata1_w = main_litedramcore_phaseinjector0_wrdata_storage[15:8];
assign builder_csrbank2_dfii_pi0_wrdata0_w = main_litedramcore_phaseinjector0_wrdata_storage[7:0];
assign builder_csrbank2_dfii_pi0_rddata3_w = main_litedramcore_phaseinjector0_rddata_status[31:24];
assign builder_csrbank2_dfii_pi0_rddata2_w = main_litedramcore_phaseinjector0_rddata_status[23:16];
assign builder_csrbank2_dfii_pi0_rddata1_w = main_litedramcore_phaseinjector0_rddata_status[15:8];
assign builder_csrbank2_dfii_pi0_rddata0_w = main_litedramcore_phaseinjector0_rddata_status[7:0];
assign main_litedramcore_phaseinjector0_rddata_we = builder_csrbank2_dfii_pi0_rddata0_we;
assign builder_csrbank2_dfii_pi1_command0_w = main_litedramcore_phaseinjector1_command_storage[5:0];
assign builder_csrbank2_dfii_pi1_address1_w = main_litedramcore_phaseinjector1_address_storage[12:8];
assign builder_csrbank2_dfii_pi1_address0_w = main_litedramcore_phaseinjector1_address_storage[7:0];
assign builder_csrbank2_dfii_pi1_baddress0_w = main_litedramcore_phaseinjector1_baddress_storage[2:0];
assign builder_csrbank2_dfii_pi1_wrdata3_w = main_litedramcore_phaseinjector1_wrdata_storage[31:24];
assign builder_csrbank2_dfii_pi1_wrdata2_w = main_litedramcore_phaseinjector1_wrdata_storage[23:16];
assign builder_csrbank2_dfii_pi1_wrdata1_w = main_litedramcore_phaseinjector1_wrdata_storage[15:8];
assign builder_csrbank2_dfii_pi1_wrdata0_w = main_litedramcore_phaseinjector1_wrdata_storage[7:0];
assign builder_csrbank2_dfii_pi1_rddata3_w = main_litedramcore_phaseinjector1_rddata_status[31:24];
assign builder_csrbank2_dfii_pi1_rddata2_w = main_litedramcore_phaseinjector1_rddata_status[23:16];
assign builder_csrbank2_dfii_pi1_rddata1_w = main_litedramcore_phaseinjector1_rddata_status[15:8];
assign builder_csrbank2_dfii_pi1_rddata0_w = main_litedramcore_phaseinjector1_rddata_status[7:0];
assign main_litedramcore_phaseinjector1_rddata_we = builder_csrbank2_dfii_pi1_rddata0_we;
assign builder_csr_interconnect_adr = builder_litedramcore_adr;
assign builder_csr_interconnect_we = builder_litedramcore_we;
assign builder_csr_interconnect_dat_w = builder_litedramcore_dat_w;
assign builder_litedramcore_dat_r = builder_csr_interconnect_dat_r;
assign builder_interface0_bank_bus_adr = builder_csr_interconnect_adr;
assign builder_interface1_bank_bus_adr = builder_csr_interconnect_adr;
assign builder_interface2_bank_bus_adr = builder_csr_interconnect_adr;
assign builder_interface0_bank_bus_we = builder_csr_interconnect_we;
assign builder_interface1_bank_bus_we = builder_csr_interconnect_we;
assign builder_interface2_bank_bus_we = builder_csr_interconnect_we;
assign builder_interface0_bank_bus_dat_w = builder_csr_interconnect_dat_w;
assign builder_interface1_bank_bus_dat_w = builder_csr_interconnect_dat_w;
assign builder_interface2_bank_bus_dat_w = builder_csr_interconnect_dat_w;
assign builder_csr_interconnect_dat_r = ((builder_interface0_bank_bus_dat_r | builder_interface1_bank_bus_dat_r) | builder_interface2_bank_bus_dat_r);

// synthesis translate_off
reg dummy_d_348;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed0 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[0];
		end
		1'd1: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[1];
		end
		2'd2: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[2];
		end
		2'd3: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[3];
		end
		3'd4: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[4];
		end
		3'd5: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[5];
		end
		3'd6: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[6];
		end
		default: begin
			builder_rhs_array_muxed0 <= main_litedramcore_choose_cmd_valids[7];
		end
	endcase
// synthesis translate_off
	dummy_d_348 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_349;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed1 <= 13'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine0_cmd_payload_a;
		end
		1'd1: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine1_cmd_payload_a;
		end
		2'd2: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine2_cmd_payload_a;
		end
		2'd3: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine3_cmd_payload_a;
		end
		3'd4: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine4_cmd_payload_a;
		end
		3'd5: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine5_cmd_payload_a;
		end
		3'd6: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine6_cmd_payload_a;
		end
		default: begin
			builder_rhs_array_muxed1 <= main_litedramcore_bankmachine7_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_349 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_350;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed2 <= 3'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine0_cmd_payload_ba;
		end
		1'd1: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine1_cmd_payload_ba;
		end
		2'd2: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine2_cmd_payload_ba;
		end
		2'd3: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine3_cmd_payload_ba;
		end
		3'd4: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine4_cmd_payload_ba;
		end
		3'd5: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine5_cmd_payload_ba;
		end
		3'd6: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine6_cmd_payload_ba;
		end
		default: begin
			builder_rhs_array_muxed2 <= main_litedramcore_bankmachine7_cmd_payload_ba;
		end
	endcase
// synthesis translate_off
	dummy_d_350 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_351;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed3 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine0_cmd_payload_is_read;
		end
		1'd1: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine1_cmd_payload_is_read;
		end
		2'd2: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine2_cmd_payload_is_read;
		end
		2'd3: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine3_cmd_payload_is_read;
		end
		3'd4: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine4_cmd_payload_is_read;
		end
		3'd5: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine5_cmd_payload_is_read;
		end
		3'd6: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine6_cmd_payload_is_read;
		end
		default: begin
			builder_rhs_array_muxed3 <= main_litedramcore_bankmachine7_cmd_payload_is_read;
		end
	endcase
// synthesis translate_off
	dummy_d_351 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_352;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed4 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine0_cmd_payload_is_write;
		end
		1'd1: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine1_cmd_payload_is_write;
		end
		2'd2: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine2_cmd_payload_is_write;
		end
		2'd3: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine3_cmd_payload_is_write;
		end
		3'd4: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine4_cmd_payload_is_write;
		end
		3'd5: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine5_cmd_payload_is_write;
		end
		3'd6: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine6_cmd_payload_is_write;
		end
		default: begin
			builder_rhs_array_muxed4 <= main_litedramcore_bankmachine7_cmd_payload_is_write;
		end
	endcase
// synthesis translate_off
	dummy_d_352 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_353;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed5 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine0_cmd_payload_is_cmd;
		end
		1'd1: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine1_cmd_payload_is_cmd;
		end
		2'd2: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine2_cmd_payload_is_cmd;
		end
		2'd3: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine3_cmd_payload_is_cmd;
		end
		3'd4: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine4_cmd_payload_is_cmd;
		end
		3'd5: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine5_cmd_payload_is_cmd;
		end
		3'd6: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine6_cmd_payload_is_cmd;
		end
		default: begin
			builder_rhs_array_muxed5 <= main_litedramcore_bankmachine7_cmd_payload_is_cmd;
		end
	endcase
// synthesis translate_off
	dummy_d_353 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_354;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed0 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine0_cmd_payload_cas;
		end
		1'd1: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine1_cmd_payload_cas;
		end
		2'd2: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine2_cmd_payload_cas;
		end
		2'd3: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine3_cmd_payload_cas;
		end
		3'd4: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine4_cmd_payload_cas;
		end
		3'd5: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine5_cmd_payload_cas;
		end
		3'd6: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine6_cmd_payload_cas;
		end
		default: begin
			builder_t_array_muxed0 <= main_litedramcore_bankmachine7_cmd_payload_cas;
		end
	endcase
// synthesis translate_off
	dummy_d_354 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_355;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed1 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine0_cmd_payload_ras;
		end
		1'd1: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine1_cmd_payload_ras;
		end
		2'd2: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine2_cmd_payload_ras;
		end
		2'd3: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine3_cmd_payload_ras;
		end
		3'd4: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine4_cmd_payload_ras;
		end
		3'd5: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine5_cmd_payload_ras;
		end
		3'd6: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine6_cmd_payload_ras;
		end
		default: begin
			builder_t_array_muxed1 <= main_litedramcore_bankmachine7_cmd_payload_ras;
		end
	endcase
// synthesis translate_off
	dummy_d_355 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_356;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed2 <= 1'd0;
	case (main_litedramcore_choose_cmd_grant)
		1'd0: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine0_cmd_payload_we;
		end
		1'd1: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine1_cmd_payload_we;
		end
		2'd2: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine2_cmd_payload_we;
		end
		2'd3: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine3_cmd_payload_we;
		end
		3'd4: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine4_cmd_payload_we;
		end
		3'd5: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine5_cmd_payload_we;
		end
		3'd6: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine6_cmd_payload_we;
		end
		default: begin
			builder_t_array_muxed2 <= main_litedramcore_bankmachine7_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_356 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_357;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed6 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[0];
		end
		1'd1: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[1];
		end
		2'd2: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[2];
		end
		2'd3: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[3];
		end
		3'd4: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[4];
		end
		3'd5: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[5];
		end
		3'd6: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[6];
		end
		default: begin
			builder_rhs_array_muxed6 <= main_litedramcore_choose_req_valids[7];
		end
	endcase
// synthesis translate_off
	dummy_d_357 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_358;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed7 <= 13'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine0_cmd_payload_a;
		end
		1'd1: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine1_cmd_payload_a;
		end
		2'd2: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine2_cmd_payload_a;
		end
		2'd3: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine3_cmd_payload_a;
		end
		3'd4: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine4_cmd_payload_a;
		end
		3'd5: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine5_cmd_payload_a;
		end
		3'd6: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine6_cmd_payload_a;
		end
		default: begin
			builder_rhs_array_muxed7 <= main_litedramcore_bankmachine7_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_358 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_359;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed8 <= 3'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine0_cmd_payload_ba;
		end
		1'd1: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine1_cmd_payload_ba;
		end
		2'd2: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine2_cmd_payload_ba;
		end
		2'd3: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine3_cmd_payload_ba;
		end
		3'd4: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine4_cmd_payload_ba;
		end
		3'd5: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine5_cmd_payload_ba;
		end
		3'd6: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine6_cmd_payload_ba;
		end
		default: begin
			builder_rhs_array_muxed8 <= main_litedramcore_bankmachine7_cmd_payload_ba;
		end
	endcase
// synthesis translate_off
	dummy_d_359 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_360;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed9 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine0_cmd_payload_is_read;
		end
		1'd1: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine1_cmd_payload_is_read;
		end
		2'd2: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine2_cmd_payload_is_read;
		end
		2'd3: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine3_cmd_payload_is_read;
		end
		3'd4: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine4_cmd_payload_is_read;
		end
		3'd5: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine5_cmd_payload_is_read;
		end
		3'd6: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine6_cmd_payload_is_read;
		end
		default: begin
			builder_rhs_array_muxed9 <= main_litedramcore_bankmachine7_cmd_payload_is_read;
		end
	endcase
// synthesis translate_off
	dummy_d_360 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_361;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed10 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine0_cmd_payload_is_write;
		end
		1'd1: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine1_cmd_payload_is_write;
		end
		2'd2: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine2_cmd_payload_is_write;
		end
		2'd3: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine3_cmd_payload_is_write;
		end
		3'd4: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine4_cmd_payload_is_write;
		end
		3'd5: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine5_cmd_payload_is_write;
		end
		3'd6: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine6_cmd_payload_is_write;
		end
		default: begin
			builder_rhs_array_muxed10 <= main_litedramcore_bankmachine7_cmd_payload_is_write;
		end
	endcase
// synthesis translate_off
	dummy_d_361 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_362;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed11 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine0_cmd_payload_is_cmd;
		end
		1'd1: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine1_cmd_payload_is_cmd;
		end
		2'd2: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine2_cmd_payload_is_cmd;
		end
		2'd3: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine3_cmd_payload_is_cmd;
		end
		3'd4: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine4_cmd_payload_is_cmd;
		end
		3'd5: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine5_cmd_payload_is_cmd;
		end
		3'd6: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine6_cmd_payload_is_cmd;
		end
		default: begin
			builder_rhs_array_muxed11 <= main_litedramcore_bankmachine7_cmd_payload_is_cmd;
		end
	endcase
// synthesis translate_off
	dummy_d_362 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_363;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed3 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine0_cmd_payload_cas;
		end
		1'd1: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine1_cmd_payload_cas;
		end
		2'd2: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine2_cmd_payload_cas;
		end
		2'd3: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine3_cmd_payload_cas;
		end
		3'd4: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine4_cmd_payload_cas;
		end
		3'd5: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine5_cmd_payload_cas;
		end
		3'd6: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine6_cmd_payload_cas;
		end
		default: begin
			builder_t_array_muxed3 <= main_litedramcore_bankmachine7_cmd_payload_cas;
		end
	endcase
// synthesis translate_off
	dummy_d_363 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_364;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed4 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine0_cmd_payload_ras;
		end
		1'd1: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine1_cmd_payload_ras;
		end
		2'd2: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine2_cmd_payload_ras;
		end
		2'd3: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine3_cmd_payload_ras;
		end
		3'd4: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine4_cmd_payload_ras;
		end
		3'd5: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine5_cmd_payload_ras;
		end
		3'd6: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine6_cmd_payload_ras;
		end
		default: begin
			builder_t_array_muxed4 <= main_litedramcore_bankmachine7_cmd_payload_ras;
		end
	endcase
// synthesis translate_off
	dummy_d_364 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_365;
// synthesis translate_on
always @(*) begin
	builder_t_array_muxed5 <= 1'd0;
	case (main_litedramcore_choose_req_grant)
		1'd0: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine0_cmd_payload_we;
		end
		1'd1: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine1_cmd_payload_we;
		end
		2'd2: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine2_cmd_payload_we;
		end
		2'd3: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine3_cmd_payload_we;
		end
		3'd4: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine4_cmd_payload_we;
		end
		3'd5: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine5_cmd_payload_we;
		end
		3'd6: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine6_cmd_payload_we;
		end
		default: begin
			builder_t_array_muxed5 <= main_litedramcore_bankmachine7_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_365 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_366;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed12 <= 21'd0;
	case (builder_roundrobin0_grant)
		default: begin
			builder_rhs_array_muxed12 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_366 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_367;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed13 <= 1'd0;
	case (builder_roundrobin0_grant)
		default: begin
			builder_rhs_array_muxed13 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_367 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_368;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed14 <= 1'd0;
	case (builder_roundrobin0_grant)
		default: begin
			builder_rhs_array_muxed14 <= (((main_user_port_cmd_payload_addr[10:8] == 1'd0) & (~(((((((builder_locked0 | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_368 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_369;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed15 <= 21'd0;
	case (builder_roundrobin1_grant)
		default: begin
			builder_rhs_array_muxed15 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_369 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_370;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed16 <= 1'd0;
	case (builder_roundrobin1_grant)
		default: begin
			builder_rhs_array_muxed16 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_370 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_371;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed17 <= 1'd0;
	case (builder_roundrobin1_grant)
		default: begin
			builder_rhs_array_muxed17 <= (((main_user_port_cmd_payload_addr[10:8] == 1'd1) & (~(((((((builder_locked1 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_371 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_372;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed18 <= 21'd0;
	case (builder_roundrobin2_grant)
		default: begin
			builder_rhs_array_muxed18 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_372 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_373;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed19 <= 1'd0;
	case (builder_roundrobin2_grant)
		default: begin
			builder_rhs_array_muxed19 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_373 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_374;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed20 <= 1'd0;
	case (builder_roundrobin2_grant)
		default: begin
			builder_rhs_array_muxed20 <= (((main_user_port_cmd_payload_addr[10:8] == 2'd2) & (~(((((((builder_locked2 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_374 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_375;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed21 <= 21'd0;
	case (builder_roundrobin3_grant)
		default: begin
			builder_rhs_array_muxed21 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_375 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_376;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed22 <= 1'd0;
	case (builder_roundrobin3_grant)
		default: begin
			builder_rhs_array_muxed22 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_376 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_377;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed23 <= 1'd0;
	case (builder_roundrobin3_grant)
		default: begin
			builder_rhs_array_muxed23 <= (((main_user_port_cmd_payload_addr[10:8] == 2'd3) & (~(((((((builder_locked3 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_377 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_378;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed24 <= 21'd0;
	case (builder_roundrobin4_grant)
		default: begin
			builder_rhs_array_muxed24 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_378 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_379;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed25 <= 1'd0;
	case (builder_roundrobin4_grant)
		default: begin
			builder_rhs_array_muxed25 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_379 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_380;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed26 <= 1'd0;
	case (builder_roundrobin4_grant)
		default: begin
			builder_rhs_array_muxed26 <= (((main_user_port_cmd_payload_addr[10:8] == 3'd4) & (~(((((((builder_locked4 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_380 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_381;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed27 <= 21'd0;
	case (builder_roundrobin5_grant)
		default: begin
			builder_rhs_array_muxed27 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_381 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_382;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed28 <= 1'd0;
	case (builder_roundrobin5_grant)
		default: begin
			builder_rhs_array_muxed28 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_382 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_383;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed29 <= 1'd0;
	case (builder_roundrobin5_grant)
		default: begin
			builder_rhs_array_muxed29 <= (((main_user_port_cmd_payload_addr[10:8] == 3'd5) & (~(((((((builder_locked5 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_383 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_384;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed30 <= 21'd0;
	case (builder_roundrobin6_grant)
		default: begin
			builder_rhs_array_muxed30 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_384 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_385;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed31 <= 1'd0;
	case (builder_roundrobin6_grant)
		default: begin
			builder_rhs_array_muxed31 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_385 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_386;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed32 <= 1'd0;
	case (builder_roundrobin6_grant)
		default: begin
			builder_rhs_array_muxed32 <= (((main_user_port_cmd_payload_addr[10:8] == 3'd6) & (~(((((((builder_locked6 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank7_lock & (builder_roundrobin7_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_386 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_387;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed33 <= 21'd0;
	case (builder_roundrobin7_grant)
		default: begin
			builder_rhs_array_muxed33 <= {main_user_port_cmd_payload_addr[23:11], main_user_port_cmd_payload_addr[7:0]};
		end
	endcase
// synthesis translate_off
	dummy_d_387 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_388;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed34 <= 1'd0;
	case (builder_roundrobin7_grant)
		default: begin
			builder_rhs_array_muxed34 <= main_user_port_cmd_payload_we;
		end
	endcase
// synthesis translate_off
	dummy_d_388 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_389;
// synthesis translate_on
always @(*) begin
	builder_rhs_array_muxed35 <= 1'd0;
	case (builder_roundrobin7_grant)
		default: begin
			builder_rhs_array_muxed35 <= (((main_user_port_cmd_payload_addr[10:8] == 3'd7) & (~(((((((builder_locked7 | (main_litedramcore_interface_bank0_lock & (builder_roundrobin0_grant == 1'd0))) | (main_litedramcore_interface_bank1_lock & (builder_roundrobin1_grant == 1'd0))) | (main_litedramcore_interface_bank2_lock & (builder_roundrobin2_grant == 1'd0))) | (main_litedramcore_interface_bank3_lock & (builder_roundrobin3_grant == 1'd0))) | (main_litedramcore_interface_bank4_lock & (builder_roundrobin4_grant == 1'd0))) | (main_litedramcore_interface_bank5_lock & (builder_roundrobin5_grant == 1'd0))) | (main_litedramcore_interface_bank6_lock & (builder_roundrobin6_grant == 1'd0))))) & main_user_port_cmd_valid);
		end
	endcase
// synthesis translate_off
	dummy_d_389 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_390;
// synthesis translate_on
always @(*) begin
	builder_array_muxed0 <= 3'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed0 <= main_litedramcore_nop_ba[2:0];
		end
		1'd1: begin
			builder_array_muxed0 <= main_litedramcore_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			builder_array_muxed0 <= main_litedramcore_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			builder_array_muxed0 <= main_litedramcore_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_390 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_391;
// synthesis translate_on
always @(*) begin
	builder_array_muxed1 <= 13'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed1 <= main_litedramcore_nop_a;
		end
		1'd1: begin
			builder_array_muxed1 <= main_litedramcore_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			builder_array_muxed1 <= main_litedramcore_choose_req_cmd_payload_a;
		end
		default: begin
			builder_array_muxed1 <= main_litedramcore_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_391 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_392;
// synthesis translate_on
always @(*) begin
	builder_array_muxed2 <= 1'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed2 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed2 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			builder_array_muxed2 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_cas);
		end
		default: begin
			builder_array_muxed2 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_392 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_393;
// synthesis translate_on
always @(*) begin
	builder_array_muxed3 <= 1'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed3 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed3 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			builder_array_muxed3 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_ras);
		end
		default: begin
			builder_array_muxed3 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_393 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_394;
// synthesis translate_on
always @(*) begin
	builder_array_muxed4 <= 1'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed4 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed4 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			builder_array_muxed4 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_we);
		end
		default: begin
			builder_array_muxed4 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_394 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_395;
// synthesis translate_on
always @(*) begin
	builder_array_muxed5 <= 1'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed5 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed5 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			builder_array_muxed5 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_is_read);
		end
		default: begin
			builder_array_muxed5 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_395 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_396;
// synthesis translate_on
always @(*) begin
	builder_array_muxed6 <= 1'd0;
	case (main_litedramcore_steerer_sel0)
		1'd0: begin
			builder_array_muxed6 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed6 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			builder_array_muxed6 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_is_write);
		end
		default: begin
			builder_array_muxed6 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_396 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_397;
// synthesis translate_on
always @(*) begin
	builder_array_muxed7 <= 3'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed7 <= main_litedramcore_nop_ba[2:0];
		end
		1'd1: begin
			builder_array_muxed7 <= main_litedramcore_choose_cmd_cmd_payload_ba[2:0];
		end
		2'd2: begin
			builder_array_muxed7 <= main_litedramcore_choose_req_cmd_payload_ba[2:0];
		end
		default: begin
			builder_array_muxed7 <= main_litedramcore_cmd_payload_ba[2:0];
		end
	endcase
// synthesis translate_off
	dummy_d_397 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_398;
// synthesis translate_on
always @(*) begin
	builder_array_muxed8 <= 13'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed8 <= main_litedramcore_nop_a;
		end
		1'd1: begin
			builder_array_muxed8 <= main_litedramcore_choose_cmd_cmd_payload_a;
		end
		2'd2: begin
			builder_array_muxed8 <= main_litedramcore_choose_req_cmd_payload_a;
		end
		default: begin
			builder_array_muxed8 <= main_litedramcore_cmd_payload_a;
		end
	endcase
// synthesis translate_off
	dummy_d_398 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_399;
// synthesis translate_on
always @(*) begin
	builder_array_muxed9 <= 1'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed9 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed9 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_cas);
		end
		2'd2: begin
			builder_array_muxed9 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_cas);
		end
		default: begin
			builder_array_muxed9 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_cas);
		end
	endcase
// synthesis translate_off
	dummy_d_399 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_400;
// synthesis translate_on
always @(*) begin
	builder_array_muxed10 <= 1'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed10 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed10 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_ras);
		end
		2'd2: begin
			builder_array_muxed10 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_ras);
		end
		default: begin
			builder_array_muxed10 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_ras);
		end
	endcase
// synthesis translate_off
	dummy_d_400 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_401;
// synthesis translate_on
always @(*) begin
	builder_array_muxed11 <= 1'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed11 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed11 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_we);
		end
		2'd2: begin
			builder_array_muxed11 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_we);
		end
		default: begin
			builder_array_muxed11 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_we);
		end
	endcase
// synthesis translate_off
	dummy_d_401 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_402;
// synthesis translate_on
always @(*) begin
	builder_array_muxed12 <= 1'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed12 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed12 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_is_read);
		end
		2'd2: begin
			builder_array_muxed12 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_is_read);
		end
		default: begin
			builder_array_muxed12 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_is_read);
		end
	endcase
// synthesis translate_off
	dummy_d_402 = dummy_s;
// synthesis translate_on
end

// synthesis translate_off
reg dummy_d_403;
// synthesis translate_on
always @(*) begin
	builder_array_muxed13 <= 1'd0;
	case (main_litedramcore_steerer_sel1)
		1'd0: begin
			builder_array_muxed13 <= 1'd0;
		end
		1'd1: begin
			builder_array_muxed13 <= ((main_litedramcore_choose_cmd_cmd_valid & main_litedramcore_choose_cmd_cmd_ready) & main_litedramcore_choose_cmd_cmd_payload_is_write);
		end
		2'd2: begin
			builder_array_muxed13 <= ((main_litedramcore_choose_req_cmd_valid & main_litedramcore_choose_req_cmd_ready) & main_litedramcore_choose_req_cmd_payload_is_write);
		end
		default: begin
			builder_array_muxed13 <= ((main_litedramcore_cmd_valid & main_litedramcore_cmd_ready) & main_litedramcore_cmd_payload_is_write);
		end
	endcase
// synthesis translate_off
	dummy_d_403 = dummy_s;
// synthesis translate_on
end
assign builder_xilinxasyncresetsynchronizerimpl0 = (~main_locked);
assign builder_xilinxasyncresetsynchronizerimpl1 = (~main_locked);
assign builder_xilinxasyncresetsynchronizerimpl2 = (~main_locked);
assign builder_xilinxasyncresetsynchronizerimpl3 = (~main_locked);

always @(posedge iodelay_clk) begin
	if ((main_reset_counter != 1'd0)) begin
		main_reset_counter <= (main_reset_counter - 1'd1);
	end else begin
		main_ic_reset <= 1'd0;
	end
	if (iodelay_rst) begin
		main_reset_counter <= 4'd15;
		main_ic_reset <= 1'd1;
	end
end

always @(posedge sys_clk) begin
	main_a7ddrphy_dqs_oe_delay_tappeddelayline_tappeddelayline <= main_a7ddrphy_dqs_oe_delay_tappeddelayline;
	main_a7ddrphy_dqspattern_o1 <= main_a7ddrphy_dqspattern_o0;
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip0_value0 <= (main_a7ddrphy_bitslip0_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip0_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip0_r0 <= {main_a7ddrphy_dqspattern_o1, main_a7ddrphy_bitslip0_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip1_value0 <= (main_a7ddrphy_bitslip1_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip1_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip1_r0 <= {main_a7ddrphy_dqspattern_o1, main_a7ddrphy_bitslip1_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip0_value1 <= (main_a7ddrphy_bitslip0_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip0_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip0_r1 <= {{main_a7ddrphy_dfi_p3_wrdata_mask[2], main_a7ddrphy_dfi_p3_wrdata_mask[0], main_a7ddrphy_dfi_p2_wrdata_mask[2], main_a7ddrphy_dfi_p2_wrdata_mask[0], main_a7ddrphy_dfi_p1_wrdata_mask[2], main_a7ddrphy_dfi_p1_wrdata_mask[0], main_a7ddrphy_dfi_p0_wrdata_mask[2], main_a7ddrphy_dfi_p0_wrdata_mask[0]}, main_a7ddrphy_bitslip0_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip1_value1 <= (main_a7ddrphy_bitslip1_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip1_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip1_r1 <= {{main_a7ddrphy_dfi_p3_wrdata_mask[3], main_a7ddrphy_dfi_p3_wrdata_mask[1], main_a7ddrphy_dfi_p2_wrdata_mask[3], main_a7ddrphy_dfi_p2_wrdata_mask[1], main_a7ddrphy_dfi_p1_wrdata_mask[3], main_a7ddrphy_dfi_p1_wrdata_mask[1], main_a7ddrphy_dfi_p0_wrdata_mask[3], main_a7ddrphy_dfi_p0_wrdata_mask[1]}, main_a7ddrphy_bitslip1_r1[15:8]};
	main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline <= main_a7ddrphy_dq_oe_delay_tappeddelayline;
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip0_value2 <= (main_a7ddrphy_bitslip0_value2 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip0_value2 <= 3'd7;
	end
	main_a7ddrphy_bitslip0_r2 <= {{main_a7ddrphy_dfi_p3_wrdata[16], main_a7ddrphy_dfi_p3_wrdata[0], main_a7ddrphy_dfi_p2_wrdata[16], main_a7ddrphy_dfi_p2_wrdata[0], main_a7ddrphy_dfi_p1_wrdata[16], main_a7ddrphy_dfi_p1_wrdata[0], main_a7ddrphy_dfi_p0_wrdata[16], main_a7ddrphy_dfi_p0_wrdata[0]}, main_a7ddrphy_bitslip0_r2[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip0_value3 <= (main_a7ddrphy_bitslip0_value3 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip0_value3 <= 3'd7;
	end
	main_a7ddrphy_bitslip0_r3 <= {main_a7ddrphy_bitslip03, main_a7ddrphy_bitslip0_r3[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip1_value2 <= (main_a7ddrphy_bitslip1_value2 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip1_value2 <= 3'd7;
	end
	main_a7ddrphy_bitslip1_r2 <= {{main_a7ddrphy_dfi_p3_wrdata[17], main_a7ddrphy_dfi_p3_wrdata[1], main_a7ddrphy_dfi_p2_wrdata[17], main_a7ddrphy_dfi_p2_wrdata[1], main_a7ddrphy_dfi_p1_wrdata[17], main_a7ddrphy_dfi_p1_wrdata[1], main_a7ddrphy_dfi_p0_wrdata[17], main_a7ddrphy_dfi_p0_wrdata[1]}, main_a7ddrphy_bitslip1_r2[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip1_value3 <= (main_a7ddrphy_bitslip1_value3 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip1_value3 <= 3'd7;
	end
	main_a7ddrphy_bitslip1_r3 <= {main_a7ddrphy_bitslip13, main_a7ddrphy_bitslip1_r3[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip2_value0 <= (main_a7ddrphy_bitslip2_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip2_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip2_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[18], main_a7ddrphy_dfi_p3_wrdata[2], main_a7ddrphy_dfi_p2_wrdata[18], main_a7ddrphy_dfi_p2_wrdata[2], main_a7ddrphy_dfi_p1_wrdata[18], main_a7ddrphy_dfi_p1_wrdata[2], main_a7ddrphy_dfi_p0_wrdata[18], main_a7ddrphy_dfi_p0_wrdata[2]}, main_a7ddrphy_bitslip2_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip2_value1 <= (main_a7ddrphy_bitslip2_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip2_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip2_r1 <= {main_a7ddrphy_bitslip21, main_a7ddrphy_bitslip2_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip3_value0 <= (main_a7ddrphy_bitslip3_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip3_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip3_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[19], main_a7ddrphy_dfi_p3_wrdata[3], main_a7ddrphy_dfi_p2_wrdata[19], main_a7ddrphy_dfi_p2_wrdata[3], main_a7ddrphy_dfi_p1_wrdata[19], main_a7ddrphy_dfi_p1_wrdata[3], main_a7ddrphy_dfi_p0_wrdata[19], main_a7ddrphy_dfi_p0_wrdata[3]}, main_a7ddrphy_bitslip3_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip3_value1 <= (main_a7ddrphy_bitslip3_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip3_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip3_r1 <= {main_a7ddrphy_bitslip31, main_a7ddrphy_bitslip3_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip4_value0 <= (main_a7ddrphy_bitslip4_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip4_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip4_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[20], main_a7ddrphy_dfi_p3_wrdata[4], main_a7ddrphy_dfi_p2_wrdata[20], main_a7ddrphy_dfi_p2_wrdata[4], main_a7ddrphy_dfi_p1_wrdata[20], main_a7ddrphy_dfi_p1_wrdata[4], main_a7ddrphy_dfi_p0_wrdata[20], main_a7ddrphy_dfi_p0_wrdata[4]}, main_a7ddrphy_bitslip4_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip4_value1 <= (main_a7ddrphy_bitslip4_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip4_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip4_r1 <= {main_a7ddrphy_bitslip41, main_a7ddrphy_bitslip4_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip5_value0 <= (main_a7ddrphy_bitslip5_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip5_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip5_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[21], main_a7ddrphy_dfi_p3_wrdata[5], main_a7ddrphy_dfi_p2_wrdata[21], main_a7ddrphy_dfi_p2_wrdata[5], main_a7ddrphy_dfi_p1_wrdata[21], main_a7ddrphy_dfi_p1_wrdata[5], main_a7ddrphy_dfi_p0_wrdata[21], main_a7ddrphy_dfi_p0_wrdata[5]}, main_a7ddrphy_bitslip5_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip5_value1 <= (main_a7ddrphy_bitslip5_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip5_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip5_r1 <= {main_a7ddrphy_bitslip51, main_a7ddrphy_bitslip5_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip6_value0 <= (main_a7ddrphy_bitslip6_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip6_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip6_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[22], main_a7ddrphy_dfi_p3_wrdata[6], main_a7ddrphy_dfi_p2_wrdata[22], main_a7ddrphy_dfi_p2_wrdata[6], main_a7ddrphy_dfi_p1_wrdata[22], main_a7ddrphy_dfi_p1_wrdata[6], main_a7ddrphy_dfi_p0_wrdata[22], main_a7ddrphy_dfi_p0_wrdata[6]}, main_a7ddrphy_bitslip6_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip6_value1 <= (main_a7ddrphy_bitslip6_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip6_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip6_r1 <= {main_a7ddrphy_bitslip61, main_a7ddrphy_bitslip6_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip7_value0 <= (main_a7ddrphy_bitslip7_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip7_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip7_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[23], main_a7ddrphy_dfi_p3_wrdata[7], main_a7ddrphy_dfi_p2_wrdata[23], main_a7ddrphy_dfi_p2_wrdata[7], main_a7ddrphy_dfi_p1_wrdata[23], main_a7ddrphy_dfi_p1_wrdata[7], main_a7ddrphy_dfi_p0_wrdata[23], main_a7ddrphy_dfi_p0_wrdata[7]}, main_a7ddrphy_bitslip7_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip7_value1 <= (main_a7ddrphy_bitslip7_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip7_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip7_r1 <= {main_a7ddrphy_bitslip71, main_a7ddrphy_bitslip7_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip8_value0 <= (main_a7ddrphy_bitslip8_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip8_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip8_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[24], main_a7ddrphy_dfi_p3_wrdata[8], main_a7ddrphy_dfi_p2_wrdata[24], main_a7ddrphy_dfi_p2_wrdata[8], main_a7ddrphy_dfi_p1_wrdata[24], main_a7ddrphy_dfi_p1_wrdata[8], main_a7ddrphy_dfi_p0_wrdata[24], main_a7ddrphy_dfi_p0_wrdata[8]}, main_a7ddrphy_bitslip8_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip8_value1 <= (main_a7ddrphy_bitslip8_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip8_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip8_r1 <= {main_a7ddrphy_bitslip81, main_a7ddrphy_bitslip8_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip9_value0 <= (main_a7ddrphy_bitslip9_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip9_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip9_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[25], main_a7ddrphy_dfi_p3_wrdata[9], main_a7ddrphy_dfi_p2_wrdata[25], main_a7ddrphy_dfi_p2_wrdata[9], main_a7ddrphy_dfi_p1_wrdata[25], main_a7ddrphy_dfi_p1_wrdata[9], main_a7ddrphy_dfi_p0_wrdata[25], main_a7ddrphy_dfi_p0_wrdata[9]}, main_a7ddrphy_bitslip9_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip9_value1 <= (main_a7ddrphy_bitslip9_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip9_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip9_r1 <= {main_a7ddrphy_bitslip91, main_a7ddrphy_bitslip9_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip10_value0 <= (main_a7ddrphy_bitslip10_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip10_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip10_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[26], main_a7ddrphy_dfi_p3_wrdata[10], main_a7ddrphy_dfi_p2_wrdata[26], main_a7ddrphy_dfi_p2_wrdata[10], main_a7ddrphy_dfi_p1_wrdata[26], main_a7ddrphy_dfi_p1_wrdata[10], main_a7ddrphy_dfi_p0_wrdata[26], main_a7ddrphy_dfi_p0_wrdata[10]}, main_a7ddrphy_bitslip10_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip10_value1 <= (main_a7ddrphy_bitslip10_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip10_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip10_r1 <= {main_a7ddrphy_bitslip101, main_a7ddrphy_bitslip10_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip11_value0 <= (main_a7ddrphy_bitslip11_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip11_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip11_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[27], main_a7ddrphy_dfi_p3_wrdata[11], main_a7ddrphy_dfi_p2_wrdata[27], main_a7ddrphy_dfi_p2_wrdata[11], main_a7ddrphy_dfi_p1_wrdata[27], main_a7ddrphy_dfi_p1_wrdata[11], main_a7ddrphy_dfi_p0_wrdata[27], main_a7ddrphy_dfi_p0_wrdata[11]}, main_a7ddrphy_bitslip11_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip11_value1 <= (main_a7ddrphy_bitslip11_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip11_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip11_r1 <= {main_a7ddrphy_bitslip111, main_a7ddrphy_bitslip11_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip12_value0 <= (main_a7ddrphy_bitslip12_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip12_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip12_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[28], main_a7ddrphy_dfi_p3_wrdata[12], main_a7ddrphy_dfi_p2_wrdata[28], main_a7ddrphy_dfi_p2_wrdata[12], main_a7ddrphy_dfi_p1_wrdata[28], main_a7ddrphy_dfi_p1_wrdata[12], main_a7ddrphy_dfi_p0_wrdata[28], main_a7ddrphy_dfi_p0_wrdata[12]}, main_a7ddrphy_bitslip12_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip12_value1 <= (main_a7ddrphy_bitslip12_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip12_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip12_r1 <= {main_a7ddrphy_bitslip121, main_a7ddrphy_bitslip12_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip13_value0 <= (main_a7ddrphy_bitslip13_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip13_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip13_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[29], main_a7ddrphy_dfi_p3_wrdata[13], main_a7ddrphy_dfi_p2_wrdata[29], main_a7ddrphy_dfi_p2_wrdata[13], main_a7ddrphy_dfi_p1_wrdata[29], main_a7ddrphy_dfi_p1_wrdata[13], main_a7ddrphy_dfi_p0_wrdata[29], main_a7ddrphy_dfi_p0_wrdata[13]}, main_a7ddrphy_bitslip13_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip13_value1 <= (main_a7ddrphy_bitslip13_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip13_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip13_r1 <= {main_a7ddrphy_bitslip131, main_a7ddrphy_bitslip13_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip14_value0 <= (main_a7ddrphy_bitslip14_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip14_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip14_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[30], main_a7ddrphy_dfi_p3_wrdata[14], main_a7ddrphy_dfi_p2_wrdata[30], main_a7ddrphy_dfi_p2_wrdata[14], main_a7ddrphy_dfi_p1_wrdata[30], main_a7ddrphy_dfi_p1_wrdata[14], main_a7ddrphy_dfi_p0_wrdata[30], main_a7ddrphy_dfi_p0_wrdata[14]}, main_a7ddrphy_bitslip14_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip14_value1 <= (main_a7ddrphy_bitslip14_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip14_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip14_r1 <= {main_a7ddrphy_bitslip141, main_a7ddrphy_bitslip14_r1[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip15_value0 <= (main_a7ddrphy_bitslip15_value0 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_wdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip15_value0 <= 3'd7;
	end
	main_a7ddrphy_bitslip15_r0 <= {{main_a7ddrphy_dfi_p3_wrdata[31], main_a7ddrphy_dfi_p3_wrdata[15], main_a7ddrphy_dfi_p2_wrdata[31], main_a7ddrphy_dfi_p2_wrdata[15], main_a7ddrphy_dfi_p1_wrdata[31], main_a7ddrphy_dfi_p1_wrdata[15], main_a7ddrphy_dfi_p0_wrdata[31], main_a7ddrphy_dfi_p0_wrdata[15]}, main_a7ddrphy_bitslip15_r0[15:8]};
	if ((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_re)) begin
		main_a7ddrphy_bitslip15_value1 <= (main_a7ddrphy_bitslip15_value1 + 1'd1);
	end
	if (((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_bitslip_rst_re) | main_a7ddrphy_rst_storage)) begin
		main_a7ddrphy_bitslip15_value1 <= 3'd7;
	end
	main_a7ddrphy_bitslip15_r1 <= {main_a7ddrphy_bitslip151, main_a7ddrphy_bitslip15_r1[15:8]};
	main_a7ddrphy_rddata_en_tappeddelayline0 <= (main_a7ddrphy_dfi_p0_rddata_en | main_a7ddrphy_dfi_p1_rddata_en);
	main_a7ddrphy_rddata_en_tappeddelayline1 <= main_a7ddrphy_rddata_en_tappeddelayline0;
	main_a7ddrphy_rddata_en_tappeddelayline2 <= main_a7ddrphy_rddata_en_tappeddelayline1;
	main_a7ddrphy_rddata_en_tappeddelayline3 <= main_a7ddrphy_rddata_en_tappeddelayline2;
	main_a7ddrphy_rddata_en_tappeddelayline4 <= main_a7ddrphy_rddata_en_tappeddelayline3;
	main_a7ddrphy_rddata_en_tappeddelayline5 <= main_a7ddrphy_rddata_en_tappeddelayline4;
	main_a7ddrphy_rddata_en_tappeddelayline6 <= main_a7ddrphy_rddata_en_tappeddelayline5;
	main_a7ddrphy_rddata_en_tappeddelayline7 <= main_a7ddrphy_rddata_en_tappeddelayline6;
	main_a7ddrphy_wrdata_en_tappeddelayline0 <= (main_a7ddrphy_dfi_p0_wrdata_en | main_a7ddrphy_dfi_p1_wrdata_en);
	main_a7ddrphy_wrdata_en_tappeddelayline1 <= main_a7ddrphy_wrdata_en_tappeddelayline0;
	if (main_litedramcore_inti_p0_rddata_valid) begin
		main_litedramcore_phaseinjector0_rddata_status <= main_litedramcore_inti_p0_rddata;
	end
	if (main_litedramcore_inti_p1_rddata_valid) begin
		main_litedramcore_phaseinjector1_rddata_status <= main_litedramcore_inti_p1_rddata;
	end
	if ((main_litedramcore_timer_wait & (~main_litedramcore_timer_done0))) begin
		main_litedramcore_timer_count1 <= (main_litedramcore_timer_count1 - 1'd1);
	end else begin
		main_litedramcore_timer_count1 <= 10'd781;
	end
	main_litedramcore_postponer_req_o <= 1'd0;
	if (main_litedramcore_postponer_req_i) begin
		main_litedramcore_postponer_count <= (main_litedramcore_postponer_count - 1'd1);
		if ((main_litedramcore_postponer_count == 1'd0)) begin
			main_litedramcore_postponer_count <= 1'd0;
			main_litedramcore_postponer_req_o <= 1'd1;
		end
	end
	if (main_litedramcore_sequencer_start0) begin
		main_litedramcore_sequencer_count <= 1'd0;
	end else begin
		if (main_litedramcore_sequencer_done1) begin
			if ((main_litedramcore_sequencer_count != 1'd0)) begin
				main_litedramcore_sequencer_count <= (main_litedramcore_sequencer_count - 1'd1);
			end
		end
	end
	main_litedramcore_cmd_payload_a <= 1'd0;
	main_litedramcore_cmd_payload_ba <= 1'd0;
	main_litedramcore_cmd_payload_cas <= 1'd0;
	main_litedramcore_cmd_payload_ras <= 1'd0;
	main_litedramcore_cmd_payload_we <= 1'd0;
	main_litedramcore_sequencer_done1 <= 1'd0;
	if ((main_litedramcore_sequencer_start1 & (main_litedramcore_sequencer_counter == 1'd0))) begin
		main_litedramcore_cmd_payload_a <= 11'd1024;
		main_litedramcore_cmd_payload_ba <= 1'd0;
		main_litedramcore_cmd_payload_cas <= 1'd0;
		main_litedramcore_cmd_payload_ras <= 1'd1;
		main_litedramcore_cmd_payload_we <= 1'd1;
	end
	if ((main_litedramcore_sequencer_counter == 2'd2)) begin
		main_litedramcore_cmd_payload_a <= 1'd0;
		main_litedramcore_cmd_payload_ba <= 1'd0;
		main_litedramcore_cmd_payload_cas <= 1'd1;
		main_litedramcore_cmd_payload_ras <= 1'd1;
		main_litedramcore_cmd_payload_we <= 1'd0;
	end
	if ((main_litedramcore_sequencer_counter == 5'd16)) begin
		main_litedramcore_cmd_payload_a <= 1'd0;
		main_litedramcore_cmd_payload_ba <= 1'd0;
		main_litedramcore_cmd_payload_cas <= 1'd0;
		main_litedramcore_cmd_payload_ras <= 1'd0;
		main_litedramcore_cmd_payload_we <= 1'd0;
		main_litedramcore_sequencer_done1 <= 1'd1;
	end
	if ((main_litedramcore_sequencer_counter == 5'd16)) begin
		main_litedramcore_sequencer_counter <= 1'd0;
	end else begin
		if ((main_litedramcore_sequencer_counter != 1'd0)) begin
			main_litedramcore_sequencer_counter <= (main_litedramcore_sequencer_counter + 1'd1);
		end else begin
			if (main_litedramcore_sequencer_start1) begin
				main_litedramcore_sequencer_counter <= 1'd1;
			end
		end
	end
	builder_refresher_state <= builder_refresher_next_state;
	if (main_litedramcore_bankmachine0_row_close) begin
		main_litedramcore_bankmachine0_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine0_row_open) begin
			main_litedramcore_bankmachine0_row_opened <= 1'd1;
			main_litedramcore_bankmachine0_row <= main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_we & main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable) & (~main_litedramcore_bankmachine0_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine0_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine0_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_we & main_litedramcore_bankmachine0_cmd_buffer_lookahead_syncfifo0_writable) & (~main_litedramcore_bankmachine0_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine0_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine0_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine0_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine0_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine0_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine0_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine0_cmd_buffer_source_valid) | main_litedramcore_bankmachine0_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine0_cmd_buffer_source_valid <= main_litedramcore_bankmachine0_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine0_cmd_buffer_source_first <= main_litedramcore_bankmachine0_cmd_buffer_sink_first;
		main_litedramcore_bankmachine0_cmd_buffer_source_last <= main_litedramcore_bankmachine0_cmd_buffer_sink_last;
		main_litedramcore_bankmachine0_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine0_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine0_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine0_twtpcon_valid) begin
		main_litedramcore_bankmachine0_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine0_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine0_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine0_twtpcon_ready)) begin
			main_litedramcore_bankmachine0_twtpcon_count <= (main_litedramcore_bankmachine0_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine0_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine0_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine0_state <= builder_bankmachine0_next_state;
	if (main_litedramcore_bankmachine1_row_close) begin
		main_litedramcore_bankmachine1_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine1_row_open) begin
			main_litedramcore_bankmachine1_row_opened <= 1'd1;
			main_litedramcore_bankmachine1_row <= main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_we & main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable) & (~main_litedramcore_bankmachine1_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine1_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine1_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_we & main_litedramcore_bankmachine1_cmd_buffer_lookahead_syncfifo1_writable) & (~main_litedramcore_bankmachine1_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine1_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine1_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine1_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine1_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine1_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine1_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine1_cmd_buffer_source_valid) | main_litedramcore_bankmachine1_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine1_cmd_buffer_source_valid <= main_litedramcore_bankmachine1_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine1_cmd_buffer_source_first <= main_litedramcore_bankmachine1_cmd_buffer_sink_first;
		main_litedramcore_bankmachine1_cmd_buffer_source_last <= main_litedramcore_bankmachine1_cmd_buffer_sink_last;
		main_litedramcore_bankmachine1_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine1_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine1_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine1_twtpcon_valid) begin
		main_litedramcore_bankmachine1_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine1_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine1_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine1_twtpcon_ready)) begin
			main_litedramcore_bankmachine1_twtpcon_count <= (main_litedramcore_bankmachine1_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine1_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine1_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine1_state <= builder_bankmachine1_next_state;
	if (main_litedramcore_bankmachine2_row_close) begin
		main_litedramcore_bankmachine2_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine2_row_open) begin
			main_litedramcore_bankmachine2_row_opened <= 1'd1;
			main_litedramcore_bankmachine2_row <= main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_we & main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable) & (~main_litedramcore_bankmachine2_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine2_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine2_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_we & main_litedramcore_bankmachine2_cmd_buffer_lookahead_syncfifo2_writable) & (~main_litedramcore_bankmachine2_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine2_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine2_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine2_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine2_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine2_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine2_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine2_cmd_buffer_source_valid) | main_litedramcore_bankmachine2_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine2_cmd_buffer_source_valid <= main_litedramcore_bankmachine2_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine2_cmd_buffer_source_first <= main_litedramcore_bankmachine2_cmd_buffer_sink_first;
		main_litedramcore_bankmachine2_cmd_buffer_source_last <= main_litedramcore_bankmachine2_cmd_buffer_sink_last;
		main_litedramcore_bankmachine2_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine2_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine2_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine2_twtpcon_valid) begin
		main_litedramcore_bankmachine2_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine2_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine2_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine2_twtpcon_ready)) begin
			main_litedramcore_bankmachine2_twtpcon_count <= (main_litedramcore_bankmachine2_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine2_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine2_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine2_state <= builder_bankmachine2_next_state;
	if (main_litedramcore_bankmachine3_row_close) begin
		main_litedramcore_bankmachine3_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine3_row_open) begin
			main_litedramcore_bankmachine3_row_opened <= 1'd1;
			main_litedramcore_bankmachine3_row <= main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_we & main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable) & (~main_litedramcore_bankmachine3_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine3_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine3_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_we & main_litedramcore_bankmachine3_cmd_buffer_lookahead_syncfifo3_writable) & (~main_litedramcore_bankmachine3_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine3_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine3_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine3_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine3_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine3_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine3_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine3_cmd_buffer_source_valid) | main_litedramcore_bankmachine3_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine3_cmd_buffer_source_valid <= main_litedramcore_bankmachine3_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine3_cmd_buffer_source_first <= main_litedramcore_bankmachine3_cmd_buffer_sink_first;
		main_litedramcore_bankmachine3_cmd_buffer_source_last <= main_litedramcore_bankmachine3_cmd_buffer_sink_last;
		main_litedramcore_bankmachine3_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine3_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine3_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine3_twtpcon_valid) begin
		main_litedramcore_bankmachine3_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine3_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine3_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine3_twtpcon_ready)) begin
			main_litedramcore_bankmachine3_twtpcon_count <= (main_litedramcore_bankmachine3_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine3_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine3_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine3_state <= builder_bankmachine3_next_state;
	if (main_litedramcore_bankmachine4_row_close) begin
		main_litedramcore_bankmachine4_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine4_row_open) begin
			main_litedramcore_bankmachine4_row_opened <= 1'd1;
			main_litedramcore_bankmachine4_row <= main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_we & main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable) & (~main_litedramcore_bankmachine4_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine4_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine4_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_we & main_litedramcore_bankmachine4_cmd_buffer_lookahead_syncfifo4_writable) & (~main_litedramcore_bankmachine4_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine4_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine4_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine4_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine4_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine4_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine4_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine4_cmd_buffer_source_valid) | main_litedramcore_bankmachine4_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine4_cmd_buffer_source_valid <= main_litedramcore_bankmachine4_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine4_cmd_buffer_source_first <= main_litedramcore_bankmachine4_cmd_buffer_sink_first;
		main_litedramcore_bankmachine4_cmd_buffer_source_last <= main_litedramcore_bankmachine4_cmd_buffer_sink_last;
		main_litedramcore_bankmachine4_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine4_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine4_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine4_twtpcon_valid) begin
		main_litedramcore_bankmachine4_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine4_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine4_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine4_twtpcon_ready)) begin
			main_litedramcore_bankmachine4_twtpcon_count <= (main_litedramcore_bankmachine4_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine4_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine4_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine4_state <= builder_bankmachine4_next_state;
	if (main_litedramcore_bankmachine5_row_close) begin
		main_litedramcore_bankmachine5_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine5_row_open) begin
			main_litedramcore_bankmachine5_row_opened <= 1'd1;
			main_litedramcore_bankmachine5_row <= main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_we & main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable) & (~main_litedramcore_bankmachine5_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine5_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine5_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_we & main_litedramcore_bankmachine5_cmd_buffer_lookahead_syncfifo5_writable) & (~main_litedramcore_bankmachine5_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine5_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine5_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine5_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine5_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine5_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine5_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine5_cmd_buffer_source_valid) | main_litedramcore_bankmachine5_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine5_cmd_buffer_source_valid <= main_litedramcore_bankmachine5_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine5_cmd_buffer_source_first <= main_litedramcore_bankmachine5_cmd_buffer_sink_first;
		main_litedramcore_bankmachine5_cmd_buffer_source_last <= main_litedramcore_bankmachine5_cmd_buffer_sink_last;
		main_litedramcore_bankmachine5_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine5_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine5_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine5_twtpcon_valid) begin
		main_litedramcore_bankmachine5_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine5_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine5_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine5_twtpcon_ready)) begin
			main_litedramcore_bankmachine5_twtpcon_count <= (main_litedramcore_bankmachine5_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine5_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine5_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine5_state <= builder_bankmachine5_next_state;
	if (main_litedramcore_bankmachine6_row_close) begin
		main_litedramcore_bankmachine6_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine6_row_open) begin
			main_litedramcore_bankmachine6_row_opened <= 1'd1;
			main_litedramcore_bankmachine6_row <= main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_we & main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable) & (~main_litedramcore_bankmachine6_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine6_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine6_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_we & main_litedramcore_bankmachine6_cmd_buffer_lookahead_syncfifo6_writable) & (~main_litedramcore_bankmachine6_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine6_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine6_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine6_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine6_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine6_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine6_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine6_cmd_buffer_source_valid) | main_litedramcore_bankmachine6_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine6_cmd_buffer_source_valid <= main_litedramcore_bankmachine6_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine6_cmd_buffer_source_first <= main_litedramcore_bankmachine6_cmd_buffer_sink_first;
		main_litedramcore_bankmachine6_cmd_buffer_source_last <= main_litedramcore_bankmachine6_cmd_buffer_sink_last;
		main_litedramcore_bankmachine6_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine6_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine6_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine6_twtpcon_valid) begin
		main_litedramcore_bankmachine6_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine6_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine6_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine6_twtpcon_ready)) begin
			main_litedramcore_bankmachine6_twtpcon_count <= (main_litedramcore_bankmachine6_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine6_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine6_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine6_state <= builder_bankmachine6_next_state;
	if (main_litedramcore_bankmachine7_row_close) begin
		main_litedramcore_bankmachine7_row_opened <= 1'd0;
	end else begin
		if (main_litedramcore_bankmachine7_row_open) begin
			main_litedramcore_bankmachine7_row_opened <= 1'd1;
			main_litedramcore_bankmachine7_row <= main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr[20:8];
		end
	end
	if (((main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_we & main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable) & (~main_litedramcore_bankmachine7_cmd_buffer_lookahead_replace))) begin
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce <= (main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce + 1'd1);
	end
	if (main_litedramcore_bankmachine7_cmd_buffer_lookahead_do_read) begin
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_consume <= (main_litedramcore_bankmachine7_cmd_buffer_lookahead_consume + 1'd1);
	end
	if (((main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_we & main_litedramcore_bankmachine7_cmd_buffer_lookahead_syncfifo7_writable) & (~main_litedramcore_bankmachine7_cmd_buffer_lookahead_replace))) begin
		if ((~main_litedramcore_bankmachine7_cmd_buffer_lookahead_do_read)) begin
			main_litedramcore_bankmachine7_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine7_cmd_buffer_lookahead_level + 1'd1);
		end
	end else begin
		if (main_litedramcore_bankmachine7_cmd_buffer_lookahead_do_read) begin
			main_litedramcore_bankmachine7_cmd_buffer_lookahead_level <= (main_litedramcore_bankmachine7_cmd_buffer_lookahead_level - 1'd1);
		end
	end
	if (((~main_litedramcore_bankmachine7_cmd_buffer_source_valid) | main_litedramcore_bankmachine7_cmd_buffer_source_ready)) begin
		main_litedramcore_bankmachine7_cmd_buffer_source_valid <= main_litedramcore_bankmachine7_cmd_buffer_sink_valid;
		main_litedramcore_bankmachine7_cmd_buffer_source_first <= main_litedramcore_bankmachine7_cmd_buffer_sink_first;
		main_litedramcore_bankmachine7_cmd_buffer_source_last <= main_litedramcore_bankmachine7_cmd_buffer_sink_last;
		main_litedramcore_bankmachine7_cmd_buffer_source_payload_we <= main_litedramcore_bankmachine7_cmd_buffer_sink_payload_we;
		main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr <= main_litedramcore_bankmachine7_cmd_buffer_sink_payload_addr;
	end
	if (main_litedramcore_bankmachine7_twtpcon_valid) begin
		main_litedramcore_bankmachine7_twtpcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_bankmachine7_twtpcon_ready <= 1'd1;
		end else begin
			main_litedramcore_bankmachine7_twtpcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_bankmachine7_twtpcon_ready)) begin
			main_litedramcore_bankmachine7_twtpcon_count <= (main_litedramcore_bankmachine7_twtpcon_count - 1'd1);
			if ((main_litedramcore_bankmachine7_twtpcon_count == 1'd1)) begin
				main_litedramcore_bankmachine7_twtpcon_ready <= 1'd1;
			end
		end
	end
	builder_bankmachine7_state <= builder_bankmachine7_next_state;
	if ((~main_litedramcore_en0)) begin
		main_litedramcore_time0 <= 5'd31;
	end else begin
		if ((~main_litedramcore_max_time0)) begin
			main_litedramcore_time0 <= (main_litedramcore_time0 - 1'd1);
		end
	end
	if ((~main_litedramcore_en1)) begin
		main_litedramcore_time1 <= 4'd15;
	end else begin
		if ((~main_litedramcore_max_time1)) begin
			main_litedramcore_time1 <= (main_litedramcore_time1 - 1'd1);
		end
	end
	if (main_litedramcore_choose_cmd_ce) begin
		case (main_litedramcore_choose_cmd_grant)
			1'd0: begin
				if (main_litedramcore_choose_cmd_request[1]) begin
					main_litedramcore_choose_cmd_grant <= 1'd1;
				end else begin
					if (main_litedramcore_choose_cmd_request[2]) begin
						main_litedramcore_choose_cmd_grant <= 2'd2;
					end else begin
						if (main_litedramcore_choose_cmd_request[3]) begin
							main_litedramcore_choose_cmd_grant <= 2'd3;
						end else begin
							if (main_litedramcore_choose_cmd_request[4]) begin
								main_litedramcore_choose_cmd_grant <= 3'd4;
							end else begin
								if (main_litedramcore_choose_cmd_request[5]) begin
									main_litedramcore_choose_cmd_grant <= 3'd5;
								end else begin
									if (main_litedramcore_choose_cmd_request[6]) begin
										main_litedramcore_choose_cmd_grant <= 3'd6;
									end else begin
										if (main_litedramcore_choose_cmd_request[7]) begin
											main_litedramcore_choose_cmd_grant <= 3'd7;
										end
									end
								end
							end
						end
					end
				end
			end
			1'd1: begin
				if (main_litedramcore_choose_cmd_request[2]) begin
					main_litedramcore_choose_cmd_grant <= 2'd2;
				end else begin
					if (main_litedramcore_choose_cmd_request[3]) begin
						main_litedramcore_choose_cmd_grant <= 2'd3;
					end else begin
						if (main_litedramcore_choose_cmd_request[4]) begin
							main_litedramcore_choose_cmd_grant <= 3'd4;
						end else begin
							if (main_litedramcore_choose_cmd_request[5]) begin
								main_litedramcore_choose_cmd_grant <= 3'd5;
							end else begin
								if (main_litedramcore_choose_cmd_request[6]) begin
									main_litedramcore_choose_cmd_grant <= 3'd6;
								end else begin
									if (main_litedramcore_choose_cmd_request[7]) begin
										main_litedramcore_choose_cmd_grant <= 3'd7;
									end else begin
										if (main_litedramcore_choose_cmd_request[0]) begin
											main_litedramcore_choose_cmd_grant <= 1'd0;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd2: begin
				if (main_litedramcore_choose_cmd_request[3]) begin
					main_litedramcore_choose_cmd_grant <= 2'd3;
				end else begin
					if (main_litedramcore_choose_cmd_request[4]) begin
						main_litedramcore_choose_cmd_grant <= 3'd4;
					end else begin
						if (main_litedramcore_choose_cmd_request[5]) begin
							main_litedramcore_choose_cmd_grant <= 3'd5;
						end else begin
							if (main_litedramcore_choose_cmd_request[6]) begin
								main_litedramcore_choose_cmd_grant <= 3'd6;
							end else begin
								if (main_litedramcore_choose_cmd_request[7]) begin
									main_litedramcore_choose_cmd_grant <= 3'd7;
								end else begin
									if (main_litedramcore_choose_cmd_request[0]) begin
										main_litedramcore_choose_cmd_grant <= 1'd0;
									end else begin
										if (main_litedramcore_choose_cmd_request[1]) begin
											main_litedramcore_choose_cmd_grant <= 1'd1;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd3: begin
				if (main_litedramcore_choose_cmd_request[4]) begin
					main_litedramcore_choose_cmd_grant <= 3'd4;
				end else begin
					if (main_litedramcore_choose_cmd_request[5]) begin
						main_litedramcore_choose_cmd_grant <= 3'd5;
					end else begin
						if (main_litedramcore_choose_cmd_request[6]) begin
							main_litedramcore_choose_cmd_grant <= 3'd6;
						end else begin
							if (main_litedramcore_choose_cmd_request[7]) begin
								main_litedramcore_choose_cmd_grant <= 3'd7;
							end else begin
								if (main_litedramcore_choose_cmd_request[0]) begin
									main_litedramcore_choose_cmd_grant <= 1'd0;
								end else begin
									if (main_litedramcore_choose_cmd_request[1]) begin
										main_litedramcore_choose_cmd_grant <= 1'd1;
									end else begin
										if (main_litedramcore_choose_cmd_request[2]) begin
											main_litedramcore_choose_cmd_grant <= 2'd2;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd4: begin
				if (main_litedramcore_choose_cmd_request[5]) begin
					main_litedramcore_choose_cmd_grant <= 3'd5;
				end else begin
					if (main_litedramcore_choose_cmd_request[6]) begin
						main_litedramcore_choose_cmd_grant <= 3'd6;
					end else begin
						if (main_litedramcore_choose_cmd_request[7]) begin
							main_litedramcore_choose_cmd_grant <= 3'd7;
						end else begin
							if (main_litedramcore_choose_cmd_request[0]) begin
								main_litedramcore_choose_cmd_grant <= 1'd0;
							end else begin
								if (main_litedramcore_choose_cmd_request[1]) begin
									main_litedramcore_choose_cmd_grant <= 1'd1;
								end else begin
									if (main_litedramcore_choose_cmd_request[2]) begin
										main_litedramcore_choose_cmd_grant <= 2'd2;
									end else begin
										if (main_litedramcore_choose_cmd_request[3]) begin
											main_litedramcore_choose_cmd_grant <= 2'd3;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd5: begin
				if (main_litedramcore_choose_cmd_request[6]) begin
					main_litedramcore_choose_cmd_grant <= 3'd6;
				end else begin
					if (main_litedramcore_choose_cmd_request[7]) begin
						main_litedramcore_choose_cmd_grant <= 3'd7;
					end else begin
						if (main_litedramcore_choose_cmd_request[0]) begin
							main_litedramcore_choose_cmd_grant <= 1'd0;
						end else begin
							if (main_litedramcore_choose_cmd_request[1]) begin
								main_litedramcore_choose_cmd_grant <= 1'd1;
							end else begin
								if (main_litedramcore_choose_cmd_request[2]) begin
									main_litedramcore_choose_cmd_grant <= 2'd2;
								end else begin
									if (main_litedramcore_choose_cmd_request[3]) begin
										main_litedramcore_choose_cmd_grant <= 2'd3;
									end else begin
										if (main_litedramcore_choose_cmd_request[4]) begin
											main_litedramcore_choose_cmd_grant <= 3'd4;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd6: begin
				if (main_litedramcore_choose_cmd_request[7]) begin
					main_litedramcore_choose_cmd_grant <= 3'd7;
				end else begin
					if (main_litedramcore_choose_cmd_request[0]) begin
						main_litedramcore_choose_cmd_grant <= 1'd0;
					end else begin
						if (main_litedramcore_choose_cmd_request[1]) begin
							main_litedramcore_choose_cmd_grant <= 1'd1;
						end else begin
							if (main_litedramcore_choose_cmd_request[2]) begin
								main_litedramcore_choose_cmd_grant <= 2'd2;
							end else begin
								if (main_litedramcore_choose_cmd_request[3]) begin
									main_litedramcore_choose_cmd_grant <= 2'd3;
								end else begin
									if (main_litedramcore_choose_cmd_request[4]) begin
										main_litedramcore_choose_cmd_grant <= 3'd4;
									end else begin
										if (main_litedramcore_choose_cmd_request[5]) begin
											main_litedramcore_choose_cmd_grant <= 3'd5;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd7: begin
				if (main_litedramcore_choose_cmd_request[0]) begin
					main_litedramcore_choose_cmd_grant <= 1'd0;
				end else begin
					if (main_litedramcore_choose_cmd_request[1]) begin
						main_litedramcore_choose_cmd_grant <= 1'd1;
					end else begin
						if (main_litedramcore_choose_cmd_request[2]) begin
							main_litedramcore_choose_cmd_grant <= 2'd2;
						end else begin
							if (main_litedramcore_choose_cmd_request[3]) begin
								main_litedramcore_choose_cmd_grant <= 2'd3;
							end else begin
								if (main_litedramcore_choose_cmd_request[4]) begin
									main_litedramcore_choose_cmd_grant <= 3'd4;
								end else begin
									if (main_litedramcore_choose_cmd_request[5]) begin
										main_litedramcore_choose_cmd_grant <= 3'd5;
									end else begin
										if (main_litedramcore_choose_cmd_request[6]) begin
											main_litedramcore_choose_cmd_grant <= 3'd6;
										end
									end
								end
							end
						end
					end
				end
			end
		endcase
	end
	if (main_litedramcore_choose_req_ce) begin
		case (main_litedramcore_choose_req_grant)
			1'd0: begin
				if (main_litedramcore_choose_req_request[1]) begin
					main_litedramcore_choose_req_grant <= 1'd1;
				end else begin
					if (main_litedramcore_choose_req_request[2]) begin
						main_litedramcore_choose_req_grant <= 2'd2;
					end else begin
						if (main_litedramcore_choose_req_request[3]) begin
							main_litedramcore_choose_req_grant <= 2'd3;
						end else begin
							if (main_litedramcore_choose_req_request[4]) begin
								main_litedramcore_choose_req_grant <= 3'd4;
							end else begin
								if (main_litedramcore_choose_req_request[5]) begin
									main_litedramcore_choose_req_grant <= 3'd5;
								end else begin
									if (main_litedramcore_choose_req_request[6]) begin
										main_litedramcore_choose_req_grant <= 3'd6;
									end else begin
										if (main_litedramcore_choose_req_request[7]) begin
											main_litedramcore_choose_req_grant <= 3'd7;
										end
									end
								end
							end
						end
					end
				end
			end
			1'd1: begin
				if (main_litedramcore_choose_req_request[2]) begin
					main_litedramcore_choose_req_grant <= 2'd2;
				end else begin
					if (main_litedramcore_choose_req_request[3]) begin
						main_litedramcore_choose_req_grant <= 2'd3;
					end else begin
						if (main_litedramcore_choose_req_request[4]) begin
							main_litedramcore_choose_req_grant <= 3'd4;
						end else begin
							if (main_litedramcore_choose_req_request[5]) begin
								main_litedramcore_choose_req_grant <= 3'd5;
							end else begin
								if (main_litedramcore_choose_req_request[6]) begin
									main_litedramcore_choose_req_grant <= 3'd6;
								end else begin
									if (main_litedramcore_choose_req_request[7]) begin
										main_litedramcore_choose_req_grant <= 3'd7;
									end else begin
										if (main_litedramcore_choose_req_request[0]) begin
											main_litedramcore_choose_req_grant <= 1'd0;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd2: begin
				if (main_litedramcore_choose_req_request[3]) begin
					main_litedramcore_choose_req_grant <= 2'd3;
				end else begin
					if (main_litedramcore_choose_req_request[4]) begin
						main_litedramcore_choose_req_grant <= 3'd4;
					end else begin
						if (main_litedramcore_choose_req_request[5]) begin
							main_litedramcore_choose_req_grant <= 3'd5;
						end else begin
							if (main_litedramcore_choose_req_request[6]) begin
								main_litedramcore_choose_req_grant <= 3'd6;
							end else begin
								if (main_litedramcore_choose_req_request[7]) begin
									main_litedramcore_choose_req_grant <= 3'd7;
								end else begin
									if (main_litedramcore_choose_req_request[0]) begin
										main_litedramcore_choose_req_grant <= 1'd0;
									end else begin
										if (main_litedramcore_choose_req_request[1]) begin
											main_litedramcore_choose_req_grant <= 1'd1;
										end
									end
								end
							end
						end
					end
				end
			end
			2'd3: begin
				if (main_litedramcore_choose_req_request[4]) begin
					main_litedramcore_choose_req_grant <= 3'd4;
				end else begin
					if (main_litedramcore_choose_req_request[5]) begin
						main_litedramcore_choose_req_grant <= 3'd5;
					end else begin
						if (main_litedramcore_choose_req_request[6]) begin
							main_litedramcore_choose_req_grant <= 3'd6;
						end else begin
							if (main_litedramcore_choose_req_request[7]) begin
								main_litedramcore_choose_req_grant <= 3'd7;
							end else begin
								if (main_litedramcore_choose_req_request[0]) begin
									main_litedramcore_choose_req_grant <= 1'd0;
								end else begin
									if (main_litedramcore_choose_req_request[1]) begin
										main_litedramcore_choose_req_grant <= 1'd1;
									end else begin
										if (main_litedramcore_choose_req_request[2]) begin
											main_litedramcore_choose_req_grant <= 2'd2;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd4: begin
				if (main_litedramcore_choose_req_request[5]) begin
					main_litedramcore_choose_req_grant <= 3'd5;
				end else begin
					if (main_litedramcore_choose_req_request[6]) begin
						main_litedramcore_choose_req_grant <= 3'd6;
					end else begin
						if (main_litedramcore_choose_req_request[7]) begin
							main_litedramcore_choose_req_grant <= 3'd7;
						end else begin
							if (main_litedramcore_choose_req_request[0]) begin
								main_litedramcore_choose_req_grant <= 1'd0;
							end else begin
								if (main_litedramcore_choose_req_request[1]) begin
									main_litedramcore_choose_req_grant <= 1'd1;
								end else begin
									if (main_litedramcore_choose_req_request[2]) begin
										main_litedramcore_choose_req_grant <= 2'd2;
									end else begin
										if (main_litedramcore_choose_req_request[3]) begin
											main_litedramcore_choose_req_grant <= 2'd3;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd5: begin
				if (main_litedramcore_choose_req_request[6]) begin
					main_litedramcore_choose_req_grant <= 3'd6;
				end else begin
					if (main_litedramcore_choose_req_request[7]) begin
						main_litedramcore_choose_req_grant <= 3'd7;
					end else begin
						if (main_litedramcore_choose_req_request[0]) begin
							main_litedramcore_choose_req_grant <= 1'd0;
						end else begin
							if (main_litedramcore_choose_req_request[1]) begin
								main_litedramcore_choose_req_grant <= 1'd1;
							end else begin
								if (main_litedramcore_choose_req_request[2]) begin
									main_litedramcore_choose_req_grant <= 2'd2;
								end else begin
									if (main_litedramcore_choose_req_request[3]) begin
										main_litedramcore_choose_req_grant <= 2'd3;
									end else begin
										if (main_litedramcore_choose_req_request[4]) begin
											main_litedramcore_choose_req_grant <= 3'd4;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd6: begin
				if (main_litedramcore_choose_req_request[7]) begin
					main_litedramcore_choose_req_grant <= 3'd7;
				end else begin
					if (main_litedramcore_choose_req_request[0]) begin
						main_litedramcore_choose_req_grant <= 1'd0;
					end else begin
						if (main_litedramcore_choose_req_request[1]) begin
							main_litedramcore_choose_req_grant <= 1'd1;
						end else begin
							if (main_litedramcore_choose_req_request[2]) begin
								main_litedramcore_choose_req_grant <= 2'd2;
							end else begin
								if (main_litedramcore_choose_req_request[3]) begin
									main_litedramcore_choose_req_grant <= 2'd3;
								end else begin
									if (main_litedramcore_choose_req_request[4]) begin
										main_litedramcore_choose_req_grant <= 3'd4;
									end else begin
										if (main_litedramcore_choose_req_request[5]) begin
											main_litedramcore_choose_req_grant <= 3'd5;
										end
									end
								end
							end
						end
					end
				end
			end
			3'd7: begin
				if (main_litedramcore_choose_req_request[0]) begin
					main_litedramcore_choose_req_grant <= 1'd0;
				end else begin
					if (main_litedramcore_choose_req_request[1]) begin
						main_litedramcore_choose_req_grant <= 1'd1;
					end else begin
						if (main_litedramcore_choose_req_request[2]) begin
							main_litedramcore_choose_req_grant <= 2'd2;
						end else begin
							if (main_litedramcore_choose_req_request[3]) begin
								main_litedramcore_choose_req_grant <= 2'd3;
							end else begin
								if (main_litedramcore_choose_req_request[4]) begin
									main_litedramcore_choose_req_grant <= 3'd4;
								end else begin
									if (main_litedramcore_choose_req_request[5]) begin
										main_litedramcore_choose_req_grant <= 3'd5;
									end else begin
										if (main_litedramcore_choose_req_request[6]) begin
											main_litedramcore_choose_req_grant <= 3'd6;
										end
									end
								end
							end
						end
					end
				end
			end
		endcase
	end
	main_litedramcore_dfi_p0_cs_n <= 1'd0;
	main_litedramcore_dfi_p0_bank <= builder_array_muxed0;
	main_litedramcore_dfi_p0_address <= builder_array_muxed1;
	main_litedramcore_dfi_p0_cas_n <= (~builder_array_muxed2);
	main_litedramcore_dfi_p0_ras_n <= (~builder_array_muxed3);
	main_litedramcore_dfi_p0_we_n <= (~builder_array_muxed4);
	main_litedramcore_dfi_p0_rddata_en <= builder_array_muxed5;
	main_litedramcore_dfi_p0_wrdata_en <= builder_array_muxed6;
	main_litedramcore_dfi_p1_cs_n <= 1'd0;
	main_litedramcore_dfi_p1_bank <= builder_array_muxed7;
	main_litedramcore_dfi_p1_address <= builder_array_muxed8;
	main_litedramcore_dfi_p1_cas_n <= (~builder_array_muxed9);
	main_litedramcore_dfi_p1_ras_n <= (~builder_array_muxed10);
	main_litedramcore_dfi_p1_we_n <= (~builder_array_muxed11);
	main_litedramcore_dfi_p1_rddata_en <= builder_array_muxed12;
	main_litedramcore_dfi_p1_wrdata_en <= builder_array_muxed13;
	if (main_litedramcore_tccdcon_valid) begin
		main_litedramcore_tccdcon_count <= 1'd0;
		if (1'd1) begin
			main_litedramcore_tccdcon_ready <= 1'd1;
		end else begin
			main_litedramcore_tccdcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_tccdcon_ready)) begin
			main_litedramcore_tccdcon_count <= (main_litedramcore_tccdcon_count - 1'd1);
			if ((main_litedramcore_tccdcon_count == 1'd1)) begin
				main_litedramcore_tccdcon_ready <= 1'd1;
			end
		end
	end
	if (main_litedramcore_twtrcon_valid) begin
		main_litedramcore_twtrcon_count <= 2'd3;
		if (1'd0) begin
			main_litedramcore_twtrcon_ready <= 1'd1;
		end else begin
			main_litedramcore_twtrcon_ready <= 1'd0;
		end
	end else begin
		if ((~main_litedramcore_twtrcon_ready)) begin
			main_litedramcore_twtrcon_count <= (main_litedramcore_twtrcon_count - 1'd1);
			if ((main_litedramcore_twtrcon_count == 1'd1)) begin
				main_litedramcore_twtrcon_ready <= 1'd1;
			end
		end
	end
	builder_multiplexer_state <= builder_multiplexer_next_state;
	builder_new_master_wdata_ready <= ((((((((1'd0 | ((builder_roundrobin0_grant == 1'd0) & main_litedramcore_interface_bank0_wdata_ready)) | ((builder_roundrobin1_grant == 1'd0) & main_litedramcore_interface_bank1_wdata_ready)) | ((builder_roundrobin2_grant == 1'd0) & main_litedramcore_interface_bank2_wdata_ready)) | ((builder_roundrobin3_grant == 1'd0) & main_litedramcore_interface_bank3_wdata_ready)) | ((builder_roundrobin4_grant == 1'd0) & main_litedramcore_interface_bank4_wdata_ready)) | ((builder_roundrobin5_grant == 1'd0) & main_litedramcore_interface_bank5_wdata_ready)) | ((builder_roundrobin6_grant == 1'd0) & main_litedramcore_interface_bank6_wdata_ready)) | ((builder_roundrobin7_grant == 1'd0) & main_litedramcore_interface_bank7_wdata_ready));
	builder_new_master_rdata_valid0 <= ((((((((1'd0 | ((builder_roundrobin0_grant == 1'd0) & main_litedramcore_interface_bank0_rdata_valid)) | ((builder_roundrobin1_grant == 1'd0) & main_litedramcore_interface_bank1_rdata_valid)) | ((builder_roundrobin2_grant == 1'd0) & main_litedramcore_interface_bank2_rdata_valid)) | ((builder_roundrobin3_grant == 1'd0) & main_litedramcore_interface_bank3_rdata_valid)) | ((builder_roundrobin4_grant == 1'd0) & main_litedramcore_interface_bank4_rdata_valid)) | ((builder_roundrobin5_grant == 1'd0) & main_litedramcore_interface_bank5_rdata_valid)) | ((builder_roundrobin6_grant == 1'd0) & main_litedramcore_interface_bank6_rdata_valid)) | ((builder_roundrobin7_grant == 1'd0) & main_litedramcore_interface_bank7_rdata_valid));
	builder_new_master_rdata_valid1 <= builder_new_master_rdata_valid0;
	builder_new_master_rdata_valid2 <= builder_new_master_rdata_valid1;
	builder_new_master_rdata_valid3 <= builder_new_master_rdata_valid2;
	builder_new_master_rdata_valid4 <= builder_new_master_rdata_valid3;
	builder_new_master_rdata_valid5 <= builder_new_master_rdata_valid4;
	builder_new_master_rdata_valid6 <= builder_new_master_rdata_valid5;
	builder_new_master_rdata_valid7 <= builder_new_master_rdata_valid6;
	builder_new_master_rdata_valid8 <= builder_new_master_rdata_valid7;
	if (main_wb_port_ack) begin
		main_cmd_consumed <= 1'd0;
		main_wdata_consumed <= 1'd0;
	end else begin
		if ((main_user_port_cmd_valid & main_user_port_cmd_ready)) begin
			main_cmd_consumed <= 1'd1;
		end
		if ((main_user_port_wdata_valid & main_user_port_wdata_ready)) begin
			main_wdata_consumed <= 1'd1;
		end
	end
	builder_state <= builder_next_state;
	if (builder_litedramcore_dat_w_next_value_ce0) begin
		builder_litedramcore_dat_w <= builder_litedramcore_dat_w_next_value0;
	end
	if (builder_litedramcore_adr_next_value_ce1) begin
		builder_litedramcore_adr <= builder_litedramcore_adr_next_value1;
	end
	if (builder_litedramcore_we_next_value_ce2) begin
		builder_litedramcore_we <= builder_litedramcore_we_next_value2;
	end
	builder_interface0_bank_bus_dat_r <= 1'd0;
	if (builder_csrbank0_sel) begin
		case (builder_interface0_bank_bus_adr[8:0])
			1'd0: begin
				builder_interface0_bank_bus_dat_r <= builder_csrbank0_init_done0_w;
			end
			1'd1: begin
				builder_interface0_bank_bus_dat_r <= builder_csrbank0_init_error0_w;
			end
		endcase
	end
	if (builder_csrbank0_init_done0_re) begin
		main_init_done_storage <= builder_csrbank0_init_done0_r;
	end
	main_init_done_re <= builder_csrbank0_init_done0_re;
	if (builder_csrbank0_init_error0_re) begin
		main_init_error_storage <= builder_csrbank0_init_error0_r;
	end
	main_init_error_re <= builder_csrbank0_init_error0_re;
	builder_interface1_bank_bus_dat_r <= 1'd0;
	if (builder_csrbank1_sel) begin
		case (builder_interface1_bank_bus_adr[8:0])
			1'd0: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_rst0_w;
			end
			1'd1: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_half_sys8x_taps0_w;
			end
			2'd2: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_wlevel_en0_w;
			end
			2'd3: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_wlevel_strobe_w;
			end
			3'd4: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_dly_sel0_w;
			end
			3'd5: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_rdly_dq_rst_w;
			end
			3'd6: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_rdly_dq_inc_w;
			end
			3'd7: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_rdly_dq_bitslip_rst_w;
			end
			4'd8: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_rdly_dq_bitslip_w;
			end
			4'd9: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_wdly_dq_bitslip_rst_w;
			end
			4'd10: begin
				builder_interface1_bank_bus_dat_r <= main_a7ddrphy_wdly_dq_bitslip_w;
			end
			4'd11: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_rdphase0_w;
			end
			4'd12: begin
				builder_interface1_bank_bus_dat_r <= builder_csrbank1_wrphase0_w;
			end
		endcase
	end
	if (builder_csrbank1_rst0_re) begin
		main_a7ddrphy_rst_storage <= builder_csrbank1_rst0_r;
	end
	main_a7ddrphy_rst_re <= builder_csrbank1_rst0_re;
	if (builder_csrbank1_half_sys8x_taps0_re) begin
		main_a7ddrphy_half_sys8x_taps_storage[4:0] <= builder_csrbank1_half_sys8x_taps0_r;
	end
	main_a7ddrphy_half_sys8x_taps_re <= builder_csrbank1_half_sys8x_taps0_re;
	if (builder_csrbank1_wlevel_en0_re) begin
		main_a7ddrphy_wlevel_en_storage <= builder_csrbank1_wlevel_en0_r;
	end
	main_a7ddrphy_wlevel_en_re <= builder_csrbank1_wlevel_en0_re;
	if (builder_csrbank1_dly_sel0_re) begin
		main_a7ddrphy_dly_sel_storage[1:0] <= builder_csrbank1_dly_sel0_r;
	end
	main_a7ddrphy_dly_sel_re <= builder_csrbank1_dly_sel0_re;
	if (builder_csrbank1_rdphase0_re) begin
		main_a7ddrphy_rdphase_storage <= builder_csrbank1_rdphase0_r;
	end
	main_a7ddrphy_rdphase_re <= builder_csrbank1_rdphase0_re;
	if (builder_csrbank1_wrphase0_re) begin
		main_a7ddrphy_wrphase_storage <= builder_csrbank1_wrphase0_r;
	end
	main_a7ddrphy_wrphase_re <= builder_csrbank1_wrphase0_re;
	builder_interface2_bank_bus_dat_r <= 1'd0;
	if (builder_csrbank2_sel) begin
		case (builder_interface2_bank_bus_adr[8:0])
			1'd0: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_control0_w;
			end
			1'd1: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_command0_w;
			end
			2'd2: begin
				builder_interface2_bank_bus_dat_r <= main_litedramcore_phaseinjector0_command_issue_w;
			end
			2'd3: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_address1_w;
			end
			3'd4: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_address0_w;
			end
			3'd5: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_baddress0_w;
			end
			3'd6: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_wrdata3_w;
			end
			3'd7: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_wrdata2_w;
			end
			4'd8: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_wrdata1_w;
			end
			4'd9: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_wrdata0_w;
			end
			4'd10: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_rddata3_w;
			end
			4'd11: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_rddata2_w;
			end
			4'd12: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_rddata1_w;
			end
			4'd13: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi0_rddata0_w;
			end
			4'd14: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_command0_w;
			end
			4'd15: begin
				builder_interface2_bank_bus_dat_r <= main_litedramcore_phaseinjector1_command_issue_w;
			end
			5'd16: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_address1_w;
			end
			5'd17: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_address0_w;
			end
			5'd18: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_baddress0_w;
			end
			5'd19: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_wrdata3_w;
			end
			5'd20: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_wrdata2_w;
			end
			5'd21: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_wrdata1_w;
			end
			5'd22: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_wrdata0_w;
			end
			5'd23: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_rddata3_w;
			end
			5'd24: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_rddata2_w;
			end
			5'd25: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_rddata1_w;
			end
			5'd26: begin
				builder_interface2_bank_bus_dat_r <= builder_csrbank2_dfii_pi1_rddata0_w;
			end
		endcase
	end
	if (builder_csrbank2_dfii_control0_re) begin
		main_litedramcore_storage[3:0] <= builder_csrbank2_dfii_control0_r;
	end
	main_litedramcore_re <= builder_csrbank2_dfii_control0_re;
	if (builder_csrbank2_dfii_pi0_command0_re) begin
		main_litedramcore_phaseinjector0_command_storage[5:0] <= builder_csrbank2_dfii_pi0_command0_r;
	end
	main_litedramcore_phaseinjector0_command_re <= builder_csrbank2_dfii_pi0_command0_re;
	if (builder_csrbank2_dfii_pi0_address1_re) begin
		main_litedramcore_phaseinjector0_address_storage[12:8] <= builder_csrbank2_dfii_pi0_address1_r;
	end
	if (builder_csrbank2_dfii_pi0_address0_re) begin
		main_litedramcore_phaseinjector0_address_storage[7:0] <= builder_csrbank2_dfii_pi0_address0_r;
	end
	main_litedramcore_phaseinjector0_address_re <= builder_csrbank2_dfii_pi0_address0_re;
	if (builder_csrbank2_dfii_pi0_baddress0_re) begin
		main_litedramcore_phaseinjector0_baddress_storage[2:0] <= builder_csrbank2_dfii_pi0_baddress0_r;
	end
	main_litedramcore_phaseinjector0_baddress_re <= builder_csrbank2_dfii_pi0_baddress0_re;
	if (builder_csrbank2_dfii_pi0_wrdata3_re) begin
		main_litedramcore_phaseinjector0_wrdata_storage[31:24] <= builder_csrbank2_dfii_pi0_wrdata3_r;
	end
	if (builder_csrbank2_dfii_pi0_wrdata2_re) begin
		main_litedramcore_phaseinjector0_wrdata_storage[23:16] <= builder_csrbank2_dfii_pi0_wrdata2_r;
	end
	if (builder_csrbank2_dfii_pi0_wrdata1_re) begin
		main_litedramcore_phaseinjector0_wrdata_storage[15:8] <= builder_csrbank2_dfii_pi0_wrdata1_r;
	end
	if (builder_csrbank2_dfii_pi0_wrdata0_re) begin
		main_litedramcore_phaseinjector0_wrdata_storage[7:0] <= builder_csrbank2_dfii_pi0_wrdata0_r;
	end
	main_litedramcore_phaseinjector0_wrdata_re <= builder_csrbank2_dfii_pi0_wrdata0_re;
	main_litedramcore_phaseinjector0_rddata_re <= builder_csrbank2_dfii_pi0_rddata0_re;
	if (builder_csrbank2_dfii_pi1_command0_re) begin
		main_litedramcore_phaseinjector1_command_storage[5:0] <= builder_csrbank2_dfii_pi1_command0_r;
	end
	main_litedramcore_phaseinjector1_command_re <= builder_csrbank2_dfii_pi1_command0_re;
	if (builder_csrbank2_dfii_pi1_address1_re) begin
		main_litedramcore_phaseinjector1_address_storage[12:8] <= builder_csrbank2_dfii_pi1_address1_r;
	end
	if (builder_csrbank2_dfii_pi1_address0_re) begin
		main_litedramcore_phaseinjector1_address_storage[7:0] <= builder_csrbank2_dfii_pi1_address0_r;
	end
	main_litedramcore_phaseinjector1_address_re <= builder_csrbank2_dfii_pi1_address0_re;
	if (builder_csrbank2_dfii_pi1_baddress0_re) begin
		main_litedramcore_phaseinjector1_baddress_storage[2:0] <= builder_csrbank2_dfii_pi1_baddress0_r;
	end
	main_litedramcore_phaseinjector1_baddress_re <= builder_csrbank2_dfii_pi1_baddress0_re;
	if (builder_csrbank2_dfii_pi1_wrdata3_re) begin
		main_litedramcore_phaseinjector1_wrdata_storage[31:24] <= builder_csrbank2_dfii_pi1_wrdata3_r;
	end
	if (builder_csrbank2_dfii_pi1_wrdata2_re) begin
		main_litedramcore_phaseinjector1_wrdata_storage[23:16] <= builder_csrbank2_dfii_pi1_wrdata2_r;
	end
	if (builder_csrbank2_dfii_pi1_wrdata1_re) begin
		main_litedramcore_phaseinjector1_wrdata_storage[15:8] <= builder_csrbank2_dfii_pi1_wrdata1_r;
	end
	if (builder_csrbank2_dfii_pi1_wrdata0_re) begin
		main_litedramcore_phaseinjector1_wrdata_storage[7:0] <= builder_csrbank2_dfii_pi1_wrdata0_r;
	end
	main_litedramcore_phaseinjector1_wrdata_re <= builder_csrbank2_dfii_pi1_wrdata0_re;
	main_litedramcore_phaseinjector1_rddata_re <= builder_csrbank2_dfii_pi1_rddata0_re;
	if (sys_rst) begin
		main_a7ddrphy_rst_storage <= 1'd0;
		main_a7ddrphy_rst_re <= 1'd0;
		main_a7ddrphy_half_sys8x_taps_storage <= 5'd16;
		main_a7ddrphy_half_sys8x_taps_re <= 1'd0;
		main_a7ddrphy_wlevel_en_storage <= 1'd0;
		main_a7ddrphy_wlevel_en_re <= 1'd0;
		main_a7ddrphy_dly_sel_storage <= 2'd0;
		main_a7ddrphy_dly_sel_re <= 1'd0;
		main_a7ddrphy_rdphase_storage <= 1'd1;
		main_a7ddrphy_rdphase_re <= 1'd0;
		main_a7ddrphy_wrphase_storage <= 1'd0;
		main_a7ddrphy_wrphase_re <= 1'd0;
		main_a7ddrphy_dqs_oe_delay_tappeddelayline_tappeddelayline <= 1'd0;
		main_a7ddrphy_dqspattern_o1 <= 8'd0;
		main_a7ddrphy_bitslip0_value0 <= 3'd7;
		main_a7ddrphy_bitslip1_value0 <= 3'd7;
		main_a7ddrphy_bitslip0_value1 <= 3'd7;
		main_a7ddrphy_bitslip1_value1 <= 3'd7;
		main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline <= 1'd0;
		main_a7ddrphy_bitslip0_value2 <= 3'd7;
		main_a7ddrphy_bitslip0_value3 <= 3'd7;
		main_a7ddrphy_bitslip1_value2 <= 3'd7;
		main_a7ddrphy_bitslip1_value3 <= 3'd7;
		main_a7ddrphy_bitslip2_value0 <= 3'd7;
		main_a7ddrphy_bitslip2_value1 <= 3'd7;
		main_a7ddrphy_bitslip3_value0 <= 3'd7;
		main_a7ddrphy_bitslip3_value1 <= 3'd7;
		main_a7ddrphy_bitslip4_value0 <= 3'd7;
		main_a7ddrphy_bitslip4_value1 <= 3'd7;
		main_a7ddrphy_bitslip5_value0 <= 3'd7;
		main_a7ddrphy_bitslip5_value1 <= 3'd7;
		main_a7ddrphy_bitslip6_value0 <= 3'd7;
		main_a7ddrphy_bitslip6_value1 <= 3'd7;
		main_a7ddrphy_bitslip7_value0 <= 3'd7;
		main_a7ddrphy_bitslip7_value1 <= 3'd7;
		main_a7ddrphy_bitslip8_value0 <= 3'd7;
		main_a7ddrphy_bitslip8_value1 <= 3'd7;
		main_a7ddrphy_bitslip9_value0 <= 3'd7;
		main_a7ddrphy_bitslip9_value1 <= 3'd7;
		main_a7ddrphy_bitslip10_value0 <= 3'd7;
		main_a7ddrphy_bitslip10_value1 <= 3'd7;
		main_a7ddrphy_bitslip11_value0 <= 3'd7;
		main_a7ddrphy_bitslip11_value1 <= 3'd7;
		main_a7ddrphy_bitslip12_value0 <= 3'd7;
		main_a7ddrphy_bitslip12_value1 <= 3'd7;
		main_a7ddrphy_bitslip13_value0 <= 3'd7;
		main_a7ddrphy_bitslip13_value1 <= 3'd7;
		main_a7ddrphy_bitslip14_value0 <= 3'd7;
		main_a7ddrphy_bitslip14_value1 <= 3'd7;
		main_a7ddrphy_bitslip15_value0 <= 3'd7;
		main_a7ddrphy_bitslip15_value1 <= 3'd7;
		main_a7ddrphy_rddata_en_tappeddelayline0 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline1 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline2 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline3 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline4 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline5 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline6 <= 1'd0;
		main_a7ddrphy_rddata_en_tappeddelayline7 <= 1'd0;
		main_a7ddrphy_wrdata_en_tappeddelayline0 <= 1'd0;
		main_a7ddrphy_wrdata_en_tappeddelayline1 <= 1'd0;
		main_litedramcore_storage <= 4'd1;
		main_litedramcore_re <= 1'd0;
		main_litedramcore_phaseinjector0_command_storage <= 6'd0;
		main_litedramcore_phaseinjector0_command_re <= 1'd0;
		main_litedramcore_phaseinjector0_address_re <= 1'd0;
		main_litedramcore_phaseinjector0_baddress_re <= 1'd0;
		main_litedramcore_phaseinjector0_wrdata_re <= 1'd0;
		main_litedramcore_phaseinjector0_rddata_status <= 32'd0;
		main_litedramcore_phaseinjector0_rddata_re <= 1'd0;
		main_litedramcore_phaseinjector1_command_storage <= 6'd0;
		main_litedramcore_phaseinjector1_command_re <= 1'd0;
		main_litedramcore_phaseinjector1_address_re <= 1'd0;
		main_litedramcore_phaseinjector1_baddress_re <= 1'd0;
		main_litedramcore_phaseinjector1_wrdata_re <= 1'd0;
		main_litedramcore_phaseinjector1_rddata_status <= 32'd0;
		main_litedramcore_phaseinjector1_rddata_re <= 1'd0;
		main_litedramcore_dfi_p0_address <= 13'd0;
		main_litedramcore_dfi_p0_bank <= 3'd0;
		main_litedramcore_dfi_p0_cas_n <= 1'd1;
		main_litedramcore_dfi_p0_cs_n <= 1'd1;
		main_litedramcore_dfi_p0_ras_n <= 1'd1;
		main_litedramcore_dfi_p0_we_n <= 1'd1;
		main_litedramcore_dfi_p0_wrdata_en <= 1'd0;
		main_litedramcore_dfi_p0_rddata_en <= 1'd0;
		main_litedramcore_dfi_p1_address <= 13'd0;
		main_litedramcore_dfi_p1_bank <= 3'd0;
		main_litedramcore_dfi_p1_cas_n <= 1'd1;
		main_litedramcore_dfi_p1_cs_n <= 1'd1;
		main_litedramcore_dfi_p1_ras_n <= 1'd1;
		main_litedramcore_dfi_p1_we_n <= 1'd1;
		main_litedramcore_dfi_p1_wrdata_en <= 1'd0;
		main_litedramcore_dfi_p1_rddata_en <= 1'd0;
		main_litedramcore_cmd_payload_a <= 13'd0;
		main_litedramcore_cmd_payload_ba <= 3'd0;
		main_litedramcore_cmd_payload_cas <= 1'd0;
		main_litedramcore_cmd_payload_ras <= 1'd0;
		main_litedramcore_cmd_payload_we <= 1'd0;
		main_litedramcore_timer_count1 <= 10'd781;
		main_litedramcore_postponer_req_o <= 1'd0;
		main_litedramcore_postponer_count <= 1'd0;
		main_litedramcore_sequencer_done1 <= 1'd0;
		main_litedramcore_sequencer_counter <= 5'd0;
		main_litedramcore_sequencer_count <= 1'd0;
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine0_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine0_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine0_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine0_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine0_row <= 13'd0;
		main_litedramcore_bankmachine0_row_opened <= 1'd0;
		main_litedramcore_bankmachine0_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine0_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine1_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine1_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine1_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine1_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine1_row <= 13'd0;
		main_litedramcore_bankmachine1_row_opened <= 1'd0;
		main_litedramcore_bankmachine1_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine1_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine2_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine2_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine2_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine2_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine2_row <= 13'd0;
		main_litedramcore_bankmachine2_row_opened <= 1'd0;
		main_litedramcore_bankmachine2_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine2_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine3_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine3_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine3_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine3_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine3_row <= 13'd0;
		main_litedramcore_bankmachine3_row_opened <= 1'd0;
		main_litedramcore_bankmachine3_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine3_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine4_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine4_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine4_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine4_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine4_row <= 13'd0;
		main_litedramcore_bankmachine4_row_opened <= 1'd0;
		main_litedramcore_bankmachine4_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine4_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine5_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine5_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine5_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine5_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine5_row <= 13'd0;
		main_litedramcore_bankmachine5_row_opened <= 1'd0;
		main_litedramcore_bankmachine5_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine5_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine6_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine6_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine6_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine6_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine6_row <= 13'd0;
		main_litedramcore_bankmachine6_row_opened <= 1'd0;
		main_litedramcore_bankmachine6_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine6_twtpcon_count <= 2'd0;
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_level <= 5'd0;
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_produce <= 4'd0;
		main_litedramcore_bankmachine7_cmd_buffer_lookahead_consume <= 4'd0;
		main_litedramcore_bankmachine7_cmd_buffer_source_valid <= 1'd0;
		main_litedramcore_bankmachine7_cmd_buffer_source_payload_we <= 1'd0;
		main_litedramcore_bankmachine7_cmd_buffer_source_payload_addr <= 21'd0;
		main_litedramcore_bankmachine7_row <= 13'd0;
		main_litedramcore_bankmachine7_row_opened <= 1'd0;
		main_litedramcore_bankmachine7_twtpcon_ready <= 1'd0;
		main_litedramcore_bankmachine7_twtpcon_count <= 2'd0;
		main_litedramcore_choose_cmd_grant <= 3'd0;
		main_litedramcore_choose_req_grant <= 3'd0;
		main_litedramcore_tccdcon_ready <= 1'd0;
		main_litedramcore_tccdcon_count <= 1'd0;
		main_litedramcore_twtrcon_ready <= 1'd0;
		main_litedramcore_twtrcon_count <= 2'd0;
		main_litedramcore_time0 <= 5'd0;
		main_litedramcore_time1 <= 4'd0;
		main_init_done_storage <= 1'd0;
		main_init_done_re <= 1'd0;
		main_init_error_storage <= 1'd0;
		main_init_error_re <= 1'd0;
		main_cmd_consumed <= 1'd0;
		main_wdata_consumed <= 1'd0;
		builder_refresher_state <= 2'd0;
		builder_bankmachine0_state <= 3'd0;
		builder_bankmachine1_state <= 3'd0;
		builder_bankmachine2_state <= 3'd0;
		builder_bankmachine3_state <= 3'd0;
		builder_bankmachine4_state <= 3'd0;
		builder_bankmachine5_state <= 3'd0;
		builder_bankmachine6_state <= 3'd0;
		builder_bankmachine7_state <= 3'd0;
		builder_multiplexer_state <= 4'd0;
		builder_new_master_wdata_ready <= 1'd0;
		builder_new_master_rdata_valid0 <= 1'd0;
		builder_new_master_rdata_valid1 <= 1'd0;
		builder_new_master_rdata_valid2 <= 1'd0;
		builder_new_master_rdata_valid3 <= 1'd0;
		builder_new_master_rdata_valid4 <= 1'd0;
		builder_new_master_rdata_valid5 <= 1'd0;
		builder_new_master_rdata_valid6 <= 1'd0;
		builder_new_master_rdata_valid7 <= 1'd0;
		builder_new_master_rdata_valid8 <= 1'd0;
		builder_litedramcore_we <= 1'd0;
		builder_state <= 2'd0;
	end
end

BUFG BUFG(
	.I(main_clkout0),
	.O(main_clkout_buf0)
);

BUFG BUFG_1(
	.I(main_clkout1),
	.O(main_clkout_buf1)
);

BUFG BUFG_2(
	.I(main_clkout2),
	.O(main_clkout_buf2)
);

BUFG BUFG_3(
	.I(main_clkout3),
	.O(main_clkout_buf3)
);

IDELAYCTRL IDELAYCTRL(
	.REFCLK(iodelay_clk),
	.RST(main_ic_reset)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(1'd0),
	.D2(1'd1),
	.D3(1'd0),
	.D4(1'd1),
	.D5(1'd0),
	.D6(1'd1),
	.D7(1'd0),
	.D8(1'd1),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(main_a7ddrphy_sd_clk_se_nodelay)
);

OBUFDS OBUFDS(
	.I(main_a7ddrphy_sd_clk_se_nodelay),
	.O(ddram_clk_p),
	.OB(ddram_clk_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_1 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_reset_n),
	.D2(main_a7ddrphy_dfi_p0_reset_n),
	.D3(main_a7ddrphy_dfi_p1_reset_n),
	.D4(main_a7ddrphy_dfi_p1_reset_n),
	.D5(main_a7ddrphy_dfi_p2_reset_n),
	.D6(main_a7ddrphy_dfi_p2_reset_n),
	.D7(main_a7ddrphy_dfi_p3_reset_n),
	.D8(main_a7ddrphy_dfi_p3_reset_n),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_reset_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_2 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_cs_n),
	.D2(main_a7ddrphy_dfi_p0_cs_n),
	.D3(main_a7ddrphy_dfi_p1_cs_n),
	.D4(main_a7ddrphy_dfi_p1_cs_n),
	.D5(main_a7ddrphy_dfi_p2_cs_n),
	.D6(main_a7ddrphy_dfi_p2_cs_n),
	.D7(main_a7ddrphy_dfi_p3_cs_n),
	.D8(main_a7ddrphy_dfi_p3_cs_n),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_cs_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_3 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[0]),
	.D2(main_a7ddrphy_dfi_p0_address[0]),
	.D3(main_a7ddrphy_dfi_p1_address[0]),
	.D4(main_a7ddrphy_dfi_p1_address[0]),
	.D5(main_a7ddrphy_dfi_p2_address[0]),
	.D6(main_a7ddrphy_dfi_p2_address[0]),
	.D7(main_a7ddrphy_dfi_p3_address[0]),
	.D8(main_a7ddrphy_dfi_p3_address[0]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[0])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_4 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[1]),
	.D2(main_a7ddrphy_dfi_p0_address[1]),
	.D3(main_a7ddrphy_dfi_p1_address[1]),
	.D4(main_a7ddrphy_dfi_p1_address[1]),
	.D5(main_a7ddrphy_dfi_p2_address[1]),
	.D6(main_a7ddrphy_dfi_p2_address[1]),
	.D7(main_a7ddrphy_dfi_p3_address[1]),
	.D8(main_a7ddrphy_dfi_p3_address[1]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[1])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_5 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[2]),
	.D2(main_a7ddrphy_dfi_p0_address[2]),
	.D3(main_a7ddrphy_dfi_p1_address[2]),
	.D4(main_a7ddrphy_dfi_p1_address[2]),
	.D5(main_a7ddrphy_dfi_p2_address[2]),
	.D6(main_a7ddrphy_dfi_p2_address[2]),
	.D7(main_a7ddrphy_dfi_p3_address[2]),
	.D8(main_a7ddrphy_dfi_p3_address[2]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[2])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_6 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[3]),
	.D2(main_a7ddrphy_dfi_p0_address[3]),
	.D3(main_a7ddrphy_dfi_p1_address[3]),
	.D4(main_a7ddrphy_dfi_p1_address[3]),
	.D5(main_a7ddrphy_dfi_p2_address[3]),
	.D6(main_a7ddrphy_dfi_p2_address[3]),
	.D7(main_a7ddrphy_dfi_p3_address[3]),
	.D8(main_a7ddrphy_dfi_p3_address[3]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[3])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_7 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[4]),
	.D2(main_a7ddrphy_dfi_p0_address[4]),
	.D3(main_a7ddrphy_dfi_p1_address[4]),
	.D4(main_a7ddrphy_dfi_p1_address[4]),
	.D5(main_a7ddrphy_dfi_p2_address[4]),
	.D6(main_a7ddrphy_dfi_p2_address[4]),
	.D7(main_a7ddrphy_dfi_p3_address[4]),
	.D8(main_a7ddrphy_dfi_p3_address[4]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[4])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_8 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[5]),
	.D2(main_a7ddrphy_dfi_p0_address[5]),
	.D3(main_a7ddrphy_dfi_p1_address[5]),
	.D4(main_a7ddrphy_dfi_p1_address[5]),
	.D5(main_a7ddrphy_dfi_p2_address[5]),
	.D6(main_a7ddrphy_dfi_p2_address[5]),
	.D7(main_a7ddrphy_dfi_p3_address[5]),
	.D8(main_a7ddrphy_dfi_p3_address[5]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[5])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_9 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[6]),
	.D2(main_a7ddrphy_dfi_p0_address[6]),
	.D3(main_a7ddrphy_dfi_p1_address[6]),
	.D4(main_a7ddrphy_dfi_p1_address[6]),
	.D5(main_a7ddrphy_dfi_p2_address[6]),
	.D6(main_a7ddrphy_dfi_p2_address[6]),
	.D7(main_a7ddrphy_dfi_p3_address[6]),
	.D8(main_a7ddrphy_dfi_p3_address[6]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[6])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_10 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[7]),
	.D2(main_a7ddrphy_dfi_p0_address[7]),
	.D3(main_a7ddrphy_dfi_p1_address[7]),
	.D4(main_a7ddrphy_dfi_p1_address[7]),
	.D5(main_a7ddrphy_dfi_p2_address[7]),
	.D6(main_a7ddrphy_dfi_p2_address[7]),
	.D7(main_a7ddrphy_dfi_p3_address[7]),
	.D8(main_a7ddrphy_dfi_p3_address[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[7])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_11 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[8]),
	.D2(main_a7ddrphy_dfi_p0_address[8]),
	.D3(main_a7ddrphy_dfi_p1_address[8]),
	.D4(main_a7ddrphy_dfi_p1_address[8]),
	.D5(main_a7ddrphy_dfi_p2_address[8]),
	.D6(main_a7ddrphy_dfi_p2_address[8]),
	.D7(main_a7ddrphy_dfi_p3_address[8]),
	.D8(main_a7ddrphy_dfi_p3_address[8]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[8])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_12 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[9]),
	.D2(main_a7ddrphy_dfi_p0_address[9]),
	.D3(main_a7ddrphy_dfi_p1_address[9]),
	.D4(main_a7ddrphy_dfi_p1_address[9]),
	.D5(main_a7ddrphy_dfi_p2_address[9]),
	.D6(main_a7ddrphy_dfi_p2_address[9]),
	.D7(main_a7ddrphy_dfi_p3_address[9]),
	.D8(main_a7ddrphy_dfi_p3_address[9]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[9])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_13 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[10]),
	.D2(main_a7ddrphy_dfi_p0_address[10]),
	.D3(main_a7ddrphy_dfi_p1_address[10]),
	.D4(main_a7ddrphy_dfi_p1_address[10]),
	.D5(main_a7ddrphy_dfi_p2_address[10]),
	.D6(main_a7ddrphy_dfi_p2_address[10]),
	.D7(main_a7ddrphy_dfi_p3_address[10]),
	.D8(main_a7ddrphy_dfi_p3_address[10]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[10])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_14 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[11]),
	.D2(main_a7ddrphy_dfi_p0_address[11]),
	.D3(main_a7ddrphy_dfi_p1_address[11]),
	.D4(main_a7ddrphy_dfi_p1_address[11]),
	.D5(main_a7ddrphy_dfi_p2_address[11]),
	.D6(main_a7ddrphy_dfi_p2_address[11]),
	.D7(main_a7ddrphy_dfi_p3_address[11]),
	.D8(main_a7ddrphy_dfi_p3_address[11]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[11])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_15 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_address[12]),
	.D2(main_a7ddrphy_dfi_p0_address[12]),
	.D3(main_a7ddrphy_dfi_p1_address[12]),
	.D4(main_a7ddrphy_dfi_p1_address[12]),
	.D5(main_a7ddrphy_dfi_p2_address[12]),
	.D6(main_a7ddrphy_dfi_p2_address[12]),
	.D7(main_a7ddrphy_dfi_p3_address[12]),
	.D8(main_a7ddrphy_dfi_p3_address[12]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_a[12])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_16 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_bank[0]),
	.D2(main_a7ddrphy_dfi_p0_bank[0]),
	.D3(main_a7ddrphy_dfi_p1_bank[0]),
	.D4(main_a7ddrphy_dfi_p1_bank[0]),
	.D5(main_a7ddrphy_dfi_p2_bank[0]),
	.D6(main_a7ddrphy_dfi_p2_bank[0]),
	.D7(main_a7ddrphy_dfi_p3_bank[0]),
	.D8(main_a7ddrphy_dfi_p3_bank[0]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_ba[0])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_17 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_bank[1]),
	.D2(main_a7ddrphy_dfi_p0_bank[1]),
	.D3(main_a7ddrphy_dfi_p1_bank[1]),
	.D4(main_a7ddrphy_dfi_p1_bank[1]),
	.D5(main_a7ddrphy_dfi_p2_bank[1]),
	.D6(main_a7ddrphy_dfi_p2_bank[1]),
	.D7(main_a7ddrphy_dfi_p3_bank[1]),
	.D8(main_a7ddrphy_dfi_p3_bank[1]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_ba[1])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_18 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_bank[2]),
	.D2(main_a7ddrphy_dfi_p0_bank[2]),
	.D3(main_a7ddrphy_dfi_p1_bank[2]),
	.D4(main_a7ddrphy_dfi_p1_bank[2]),
	.D5(main_a7ddrphy_dfi_p2_bank[2]),
	.D6(main_a7ddrphy_dfi_p2_bank[2]),
	.D7(main_a7ddrphy_dfi_p3_bank[2]),
	.D8(main_a7ddrphy_dfi_p3_bank[2]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_ba[2])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_19 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_ras_n),
	.D2(main_a7ddrphy_dfi_p0_ras_n),
	.D3(main_a7ddrphy_dfi_p1_ras_n),
	.D4(main_a7ddrphy_dfi_p1_ras_n),
	.D5(main_a7ddrphy_dfi_p2_ras_n),
	.D6(main_a7ddrphy_dfi_p2_ras_n),
	.D7(main_a7ddrphy_dfi_p3_ras_n),
	.D8(main_a7ddrphy_dfi_p3_ras_n),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_ras_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_20 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_cas_n),
	.D2(main_a7ddrphy_dfi_p0_cas_n),
	.D3(main_a7ddrphy_dfi_p1_cas_n),
	.D4(main_a7ddrphy_dfi_p1_cas_n),
	.D5(main_a7ddrphy_dfi_p2_cas_n),
	.D6(main_a7ddrphy_dfi_p2_cas_n),
	.D7(main_a7ddrphy_dfi_p3_cas_n),
	.D8(main_a7ddrphy_dfi_p3_cas_n),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_cas_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_21 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_we_n),
	.D2(main_a7ddrphy_dfi_p0_we_n),
	.D3(main_a7ddrphy_dfi_p1_we_n),
	.D4(main_a7ddrphy_dfi_p1_we_n),
	.D5(main_a7ddrphy_dfi_p2_we_n),
	.D6(main_a7ddrphy_dfi_p2_we_n),
	.D7(main_a7ddrphy_dfi_p3_we_n),
	.D8(main_a7ddrphy_dfi_p3_we_n),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_we_n)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_22 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_cke),
	.D2(main_a7ddrphy_dfi_p0_cke),
	.D3(main_a7ddrphy_dfi_p1_cke),
	.D4(main_a7ddrphy_dfi_p1_cke),
	.D5(main_a7ddrphy_dfi_p2_cke),
	.D6(main_a7ddrphy_dfi_p2_cke),
	.D7(main_a7ddrphy_dfi_p3_cke),
	.D8(main_a7ddrphy_dfi_p3_cke),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_cke)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_23 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_dfi_p0_odt),
	.D2(main_a7ddrphy_dfi_p0_odt),
	.D3(main_a7ddrphy_dfi_p1_odt),
	.D4(main_a7ddrphy_dfi_p1_odt),
	.D5(main_a7ddrphy_dfi_p2_odt),
	.D6(main_a7ddrphy_dfi_p2_odt),
	.D7(main_a7ddrphy_dfi_p3_odt),
	.D8(main_a7ddrphy_dfi_p3_odt),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_odt)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_24 (
	.CLK(sys2x_dqs_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip00[0]),
	.D2(main_a7ddrphy_bitslip00[1]),
	.D3(main_a7ddrphy_bitslip00[2]),
	.D4(main_a7ddrphy_bitslip00[3]),
	.D5(main_a7ddrphy_bitslip00[4]),
	.D6(main_a7ddrphy_bitslip00[5]),
	.D7(main_a7ddrphy_bitslip00[6]),
	.D8(main_a7ddrphy_bitslip00[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dqs_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OFB(main_a7ddrphy0),
	.OQ(main_a7ddrphy_dqs_o_no_delay0),
	.TQ(main_a7ddrphy_dqs_t0)
);

IOBUFDS IOBUFDS(
	.I(main_a7ddrphy_dqs_o_no_delay0),
	.T(main_a7ddrphy_dqs_t0),
	.IO(ddram_dqs_p[0]),
	.IOB(ddram_dqs_n[0])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_25 (
	.CLK(sys2x_dqs_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip10[0]),
	.D2(main_a7ddrphy_bitslip10[1]),
	.D3(main_a7ddrphy_bitslip10[2]),
	.D4(main_a7ddrphy_bitslip10[3]),
	.D5(main_a7ddrphy_bitslip10[4]),
	.D6(main_a7ddrphy_bitslip10[5]),
	.D7(main_a7ddrphy_bitslip10[6]),
	.D8(main_a7ddrphy_bitslip10[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dqs_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OFB(main_a7ddrphy1),
	.OQ(main_a7ddrphy_dqs_o_no_delay1),
	.TQ(main_a7ddrphy_dqs_t1)
);

IOBUFDS IOBUFDS_1(
	.I(main_a7ddrphy_dqs_o_no_delay1),
	.T(main_a7ddrphy_dqs_t1),
	.IO(ddram_dqs_p[1]),
	.IOB(ddram_dqs_n[1])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_26 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip01[0]),
	.D2(main_a7ddrphy_bitslip01[1]),
	.D3(main_a7ddrphy_bitslip01[2]),
	.D4(main_a7ddrphy_bitslip01[3]),
	.D5(main_a7ddrphy_bitslip01[4]),
	.D6(main_a7ddrphy_bitslip01[5]),
	.D7(main_a7ddrphy_bitslip01[6]),
	.D8(main_a7ddrphy_bitslip01[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_dm[0])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_27 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip11[0]),
	.D2(main_a7ddrphy_bitslip11[1]),
	.D3(main_a7ddrphy_bitslip11[2]),
	.D4(main_a7ddrphy_bitslip11[3]),
	.D5(main_a7ddrphy_bitslip11[4]),
	.D6(main_a7ddrphy_bitslip11[5]),
	.D7(main_a7ddrphy_bitslip11[6]),
	.D8(main_a7ddrphy_bitslip11[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.OQ(ddram_dm[1])
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_28 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip02[0]),
	.D2(main_a7ddrphy_bitslip02[1]),
	.D3(main_a7ddrphy_bitslip02[2]),
	.D4(main_a7ddrphy_bitslip02[3]),
	.D5(main_a7ddrphy_bitslip02[4]),
	.D6(main_a7ddrphy_bitslip02[5]),
	.D7(main_a7ddrphy_bitslip02[6]),
	.D8(main_a7ddrphy_bitslip02[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay0),
	.TQ(main_a7ddrphy_dq_t0)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed0),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip03[7]),
	.Q2(main_a7ddrphy_bitslip03[6]),
	.Q3(main_a7ddrphy_bitslip03[5]),
	.Q4(main_a7ddrphy_bitslip03[4]),
	.Q5(main_a7ddrphy_bitslip03[3]),
	.Q6(main_a7ddrphy_bitslip03[2]),
	.Q7(main_a7ddrphy_bitslip03[1]),
	.Q8(main_a7ddrphy_bitslip03[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay0),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed0)
);

IOBUF IOBUF(
	.I(main_a7ddrphy_dq_o_nodelay0),
	.T(main_a7ddrphy_dq_t0),
	.IO(ddram_dq[0]),
	.O(main_a7ddrphy_dq_i_nodelay0)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_29 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip12[0]),
	.D2(main_a7ddrphy_bitslip12[1]),
	.D3(main_a7ddrphy_bitslip12[2]),
	.D4(main_a7ddrphy_bitslip12[3]),
	.D5(main_a7ddrphy_bitslip12[4]),
	.D6(main_a7ddrphy_bitslip12[5]),
	.D7(main_a7ddrphy_bitslip12[6]),
	.D8(main_a7ddrphy_bitslip12[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay1),
	.TQ(main_a7ddrphy_dq_t1)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_1 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip13[7]),
	.Q2(main_a7ddrphy_bitslip13[6]),
	.Q3(main_a7ddrphy_bitslip13[5]),
	.Q4(main_a7ddrphy_bitslip13[4]),
	.Q5(main_a7ddrphy_bitslip13[3]),
	.Q6(main_a7ddrphy_bitslip13[2]),
	.Q7(main_a7ddrphy_bitslip13[1]),
	.Q8(main_a7ddrphy_bitslip13[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_1 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay1),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed1)
);

IOBUF IOBUF_1(
	.I(main_a7ddrphy_dq_o_nodelay1),
	.T(main_a7ddrphy_dq_t1),
	.IO(ddram_dq[1]),
	.O(main_a7ddrphy_dq_i_nodelay1)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_30 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip20[0]),
	.D2(main_a7ddrphy_bitslip20[1]),
	.D3(main_a7ddrphy_bitslip20[2]),
	.D4(main_a7ddrphy_bitslip20[3]),
	.D5(main_a7ddrphy_bitslip20[4]),
	.D6(main_a7ddrphy_bitslip20[5]),
	.D7(main_a7ddrphy_bitslip20[6]),
	.D8(main_a7ddrphy_bitslip20[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay2),
	.TQ(main_a7ddrphy_dq_t2)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_2 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed2),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip21[7]),
	.Q2(main_a7ddrphy_bitslip21[6]),
	.Q3(main_a7ddrphy_bitslip21[5]),
	.Q4(main_a7ddrphy_bitslip21[4]),
	.Q5(main_a7ddrphy_bitslip21[3]),
	.Q6(main_a7ddrphy_bitslip21[2]),
	.Q7(main_a7ddrphy_bitslip21[1]),
	.Q8(main_a7ddrphy_bitslip21[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_2 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay2),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed2)
);

IOBUF IOBUF_2(
	.I(main_a7ddrphy_dq_o_nodelay2),
	.T(main_a7ddrphy_dq_t2),
	.IO(ddram_dq[2]),
	.O(main_a7ddrphy_dq_i_nodelay2)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_31 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip30[0]),
	.D2(main_a7ddrphy_bitslip30[1]),
	.D3(main_a7ddrphy_bitslip30[2]),
	.D4(main_a7ddrphy_bitslip30[3]),
	.D5(main_a7ddrphy_bitslip30[4]),
	.D6(main_a7ddrphy_bitslip30[5]),
	.D7(main_a7ddrphy_bitslip30[6]),
	.D8(main_a7ddrphy_bitslip30[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay3),
	.TQ(main_a7ddrphy_dq_t3)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_3 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed3),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip31[7]),
	.Q2(main_a7ddrphy_bitslip31[6]),
	.Q3(main_a7ddrphy_bitslip31[5]),
	.Q4(main_a7ddrphy_bitslip31[4]),
	.Q5(main_a7ddrphy_bitslip31[3]),
	.Q6(main_a7ddrphy_bitslip31[2]),
	.Q7(main_a7ddrphy_bitslip31[1]),
	.Q8(main_a7ddrphy_bitslip31[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_3 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay3),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed3)
);

IOBUF IOBUF_3(
	.I(main_a7ddrphy_dq_o_nodelay3),
	.T(main_a7ddrphy_dq_t3),
	.IO(ddram_dq[3]),
	.O(main_a7ddrphy_dq_i_nodelay3)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_32 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip40[0]),
	.D2(main_a7ddrphy_bitslip40[1]),
	.D3(main_a7ddrphy_bitslip40[2]),
	.D4(main_a7ddrphy_bitslip40[3]),
	.D5(main_a7ddrphy_bitslip40[4]),
	.D6(main_a7ddrphy_bitslip40[5]),
	.D7(main_a7ddrphy_bitslip40[6]),
	.D8(main_a7ddrphy_bitslip40[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay4),
	.TQ(main_a7ddrphy_dq_t4)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_4 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed4),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip41[7]),
	.Q2(main_a7ddrphy_bitslip41[6]),
	.Q3(main_a7ddrphy_bitslip41[5]),
	.Q4(main_a7ddrphy_bitslip41[4]),
	.Q5(main_a7ddrphy_bitslip41[3]),
	.Q6(main_a7ddrphy_bitslip41[2]),
	.Q7(main_a7ddrphy_bitslip41[1]),
	.Q8(main_a7ddrphy_bitslip41[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_4 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay4),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed4)
);

IOBUF IOBUF_4(
	.I(main_a7ddrphy_dq_o_nodelay4),
	.T(main_a7ddrphy_dq_t4),
	.IO(ddram_dq[4]),
	.O(main_a7ddrphy_dq_i_nodelay4)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_33 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip50[0]),
	.D2(main_a7ddrphy_bitslip50[1]),
	.D3(main_a7ddrphy_bitslip50[2]),
	.D4(main_a7ddrphy_bitslip50[3]),
	.D5(main_a7ddrphy_bitslip50[4]),
	.D6(main_a7ddrphy_bitslip50[5]),
	.D7(main_a7ddrphy_bitslip50[6]),
	.D8(main_a7ddrphy_bitslip50[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay5),
	.TQ(main_a7ddrphy_dq_t5)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_5 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed5),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip51[7]),
	.Q2(main_a7ddrphy_bitslip51[6]),
	.Q3(main_a7ddrphy_bitslip51[5]),
	.Q4(main_a7ddrphy_bitslip51[4]),
	.Q5(main_a7ddrphy_bitslip51[3]),
	.Q6(main_a7ddrphy_bitslip51[2]),
	.Q7(main_a7ddrphy_bitslip51[1]),
	.Q8(main_a7ddrphy_bitslip51[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_5 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay5),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed5)
);

IOBUF IOBUF_5(
	.I(main_a7ddrphy_dq_o_nodelay5),
	.T(main_a7ddrphy_dq_t5),
	.IO(ddram_dq[5]),
	.O(main_a7ddrphy_dq_i_nodelay5)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_34 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip60[0]),
	.D2(main_a7ddrphy_bitslip60[1]),
	.D3(main_a7ddrphy_bitslip60[2]),
	.D4(main_a7ddrphy_bitslip60[3]),
	.D5(main_a7ddrphy_bitslip60[4]),
	.D6(main_a7ddrphy_bitslip60[5]),
	.D7(main_a7ddrphy_bitslip60[6]),
	.D8(main_a7ddrphy_bitslip60[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay6),
	.TQ(main_a7ddrphy_dq_t6)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_6 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed6),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip61[7]),
	.Q2(main_a7ddrphy_bitslip61[6]),
	.Q3(main_a7ddrphy_bitslip61[5]),
	.Q4(main_a7ddrphy_bitslip61[4]),
	.Q5(main_a7ddrphy_bitslip61[3]),
	.Q6(main_a7ddrphy_bitslip61[2]),
	.Q7(main_a7ddrphy_bitslip61[1]),
	.Q8(main_a7ddrphy_bitslip61[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_6 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay6),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed6)
);

IOBUF IOBUF_6(
	.I(main_a7ddrphy_dq_o_nodelay6),
	.T(main_a7ddrphy_dq_t6),
	.IO(ddram_dq[6]),
	.O(main_a7ddrphy_dq_i_nodelay6)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_35 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip70[0]),
	.D2(main_a7ddrphy_bitslip70[1]),
	.D3(main_a7ddrphy_bitslip70[2]),
	.D4(main_a7ddrphy_bitslip70[3]),
	.D5(main_a7ddrphy_bitslip70[4]),
	.D6(main_a7ddrphy_bitslip70[5]),
	.D7(main_a7ddrphy_bitslip70[6]),
	.D8(main_a7ddrphy_bitslip70[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay7),
	.TQ(main_a7ddrphy_dq_t7)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_7 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed7),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip71[7]),
	.Q2(main_a7ddrphy_bitslip71[6]),
	.Q3(main_a7ddrphy_bitslip71[5]),
	.Q4(main_a7ddrphy_bitslip71[4]),
	.Q5(main_a7ddrphy_bitslip71[3]),
	.Q6(main_a7ddrphy_bitslip71[2]),
	.Q7(main_a7ddrphy_bitslip71[1]),
	.Q8(main_a7ddrphy_bitslip71[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_7 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay7),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[0] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed7)
);

IOBUF IOBUF_7(
	.I(main_a7ddrphy_dq_o_nodelay7),
	.T(main_a7ddrphy_dq_t7),
	.IO(ddram_dq[7]),
	.O(main_a7ddrphy_dq_i_nodelay7)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_36 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip80[0]),
	.D2(main_a7ddrphy_bitslip80[1]),
	.D3(main_a7ddrphy_bitslip80[2]),
	.D4(main_a7ddrphy_bitslip80[3]),
	.D5(main_a7ddrphy_bitslip80[4]),
	.D6(main_a7ddrphy_bitslip80[5]),
	.D7(main_a7ddrphy_bitslip80[6]),
	.D8(main_a7ddrphy_bitslip80[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay8),
	.TQ(main_a7ddrphy_dq_t8)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_8 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed8),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip81[7]),
	.Q2(main_a7ddrphy_bitslip81[6]),
	.Q3(main_a7ddrphy_bitslip81[5]),
	.Q4(main_a7ddrphy_bitslip81[4]),
	.Q5(main_a7ddrphy_bitslip81[3]),
	.Q6(main_a7ddrphy_bitslip81[2]),
	.Q7(main_a7ddrphy_bitslip81[1]),
	.Q8(main_a7ddrphy_bitslip81[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_8 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay8),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed8)
);

IOBUF IOBUF_8(
	.I(main_a7ddrphy_dq_o_nodelay8),
	.T(main_a7ddrphy_dq_t8),
	.IO(ddram_dq[8]),
	.O(main_a7ddrphy_dq_i_nodelay8)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_37 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip90[0]),
	.D2(main_a7ddrphy_bitslip90[1]),
	.D3(main_a7ddrphy_bitslip90[2]),
	.D4(main_a7ddrphy_bitslip90[3]),
	.D5(main_a7ddrphy_bitslip90[4]),
	.D6(main_a7ddrphy_bitslip90[5]),
	.D7(main_a7ddrphy_bitslip90[6]),
	.D8(main_a7ddrphy_bitslip90[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay9),
	.TQ(main_a7ddrphy_dq_t9)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_9 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed9),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip91[7]),
	.Q2(main_a7ddrphy_bitslip91[6]),
	.Q3(main_a7ddrphy_bitslip91[5]),
	.Q4(main_a7ddrphy_bitslip91[4]),
	.Q5(main_a7ddrphy_bitslip91[3]),
	.Q6(main_a7ddrphy_bitslip91[2]),
	.Q7(main_a7ddrphy_bitslip91[1]),
	.Q8(main_a7ddrphy_bitslip91[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_9 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay9),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed9)
);

IOBUF IOBUF_9(
	.I(main_a7ddrphy_dq_o_nodelay9),
	.T(main_a7ddrphy_dq_t9),
	.IO(ddram_dq[9]),
	.O(main_a7ddrphy_dq_i_nodelay9)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_38 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip100[0]),
	.D2(main_a7ddrphy_bitslip100[1]),
	.D3(main_a7ddrphy_bitslip100[2]),
	.D4(main_a7ddrphy_bitslip100[3]),
	.D5(main_a7ddrphy_bitslip100[4]),
	.D6(main_a7ddrphy_bitslip100[5]),
	.D7(main_a7ddrphy_bitslip100[6]),
	.D8(main_a7ddrphy_bitslip100[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay10),
	.TQ(main_a7ddrphy_dq_t10)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_10 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed10),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip101[7]),
	.Q2(main_a7ddrphy_bitslip101[6]),
	.Q3(main_a7ddrphy_bitslip101[5]),
	.Q4(main_a7ddrphy_bitslip101[4]),
	.Q5(main_a7ddrphy_bitslip101[3]),
	.Q6(main_a7ddrphy_bitslip101[2]),
	.Q7(main_a7ddrphy_bitslip101[1]),
	.Q8(main_a7ddrphy_bitslip101[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_10 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay10),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed10)
);

IOBUF IOBUF_10(
	.I(main_a7ddrphy_dq_o_nodelay10),
	.T(main_a7ddrphy_dq_t10),
	.IO(ddram_dq[10]),
	.O(main_a7ddrphy_dq_i_nodelay10)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_39 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip110[0]),
	.D2(main_a7ddrphy_bitslip110[1]),
	.D3(main_a7ddrphy_bitslip110[2]),
	.D4(main_a7ddrphy_bitslip110[3]),
	.D5(main_a7ddrphy_bitslip110[4]),
	.D6(main_a7ddrphy_bitslip110[5]),
	.D7(main_a7ddrphy_bitslip110[6]),
	.D8(main_a7ddrphy_bitslip110[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay11),
	.TQ(main_a7ddrphy_dq_t11)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_11 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed11),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip111[7]),
	.Q2(main_a7ddrphy_bitslip111[6]),
	.Q3(main_a7ddrphy_bitslip111[5]),
	.Q4(main_a7ddrphy_bitslip111[4]),
	.Q5(main_a7ddrphy_bitslip111[3]),
	.Q6(main_a7ddrphy_bitslip111[2]),
	.Q7(main_a7ddrphy_bitslip111[1]),
	.Q8(main_a7ddrphy_bitslip111[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_11 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay11),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed11)
);

IOBUF IOBUF_11(
	.I(main_a7ddrphy_dq_o_nodelay11),
	.T(main_a7ddrphy_dq_t11),
	.IO(ddram_dq[11]),
	.O(main_a7ddrphy_dq_i_nodelay11)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_40 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip120[0]),
	.D2(main_a7ddrphy_bitslip120[1]),
	.D3(main_a7ddrphy_bitslip120[2]),
	.D4(main_a7ddrphy_bitslip120[3]),
	.D5(main_a7ddrphy_bitslip120[4]),
	.D6(main_a7ddrphy_bitslip120[5]),
	.D7(main_a7ddrphy_bitslip120[6]),
	.D8(main_a7ddrphy_bitslip120[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay12),
	.TQ(main_a7ddrphy_dq_t12)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_12 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed12),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip121[7]),
	.Q2(main_a7ddrphy_bitslip121[6]),
	.Q3(main_a7ddrphy_bitslip121[5]),
	.Q4(main_a7ddrphy_bitslip121[4]),
	.Q5(main_a7ddrphy_bitslip121[3]),
	.Q6(main_a7ddrphy_bitslip121[2]),
	.Q7(main_a7ddrphy_bitslip121[1]),
	.Q8(main_a7ddrphy_bitslip121[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_12 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay12),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed12)
);

IOBUF IOBUF_12(
	.I(main_a7ddrphy_dq_o_nodelay12),
	.T(main_a7ddrphy_dq_t12),
	.IO(ddram_dq[12]),
	.O(main_a7ddrphy_dq_i_nodelay12)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_41 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip130[0]),
	.D2(main_a7ddrphy_bitslip130[1]),
	.D3(main_a7ddrphy_bitslip130[2]),
	.D4(main_a7ddrphy_bitslip130[3]),
	.D5(main_a7ddrphy_bitslip130[4]),
	.D6(main_a7ddrphy_bitslip130[5]),
	.D7(main_a7ddrphy_bitslip130[6]),
	.D8(main_a7ddrphy_bitslip130[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay13),
	.TQ(main_a7ddrphy_dq_t13)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_13 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed13),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip131[7]),
	.Q2(main_a7ddrphy_bitslip131[6]),
	.Q3(main_a7ddrphy_bitslip131[5]),
	.Q4(main_a7ddrphy_bitslip131[4]),
	.Q5(main_a7ddrphy_bitslip131[3]),
	.Q6(main_a7ddrphy_bitslip131[2]),
	.Q7(main_a7ddrphy_bitslip131[1]),
	.Q8(main_a7ddrphy_bitslip131[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_13 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay13),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed13)
);

IOBUF IOBUF_13(
	.I(main_a7ddrphy_dq_o_nodelay13),
	.T(main_a7ddrphy_dq_t13),
	.IO(ddram_dq[13]),
	.O(main_a7ddrphy_dq_i_nodelay13)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_42 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip140[0]),
	.D2(main_a7ddrphy_bitslip140[1]),
	.D3(main_a7ddrphy_bitslip140[2]),
	.D4(main_a7ddrphy_bitslip140[3]),
	.D5(main_a7ddrphy_bitslip140[4]),
	.D6(main_a7ddrphy_bitslip140[5]),
	.D7(main_a7ddrphy_bitslip140[6]),
	.D8(main_a7ddrphy_bitslip140[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay14),
	.TQ(main_a7ddrphy_dq_t14)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_14 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed14),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip141[7]),
	.Q2(main_a7ddrphy_bitslip141[6]),
	.Q3(main_a7ddrphy_bitslip141[5]),
	.Q4(main_a7ddrphy_bitslip141[4]),
	.Q5(main_a7ddrphy_bitslip141[3]),
	.Q6(main_a7ddrphy_bitslip141[2]),
	.Q7(main_a7ddrphy_bitslip141[1]),
	.Q8(main_a7ddrphy_bitslip141[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_14 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay14),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed14)
);

IOBUF IOBUF_14(
	.I(main_a7ddrphy_dq_o_nodelay14),
	.T(main_a7ddrphy_dq_t14),
	.IO(ddram_dq[14]),
	.O(main_a7ddrphy_dq_i_nodelay14)
);

OSERDESE2 #(
	.DATA_RATE_OQ("DDR"),
	.DATA_RATE_TQ("BUF"),
	.DATA_WIDTH(3'd4),
	.SERDES_MODE("MASTER"),
	.TRISTATE_WIDTH(1'd1)
) OSERDESE2_43 (
	.CLK(sys2x_clk),
	.CLKDIV(sys_clk),
	.D1(main_a7ddrphy_bitslip150[0]),
	.D2(main_a7ddrphy_bitslip150[1]),
	.D3(main_a7ddrphy_bitslip150[2]),
	.D4(main_a7ddrphy_bitslip150[3]),
	.D5(main_a7ddrphy_bitslip150[4]),
	.D6(main_a7ddrphy_bitslip150[5]),
	.D7(main_a7ddrphy_bitslip150[6]),
	.D8(main_a7ddrphy_bitslip150[7]),
	.OCE(1'd1),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.T1((~main_a7ddrphy_dq_oe_delay_tappeddelayline_tappeddelayline)),
	.TCE(1'd1),
	.OQ(main_a7ddrphy_dq_o_nodelay15),
	.TQ(main_a7ddrphy_dq_t15)
);

ISERDESE2 #(
	.DATA_RATE("DDR"),
	.DATA_WIDTH(3'd4),
	.INTERFACE_TYPE("NETWORKING"),
	.IOBDELAY("IFD"),
	.NUM_CE(1'd1),
	.SERDES_MODE("MASTER")
) ISERDESE2_15 (
	.BITSLIP(1'd0),
	.CE1(1'd1),
	.CLK(sys2x_clk),
	.CLKB((~sys2x_clk)),
	.CLKDIV(sys_clk),
	.DDLY(main_a7ddrphy_dq_i_delayed15),
	.RST((sys_rst | main_a7ddrphy_rst_storage)),
	.Q1(main_a7ddrphy_bitslip151[7]),
	.Q2(main_a7ddrphy_bitslip151[6]),
	.Q3(main_a7ddrphy_bitslip151[5]),
	.Q4(main_a7ddrphy_bitslip151[4]),
	.Q5(main_a7ddrphy_bitslip151[3]),
	.Q6(main_a7ddrphy_bitslip151[2]),
	.Q7(main_a7ddrphy_bitslip151[1]),
	.Q8(main_a7ddrphy_bitslip151[0])
);

IDELAYE2 #(
	.CINVCTRL_SEL("FALSE"),
	.DELAY_SRC("IDATAIN"),
	.HIGH_PERFORMANCE_MODE("TRUE"),
	.IDELAY_TYPE("VARIABLE"),
	.IDELAY_VALUE(1'd0),
	.PIPE_SEL("FALSE"),
	.REFCLK_FREQUENCY(200.0),
	.SIGNAL_PATTERN("DATA")
) IDELAYE2_15 (
	.C(sys_clk),
	.CE((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_inc_re)),
	.IDATAIN(main_a7ddrphy_dq_i_nodelay15),
	.INC(1'd1),
	.LD(((main_a7ddrphy_dly_sel_storage[1] & main_a7ddrphy_rdly_dq_rst_re) | main_a7ddrphy_rst_storage)),
	.LDPIPEEN(1'd0),
	.DATAOUT(main_a7ddrphy_dq_i_delayed15)
);

IOBUF IOBUF_15(
	.I(main_a7ddrphy_dq_o_nodelay15),
	.T(main_a7ddrphy_dq_t15),
	.IO(ddram_dq[15]),
	.O(main_a7ddrphy_dq_i_nodelay15)
);

reg [23:0] storage[0:15];
reg [23:0] memdat;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_we)
		storage[main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_dat_w;
	memdat <= storage[main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_wrport_dat_r = memdat;
assign main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_dat_r = storage[main_litedramcore_bankmachine0_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_1[0:15];
reg [23:0] memdat_1;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_we)
		storage_1[main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_dat_w;
	memdat_1 <= storage_1[main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_wrport_dat_r = memdat_1;
assign main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_dat_r = storage_1[main_litedramcore_bankmachine1_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_2[0:15];
reg [23:0] memdat_2;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_we)
		storage_2[main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_dat_w;
	memdat_2 <= storage_2[main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_wrport_dat_r = memdat_2;
assign main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_dat_r = storage_2[main_litedramcore_bankmachine2_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_3[0:15];
reg [23:0] memdat_3;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_we)
		storage_3[main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_dat_w;
	memdat_3 <= storage_3[main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_wrport_dat_r = memdat_3;
assign main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_dat_r = storage_3[main_litedramcore_bankmachine3_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_4[0:15];
reg [23:0] memdat_4;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_we)
		storage_4[main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_dat_w;
	memdat_4 <= storage_4[main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_wrport_dat_r = memdat_4;
assign main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_dat_r = storage_4[main_litedramcore_bankmachine4_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_5[0:15];
reg [23:0] memdat_5;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_we)
		storage_5[main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_dat_w;
	memdat_5 <= storage_5[main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_wrport_dat_r = memdat_5;
assign main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_dat_r = storage_5[main_litedramcore_bankmachine5_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_6[0:15];
reg [23:0] memdat_6;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_we)
		storage_6[main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_dat_w;
	memdat_6 <= storage_6[main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_wrport_dat_r = memdat_6;
assign main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_dat_r = storage_6[main_litedramcore_bankmachine6_cmd_buffer_lookahead_rdport_adr];

reg [23:0] storage_7[0:15];
reg [23:0] memdat_7;
always @(posedge sys_clk) begin
	if (main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_we)
		storage_7[main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr] <= main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_dat_w;
	memdat_7 <= storage_7[main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_adr];
end

always @(posedge sys_clk) begin
end

assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_wrport_dat_r = memdat_7;
assign main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_dat_r = storage_7[main_litedramcore_bankmachine7_cmd_buffer_lookahead_rdport_adr];

FD FD(
	.C(main_clkin),
	.D(main_reset),
	.Q(builder_reset0)
);

FD FD_1(
	.C(main_clkin),
	.D(builder_reset0),
	.Q(builder_reset1)
);

FD FD_2(
	.C(main_clkin),
	.D(builder_reset1),
	.Q(builder_reset2)
);

FD FD_3(
	.C(main_clkin),
	.D(builder_reset2),
	.Q(builder_reset3)
);

FD FD_4(
	.C(main_clkin),
	.D(builder_reset3),
	.Q(builder_reset4)
);

FD FD_5(
	.C(main_clkin),
	.D(builder_reset4),
	.Q(builder_reset5)
);

FD FD_6(
	.C(main_clkin),
	.D(builder_reset5),
	.Q(builder_reset6)
);

FD FD_7(
	.C(main_clkin),
	.D(builder_reset6),
	.Q(builder_reset7)
);

PLLE2_ADV #(
	.CLKFBOUT_MULT(5'd16),
	.CLKIN1_PERIOD(10.0),
	.CLKOUT0_DIVIDE(4'd8),
	.CLKOUT0_PHASE(1'd0),
	.CLKOUT1_DIVIDE(5'd16),
	.CLKOUT1_PHASE(1'd0),
	.CLKOUT2_DIVIDE(4'd8),
	.CLKOUT2_PHASE(1'd0),
	.CLKOUT3_DIVIDE(4'd8),
	.CLKOUT3_PHASE(7'd90),
	.DIVCLK_DIVIDE(1'd1),
	.REF_JITTER1(0.01),
	.STARTUP_WAIT("FALSE")
) PLLE2_ADV (
	.CLKFBIN(builder_pll_fb),
	.CLKIN1(main_clkin),
	.RST(builder_reset7),
	.CLKFBOUT(builder_pll_fb),
	.CLKOUT0(main_clkout0),
	.CLKOUT1(main_clkout1),
	.CLKOUT2(main_clkout2),
	.CLKOUT3(main_clkout3),
	.LOCKED(main_locked)
);

(* ars_ff1 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE (
	.C(iodelay_clk),
	.CE(1'd1),
	.D(1'd0),
	.PRE(builder_xilinxasyncresetsynchronizerimpl0),
	.Q(builder_xilinxasyncresetsynchronizerimpl0_rst_meta)
);

(* ars_ff2 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_1 (
	.C(iodelay_clk),
	.CE(1'd1),
	.D(builder_xilinxasyncresetsynchronizerimpl0_rst_meta),
	.PRE(builder_xilinxasyncresetsynchronizerimpl0),
	.Q(iodelay_rst)
);

(* ars_ff1 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_2 (
	.C(sys_clk),
	.CE(1'd1),
	.D(1'd0),
	.PRE(builder_xilinxasyncresetsynchronizerimpl1),
	.Q(builder_xilinxasyncresetsynchronizerimpl1_rst_meta)
);

(* ars_ff2 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_3 (
	.C(sys_clk),
	.CE(1'd1),
	.D(builder_xilinxasyncresetsynchronizerimpl1_rst_meta),
	.PRE(builder_xilinxasyncresetsynchronizerimpl1),
	.Q(sys_rst)
);

(* ars_ff1 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_4 (
	.C(sys2x_clk),
	.CE(1'd1),
	.D(1'd0),
	.PRE(builder_xilinxasyncresetsynchronizerimpl2),
	.Q(builder_xilinxasyncresetsynchronizerimpl2_rst_meta)
);

(* ars_ff2 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_5 (
	.C(sys2x_clk),
	.CE(1'd1),
	.D(builder_xilinxasyncresetsynchronizerimpl2_rst_meta),
	.PRE(builder_xilinxasyncresetsynchronizerimpl2),
	.Q(builder_xilinxasyncresetsynchronizerimpl2_expr)
);

(* ars_ff1 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_6 (
	.C(sys2x_dqs_clk),
	.CE(1'd1),
	.D(1'd0),
	.PRE(builder_xilinxasyncresetsynchronizerimpl3),
	.Q(builder_xilinxasyncresetsynchronizerimpl3_rst_meta)
);

(* ars_ff2 = "true", async_reg = "true" *) FDPE #(
	.INIT(1'd1)
) FDPE_7 (
	.C(sys2x_dqs_clk),
	.CE(1'd1),
	.D(builder_xilinxasyncresetsynchronizerimpl3_rst_meta),
	.PRE(builder_xilinxasyncresetsynchronizerimpl3),
	.Q(builder_xilinxasyncresetsynchronizerimpl3_expr)
);

endmodule
