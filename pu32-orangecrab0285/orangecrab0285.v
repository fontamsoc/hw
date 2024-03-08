// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/wb_arbiter.v"
`include "lib/wb_mux.v"
`include "lib/wb_dnsizr.v"

`define PUMMU
`define PUHPTW
`define PUIMULCLK
`define PUIDIVCLK
`define PUFADDFSUBCLK
`define PUFMULCLK
`define PUFDIVCLK
`define PUIMULDSP
`define PUFADDFSUB
`define PUFMUL
`define PUFMULDSP
`define PUFDIV
`define PUDCACHE
`define PUCOUNT 1 /* 2 max */
`include "pu/cpu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/irqctrl.v"

`include "dev/usb_serial.v"

`include "dev/dcache.v"
`include "lib/wb_cdc.v"
`include "./litedram/litedram.v"

`include "dev/bootldr/bootldr.v"

module orangecrab0285 (

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
// Parameters for Micron MT41K256M16TW DDR3L.
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

wire cpu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

wire rst_p = !usr_btn_n;

localparam CLKFREQ12MHZ = 12000000;
localparam CLKFREQ24MHZ = 24000000;
localparam CLKFREQ48MHZ = 48000000;
localparam CLKFREQ96MHZ = 96000000;

localparam CLK1XFREQ = CLKFREQ12MHZ; // Frequency of clk_1x_w.
localparam CLK2XFREQ = CLKFREQ24MHZ; // Frequency of clk_2x_w.
localparam CLK4XFREQ = CLKFREQ48MHZ; // Frequency of clk_4x_w.
localparam CLK8XFREQ = CLKFREQ96MHZ; // Frequency of clk_8x_w.

wire [3:0] pll_clk_w;
wire       pll_locked;
ecp5pll #(

	 .in_hz    (CLKFREQ48MHZ)
	,.out0_hz  (CLK1XFREQ)
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

wire clk_1x_w = clk12mhz;
wire clk_2x_w = clk24mhz;
wire clk_4x_w = clk48mhz;
wire clk_8x_w = clk96mhz;

//GSR GSR_INST (.GSR (~swcoldrst));

localparam RST_CNTR_BITSZ = 16;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk_4x_w) begin
	if (!cpu_rst_ow && !swwarmrst && usr_btn_n) begin
		if (rst_cntr)
			rst_cntr <= rst_cntr - 1'b1;
	end else
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
end

always @ (posedge clk_4x_w) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

wire rst_w = (!pll_locked || devtbl_rst0_r || (|rst_cntr));

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_SDCARD     = 0;
localparam S_WBPI_DEVTBL     = (S_WBPI_SDCARD + 1);
localparam S_WBPI_IRQCTRL    = (S_WBPI_DEVTBL + 1);
localparam S_WBPI_SERIAL     = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_RAM        = (S_WBPI_SERIAL + 1);
localparam S_WBPI_RAMCTRL    = (S_WBPI_RAM + 1);
localparam S_WBPI_BOOTLDR    = (S_WBPI_RAMCTRL + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_BOOTLDR + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = 0;
localparam WBPI_DNSIZR            = 8'b00101110;
localparam WBPI_ARCHBITSZ         = 128/* RAM ARCHBITSZ */;
localparam WBPI_CLOG2ARCHBITSZBY8 = clog2(WBPI_ARCHBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_ARCHBITSZ - WBPI_CLOG2ARCHBITSZBY8);
localparam WBPI_CLKFREQ           = CLK2XFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_2x_w;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                              m_wbpi_cyc_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_stb_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_we_w   [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_ADDRBITSZ -1 : 0]     m_wbpi_addr_w [WBPI_MASTERCOUNT -1 : 0];
// 	input  [(WBPI_ARCHBITSZ/8) -1 : 0] m_wbpi_sel_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dati_w [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_bsy_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_ack_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output [WBPI_ARCHBITSZ -1 : 0]     m_wbpi_dato_w [WBPI_MASTERCOUNT -1 : 0];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                             s_wbpi_cyc_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_stb_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_we_w    [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_ADDRBITSZ -1 : 0]     s_wbpi_addr_w  [WBPI_SLAVECOUNT -1 : 0];
// 	output [(WBPI_ARCHBITSZ/8) -1 : 0] s_wbpi_sel_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dato_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_bsy_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_ack_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input  [WBPI_ARCHBITSZ -1 : 0]     s_wbpi_dati_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]          s_wbpi_mapsz_w [WBPI_SLAVECOUNT -1 : 0];
// If "dev/devtbl.v" was included, slave devices must also use following signals:
// 	input  [ARCHBITSZ -1 : 0]          dev_id_w       [WBPI_SLAVECOUNT -1 : 0];
// 	input                              dev_useirq_w   [WBPI_SLAVECOUNT -1 : 0];
`include "lib/wbpi_inst.v"

localparam IRQ_SDCARD = 0;
localparam IRQ_SERIAL = (IRQ_SDCARD + 1);

localparam IRQSRCCOUNT = (IRQ_SERIAL +1); // Number of interrupt source.
localparam IRQDSTCOUNT = PUCOUNT; // Number of interrupt destination.
wire [IRQSRCCOUNT -1 : 0] irq_src_stb_w;
wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_w;

localparam ICACHESZ = 64;
localparam DCACHESZ = 16;
localparam TLBSZ    = 64;

localparam ICACHEWAYCOUNT = 2;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 1;

cpu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (WBPI_ARCHBITSZ)
	,.CLKFREQ        (CLK2XFREQ)
	,.ICACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*((ICACHESZ/ICACHEWAYCOUNT)/PUCOUNT))
	,.DCACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*((DCACHESZ/DCACHEWAYCOUNT)/PUCOUNT))
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.IMULCNT        (2)
	,.IDIVCNT        (4)
	,.FADDFSUBCNT    (2)
	,.FMULCNT        (2)
	,.FDIVCNT        (4)

) cpu (

	 .rst_i (rst_w)

	,.rst_o (cpu_rst_ow)

	,.clk_i          (clk_2x_w)
	,.clk_imul_i     (clk_8x_w)
	,.clk_idiv_i     (clk_8x_w)
	,.clk_faddfsub_i (clk_4x_w)
	,.clk_fmul_i     (clk_4x_w)
	,.clk_fdiv_i     (clk_4x_w)
	`ifdef PUCOUNT
	,.clk_mem_i      (wbpi_clk_w)
	`endif

	,.wb_cyc_o  (m_wbpi_cyc_w[M_WBPI_CPU])
	,.wb_stb_o  (m_wbpi_stb_w[M_WBPI_CPU])
	,.wb_we_o   (m_wbpi_we_w[M_WBPI_CPU])
	,.wb_addr_o (m_wbpi_addr_w[M_WBPI_CPU])
	,.wb_sel_o  (m_wbpi_sel_w[M_WBPI_CPU])
	,.wb_dat_o  (m_wbpi_dati_w[M_WBPI_CPU])
	,.wb_bsy_i  (m_wbpi_bsy_w[M_WBPI_CPU])
	,.wb_ack_i  (m_wbpi_ack_w[M_WBPI_CPU])
	,.wb_dat_i  (m_wbpi_dato_w[M_WBPI_CPU])

	,.irq_stb_i (irq_dst_stb_w)
	,.irq_rdy_o (irq_dst_rdy_w)
	,.halted_o  (irq_dst_pri_w)

	,.rstaddr_i  ((('h1000)>>1) +
		(s_wbpi_mapsz_w[S_WBPI_RAM]>>1) +
		(s_wbpi_mapsz_w[S_WBPI_RAMCTRL]>>1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)
);

sdcard_spi #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (WBPI_ARCHBITSZ)
	,.CLKFREQ    (WBPI_CLKFREQ)
	,.PHYCLKFREQ (CLK8XFREQ)

) sdcard (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (clk_8x_w)

	,.sclk_o (sdcard_clk)
	,.di_o   (sdcard_di)
	,.do_i   (sdcard_do)
	,.cs_o   (sdcard_cs_n)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_SDCARD])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SDCARD])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SDCARD])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SDCARD])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SDCARD])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SDCARD])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SDCARD])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SDCARD])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SDCARD])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_SDCARD])

	,.irq_stb_o (irq_src_stb_w[IRQ_SDCARD])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SDCARD])
);

assign dev_id_w    [S_WBPI_SDCARD] = 4;
assign dev_useirq_w[S_WBPI_SDCARD] = 1;

localparam RAMCACHEWAYCOUNT = 2;

localparam RAMCACHESZ = /* In (ARCHBITSZ/8) units */
	((1024/(ARCHBITSZ/8))*(32/RAMCACHEWAYCOUNT));

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	,.DEVMAPCNT  (WBPI_SLAVECOUNT)
	,.SOCID      (6)

) devtbl (

	 .rst_i (wbpi_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	,.rst2_o (devtbl_rst2_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_DEVTBL])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_DEVTBL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_DEVTBL])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_DEVTBL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_DEVTBL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_DEVTBL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_DEVTBL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_DEVTBL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_DEVTBL])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_DEVTBL])

	,.dev_id_i     (devtbl_id_w)
	,.dev_mapsz_i  (devtbl_mapsz_w)
	,.dev_useirq_i (devtbl_useirq_w)
);

assign dev_id_w    [S_WBPI_DEVTBL] = 7;
assign dev_useirq_w[S_WBPI_DEVTBL] = 0;

irqctrl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.IRQSRCCOUNT (IRQSRCCOUNT)
	,.IRQDSTCOUNT (IRQDSTCOUNT)

) irqctrl (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_IRQCTRL])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_IRQCTRL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_IRQCTRL])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_IRQCTRL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_IRQCTRL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_IRQCTRL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_IRQCTRL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_IRQCTRL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_IRQCTRL])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_IRQCTRL])

	,.irq_dst_stb_o (irq_dst_stb_w)
	,.irq_dst_rdy_i (irq_dst_rdy_w)
	,.irq_dst_pri_i (irq_dst_pri_w)

	,.irq_src_stb_i (irq_src_stb_w)
	,.irq_src_rdy_o (irq_src_rdy_w)
);

assign dev_id_w    [S_WBPI_IRQCTRL] = 3;
assign dev_useirq_w[S_WBPI_IRQCTRL] = 0;

usb_serial #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz or 60MHz.
	,.BUFSZ      (4096)

) serial (

	 .rst_i (!pll_locked
		/* wbpi_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (clk48mhz)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_SERIAL])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SERIAL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SERIAL])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SERIAL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SERIAL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SERIAL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SERIAL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SERIAL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SERIAL])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_SERIAL])

	,.irq_stb_o (irq_src_stb_w[IRQ_SERIAL])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SERIAL])

	,.usb_dp_io (usb_d_p)
	,.usb_dn_io (usb_d_n)
);

assign dev_id_w    [S_WBPI_SERIAL] = 5;
assign dev_useirq_w[S_WBPI_SERIAL] = 1;

wire wb_rst_user_port_w;
wire wb_clk_user_port_w;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk48mhz_i) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

reg conly_r;
always @ (posedge wbpi_clk_w) begin
	if (ram_rst_w)
		conly_r <= 1;
	else if (devtbl_rst2_w)
		conly_r <= 0;
end

wire                             dcache_wb_cyc_w;
wire                             dcache_wb_stb_w;
wire                             dcache_wb_we_w;
wire [WBPI_ADDRBITSZ -1 : 0]     dcache_wb_addr_w;
wire [(WBPI_ARCHBITSZ/8) -1 : 0] dcache_wb_sel_w;
wire [WBPI_ARCHBITSZ -1 : 0]     dcache_wb_dato_w;
wire                             dcache_wb_bsy_w;
wire                             dcache_wb_ack_w;
wire [WBPI_ARCHBITSZ -1 : 0]     dcache_wb_dati_w;

dcache #(

	 .ARCHBITSZ     (WBPI_ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ/(WBPI_ARCHBITSZ/ARCHBITSZ))
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.INITFILE      ("litedram.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (wbpi_clk_w)

	,.conly_i (conly_r)
	,.cmiss_i (1'b0)

	,.m_wb_cyc_i  (s_wbpi_cyc_w[S_WBPI_RAM])
	,.m_wb_stb_i  (s_wbpi_stb_w[S_WBPI_RAM])
	,.m_wb_we_i   (s_wbpi_we_w[S_WBPI_RAM])
	,.m_wb_addr_i (s_wbpi_addr_w[S_WBPI_RAM])
	,.m_wb_sel_i  (s_wbpi_sel_w[S_WBPI_RAM])
	,.m_wb_dat_i  (s_wbpi_dato_w[S_WBPI_RAM])
	,.m_wb_bsy_o  (s_wbpi_bsy_w[S_WBPI_RAM])
	,.m_wb_ack_o  (s_wbpi_ack_w[S_WBPI_RAM])
	,.m_wb_dat_o  (s_wbpi_dati_w[S_WBPI_RAM])

	,.s_wb_cyc_o  (dcache_wb_cyc_w)
	,.s_wb_stb_o  (dcache_wb_stb_w)
	,.s_wb_we_o   (dcache_wb_we_w)
	,.s_wb_addr_o (dcache_wb_addr_w)
	,.s_wb_sel_o  (dcache_wb_sel_w)
	,.s_wb_dat_o  (dcache_wb_dato_w)
	,.s_wb_bsy_i  (dcache_wb_bsy_w)
	,.s_wb_ack_i  (dcache_wb_ack_w)
	,.s_wb_dat_i  (dcache_wb_dati_w)
);

wire                             dcache_wb_cdc_wb_cyc_w;
wire                             dcache_wb_cdc_wb_stb_w;
wire                             dcache_wb_cdc_wb_we_w;
wire [WBPI_ADDRBITSZ -1 : 0]     dcache_wb_cdc_wb_addr_w;
wire [(WBPI_ARCHBITSZ/8) -1 : 0] dcache_wb_cdc_wb_sel_w;
wire [WBPI_ARCHBITSZ -1 : 0]     dcache_wb_cdc_wb_dato_w;
wire                             dcache_wb_cdc_wb_bsy_w;
wire                             dcache_wb_cdc_wb_ack_w;
wire [WBPI_ARCHBITSZ -1 : 0]     dcache_wb_cdc_wb_dati_w;

wb_cdc #(

	.ARCHBITSZ (WBPI_ARCHBITSZ)

) dcache_wb_cdc (

	 .rst_i (wb_rst_user_port_w)

	,.m_clk_i (wbpi_clk_w)
	,.s_clk_i (wb_clk_user_port_w)

	,.m_wb_cyc_i  (dcache_wb_cyc_w)
	,.m_wb_stb_i  (dcache_wb_stb_w)
	,.m_wb_we_i   (dcache_wb_we_w)
	,.m_wb_addr_i (dcache_wb_addr_w)
	,.m_wb_sel_i  (dcache_wb_sel_w)
	,.m_wb_dat_i  (dcache_wb_dato_w)
	,.m_wb_bsy_o  (dcache_wb_bsy_w)
	,.m_wb_ack_o  (dcache_wb_ack_w)
	,.m_wb_dat_o  (dcache_wb_dati_w)

	,.s_wb_cyc_o  (dcache_wb_cdc_wb_cyc_w)
	,.s_wb_stb_o  (dcache_wb_cdc_wb_stb_w)
	,.s_wb_we_o   (dcache_wb_cdc_wb_we_w)
	,.s_wb_addr_o (dcache_wb_cdc_wb_addr_w)
	,.s_wb_sel_o  (dcache_wb_cdc_wb_sel_w)
	,.s_wb_dat_o  (dcache_wb_cdc_wb_dato_w)
	,.s_wb_bsy_i  (1'b0)
	,.s_wb_ack_i  (dcache_wb_cdc_wb_ack_w)
	,.s_wb_dat_i  (dcache_wb_cdc_wb_dati_w)
);

wire                        ramctrl_wb_cdc_wb_cyc_w;
wire                        ramctrl_wb_cdc_wb_stb_w;
wire                        ramctrl_wb_cdc_wb_we_w;
wire [ADDRBITSZ -1 : 0]     ramctrl_wb_cdc_wb_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] ramctrl_wb_cdc_wb_sel_w;
wire [ARCHBITSZ -1 : 0]     ramctrl_wb_cdc_wb_dato_w;
wire                        ramctrl_wb_cdc_wb_bsy_w;
wire                        ramctrl_wb_cdc_wb_ack_w;
wire [ARCHBITSZ -1 : 0]     ramctrl_wb_cdc_wb_dati_w;

wb_cdc #(

	.ARCHBITSZ (ARCHBITSZ)

) ramctrl_wb_cdc (

	 .rst_i (wb_rst_user_port_w)

	,.m_clk_i (wbpi_clk_w)
	,.s_clk_i (wb_clk_user_port_w)

	,.m_wb_cyc_i  (s_wbpi_cyc_w[S_WBPI_RAMCTRL])
	,.m_wb_stb_i  (s_wbpi_stb_w[S_WBPI_RAMCTRL])
	,.m_wb_we_i   (s_wbpi_we_w[S_WBPI_RAMCTRL])
	,.m_wb_addr_i (s_wbpi_addr_w[S_WBPI_RAMCTRL])
	,.m_wb_sel_i  (s_wbpi_sel_w[S_WBPI_RAMCTRL])
	,.m_wb_dat_i  (s_wbpi_dato_w[S_WBPI_RAMCTRL])
	,.m_wb_bsy_o  (s_wbpi_bsy_w[S_WBPI_RAMCTRL])
	,.m_wb_ack_o  (s_wbpi_ack_w[S_WBPI_RAMCTRL])
	,.m_wb_dat_o  (s_wbpi_dati_w[S_WBPI_RAMCTRL])

	,.s_wb_cyc_o  (ramctrl_wb_cdc_wb_cyc_w)
	,.s_wb_stb_o  (ramctrl_wb_cdc_wb_stb_w)
	,.s_wb_we_o   (ramctrl_wb_cdc_wb_we_w)
	,.s_wb_addr_o (ramctrl_wb_cdc_wb_addr_w)
	,.s_wb_sel_o  (ramctrl_wb_cdc_wb_sel_w)
	,.s_wb_dat_o  (ramctrl_wb_cdc_wb_dato_w)
	,.s_wb_bsy_i  (1'b0)
	,.s_wb_ack_i  (ramctrl_wb_cdc_wb_ack_w)
	,.s_wb_dat_i  (ramctrl_wb_cdc_wb_dati_w)
);

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

	,.user_clk (wb_clk_user_port_w)
	,.user_rst (wb_rst_user_port_w)

	,.user_port_wishbone_0_cyc   (dcache_wb_cdc_wb_cyc_w)
	,.user_port_wishbone_0_stb   (dcache_wb_cdc_wb_stb_w)
	,.user_port_wishbone_0_we    (dcache_wb_cdc_wb_we_w)
	,.user_port_wishbone_0_adr   (dcache_wb_cdc_wb_addr_w)
	,.user_port_wishbone_0_sel   (dcache_wb_cdc_wb_sel_w)
	,.user_port_wishbone_0_dat_w (dcache_wb_cdc_wb_dato_w)
	,.user_port_wishbone_0_ack   (dcache_wb_cdc_wb_ack_w)
	,.user_port_wishbone_0_dat_r (dcache_wb_cdc_wb_dati_w)

	,.wb_ctrl_cyc   (ramctrl_wb_cdc_wb_cyc_w)
	,.wb_ctrl_stb   (ramctrl_wb_cdc_wb_stb_w)
	,.wb_ctrl_we    (ramctrl_wb_cdc_wb_we_w)
	,.wb_ctrl_adr   (ramctrl_wb_cdc_wb_addr_w)
	,.wb_ctrl_sel   (ramctrl_wb_cdc_wb_sel_w)
	,.wb_ctrl_dat_w (ramctrl_wb_cdc_wb_dato_w)
	,.wb_ctrl_ack   (ramctrl_wb_cdc_wb_ack_w)
	,.wb_ctrl_dat_r (ramctrl_wb_cdc_wb_dati_w)
	,.wb_ctrl_cti   (3'b000)
	,.wb_ctrl_bte   (2'b00)
);

assign s_wbpi_mapsz_w[S_WBPI_RAM] = ('h20000000/* 512MB */);

assign dev_id_w    [S_WBPI_RAM] = 1;
assign dev_useirq_w[S_WBPI_RAM] = 0;

assign s_wbpi_mapsz_w[S_WBPI_RAMCTRL] = ('h10000/* 64KB */);

assign dev_id_w    [S_WBPI_RAMCTRL] = 0;
assign dev_useirq_w[S_WBPI_RAMCTRL] = 0;

bootldr #(

	 .ARCHBITSZ (WBPI_ARCHBITSZ)

) bootldr (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_BOOTLDR])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_BOOTLDR])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_BOOTLDR])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_BOOTLDR])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_BOOTLDR])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_BOOTLDR])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_BOOTLDR])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_BOOTLDR])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_BOOTLDR])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_BOOTLDR])
);

assign dev_id_w    [S_WBPI_BOOTLDR] = 0;
assign dev_useirq_w[S_WBPI_BOOTLDR] = 0;

// WBPI_DEFAULTSLAVEINDEX to catch invalid physical address space access.
assign s_wbpi_bsy_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_ack_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_mapsz_w[S_WBPI_INVALIDDEV] = ('h1000/* 4KB */);

assign dev_id_w    [S_WBPI_INVALIDDEV] = 0;
assign dev_useirq_w[S_WBPI_INVALIDDEV] = 0;

endmodule
