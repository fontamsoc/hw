// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "./pll_100_to_50_100_200_mhz.v"

`include "lib/perint/pi1r.v"

`include "dev/pi1_downconverter.v"

`define PUMMU
`define PUHPTW
`define PUMULDIVCLK
`define PUFADDFSUBCLK
`define PUFMULCLK
`define PUFDIVCLK
`define PUDSPMUL
`define PUFADDFSUB
`define PUFMUL
`define PUDSPFMUL
`define PUFDIV
`define PUDCACHE
`define PUCOUNT 1 /* 16 max */
`include "pu/multipu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/gpio.v"

`include "dev/intctrl.v"

`include "dev/uart_hw.v"

`include "dev/pi1_upconverter.v"
`include "dev/pi1_dcache.v"
`include "dev/pi1q_to_wb4.v"
`include "./litedram/litedram.v"

`include "dev/bootldr/bootldr.v"

`include "dev/fbdev/fbdev_hdmi.v"

module nexysvideo (

	 rst_n

	,clk100mhz_i

	// SDCARD signals.
	,sd_sclk
	,sd_di
	,sd_do
	,sd_cs
	,sd_dat1
	,sd_dat2
	,sd_cd
	,sd_reset

	// GPIO signals.
	,gp_i
	,gp_o

	// UART signals.
	,uart_rx
	,uart_tx

	// DDR3 signals.
	,ddr3_ck_p
	,ddr3_ck_n
	,ddr3_cke
	,ddr3_odt
	//,ddr3_cs_n
	,ddr3_ras_n
	,ddr3_cas_n
	,ddr3_we_n
	,ddr3_ba
	,ddr3_addr
	,ddr3_dq
	,ddr3_dm
	,ddr3_dqs_p
	,ddr3_dqs_n
	,ddr3_reset_n

	// HDMI signals.
	,tmds_out_p
	,tmds_out_n
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_n;

(* clock_buffer_type = "BUFG" *)
input wire clk100mhz_i;

// SDCARD signals.
output wire sd_sclk;
output wire sd_di;
input  wire sd_do;
output wire sd_cs;
output wire sd_dat1;
output wire sd_dat2;
input  wire sd_cd;    // Becomes low when sdcard inserted.
output wire sd_reset; // Must be set low to power the SDCard.

assign sd_dat1 = 1;
assign sd_dat2 = 1;

// GPIO signals.
localparam GPIOCOUNT = 8;
input  wire [GPIOCOUNT -1 : 0] gp_i;
output wire [GPIOCOUNT -1 : 0] gp_o;

// UART signals.
input  wire uart_rx;
output wire uart_tx;

// DDR3 signals.
// Parameters for Micron MT41K256M16HA-187E.
localparam DDR3BANKCOUNT   = 8;
localparam DDR3ABITSIZE    = 15;
localparam DDR3DQBITSIZE   = 16;
output wire                               ddr3_ck_p;
output wire                               ddr3_ck_n;
output wire                               ddr3_cke;
output wire                               ddr3_odt;
//output wire                               ddr3_cs_n;
output wire                               ddr3_ras_n;
output wire                               ddr3_cas_n;
output wire                               ddr3_we_n;
output wire [clog2(DDR3BANKCOUNT) -1 : 0] ddr3_ba;
output wire [DDR3ABITSIZE -1 : 0]         ddr3_addr;
inout  wire [DDR3DQBITSIZE -1 : 0]        ddr3_dq;
output wire [(DDR3DQBITSIZE / 8) -1 : 0]  ddr3_dm;
inout  wire [(DDR3DQBITSIZE / 8) -1 : 0]  ddr3_dqs_p;
inout  wire [(DDR3DQBITSIZE / 8) -1 : 0]  ddr3_dqs_n;
output wire                               ddr3_reset_n;

// HDMI signals.
output wire [3:0] tmds_out_p;
output wire [3:0] tmds_out_n;

wire litedram_pll_locked;
wire litedram_init_done;
wire litedram_init_error;

wire multipu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

wire rst_p = !rst_n;

(* direct_reset = "true" *)
wire rst_w;

localparam CLKFREQ   = ( 50000000) /*  50 MHz */; // Frequency of clk_w.
localparam CLK2XFREQ = (100000000) /* 100 MHz */; // Frequency of clk_2x_w.
localparam CLK4XFREQ = (200000000) /* 200 MHz */; // Frequency of clk_4x_w.

wire pll_locked;

wire clk50mhz;
wire clk100mhz;
wire clk200mhz;
pll_100_to_50_100_200_mhz pll (
	 .reset    (1'b0)
	,.locked   (pll_locked)
	,.clk_in1  (clk100mhz_i)
	,.clk_out1 (clk50mhz)
	,.clk_out2 (clk100mhz)
	,.clk_out3 (clk200mhz)
);

wire clk_w    = clk50mhz;
wire clk_2x_w = clk100mhz;
wire clk_4x_w = clk200mhz;

STARTUPE2 startupe (.CLK (clk100mhz_i), .GSR (swcoldrst));

localparam RST_CNTR_BITSZ = 16;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk_2x_w) begin
	if (!multipu_rst_ow && !swwarmrst && rst_n) begin
		if (rst_cntr)
			rst_cntr <= rst_cntr - 1'b1;
	end else
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
end

always @ (posedge clk_2x_w) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

reg activity;
// Used to dim activity intensity.
localparam ACTIVITY_CNTR_BITSZ = 1;
reg [ACTIVITY_CNTR_BITSZ -1 : 0] activity_cntr = 0;
always @ (posedge clk_2x_w) begin
	if (activity_cntr) begin
		activity <= 0;
		activity_cntr <= activity_cntr - 1'b1;
	end else if ((~(sd_di & sd_do) || litedram_init_error)) begin
		activity <= 1;
		activity_cntr <= {ACTIVITY_CNTR_BITSZ{1'b1}};
	end
end

assign rst_w = (!pll_locked || devtbl_rst0_r || (|rst_cntr));

assign sd_reset = rst_w;

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_GPIO   = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRC_UART   = (INTCTRLSRC_GPIO + 1);
localparam INTCTRLSRCCOUNT   = (INTCTRLSRC_UART +1); // Number of interrupt source.
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
localparam S_PI1R_GPIO       = (S_PI1R_DEVTBL + 1);
localparam S_PI1R_INTCTRL    = (S_PI1R_GPIO + 1);
localparam S_PI1R_UART       = (S_PI1R_INTCTRL + 1);
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_RAMCTRL    = (S_PI1R_RAM + 1);
localparam S_PI1R_BOOTLDR    = (S_PI1R_RAMCTRL + 1);
localparam S_PI1R_FBDEV      = (S_PI1R_BOOTLDR + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_FBDEV + 1);

localparam LITEDRAM_ARCHBITSZ = 128;
localparam LITEDRAM_CLOG2ARCHBITSZBY8 = clog2(LITEDRAM_ARCHBITSZ/8);
localparam LITEDRAM_ADDRBITSZ = (LITEDRAM_ARCHBITSZ-LITEDRAM_CLOG2ARCHBITSZBY8);

localparam PI1RMASTERCOUNT       = (M_PI1R_LAST + 1);
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ((PUCOUNT > 4) ? ARCHBITSZ : LITEDRAM_ARCHBITSZ);
localparam CLOG2PI1RARCHBITSZBY8 = clog2(PI1RARCHBITSZ/8);
localparam PI1RADDRBITSZ         = (PI1RARCHBITSZ-CLOG2PI1RARCHBITSZBY8);
localparam PI1RCLKFREQ           = CLK2XFREQ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_2x_w;
// PerInt is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerInt:
// 	input  [2 -1 : 0]                 m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
// 	input  [PI1RADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
// 	output [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
// 	input  [(PI1RARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
// 	output                            m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];
// Slaves should use the following signals to plug onto PerInt:
// 	output [2 -1 : 0]                 s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
// 	output [PI1RADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
// 	output [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
// 	output [(PI1RARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
// 	input                             s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];
`include "lib/perint/inst.pi1r.v"

wire [(PI1RARCHBITSZ * PI1RSLAVECOUNT) -1 : 0] devtbl_id_flat_w;
wire [PI1RARCHBITSZ -1 : 0]                    devtbl_id_w           [PI1RSLAVECOUNT -1 : 0];
wire [(PI1RARCHBITSZ * PI1RSLAVECOUNT) -1 : 0] devtbl_mapsz_flat_w;
wire [PI1RSLAVECOUNT -1 : 0]                   devtbl_useintr_flat_w;
wire [PI1RSLAVECOUNT -1 : 0]                   devtbl_useintr_w;
genvar gen_devtbl_id_flat_w_idx;
generate for (gen_devtbl_id_flat_w_idx = 0; gen_devtbl_id_flat_w_idx < PI1RSLAVECOUNT; gen_devtbl_id_flat_w_idx = gen_devtbl_id_flat_w_idx + 1) begin :gen_devtbl_id_flat_w
assign devtbl_id_flat_w[((gen_devtbl_id_flat_w_idx+1) * PI1RARCHBITSZ) -1 : gen_devtbl_id_flat_w_idx * PI1RARCHBITSZ] = devtbl_id_w[gen_devtbl_id_flat_w_idx];
end endgenerate
assign devtbl_mapsz_flat_w = s_pi1r_mapsz_w_flat /* defined in "lib/perint/inst.pi1r.v" */;
assign devtbl_useintr_flat_w = devtbl_useintr_w;

localparam ICACHESZ = 512;
localparam DCACHESZ = 64;
localparam TLBSZ    = 64;

localparam ICACHEWAYCOUNT = ((PUCOUNT > 4) ? 2 : 4);
localparam DCACHEWAYCOUNT = ((PUCOUNT > 4) ? 1 : 2);
localparam TLBWAYCOUNT    = 1;

localparam MULTIPUCLKFREQ = CLK2XFREQ;
wire multipu_clk_w = clk_2x_w;

multipu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (PI1RARCHBITSZ)
	,.CLKFREQ        (MULTIPUCLKFREQ)
	,.ICACHESETCOUNT ((1024/(PI1RARCHBITSZ/8))*((ICACHESZ/ICACHEWAYCOUNT)/PUCOUNT))
	,.DCACHESETCOUNT ((1024/(PI1RARCHBITSZ/8))*((DCACHESZ/DCACHEWAYCOUNT)/PUCOUNT))
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.MULDIVCNT      (4)
	,.FADDFSUBCNT    (2)
	,.FMULCNT        (2)
	,.FDIVCNT        (4)

) multipu (

	 .rst_i (rst_w || !litedram_pll_locked)

	,.rst_o (multipu_rst_ow)

	,.clk_i          (multipu_clk_w)
	,.clk_muldiv_i   (clk_4x_w)
	,.clk_faddfsub_i (clk_4x_w)
	,.clk_fmul_i     (clk_4x_w)
	,.clk_fdiv_i     (clk_4x_w)
	`ifdef PUCOUNT
	,.clk_mem_i      (pi1r_clk_w)
	`endif

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
		(s_pi1r_mapsz_w[S_PI1R_RAM]>>1) +
		(s_pi1r_mapsz_w[S_PI1R_RAMCTRL]>>1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)
);

sdcard_spi #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (PI1RARCHBITSZ)
	,.CLKFREQ    (PI1RCLKFREQ)
	,.PHYCLKFREQ (CLK4XFREQ*2/* incorrect but helps as controller will run slower */)

) sdcard (

	 .rst_i (pi1r_rst_w || sd_cd)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk_4x_w)

	,.sclk_o (sd_sclk)
	,.di_o   (sd_di)
	,.do_i   (sd_do)
	,.cs_o   (sd_cs)

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

localparam RAMCACHEWAYCOUNT = 2;

localparam RAMCACHESZ = /* In (ARCHBITSZ/8) units */
	((1024/(ARCHBITSZ/8))*(128/RAMCACHEWAYCOUNT));

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (PI1RARCHBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	,.DEVMAPCNT  (PI1RSLAVECOUNT)
	,.SOCID      (3)

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

wire [2 -1 : 0]             gpio_op_w;
wire [ADDRBITSZ -1 : 0]     gpio_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] gpio_sel_w;
wire [ARCHBITSZ -1 : 0]     gpio_data_w1;
wire [ARCHBITSZ -1 : 0]     gpio_data_w0;
wire                        gpio_rdy_w;
wire [ADDRBITSZ -1 : 0]     gpio_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_gpio (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_GPIO])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_GPIO])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_GPIO])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_GPIO])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_GPIO])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_GPIO])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_GPIO])
	,.s_pi1_op_o (gpio_op_w)
	,.s_pi1_addr_o (gpio_addr_w)
	,.s_pi1_data_o (gpio_data_w1)
	,.s_pi1_data_i (gpio_data_w0)
	,.s_pi1_sel_o (gpio_sel_w)
	,.s_pi1_rdy_i (gpio_rdy_w)
	,.s_pi1_mapsz_i (gpio_mapsz_w)
);

wire [GPIOCOUNT -1 : 0] gpio_o;

gpio #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.CLKFREQ    (PI1RCLKFREQ)
	,.IOCOUNT    (GPIOCOUNT)

) gpio (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (gpio_op_w)
	,.pi1_addr_i  (gpio_addr_w)
	,.pi1_data_i  (gpio_data_w1)
	,.pi1_data_o  (gpio_data_w0)
	,.pi1_sel_i   (gpio_sel_w)
	,.pi1_rdy_o   (gpio_rdy_w)
	,.pi1_mapsz_o (gpio_mapsz_w)

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_GPIO])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_GPIO])

	,.i (gp_i)
	,.o (gpio_o)
);

assign devtbl_id_w     [S_PI1R_GPIO] = 6;
assign devtbl_useintr_w[S_PI1R_GPIO] = 1;

assign gp_o = ({{(GPIOCOUNT-1){1'b0}}, activity} | gpio_o);

wire [2 -1 : 0]             intctrl_op_w;
wire [ADDRBITSZ -1 : 0]     intctrl_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] intctrl_sel_w;
wire [ARCHBITSZ -1 : 0]     intctrl_data_w1;
wire [ARCHBITSZ -1 : 0]     intctrl_data_w0;
wire                        intctrl_rdy_w;
wire [ADDRBITSZ -1 : 0]     intctrl_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_intctrl (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_INTCTRL])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_INTCTRL])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_INTCTRL])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_INTCTRL])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_INTCTRL])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_INTCTRL])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_INTCTRL])
	,.s_pi1_op_o (intctrl_op_w)
	,.s_pi1_addr_o (intctrl_addr_w)
	,.s_pi1_data_o (intctrl_data_w1)
	,.s_pi1_data_i (intctrl_data_w0)
	,.s_pi1_sel_o (intctrl_sel_w)
	,.s_pi1_rdy_i (intctrl_rdy_w)
	,.s_pi1_mapsz_i (intctrl_mapsz_w)
);

intctrl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.INTSRCCOUNT (INTCTRLSRCCOUNT)
	,.INTDSTCOUNT (INTCTRLDSTCOUNT)

) intctrl (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (intctrl_op_w)
	,.pi1_addr_i  (intctrl_addr_w)
	,.pi1_data_i  (intctrl_data_w1)
	,.pi1_data_o  (intctrl_data_w0)
	,.pi1_sel_i   (intctrl_sel_w)
	,.pi1_rdy_o   (intctrl_rdy_w)
	,.pi1_mapsz_o (intctrl_mapsz_w)

	,.intrqstdst_o (intrqstdst_w)
	,.intrdydst_i  (intrdydst_w)
	,.intbestdst_i (intbestdst_w)

	,.intrqstsrc_i (intrqstsrc_w)
	,.intrdysrc_o  (intrdysrc_w)
);

assign devtbl_id_w     [S_PI1R_INTCTRL] = 3;
assign devtbl_useintr_w[S_PI1R_INTCTRL] = 0;

wire [2 -1 : 0]             uart_op_w;
wire [ADDRBITSZ -1 : 0]     uart_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] uart_sel_w;
wire [ARCHBITSZ -1 : 0]     uart_data_w1;
wire [ARCHBITSZ -1 : 0]     uart_data_w0;
wire                        uart_rdy_w;
wire [ADDRBITSZ -1 : 0]     uart_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_uart (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_UART])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_UART])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_UART])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_UART])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_UART])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_UART])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])
	,.s_pi1_op_o (uart_op_w)
	,.s_pi1_addr_o (uart_addr_w)
	,.s_pi1_data_o (uart_data_w1)
	,.s_pi1_data_i (uart_data_w0)
	,.s_pi1_sel_o (uart_sel_w)
	,.s_pi1_rdy_i (uart_rdy_w)
	,.s_pi1_mapsz_i (uart_mapsz_w)
);

uart_hw #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (PI1RCLKFREQ)
	,.BUFSZ      (4096)

) uart (

	 .rst_i (!pll_locked || rst_p
		/* pi1r_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)
	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (pi1r_clk_w)

	,.pi1_op_i    (uart_op_w)
	,.pi1_addr_i  (uart_addr_w)
	,.pi1_data_i  (uart_data_w1)
	,.pi1_data_o  (uart_data_w0)
	,.pi1_sel_i   (uart_sel_w)
	,.pi1_rdy_o   (uart_rdy_w)
	,.pi1_mapsz_o (uart_mapsz_w)

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_UART])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_UART])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

assign devtbl_id_w     [S_PI1R_UART] = 5;
assign devtbl_useintr_w[S_PI1R_UART] = 1;

wire [2 -1 : 0]                                                  dcache_m_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] dcache_m_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w1;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             dcache_m_sel_w;
wire                                                             dcache_m_rdy_w;

pi1_upconverter #(

	 .MARCHBITSZ (PI1RARCHBITSZ)
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

assign s_pi1r_mapsz_w[S_PI1R_RAM] = ('h20000000/* 512MB */);

assign devtbl_id_w     [S_PI1R_RAM] = 1;
assign devtbl_useintr_w[S_PI1R_RAM] = 0;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk100mhz_i) begin
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

wire [PI1RADDRBITSZ -1 : 0] fbdev_first_addr_w;
wire [PI1RADDRBITSZ -1 : 0] fbdev_last_addr_w;

pi1_dcache #(

	 .ARCHBITSZ     (LITEDRAM_ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ/(LITEDRAM_ARCHBITSZ/ARCHBITSZ))
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.BUFFERDEPTH   (64)
	,.INITFILE      ("litedram.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.crst_i    (ram_rst_w || devtbl_rst2_w)
	,.cenable_i (
		(dcache_m_addr_w < fbdev_first_addr_w[PI1RADDRBITSZ-1:(LITEDRAM_CLOG2ARCHBITSZBY8-CLOG2PI1RARCHBITSZBY8)]) ||
			(dcache_m_addr_w >= (fbdev_last_addr_w[PI1RADDRBITSZ-1:(LITEDRAM_CLOG2ARCHBITSZBY8-CLOG2PI1RARCHBITSZBY8)]+1)))
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

wire [2 -1 : 0]                                                  _fbdev_m_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] _fbdev_m_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 _fbdev_m_data_w0;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 _fbdev_m_data_w1;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             _fbdev_m_sel_w;
wire                                                             _fbdev_m_rdy_w;

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

	 .MASTERCOUNT (2)
	,.ARCHBITSZ   (LITEDRAM_ARCHBITSZ)

) pi1q_to_wb4_user_port (

	 .wb4_rst_i (wb4_rst_user_port_w)

	,.pi1_clk_i   (pi1r_clk_w)
	,.pi1_op_i    ({dcache_s_op_w, _fbdev_m_op_w})
	,.pi1_addr_i  ({dcache_s_addr_w, _fbdev_m_addr_w})
	,.pi1_data_i  ({dcache_s_data_w0, _fbdev_m_data_w0})
	,.pi1_data_o  ({dcache_s_data_w1, _fbdev_m_data_w1})
	,.pi1_sel_i   ({dcache_s_sel_w, _fbdev_m_sel_w})
	,.pi1_rdy_o   ({dcache_s_rdy_w, _fbdev_m_rdy_w})

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

wire [2 -1 : 0]             litedram_ctrl_op_w;
wire [ADDRBITSZ -1 : 0]     litedram_ctrl_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] litedram_ctrl_sel_w;
wire [ARCHBITSZ -1 : 0]     litedram_ctrl_data_w1;
wire [ARCHBITSZ -1 : 0]     litedram_ctrl_data_w0;
wire                        litedram_ctrl_rdy_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_litedram_ctrl (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_RAMCTRL])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_RAMCTRL])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_RAMCTRL])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_RAMCTRL])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_RAMCTRL])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_RAMCTRL])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_RAMCTRL])
	,.s_pi1_op_o (litedram_ctrl_op_w)
	,.s_pi1_addr_o (litedram_ctrl_addr_w)
	,.s_pi1_data_o (litedram_ctrl_data_w1)
	,.s_pi1_data_i (litedram_ctrl_data_w0)
	,.s_pi1_sel_o (litedram_ctrl_sel_w)
	,.s_pi1_rdy_i (litedram_ctrl_rdy_w)
	,.s_pi1_mapsz_i ('h10000/* 64KB */)
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
	,.pi1_op_i    (litedram_ctrl_op_w)
	,.pi1_addr_i  (litedram_ctrl_addr_w)
	,.pi1_data_i  (litedram_ctrl_data_w1)
	,.pi1_data_o  (litedram_ctrl_data_w0)
	,.pi1_sel_i   (litedram_ctrl_sel_w)
	,.pi1_rdy_o   (litedram_ctrl_rdy_w)

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

litedram litedram (

	 .rst (ram_rst_w)

	,.clk (clk100mhz_i)

	,.pll_locked (litedram_pll_locked)
	,.init_done  (litedram_init_done)
	,.init_error (litedram_init_error)

	,.ddram_a       (ddr3_addr)
	,.ddram_ba      (ddr3_ba)
	,.ddram_ras_n   (ddr3_ras_n)
	,.ddram_cas_n   (ddr3_cas_n)
	,.ddram_we_n    (ddr3_we_n)
	//,.ddram_cs_n    (ddr3_cs_n)
	,.ddram_dm      (ddr3_dm)
	,.ddram_dq      (ddr3_dq)
	,.ddram_dqs_p   (ddr3_dqs_p)
	,.ddram_dqs_n   (ddr3_dqs_n)
	,.ddram_clk_p   (ddr3_ck_p)
	,.ddram_clk_n   (ddr3_ck_n)
	,.ddram_cke     (ddr3_cke)
	,.ddram_odt     (ddr3_odt)
	,.ddram_reset_n (ddr3_reset_n)

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

	 .ARCHBITSZ (PI1RARCHBITSZ)

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

wire [2 -1 : 0]                 fbdev_m_op_w;
wire [PI1RADDRBITSZ -1 : 0]     fbdev_m_addr_w;
wire [PI1RARCHBITSZ -1 : 0]     fbdev_m_data_w0;
wire [PI1RARCHBITSZ -1 : 0]     fbdev_m_data_w1;
wire [(PI1RARCHBITSZ/8) -1 : 0] fbdev_m_sel_w;
wire                            fbdev_m_rdy_w;

pi1_upconverter #(

	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (LITEDRAM_ARCHBITSZ)

) fbdev_m_upconverter (

	 .clk_i (pi1r_clk_w)

	,.m_pi1_op_i   (fbdev_m_op_w)
	,.m_pi1_addr_i (fbdev_m_addr_w)
	,.m_pi1_data_i (fbdev_m_data_w0)
	,.m_pi1_data_o (fbdev_m_data_w1)
	,.m_pi1_sel_i  (fbdev_m_sel_w)
	,.m_pi1_rdy_o  (fbdev_m_rdy_w)

	,.s_pi1_op_o   (_fbdev_m_op_w)
	,.s_pi1_addr_o (_fbdev_m_addr_w)
	,.s_pi1_data_o (_fbdev_m_data_w0)
	,.s_pi1_data_i (_fbdev_m_data_w1)
	,.s_pi1_sel_o  (_fbdev_m_sel_w)
	,.s_pi1_rdy_i  (_fbdev_m_rdy_w)
);

fbdev_hdmi #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (PI1RARCHBITSZ)
	,.WIDTH      (!0 ? 640 : 800 /* 1280*/)
	,.HEIGHT     (!0 ? 480 : 600 /* 720*/)
	,.REFRESH    (!0 ? 60  : 72  /* 60*/)
	,.BUFSZ      (1024*8)

) fbdev (

	 .rst_i (pi1r_rst_w)

	,.pi1_clk_i   (pi1r_clk_w)
	,.clk100mhz_i (clk100mhz_i)

	,.m_pi1_op_o   (fbdev_m_op_w)
	,.m_pi1_addr_o (fbdev_m_addr_w)
	,.m_pi1_data_o (fbdev_m_data_w0)
	,.m_pi1_data_i (fbdev_m_data_w1)
	,.m_pi1_sel_o  (fbdev_m_sel_w)
	,.m_pi1_rdy_i  (fbdev_m_rdy_w)

	,.s_pi1_op_i    (s_pi1r_op_w[S_PI1R_FBDEV])
	,.s_pi1_addr_i  (s_pi1r_addr_w[S_PI1R_FBDEV])
	,.s_pi1_data_i  (s_pi1r_data_w0[S_PI1R_FBDEV])
	,.s_pi1_data_o  (s_pi1r_data_w1[S_PI1R_FBDEV])
	,.s_pi1_sel_i   (s_pi1r_sel_w[S_PI1R_FBDEV])
	,.s_pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_FBDEV])
	,.s_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_FBDEV])

	,.pxdat_first_addr_o (fbdev_first_addr_w)
	,.pxdat_last_addr_o (fbdev_last_addr_w)

	,.tmds_out_p (tmds_out_p)
	,.tmds_out_n (tmds_out_n)
);

assign devtbl_id_w     [S_PI1R_FBDEV] = 10;
assign devtbl_useintr_w[S_PI1R_FBDEV] = 0;

// PI1RDEFAULTSLAVEINDEX to catch invalid physical address space access.
localparam INVALIDDEVMAPSZ = ('h1000/* 4KB */);
//s_pi1r_op_w[S_PI1R_INVALIDDEV];
//s_pi1r_addr_w[S_PI1R_INVALIDDEV];
//s_pi1r_data_w0[S_PI1R_INVALIDDEV];
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {PI1RARCHBITSZ{1'b0}};
//s_pi1r_sel_w[S_PI1R_INVALIDDEV];
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;
assign devtbl_id_w     [S_PI1R_INVALIDDEV] = 0;
assign devtbl_useintr_w[S_PI1R_INVALIDDEV] = 0;

endmodule
