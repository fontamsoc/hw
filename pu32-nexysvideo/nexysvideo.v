// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "./pll_100_to_50_100_200_mhz.v"

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
//`define PUDCACHE
`define PUSC2
`define PUSC2SKIPSC1LI8
`define PUSC2SKIPSC1CPY
`define PUCOUNT 1 /* 16 max */
`include "pu/cpu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/gpio.v"

`include "dev/irqctrl.v"

`include "dev/uart_hw.v"

`include "lib/dcache.v"
`include "./litedram/litedram.v"

`include "dev/bootldr/bootldr.v"

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

wire litedram_pll_locked;
wire litedram_init_done;
wire litedram_init_error;

wire cpu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

wire rst_p = !rst_n;

(* direct_reset = "true" *)
wire rst_w;

localparam CLK1XFREQ = ( 50000000) /*  50 MHz */; // Frequency of clk_1x_w.
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

wire clk_1x_w = clk50mhz;
wire clk_2x_w = clk100mhz;
wire clk_4x_w = clk200mhz;

STARTUPE2 startupe (.CLK (clk100mhz_i), .GSR (swcoldrst));

wire rst_clk_w = clk_2x_w;

localparam RST_CNTR_BITSZ = 16;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge rst_clk_w) begin
	if (pll_locked && !cpu_rst_ow && !swwarmrst && rst_n) begin
		if (rst_cntr)
			rst_cntr <= rst_cntr - 1'b1;
	end else
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
end

always @ (posedge rst_clk_w) begin
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

assign rst_w = (devtbl_rst0_r || (|rst_cntr));

assign sd_reset = rst_w;

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_SDCARD     = 0;
localparam S_WBPI_DEVTBL     = (S_WBPI_SDCARD + 1);
localparam S_WBPI_GPIO       = (S_WBPI_DEVTBL + 1);
localparam S_WBPI_IRQCTRL    = (S_WBPI_GPIO + 1);
localparam S_WBPI_UART       = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_RAM        = (S_WBPI_UART + 1);
localparam S_WBPI_RAMCTRL    = (S_WBPI_RAM + 1);
localparam S_WBPI_BOOTLDR    = (S_WBPI_RAMCTRL + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_BOOTLDR + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = 0;
localparam WBPI_MAXPENDINGACK     = 16;
localparam WBPI_DNSIZR            = 9'b001011110;
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
localparam IRQ_GPIO   = (IRQ_SDCARD + 1);
localparam IRQ_UART   = (IRQ_GPIO + 1);

localparam IRQSRCCOUNT = (IRQ_UART +1); // Number of interrupt source.
localparam IRQDSTCOUNT = PUCOUNT; // Number of interrupt destination.
wire [IRQSRCCOUNT -1 : 0] irq_src_stb_w;
wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_w;

localparam ICACHESZ = 512;
localparam DCACHESZ = 64;
localparam TLBSZ    = 64;

localparam ICACHEWAYCOUNT = ((PUCOUNT > 4) ? 2 : 4);
localparam DCACHEWAYCOUNT = ((PUCOUNT > 4) ? 1 : 2);
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

	 .rst_i (rst_w || !litedram_pll_locked)

	,.rst_o (cpu_rst_ow)

	,.clk_i          (clk_2x_w)
	,.clk_mem_i      (wbpi_clk_w)
	,.clk_imul_i     (clk_4x_w)
	,.clk_idiv_i     (clk_4x_w)
	,.clk_faddfsub_i (clk_4x_w)
	,.clk_fmul_i     (clk_4x_w)
	,.clk_fdiv_i     (clk_4x_w)

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
	,.PHYCLKFREQ (CLK4XFREQ*2/* incorrect but helps as controller will run slower */)
) sdcard (

	 .rst_i (wbpi_rst_w || sd_cd)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (clk_4x_w)

	,.sclk_o (sd_sclk)
	,.di_o   (sd_di)
	,.do_i   (sd_do)
	,.cs_o   (sd_cs)

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
	((1024/(ARCHBITSZ/8))*(128/RAMCACHEWAYCOUNT));

wire devtbl_rst2_w;

devtbl #(
	 .ARCHBITSZ  (ARCHBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	,.DEVMAPCNT  (WBPI_SLAVECOUNT)
	,.SOCID      (3)
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

wire [GPIOCOUNT -1 : 0] gpio_o;

gpio #(
	 .ARCHBITSZ  (ARCHBITSZ)
	,.CLKFREQ    (WBPI_CLKFREQ)
	,.IOCOUNT    (GPIOCOUNT)
) gpio (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_GPIO])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_GPIO])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_GPIO])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_GPIO])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_GPIO])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_GPIO])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_GPIO])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_GPIO])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_GPIO])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_GPIO])

	,.irq_stb_o (irq_src_stb_w[IRQ_GPIO])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_GPIO])

	,.i (gp_i)
	,.o (gpio_o)
);

assign dev_id_w    [S_WBPI_GPIO] = 6;
assign dev_useirq_w[S_WBPI_GPIO] = 1;

assign gp_o = ({{(GPIOCOUNT-1){1'b0}}, activity} | gpio_o);

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

uart_hw #(
	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (WBPI_CLKFREQ)
	,.BUFSZ      (4096)
) uart (

	 .rst_i (!pll_locked || rst_p
		/* wbpi_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)
	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_UART])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_UART])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_UART])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_UART])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_UART])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_UART])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_UART])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_UART])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_UART])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_UART])

	,.irq_stb_o (irq_src_stb_w[IRQ_UART])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_UART])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

assign dev_id_w    [S_WBPI_UART] = 5;
assign dev_useirq_w[S_WBPI_UART] = 1;

wire wb_rst_user_port_w;
wire wb_clk_user_port_w;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge rst_clk_w) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

reg conly_r;
always @ (posedge rst_clk_w) begin
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

	,.clk_i (wb_clk_user_port_w)

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
	,.s_wb_bsy_i  (1'b0)
	,.s_wb_ack_i  (dcache_wb_ack_w)
	,.s_wb_dat_i  (dcache_wb_dati_w)
);

reg s_wbpi_bsy_r_S_WBPI_RAMCTRL;

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

	,.user_clk (wb_clk_user_port_w)
	,.user_rst (wb_rst_user_port_w)

	,.user_port_wishbone_0_cyc   (dcache_wb_cyc_w)
	,.user_port_wishbone_0_stb   (dcache_wb_stb_w)
	,.user_port_wishbone_0_we    (dcache_wb_we_w)
	,.user_port_wishbone_0_adr   (dcache_wb_addr_w)
	,.user_port_wishbone_0_sel   (dcache_wb_sel_w)
	,.user_port_wishbone_0_dat_w (dcache_wb_dato_w)
	,.user_port_wishbone_0_ack   (dcache_wb_ack_w)
	,.user_port_wishbone_0_dat_r (dcache_wb_dati_w)

	,.wb_ctrl_cyc   (s_wbpi_cyc_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_stb   (s_wbpi_stb_w[S_WBPI_RAMCTRL] && !s_wbpi_bsy_r_S_WBPI_RAMCTRL)
	,.wb_ctrl_we    (s_wbpi_we_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_adr   (s_wbpi_addr_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_sel   (s_wbpi_sel_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_dat_w (s_wbpi_dato_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_ack   (s_wbpi_ack_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_dat_r (s_wbpi_dati_w[S_WBPI_RAMCTRL])
	,.wb_ctrl_cti   (3'b000)
	,.wb_ctrl_bte   (2'b00)
);

assign s_wbpi_mapsz_w[S_WBPI_RAM] = ('h20000000/* 512MB */);

assign dev_id_w    [S_WBPI_RAM] = 1;
assign dev_useirq_w[S_WBPI_RAM] = 0;

// Litedram uses Wishbone classic as oppose to pipeline.
always @ (posedge wb_clk_user_port_w) begin
	if (wb_rst_user_port_w || s_wbpi_ack_w[S_WBPI_RAMCTRL])
		s_wbpi_bsy_r_S_WBPI_RAMCTRL <= 0;
	else if (s_wbpi_cyc_w[S_WBPI_RAMCTRL] && s_wbpi_stb_w[S_WBPI_RAMCTRL])
		s_wbpi_bsy_r_S_WBPI_RAMCTRL <= 1;
end
assign s_wbpi_bsy_w[S_WBPI_RAMCTRL] = s_wbpi_bsy_r_S_WBPI_RAMCTRL;
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
