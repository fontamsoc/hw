// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef CPU_COUNT
`define CPU_COUNT 1
`endif
`ifndef XWORDBITSZ
`define XWORDBITSZ 32
`endif
`ifndef SRAM_KBSIZE
`define SRAM_KBSIZE 256
`endif
`ifndef SRAM_INITFILE
`define SRAM_INITFILE "../../rv32-sim/apps/coremark/rv32/coremark.32.hex"
`endif

`default_nettype none

`include "lib/ecppll_48_to_24_48_96.sv"

`include "lib/rstctrl.sv"

`define PURV32M
`define  PUIMULDSP
//`define  PUIDIVDSP
//`define   PUIDIVDSPREG
//`define PURV32ZBA
//`define PURV32ZBB
//`define PURV32ZBC
//`define PURV32ZBS
//`define PURV32ZFINX
//`define  PUFDIVDSP
`define  PUFDIVDSP2
//`define  PUFSQRTDSP
`define  PUFSQRTDSP2
`define PUPREDICTJAL
`define PUPREDICTBRANCH
`define PUPREDICTRET
//`define PUEARLYREDIRECTFETCH
//`define PUICACHEFILLBYPASS
//`define PUDCACHEREGRQST
`define PUDCACHEREGRESP
`include "cpu/ccx.sv"

`include "lib/wb_arbiter.sv"
`include "lib/wb_mux.sv"
`include "lib/wb_dnsizr.sv"

`include "dev/irqctrl.sv"

`include "dev/serial_usb.sv"

`include "dev/sram.sv"

`include "dev/spi.sv"

`include "dev/dfltdev.sv"

`include "rv32-orangecrab0285/dev/sdram_ddr3.v"

module orangecrab0285 (

	 usr_btn_n

	,clk48mhz_i

	// USB signals.
	,usb_d_p
	,usb_d_n
	,usb_pullup

	// SD SPI signals.
	,sdspi_sclk_o
	,sdspi_mosi_o
	,sdspi_miso_i
	,sdspi_cs_o

	// LED signals.
	,led_red_n
	,led_green_n
	,led_blue_n

	// SPI flash signals.
	,spiflash_cs_o
	,spiflash_mosi_o
	,spiflash_miso_i
	,spiflash_wp_o
	,spiflash_hold_o

	// DDR3 signals.
	,ddr3l_clk_p
	,ddr3l_cke
	,ddr3l_odt
	,ddr3l_cs_n
	,ddr3l_ras_n
	,ddr3l_cas_n
	,ddr3l_we_n
	,ddr3l_reset_n
	,ddr3l_ba
	,ddr3l_a
	,ddr3l_dq
	,ddr3l_dm
	,ddr3l_dqs_p
	,ddr3l_vccio
	,ddr3l_gnd
);

`include "lib/clog2.sv"

localparam WORDBITSZ = 32;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

input wire usr_btn_n;

input wire clk48mhz_i;

// USB signals.
inout  wire usb_d_p;
inout  wire usb_d_n;
output wire usb_pullup;
assign usb_pullup = 1'b1;

// SD SPI signals.
output wire sdspi_sclk_o;
output wire sdspi_mosi_o;
input  wire sdspi_miso_i;
output wire sdspi_cs_o;

// LED signals.
output wire led_red_n;
output wire led_green_n;
output wire led_blue_n;
assign led_red_n = 1'b1;
assign led_green_n = 1'b1;
assign led_blue_n = 1'b1;

// SPI flash signals; the clock of the flash is the configuration pin
// MCLK, which USRMCLK drives.
output wire spiflash_cs_o;
output wire spiflash_mosi_o;
input  wire spiflash_miso_i;
// W# and HOLD#, active low, held high: the flash is used through single-bit
// commands, hence neither protects nor pauses it whatever its QE bit, and an
// unused-pin pull-down cannot fight its pull-up.
output wire spiflash_wp_o;
output wire spiflash_hold_o;
assign spiflash_wp_o = 1'b1;
assign spiflash_hold_o = 1'b1;

// DDR3 signals, of the MT41K256M16 of 512 MiB.
output wire             ddr3l_clk_p;
output wire             ddr3l_cke;
output wire             ddr3l_odt;
output wire             ddr3l_cs_n;
output wire             ddr3l_ras_n;
output wire             ddr3l_cas_n;
output wire             ddr3l_we_n;
output wire             ddr3l_reset_n;
output wire [3 -1 : 0]  ddr3l_ba;
output wire [15 -1 : 0] ddr3l_a;
inout  wire [16 -1 : 0] ddr3l_dq;
output wire [2 -1 : 0]  ddr3l_dm;
inout  wire [2 -1 : 0]  ddr3l_dqs_p;
// Pins which the OrangeCrab r0.2 requires driven high, and low, while its
// DDR3 SDRAM is used, as litex-boards drives them.
output wire [6 -1 : 0]  ddr3l_vccio;
output wire [2 -1 : 0]  ddr3l_gnd;
assign ddr3l_vccio = {6{1'b1}};
assign ddr3l_gnd = {2{1'b0}};

localparam CLKFREQ24MHZ = 24000000;
localparam CLKFREQ48MHZ = 48000000;
localparam CLKFREQ96MHZ = 96000000;
wire pll_locked, clk24mhz_w, clk48mhz_w, clk96mhz_w;
ecppll_48_to_24_48_96 pll (
	 .locked     (pll_locked)
	,.clk48mhz_i (clk48mhz_i)
	,.clk24mhz_o (clk24mhz_w)
	,.clk48mhz_o (clk48mhz_w)
	,.clk96mhz_o (clk96mhz_w)
);

// Clock of the system, at 48 MHz, which litedram derives from clk48mhz_i
// using its own PLL, as rv32-orangecrab0285/dev/sdram_ddr3.v describes; and
// its reset, which is high until that clock is stable, and once more while
// litedram initializes its PHY, stopping that clock. The outputs of the pll
// above are left unused.
wire sdram_ddr3_clk_w;
wire sdram_ddr3_rst_w;

wire rst_w;
wire irqctrl_rst_rqst_w;
rstctrl #(
	 .RSTDURATION (CLKFREQ48MHZ/1000000) // 1us
	,.RSTTHRESH   (4*CLKFREQ48MHZ) // 4s
) rstctrl (
	 .clk_i (sdram_ddr3_clk_w)
	,.i     (~usr_btn_n)
	,.o     (rst_w)
	,.rqst_i (irqctrl_rst_rqst_w)
);

localparam CPU_COUNT = `CPU_COUNT;

localparam M_WBPI_CPU     = 0;
localparam M_WBPI_LAST    = M_WBPI_CPU;

localparam S_WBPI_IRQCTRL      = 0;
localparam S_WBPI_SERIAL       = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_SRAM         = (S_WBPI_SERIAL + 1);
localparam S_WBPI_LITEDRAM     = (S_WBPI_SRAM + 1);
localparam S_WBPI_LITEDRAMCTRL = (S_WBPI_LITEDRAM + 1);
localparam S_WBPI_SDSPI        = (S_WBPI_LITEDRAMCTRL + 1);
localparam S_WBPI_SPIFLASH     = (S_WBPI_SDSPI + 1);
localparam S_WBPI_DEFAULT      = (S_WBPI_SPIFLASH + 1);

localparam WBPI_MDEVCOUNT = (M_WBPI_LAST + 1);
localparam WBPI_SDEVCOUNT = (S_WBPI_DEFAULT + 1);

// The DDR3 SDRAM, and the registers of litedram which litedram_init() uses.
localparam LITEDRAM_MAPSZ     = 'h20000000;
localparam LITEDRAMCTRL_MAPSZ = 'h10000;

// Number of COM ports presented to the host through the USB link; it
// must be at least 2, as the interrupt sources of the ports beyond
// port 0 follow those of the other devices, see IRQ_SERIALX.
localparam SERIAL_PORTCOUNT = 2;

localparam [0:(WBPI_SDEVCOUNT*2*32)-1] WBPI_SDEVS = {
	/* S_WBPI_IRQCTRL      */ 32'hf00,  32'(WORDBITSZ/8),
	/* S_WBPI_SERIAL       */ 32'hf80,  32'(2*(WORDBITSZ/8)*SERIAL_PORTCOUNT),
	/* S_WBPI_SRAM         */ 32'h1000, 32'(`SRAM_KBSIZE*1024),
	/* S_WBPI_LITEDRAM     */ 32'('h1000+(`SRAM_KBSIZE*1024)), 32'(LITEDRAM_MAPSZ),
	/* S_WBPI_LITEDRAMCTRL */ 32'('h1000+(`SRAM_KBSIZE*1024)+LITEDRAM_MAPSZ), 32'(LITEDRAMCTRL_MAPSZ),
	/* S_WBPI_SDSPI        */ 32'he00,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SPIFLASH     */ 32'he40,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_DEFAULT      */ 32'h0,    32'h0};

localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 8'b01110011;
localparam WBPI_WORDBITSZ         = `XWORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_ADDRLIMIT         = ('h1000+(`SRAM_KBSIZE*1024)+LITEDRAM_MAPSZ+LITEDRAMCTRL_MAPSZ);
localparam WBPI_CLKFREQ           = CLKFREQ48MHZ;
wire wbpi_rst_w = (rst_w || sdram_ddr3_rst_w);
wire wbpi_clk_w = sdram_ddr3_clk_w;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                                          m_wbpi_stb_w  [WBPI_MDEVCOUNT];
// 	input                                          m_wbpi_lock_w [WBPI_MDEVCOUNT];
// 	input                                          m_wbpi_we_w   [WBPI_MDEVCOUNT];
// 	input  [(WBPI_ADDRBITSZ-WBPI_MSBSZIGN) -1 : 0] m_wbpi_addr_w [WBPI_MDEVCOUNT];
// 	input  [(WBPI_WORDBITSZ/8) -1 : 0]             m_wbpi_sel_w  [WBPI_MDEVCOUNT];
// 	input  [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dati_w [WBPI_MDEVCOUNT];
// 	output                                         m_wbpi_bsy_w  [WBPI_MDEVCOUNT];
// 	output                                         m_wbpi_ack_w  [WBPI_MDEVCOUNT];
// 	output [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dato_w [WBPI_MDEVCOUNT];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                                         s_wbpi_stb_w  [WBPI_SDEVCOUNT];
// 	output                                         s_wbpi_lock_w [WBPI_SDEVCOUNT];
// 	output                                         s_wbpi_we_w   [WBPI_SDEVCOUNT];
// 	output [(WBPI_ADDRBITSZ-WBPI_MSBSZIGN) -1 : 0] s_wbpi_addr_w [WBPI_SDEVCOUNT];
// 	output [(WBPI_WORDBITSZ/8) -1 : 0]             s_wbpi_sel_w  [WBPI_SDEVCOUNT];
// 	output [WBPI_WORDBITSZ -1 : 0]                 s_wbpi_dato_w [WBPI_SDEVCOUNT];
// 	input                                          s_wbpi_bsy_w  [WBPI_SDEVCOUNT];
// 	input                                          s_wbpi_ack_w  [WBPI_SDEVCOUNT];
// 	input  [WBPI_WORDBITSZ -1 : 0]                 s_wbpi_dati_w [WBPI_SDEVCOUNT];
`include "lib/wbpi_inst.sv"

localparam IRQ_DFLTDEV = 0;
localparam IRQ_SERIAL = (IRQ_DFLTDEV + 1); // Interrupt source of the serial port 0.
localparam IRQ_SDSPI = (IRQ_SERIAL + 1);
localparam IRQ_SPIFLASH = (IRQ_SDSPI + 1);
localparam IRQ_SERIALX = (IRQ_SPIFLASH + 1); // First of the interrupt sources of the serial ports beyond port 0.

localparam IRQSRCCOUNT = (IRQ_SERIALX + SERIAL_PORTCOUNT - 1); // Number of interrupt sources.
localparam IRQDSTCOUNT = CPU_COUNT; // Number of interrupt destinations.
wire [IRQSRCCOUNT -1 : 0] irq_src_stb_w;
wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_w0;
wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_w1;
wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_w;

localparam ICACHESZ = 16;
localparam DCACHESZ = 16;

localparam ICACHEWAYCNT = 1;
localparam DCACHEWAYCNT = 1;

// cpu_dcache_miss_w must be combinationally set high if
// cpu_dcache_addr_w is an address that must not be cached.
wire [((WBPI_WORDBITSZ-WBPI_MSBSZIGN)*CPU_COUNT) -1 : 0] cpu_dcache_addr_w;
wire [CPU_COUNT -1 : 0]                                  cpu_dcache_miss_w;

ccx #(
	 .WORDBITSZ     (WORDBITSZ)
	,.XWORDBITSZ    (WBPI_WORDBITSZ)
	,.ADDRLIMIT     (WBPI_ADDRLIMIT)
	,.CLKFREQ       (WBPI_CLKFREQ)
	,.USEMEMCLKDOM  (!DCACHESZ || CPU_COUNT > 1)
	,.ICACHESETCNT  ((1024/(WBPI_WORDBITSZ/8))*(ICACHESZ/ICACHEWAYCNT))
	,.DCACHESETCNT  ((1024/(WBPI_WORDBITSZ/8))*(DCACHESZ/DCACHEWAYCNT))
	,.ICACHEWAYCNT  (ICACHEWAYCNT)
	,.DCACHEWAYCNT  (DCACHEWAYCNT)
	,.MAXPENDINGACK (WBPI_MAXPENDINGACK)
	,.PUCNT         (CPU_COUNT)
) cpu (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_mem_i (wbpi_clk_w)

	,.wb_stb_o  (m_wbpi_stb_w[M_WBPI_CPU])
	,.wb_lock_o (m_wbpi_lock_w[M_WBPI_CPU])
	,.wb_we_o   (m_wbpi_we_w[M_WBPI_CPU])
	,.wb_addr_o (m_wbpi_addr_w[M_WBPI_CPU])
	,.wb_sel_o  (m_wbpi_sel_w[M_WBPI_CPU])
	,.wb_dat_o  (m_wbpi_dati_w[M_WBPI_CPU])
	,.wb_bsy_i  (m_wbpi_bsy_w[M_WBPI_CPU])
	,.wb_ack_i  (m_wbpi_ack_w[M_WBPI_CPU])
	,.wb_dat_i  (m_wbpi_dato_w[M_WBPI_CPU])

	,.dcache_addr_o (cpu_dcache_addr_w)
	,.dcache_miss_i (cpu_dcache_miss_w)

	,.irq_stb_i (irq_dst_stb_w0)
	,.irq_stb_o (irq_dst_stb_w1)
	,.irq_rdy_o (irq_dst_rdy_w)
	,.halted_o  (irq_dst_pri_w)

	,.rstaddr_i  ('h1000)
	,.rstaddr2_i ('h1000)

	,.spval_i ('h1000+(`SRAM_KBSIZE*1024))
);

irqctrl #(
	 .WORDBITSZ   (WORDBITSZ)
	,.IRQSRCCOUNT (IRQSRCCOUNT)
	,.IRQDSTCOUNT (IRQDSTCOUNT)
) irqctrl (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_IRQCTRL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_IRQCTRL])
	//,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_IRQCTRL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_IRQCTRL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_IRQCTRL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_IRQCTRL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_IRQCTRL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_IRQCTRL])

	,.irq_dst_stb_o (irq_dst_stb_w0)
	,.irq_dst_stb_i (irq_dst_stb_w1)
	,.irq_dst_rdy_i (irq_dst_rdy_w)
	,.irq_dst_pri_i (irq_dst_pri_w)

	,.irq_src_stb_i (irq_src_stb_w)
	,.irq_src_rdy_o (irq_src_rdy_w)

	,.rst_rqst_o (irqctrl_rst_rqst_w)
);

// Power-on reset of serial_usb, on the clock of the system which litedram
// outputs: high from the configuration of the FPGA until 255 cycles of that
// clock after sdram_ddr3_rst_w was last high, which it is until that clock is
// stable, and once more shortly after, while litedram initializes its PHY,
// stopping that clock meanwhile.
reg [7:0] serial_rst_r = -1;
always_ff @(posedge sdram_ddr3_clk_w) begin
	if (sdram_ddr3_rst_w)
		serial_rst_r <= -1;
	else if (serial_rst_r)
		serial_rst_r <= serial_rst_r - 1'b1;
end

serial_usb #(
	 .WORDBITSZ  (WORDBITSZ)
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz.
	,.PORTCOUNT  (SERIAL_PORTCOUNT)
	,.BUFSZ      (2048)
) serial (

	 .rst_i ((|serial_rst_r)
		/* wbpi_rst_w is not used because subsequent
		   resets break the usb connection */)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (sdram_ddr3_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SERIAL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SERIAL])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SERIAL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SERIAL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SERIAL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SERIAL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SERIAL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SERIAL])

	,.irq_stb_o ({irq_src_stb_w[IRQ_SERIALX +: (SERIAL_PORTCOUNT-1)], irq_src_stb_w[IRQ_SERIAL]})
	,.irq_rdy_i ({irq_src_rdy_w[IRQ_SERIALX +: (SERIAL_PORTCOUNT-1)], irq_src_rdy_w[IRQ_SERIAL]})

	,.usb_dp_io (usb_d_p)
	,.usb_dn_io (usb_d_n)
);

sram #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
	,.SIZE      ((`SRAM_KBSIZE)*(1024/(WBPI_WORDBITSZ/8)))
	,.INITFILE  (`SRAM_INITFILE)
) sram (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SRAM])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SRAM])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SRAM])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SRAM])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SRAM])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SRAM])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SRAM])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SRAM])
);

sdram_ddr3 #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
) sdram_ddr3 (

	 .rst_i (wbpi_rst_w)

	,.clk_i (clk48mhz_i)

	,.clk_o (sdram_ddr3_clk_w)
	,.rst_o (sdram_ddr3_rst_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_LITEDRAM])
	,.wb_lock_i  (s_wbpi_lock_w[S_WBPI_LITEDRAM])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_LITEDRAM])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_LITEDRAM])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_LITEDRAM])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_LITEDRAM])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_LITEDRAM])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_LITEDRAM])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_LITEDRAM])

	,.wb_ctrl_stb_i   (s_wbpi_stb_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_we_i    (s_wbpi_we_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_addr_i  (s_wbpi_addr_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_sel_i   (s_wbpi_sel_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_dat_i   (s_wbpi_dato_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_bsy_o   (s_wbpi_bsy_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_ack_o   (s_wbpi_ack_w[S_WBPI_LITEDRAMCTRL])
	,.wb_ctrl_dat_o   (s_wbpi_dati_w[S_WBPI_LITEDRAMCTRL])

	,.ddr3l_clk_p   (ddr3l_clk_p)
	,.ddr3l_cke     (ddr3l_cke)
	,.ddr3l_odt     (ddr3l_odt)
	,.ddr3l_cs_n    (ddr3l_cs_n)
	,.ddr3l_ras_n   (ddr3l_ras_n)
	,.ddr3l_cas_n   (ddr3l_cas_n)
	,.ddr3l_we_n    (ddr3l_we_n)
	,.ddr3l_reset_n (ddr3l_reset_n)
	,.ddr3l_ba      (ddr3l_ba)
	,.ddr3l_a       (ddr3l_a)
	,.ddr3l_dm      (ddr3l_dm)
	,.ddr3l_dq      (ddr3l_dq)
	,.ddr3l_dqs_p   (ddr3l_dqs_p)
);

spi #(
	 .WORDBITSZ      (WORDBITSZ)
	,.PHYCLKFREQ     (WBPI_CLKFREQ)
	,.DEFAULTBITRATE (400000)
	,.BUFSZ          (512)
	,.CPOL           (0)
) sdspi (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SDSPI])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SDSPI])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SDSPI])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SDSPI])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SDSPI])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SDSPI])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SDSPI])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SDSPI])

	,.irq_stb_o (irq_src_stb_w[IRQ_SDSPI])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SDSPI])

	,.sclk_o (sdspi_sclk_o)
	,.mosi_o (sdspi_mosi_o)
	,.miso_i (sdspi_miso_i)
	,.cs_o   (sdspi_cs_o)
);

wire spiflash_sclk_w;

spi #(
	 .WORDBITSZ      (WORDBITSZ)
	,.PHYCLKFREQ     (WBPI_CLKFREQ)
	,.DEFAULTBITRATE (400000)
	,.BUFSZ          (512)
	,.CPOL           (0)
	,.CTRLCSHIGH     (1)
	,.LATESAMPLE     (1)
) spiflash (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SPIFLASH])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SPIFLASH])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SPIFLASH])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SPIFLASH])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SPIFLASH])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SPIFLASH])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SPIFLASH])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SPIFLASH])

	,.irq_stb_o (irq_src_stb_w[IRQ_SPIFLASH])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SPIFLASH])

	,.sclk_o (spiflash_sclk_w)
	,.mosi_o (spiflash_mosi_o)
	,.miso_i (spiflash_miso_i)
	,.cs_o   (spiflash_cs_o)
);

// The clock of the flash is the dedicated configuration pin MCLK, which user
// logic drives after configuration only through USRMCLK.
(* keep *) USRMCLK usrmclk (
	 .USRMCLKI  (spiflash_sclk_w)
	,.USRMCLKTS (1'b0)
);

// Catch invalid physical address space access.
dfltdev #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
	,.ADDRLIMIT (WBPI_ADDRLIMIT)
) dfltdev (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_DEFAULT])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_DEFAULT])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_DEFAULT])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_DEFAULT])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_DEFAULT])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_DEFAULT])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_DEFAULT])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_DEFAULT])

	,.irq_stb_o (irq_src_stb_w[IRQ_DFLTDEV])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_DFLTDEV])
);

genvar gen_cpu_dcache_miss_w_idx;
generate for (
	gen_cpu_dcache_miss_w_idx = 0;
	gen_cpu_dcache_miss_w_idx < CPU_COUNT;
	gen_cpu_dcache_miss_w_idx = gen_cpu_dcache_miss_w_idx + 1) begin :gen_cpu_dcache_miss_w
	wire [(WBPI_WORDBITSZ-WBPI_MSBSZIGN) -1 : 0] addr_w = cpu_dcache_addr_w[(gen_cpu_dcache_miss_w_idx*(WBPI_WORDBITSZ-WBPI_MSBSZIGN))+:(WBPI_WORDBITSZ-WBPI_MSBSZIGN)];
assign cpu_dcache_miss_w[gen_cpu_dcache_miss_w_idx] = (
	(addr_w < 'h1000) || (addr_w >= ('h1000+(`SRAM_KBSIZE*1024)+LITEDRAM_MAPSZ)));
end endgenerate

endmodule
