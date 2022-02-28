// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/perint/pi1r.v"

`define PUMMU
//`define PUHPTW
`define PUMULDIVCLK
`define PUDSPMUL
//`define PUDCACHE /* issues in linux when enabled; ie: `nano /etc/inittab` or `htop` shows garbaged screen */
`include "pu/multipu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/intctrl.v"

`include "dev/usb_serial.v"

`include "dev/pi1_upconverter.v"
`include "dev/pi1_dcache.v"
`include "dev/pi1q_to_wb4.v"
`include "./litedram/litedram.v"

`include "dev/bootldr/bootldr.v"

module orangecrab0225 (

	 usr_btn_n

	,clk48mhz_i

	// SDCARD signals.
	,sdcard_clk
	,sdcard_di
	,sdcard_do
	,sdcard_dat1
	,sdcard_dat2
	,sdcard_cs_n

	// USB signals.
	,usb_d_p
	,usb_d_n
	,usb_pullup

	// DDR3L signals.
	,ddr3l_clk_p
	,ddr3l_cke
	,ddr3l_odt
	,ddr3l_cs_n
	,ddr3l_ras_n
	,ddr3l_cas_n
	,ddr3l_we_n
	,ddr3l_ba
	,ddr3l_a
	,ddr3l_dq
	,ddr3l_dm
	,ddr3l_dqs_p
	,ddr3l_reset_n
	,ddr3l_vccio
	,ddr3l_gnd

	// LED signals.
	,led_red_n
	,led_green_n
	,led_blue_n
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire usr_btn_n;

input wire clk48mhz_i;

// SDCARD signals.
output wire sdcard_clk;
output wire sdcard_di;
input  wire sdcard_do;
output wire sdcard_dat1;
output wire sdcard_dat2;
output wire sdcard_cs_n;
assign sdcard_dat1 = 1;
assign sdcard_dat2 = 1;

// USB signals.
inout  wire usb_d_p;
inout  wire usb_d_n;
output wire usb_pullup;
assign usb_pullup = 1'b1;

// DDR3L signals.
// Parameters for Micron MT41K64M16TW DDR3L.
localparam DDR3BANKCOUNT   = 8;
localparam DDR3ABITSIZE    = 16;
localparam DDR3DQBITSIZE   = 16;
output wire                               ddr3l_clk_p;
output wire                               ddr3l_cke;
output wire                               ddr3l_odt;
output wire                               ddr3l_cs_n;
output wire                               ddr3l_ras_n;
output wire                               ddr3l_cas_n;
output wire                               ddr3l_we_n;
output wire [clog2(DDR3BANKCOUNT) -1 : 0] ddr3l_ba;
output wire [DDR3ABITSIZE -1 : 0]         ddr3l_a;
inout  wire [DDR3DQBITSIZE -1 : 0]        ddr3l_dq;
output wire [(DDR3DQBITSIZE / 8) -1 : 0]  ddr3l_dm;
inout  wire [(DDR3DQBITSIZE / 8) -1 : 0]  ddr3l_dqs_p;
output wire                               ddr3l_reset_n;
output wire [6 -1 : 0]                    ddr3l_vccio;
output wire [2 -1 : 0]                    ddr3l_gnd;
assign ddr3l_vccio = {6{1'b1}};
assign ddr3l_gnd = {2{1'b0}};

// LED signals.
output wire led_red_n;
output wire led_green_n;
output wire led_blue_n;
assign led_red_n = 1'b1;
assign led_green_n = 1'b1;
//assign led_blue_n = 1'b1;

wire litedram_init_done;
wire litedram_init_error;

assign led_blue_n = !(~(sdcard_di & sdcard_do) || litedram_init_error);

wire multipu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

wire rst_p = !usr_btn_n;

localparam RST_CNTR_BITSZ = 16;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk48mhz_i) begin
	if (!multipu_rst_ow && !swwarmrst && usr_btn_n) begin
		if (rst_cntr)
			rst_cntr <= rst_cntr - 1'b1;
	end else
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
end

always @ (posedge clk48mhz_i) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

//GSR GSR_INST (.GSR (~swcoldrst));

localparam CLKFREQ12MHZ = 12000000;
localparam CLKFREQ24MHZ = 24000000;
localparam CLKFREQ48MHZ = 48000000;
localparam CLKFREQ96MHZ = 96000000;

localparam CLKFREQ   = CLKFREQ12MHZ; // Frequency of clk_w.
localparam CLK2XFREQ = CLKFREQ24MHZ; // Frequency of clk_2x_w.
localparam CLK4XFREQ = CLKFREQ48MHZ; // Frequency of clk_4x_w.
localparam CLK8XFREQ = CLKFREQ96MHZ; // Frequency of clk_8x_w.

wire [3:0] pll_clk_w;
wire       pll_locked;
ecp5pll #(

	 .in_hz    (CLKFREQ48MHZ)
	,.out0_hz  (CLKFREQ)
	,.out1_hz  (CLK2XFREQ)
	,.out2_hz  (CLK4XFREQ)
	,.out3_hz  (CLK8XFREQ)

) pll (

	 .clk_i        (clk48mhz_i)
	,.clk_o        (pll_clk_w)
	,.reset        (1'b0)
	,.standby      (1'b0)
	,.phasesel     (2'b0)
	,.phasedir     (1'b0)
	,.phasestep    (1'b0)
	,.phaseloadreg (1'b0)
	,.locked       (pll_locked)
);
wire clk12mhz = pll_clk_w[0];
wire clk24mhz = pll_clk_w[1];
wire clk48mhz = pll_clk_w[2];
wire clk96mhz = pll_clk_w[3];

wire clk_w    = clk12mhz;
wire clk_2x_w = clk24mhz;
wire clk_4x_w = clk48mhz;
wire clk_8x_w = clk96mhz;

wire rst_w = (!pll_locked || devtbl_rst0_r || (|rst_cntr));

localparam PUCOUNT = 1; // 1 max.

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_SERIAL = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRCCOUNT   = (INTCTRLSRC_SERIAL +1); // Number of interrupt source.
localparam INTCTRLDSTCOUNT   = PUCOUNT; // Number of interrupt destination.
wire [INTCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [INTCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam M_PI1R_MULTIPU    = 0;
localparam M_PI1R_LAST       = M_PI1R_MULTIPU;
localparam S_PI1R_SDCARD     = 0;
localparam S_PI1R_DEVTBL     = (S_PI1R_SDCARD + 1);
localparam S_PI1R_INTCTRL    = (S_PI1R_DEVTBL + 1);
localparam S_PI1R_SERIAL     = (S_PI1R_INTCTRL + 1);
localparam S_PI1R_RAM        = (S_PI1R_SERIAL + 1);
localparam S_PI1R_RAMCTRL    = (S_PI1R_RAM + 1);
localparam S_PI1R_BOOTLDR    = (S_PI1R_RAMCTRL + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_BOOTLDR + 1);

localparam PI1RMASTERCOUNT       = (M_PI1R_LAST + 1);
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ARCHBITSZ;
localparam PI1RCLKFREQ           = CLK2XFREQ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_2x_w;
// PerInt is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerInt:
// 	input  [2 -1 : 0]             m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
// 	input  [ADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
// 	output [ARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
// 	input  [(ARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
// 	output                        m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];
// Slaves should use the following signals to plug onto PerInt:
// 	output [2 -1 : 0]             s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
// 	output [ADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
// 	output [ARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
// 	output [(ARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
// 	input                         s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
// 	input  [ADDRBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];
`include "lib/perint/inst.pi1r.v"

wire [(ARCHBITSZ * PI1RSLAVECOUNT) -1 : 0] devtbl_id_flat_w;
wire [ARCHBITSZ -1 : 0]                    devtbl_id_w           [PI1RSLAVECOUNT -1 : 0];
wire [(ADDRBITSZ * PI1RSLAVECOUNT) -1 : 0] devtbl_mapsz_flat_w;
wire [PI1RSLAVECOUNT -1 : 0]               devtbl_useintr_flat_w;
wire [PI1RSLAVECOUNT -1 : 0]               devtbl_useintr_w;
genvar gen_devtbl_id_flat_w_idx;
generate for (gen_devtbl_id_flat_w_idx = 0; gen_devtbl_id_flat_w_idx < PI1RSLAVECOUNT; gen_devtbl_id_flat_w_idx = gen_devtbl_id_flat_w_idx + 1) begin :gen_devtbl_id_flat_w
assign devtbl_id_flat_w[((gen_devtbl_id_flat_w_idx+1) * ARCHBITSZ) -1 : gen_devtbl_id_flat_w_idx * ARCHBITSZ] = devtbl_id_w[gen_devtbl_id_flat_w_idx];
end endgenerate
assign devtbl_mapsz_flat_w = s_pi1r_mapsz_w_flat /* defined in "lib/perint/inst.pi1r.v" */;
assign devtbl_useintr_flat_w = devtbl_useintr_w;

localparam ICACHESZ = 16;
localparam TLBSZ    = 16;

localparam ICACHEWAYCOUNT = 2;
localparam DCACHEWAYCOUNT = 1;
localparam TLBWAYCOUNT    = 1;

multipu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.CLKFREQ        (CLK2XFREQ)
	,.PUCOUNT        (PUCOUNT)
	,.ICACHESETCOUNT ((1024/(ARCHBITSZ/8))*((ICACHESZ/ICACHEWAYCOUNT)/PUCOUNT))
	,.DCACHESETCOUNT ((1024/(ARCHBITSZ/8))*1)
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.MULDIVCNT      (4)

) multipu (

	 .rst_i (rst_w)

	,.rst_o (multipu_rst_ow)

	,.clk_i        (clk_2x_w)
	,.clk_muldiv_i (clk_8x_w)
	,.clk_mem_i    (pi1r_clk_w)

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_MULTIPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_MULTIPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_MULTIPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_MULTIPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_MULTIPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_MULTIPU])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  ((('h1000)>>1) +
		(s_pi1r_mapsz_w[S_PI1R_RAM]<<1) +
		(s_pi1r_mapsz_w[S_PI1R_RAMCTRL]<<1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)
);

sdcard_spi #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (PI1RCLKFREQ)

) sdcard (

	 .rst_i (pi1r_rst_w)

	,.clk_mem_i (pi1r_clk_w)
	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (pi1r_clk_w)

	,.sclk_o (sdcard_clk)
	,.di_o   (sdcard_di)
	,.do_i   (sdcard_do)
	,.cs_o   (sdcard_cs_n)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_SDCARD])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_SDCARD])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_SDCARD])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_SDCARD])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_SDCARD])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_SDCARD])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_SDCARD])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_SDCARD])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_SDCARD])
);

assign devtbl_id_w     [S_PI1R_SDCARD] = 4;
assign devtbl_useintr_w[S_PI1R_SDCARD] = 1;

localparam RAMCACHEWAYCOUNT = 1;

localparam RAMCACHESZ = /* In (ARCHBITSZ/8) units */
	((1024/(ARCHBITSZ/8))*(8/RAMCACHEWAYCOUNT));

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	,.DEVMAPCNT  (PI1RSLAVECOUNT)

) devtbl (

	 .rst_i (pi1r_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	,.rst2_o (devtbl_rst2_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_DEVTBL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_DEVTBL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_DEVTBL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_DEVTBL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_DEVTBL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_DEVTBL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_DEVTBL])

	,.devtbl_id_flat_i      (devtbl_id_flat_w)
	,.devtbl_mapsz_flat_i   (devtbl_mapsz_flat_w)
	,.devtbl_useintr_flat_i (devtbl_useintr_flat_w)
);

assign devtbl_id_w     [S_PI1R_DEVTBL] = 7;
assign devtbl_useintr_w[S_PI1R_DEVTBL] = 0;

intctrl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.INTSRCCOUNT (INTCTRLSRCCOUNT)
	,.INTDSTCOUNT (INTCTRLDSTCOUNT)

) intctrl (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_INTCTRL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_INTCTRL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_INTCTRL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_INTCTRL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_INTCTRL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_INTCTRL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_INTCTRL])

	,.intrqstdst_o (intrqstdst_w)
	,.intrdydst_i  (intrdydst_w)
	,.intbestdst_i (intbestdst_w)

	,.intrqstsrc_i (intrqstsrc_w)
	,.intrdysrc_o  (intrdysrc_w)
);

assign devtbl_id_w     [S_PI1R_INTCTRL] = 3;
assign devtbl_useintr_w[S_PI1R_INTCTRL] = 0;

usb_serial #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz or 60MHz.
	,.BUFSZ      (4096)

) serial (

	 .rst_i (!pll_locked
		/* pi1r_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk48mhz)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_SERIAL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_SERIAL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_SERIAL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_SERIAL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_SERIAL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_SERIAL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_SERIAL])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_SERIAL])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_SERIAL])

	,.usb_dp_io (usb_d_p)
	,.usb_dn_io (usb_d_n)
);

assign devtbl_id_w     [S_PI1R_SERIAL] = 5;
assign devtbl_useintr_w[S_PI1R_SERIAL] = 1;

localparam LITEDRAM_ARCHBITSZ = 128;

wire [2 -1 : 0]                                                  dcache_m_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] dcache_m_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w1;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             dcache_m_sel_w;
wire                                                             dcache_m_rdy_w;

pi1_upconverter #(

	 .MARCHBITSZ (ARCHBITSZ)
	,.SARCHBITSZ (LITEDRAM_ARCHBITSZ)

) pi1_upconverter (

	 .clk_i (pi1r_clk_w)

	,.m_pi1_op_i   (s_pi1r_op_w[S_PI1R_RAM])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_RAM])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_RAM])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_RAM])
	,.m_pi1_sel_i  (s_pi1r_sel_w[S_PI1R_RAM])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[S_PI1R_RAM])

	,.s_pi1_op_o   (dcache_m_op_w)
	,.s_pi1_addr_o (dcache_m_addr_w)
	,.s_pi1_data_i (dcache_m_data_w0)
	,.s_pi1_data_o (dcache_m_data_w1)
	,.s_pi1_sel_o  (dcache_m_sel_w)
	,.s_pi1_rdy_i  (dcache_m_rdy_w)
);

assign s_pi1r_mapsz_w[S_PI1R_RAM] = 'h2000000 /* 128MB */;

assign devtbl_id_w     [S_PI1R_RAM] = 1;
assign devtbl_useintr_w[S_PI1R_RAM] = 0;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk48mhz_i) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]                                                  dcache_s_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] dcache_s_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_s_data_w1;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_s_data_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             dcache_s_sel_w;
wire                                                             dcache_s_rdy_w;

pi1_dcache #(

	 .ARCHBITSZ     (LITEDRAM_ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ/(LITEDRAM_ARCHBITSZ/ARCHBITSZ))
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.INITFILE      ("litedram.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.crst_i    (ram_rst_w || devtbl_rst2_w)
	,.cenable_i (1'b1)
	,.cmiss_i   (1'b0)
	,.conly_i   (ram_rst_w)

	,.m_pi1_op_i   (dcache_m_op_w)
	,.m_pi1_addr_i (dcache_m_addr_w)
	,.m_pi1_data_i (dcache_m_data_w1)
	,.m_pi1_data_o (dcache_m_data_w0)
	,.m_pi1_sel_i  (dcache_m_sel_w)
	,.m_pi1_rdy_o  (dcache_m_rdy_w)

	,.s_pi1_op_o   (dcache_s_op_w)
	,.s_pi1_addr_o (dcache_s_addr_w)
	,.s_pi1_data_i (dcache_s_data_w1)
	,.s_pi1_data_o (dcache_s_data_w0)
	,.s_pi1_sel_o  (dcache_s_sel_w)
	,.s_pi1_rdy_i  (dcache_s_rdy_w)
);

wire                                 wb4_clk_user_port_w;
wire                                 wb4_rst_user_port_w;
wire                                 wb4_cyc_user_port_w;
wire                                 wb4_stb_user_port_w;
wire                                 wb4_we_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_addr_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_data_user_port_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0] wb4_sel_user_port_w;
wire                                 wb4_stall_user_port_w;
wire                                 wb4_ack_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_data_user_port_w1;

pi1q_to_wb4 #(

	.ARCHBITSZ (LITEDRAM_ARCHBITSZ)

) pi1q_to_wb4_user_port (

	 .wb4_rst_i (wb4_rst_user_port_w)

	,.pi1_clk_i   (pi1r_clk_w)
	,.pi1_op_i    (dcache_s_op_w)
	,.pi1_addr_i  (dcache_s_addr_w)
	,.pi1_data_i  (dcache_s_data_w0)
	,.pi1_data_o  (dcache_s_data_w1)
	,.pi1_sel_i   (dcache_s_sel_w)
	,.pi1_rdy_o   (dcache_s_rdy_w)

	,.wb4_clk_i   (wb4_clk_user_port_w)
	,.wb4_cyc_o   (wb4_cyc_user_port_w)
	,.wb4_stb_o   (wb4_stb_user_port_w)
	,.wb4_we_o    (wb4_we_user_port_w)
	,.wb4_addr_o  (wb4_addr_user_port_w)
	,.wb4_data_o  (wb4_data_user_port_w0)
	,.wb4_sel_o   (wb4_sel_user_port_w)
	,.wb4_stall_i (wb4_stall_user_port_w)
	,.wb4_ack_i   (wb4_ack_user_port_w)
	,.wb4_data_i  (wb4_data_user_port_w1)
);

wire                        wb4_cyc_wb_ctrl_w;
wire                        wb4_stb_wb_ctrl_w;
wire                        wb4_we_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_addr_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_wb_ctrl_w0;
wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_wb_ctrl_w;
wire                        wb4_stall_wb_ctrl_w;
wire                        wb4_ack_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_wb_ctrl_w1;

pi1q_to_wb4 #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1q_to_wb4_wb_ctrl (

	 .wb4_rst_i (wb4_rst_user_port_w)

	,.pi1_clk_i   (pi1r_clk_w)
	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAMCTRL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAMCTRL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAMCTRL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAMCTRL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAMCTRL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAMCTRL])

	,.wb4_clk_i   (wb4_clk_user_port_w)
	,.wb4_cyc_o   (wb4_cyc_wb_ctrl_w)
	,.wb4_stb_o   (wb4_stb_wb_ctrl_w)
	,.wb4_we_o    (wb4_we_wb_ctrl_w)
	,.wb4_addr_o  (wb4_addr_wb_ctrl_w)
	,.wb4_data_o  (wb4_data_wb_ctrl_w0)
	,.wb4_sel_o   (wb4_sel_wb_ctrl_w)
	,.wb4_stall_i (wb4_stall_wb_ctrl_w)
	,.wb4_ack_i   (wb4_ack_wb_ctrl_w)
	,.wb4_data_i  (wb4_data_wb_ctrl_w1)
);

assign s_pi1r_mapsz_w[S_PI1R_RAMCTRL] = 'h4000 /* 64KB */;

litedram litedram (

	 .rst (ram_rst_w)

	,.clk (clk48mhz_i)

	,.init_done  (litedram_init_done)
	,.init_error (litedram_init_error)

	,.ddram_a       (ddr3l_a)
	,.ddram_ba      (ddr3l_ba)
	,.ddram_ras_n   (ddr3l_ras_n)
	,.ddram_cas_n   (ddr3l_cas_n)
	,.ddram_we_n    (ddr3l_we_n)
	,.ddram_cs_n    (ddr3l_cs_n)
	,.ddram_dm      (ddr3l_dm)
	,.ddram_dq      (ddr3l_dq)
	,.ddram_dqs_p   (ddr3l_dqs_p)
	,.ddram_clk_p   (ddr3l_clk_p)
	,.ddram_cke     (ddr3l_cke)
	,.ddram_odt     (ddr3l_odt)
	,.ddram_reset_n (ddr3l_reset_n)

	,.user_clk                   (wb4_clk_user_port_w)
	,.user_rst                   (wb4_rst_user_port_w)
	,.user_port_wishbone_0_adr   (wb4_addr_user_port_w[LITEDRAM_ARCHBITSZ -1 : clog2(LITEDRAM_ARCHBITSZ/8)])
	,.user_port_wishbone_0_dat_w (wb4_data_user_port_w0)
	,.user_port_wishbone_0_dat_r (wb4_data_user_port_w1)
	,.user_port_wishbone_0_sel   (wb4_sel_user_port_w)
	,.user_port_wishbone_0_cyc   (wb4_cyc_user_port_w)
	,.user_port_wishbone_0_stb   (wb4_stb_user_port_w)
	,.user_port_wishbone_0_ack   (wb4_ack_user_port_w)
	,.user_port_wishbone_0_we    (wb4_we_user_port_w)

	,.wb_ctrl_adr   (wb4_addr_wb_ctrl_w[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)])
	,.wb_ctrl_dat_w (wb4_data_wb_ctrl_w0)
	,.wb_ctrl_dat_r (wb4_data_wb_ctrl_w1)
	,.wb_ctrl_sel   (wb4_sel_wb_ctrl_w)
	,.wb_ctrl_cyc   (wb4_cyc_wb_ctrl_w)
	,.wb_ctrl_stb   (wb4_stb_wb_ctrl_w)
	,.wb_ctrl_ack   (wb4_ack_wb_ctrl_w)
	,.wb_ctrl_we    (wb4_we_wb_ctrl_w)
	,.wb_ctrl_cti   (3'b000)
	,.wb_ctrl_bte   (2'b00)
);

assign devtbl_id_w     [S_PI1R_RAMCTRL] = 0;
assign devtbl_useintr_w[S_PI1R_RAMCTRL] = 0;

bootldr #(

	 .ARCHBITSZ (ARCHBITSZ)

) bootldr (

	.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_BOOTLDR])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_BOOTLDR])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_BOOTLDR])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_BOOTLDR])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_BOOTLDR])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_BOOTLDR])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_BOOTLDR])
);

assign devtbl_id_w     [S_PI1R_BOOTLDR] = 0;
assign devtbl_useintr_w[S_PI1R_BOOTLDR] = 0;

// PI1RDEFAULTSLAVEINDEX to catch invalid physical address space access.
localparam INVALIDDEVMAPSZ = ('h1000/(ARCHBITSZ/8)) /* 4KB */;
//s_pi1r_op_w[S_PI1R_INVALIDDEV];
//s_pi1r_addr_w[S_PI1R_INVALIDDEV];
//s_pi1r_data_w0[S_PI1R_INVALIDDEV];
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {ARCHBITSZ{1'b0}};
//s_pi1r_sel_w[S_PI1R_INVALIDDEV];
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;
assign devtbl_id_w     [S_PI1R_INVALIDDEV] = 0;
assign devtbl_useintr_w[S_PI1R_INVALIDDEV] = 0;

endmodule
