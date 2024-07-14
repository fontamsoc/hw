// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "./pll_12_to_120_mhz.v"

`include "lib/wb_arbiter.v"
`include "lib/wb_mux.v"
`include "lib/wb_dnsizr.v"

`define PUMMU
`define PUHPTW
`define PUIMULCLK
`define PUIDIVCLK
`define PUIMULDSP
//`define PUDCACHE
`include "puxx/cpu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/irqctrl.v"

`include "dev/serial_uart.v"

// wb4sdram is 32bits only.
`include "lib/dcache.v"
`include "lib/wb4sdram.v"

`include "dev/bootldr/bootldr.v"

module xula2lx25 (

	 rst_p

	,clk12mhz_i

	// SDCARD signals.
	,flash_sclk
	,flash_di
	,flash_do
	,flash_cs
	,flash_cs2 // cs2 is the SPI FLASH CS which should be kept high.

	// UART signals.
	,uart_rx
	,uart_tx

	// SDRAM signals.
	,sdram_ck
	,sdram_cke
	,sdram_ras_n
	,sdram_cas_n
	,sdram_we_n
	,sdram_ba
	,sdram_addr
	,sdram_dq
	,sdram_dm
);

`include "lib/clog2.v"

localparam WORDBITSZ = 32;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

input wire rst_p;

input wire clk12mhz_i;

// SDCARD signals.
output wire flash_sclk;
output wire flash_di;
input  wire flash_do;
output wire flash_cs;
output wire flash_cs2; // cs2 is the SPI FLASH CS which should be kept high.

// UART signals.
input  wire uart_rx;
output wire uart_tx;

// SDRAM signals.
// Parameters for Winbond W9825G6JH-6 SDR.
localparam SDRAMCASLATENCY       = 2;
localparam SDRAMBURSTLENGTH      = 4;
localparam SDRAMBANKCOUNT        = 4;
localparam SDRAMROWCOUNT         = 8192;
localparam SDRAMCOLUMNCOUNT      = 512;
localparam SDRAMABITSIZE         = 13;
localparam SDRAMDQBITSIZE        = 16;
localparam CLOG2SDRAMBURSTLENGTH = clog2(SDRAMBURSTLENGTH);
localparam CLOG2SDRAMBANKCOUNT   = clog2(SDRAMBANKCOUNT);
localparam CLOG2SDRAMROWCOUNT    = clog2(SDRAMROWCOUNT);
localparam CLOG2SDRAMCOLUMNCOUNT = clog2(SDRAMCOLUMNCOUNT);
output wire                               sdram_ck;
output wire                               sdram_cke;
output wire                               sdram_ras_n;
output wire                               sdram_cas_n;
output wire                               sdram_we_n;
output wire [CLOG2SDRAMBANKCOUNT -1 : 0]  sdram_ba;
output wire [SDRAMABITSIZE -1 : 0]        sdram_addr;
inout  wire [SDRAMDQBITSIZE -1 : 0]       sdram_dq;
output wire [(SDRAMDQBITSIZE / 8) -1 : 0] sdram_dm;

// SPI FLASH CS pin kept high to keep it disabled.
assign flash_cs2 = 1;

wire cpu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

localparam CLK1XFREQ = 30000000 /* 30 MHz */; // Frequency of clk_1x_w.
localparam CLK2XFREQ = 60000000 /* 60 MHz */; // Frequency of clk_2x_w.

wire pll_locked;

wire clk120mhz_;
pll_12_to_120_mhz pll (
	 .RESET    (1'b0)
	,.LOCKED   (pll_locked)
	,.CLK_IN1  (clk12mhz_i)
	,.CLK_OUT1 (clk120mhz_)
);
(* keep = "true" *) wire clk120mhz;
BUFG bufg0 (.O (clk120mhz), .I (clk120mhz_));
reg [1:0] clkdiv;
always @ (posedge clk120mhz) begin
	clkdiv <= clkdiv - 1'b1; // Using substraction to have divided clocks in-phase.
end
(* keep = "true" *) wire clk60mhz;
(* keep = "true" *) wire clk30mhz;
BUFG bufg1 (.O (clk60mhz), .I (clkdiv[0]));
BUFG bufg2 (.O (clk30mhz), .I (clkdiv[1]));

wire clk_1x_w = clk30mhz;
wire clk_2x_w = clk60mhz;

STARTUP_SPARTAN6 (.CLK (clk12mhz_i), .GSR (swcoldrst));

wire rst_clk_w = clk_2x_w;

localparam RST_CNTR_BITSZ = 4;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge rst_clk_w) begin
	if (!pll_locked || cpu_rst_ow || swwarmrst || rst_p)
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
	else if (rst_cntr)
		rst_cntr <= rst_cntr - 1'b1;
end

always @ (posedge rst_clk_w) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

wire rst_w = (devtbl_rst0_r || (|rst_cntr));

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_SDCARD     = 0;
localparam S_WBPI_DEVTBL     = (S_WBPI_SDCARD + 1);
localparam S_WBPI_IRQCTRL    = (S_WBPI_DEVTBL + 1);
localparam S_WBPI_SERIAL     = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_RAM        = (S_WBPI_SERIAL + 1);
localparam S_WBPI_BOOTLDR    = (S_WBPI_RAM + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_BOOTLDR + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = 0;
localparam WBPI_MAXPENDINGACK     = 16;
localparam WBPI_DNSIZR            = 7'b0001110;
localparam WBPI_WORDBITSZ         = WORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_CLKFREQ           = CLK1XFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_1x_w;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                              m_wbpi_cyc_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_stb_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input                              m_wbpi_we_w   [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_ADDRBITSZ -1 : 0]     m_wbpi_addr_w [WBPI_MASTERCOUNT -1 : 0];
// 	input  [(WBPI_WORDBITSZ/8) -1 : 0] m_wbpi_sel_w  [WBPI_MASTERCOUNT -1 : 0];
// 	input  [WBPI_WORDBITSZ -1 : 0]     m_wbpi_dati_w [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_bsy_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output                             m_wbpi_ack_w  [WBPI_MASTERCOUNT -1 : 0];
// 	output [WBPI_WORDBITSZ -1 : 0]     m_wbpi_dato_w [WBPI_MASTERCOUNT -1 : 0];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                             s_wbpi_cyc_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_stb_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output                             s_wbpi_we_w    [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_ADDRBITSZ -1 : 0]     s_wbpi_addr_w  [WBPI_SLAVECOUNT -1 : 0];
// 	output [(WBPI_WORDBITSZ/8) -1 : 0] s_wbpi_sel_w   [WBPI_SLAVECOUNT -1 : 0];
// 	output [WBPI_WORDBITSZ -1 : 0]     s_wbpi_dato_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_bsy_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input                              s_wbpi_ack_w   [WBPI_SLAVECOUNT -1 : 0];
// 	input  [WBPI_WORDBITSZ -1 : 0]     s_wbpi_dati_w  [WBPI_SLAVECOUNT -1 : 0];
// 	input  [WORDBITSZ -1 : 0]          s_wbpi_mapsz_w [WBPI_SLAVECOUNT -1 : 0];
// If "dev/devtbl.v" was included, slave devices must also use following signals:
// 	input  [WORDBITSZ -1 : 0]          dev_id_w       [WBPI_SLAVECOUNT -1 : 0];
// 	input                              dev_useirq_w   [WBPI_SLAVECOUNT -1 : 0];
`include "lib/wbpi_inst.v"

localparam IRQ_SDCARD = 0;
localparam IRQ_SERIAL   = (IRQ_SDCARD + 1);

localparam IRQSRCCOUNT = (IRQ_SERIAL +1); // Number of interrupt source.
localparam IRQDSTCOUNT = 1; // Number of interrupt destination.
wire [IRQSRCCOUNT -1 : 0] irq_src_stb_w;
wire [IRQSRCCOUNT -1 : 0] irq_src_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_stb_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_rdy_w;
wire [IRQDSTCOUNT -1 : 0] irq_dst_pri_w;

localparam ICACHESZ = 32;
localparam DCACHESZ = 4;
localparam TLBSZ    = 16;

localparam ICACHEWAYCOUNT = 2;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 2;

cpu #(
	 .WORDBITSZ      (WORDBITSZ)
	,.XWORDBITSZ     (WBPI_WORDBITSZ)
	,.CLKFREQ        (CLK1XFREQ)
	,.ICACHESETCOUNT ((1024/(WBPI_WORDBITSZ/8))*(ICACHESZ/ICACHEWAYCOUNT))
	,.DCACHESETCOUNT ((1024/(WBPI_WORDBITSZ/8))*(DCACHESZ/DCACHEWAYCOUNT))
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.IMULCNT        (2)
	,.IDIVCNT        (2)
	,.MAXPENDINGACK  (WBPI_MAXPENDINGACK)
) cpu (

	 .rst_i (rst_w)

	,.rst_o (cpu_rst_ow)

	,.clk_i      (clk_1x_w)
	,.clk_mem_i  (wbpi_clk_w)
	,.clk_imul_i (clk_2x_w)
	,.clk_idiv_i (clk_2x_w)

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
		(s_wbpi_mapsz_w[S_WBPI_RAM]>>1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)
);

sdcard_spi #(
	 .WORDBITSZ  (WORDBITSZ)
	,.XWORDBITSZ (WBPI_WORDBITSZ)
	,.CLKFREQ    (WBPI_CLKFREQ)
	,.PHYCLKFREQ (CLK2XFREQ)
) sdcard (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (clk_2x_w)

	,.sclk_o (flash_sclk)
	,.di_o   (flash_di)
	,.do_i   (flash_do)
	,.cs_o   (flash_cs)

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

localparam RAMCACHEWAYCOUNT = 2;

localparam RAMCACHESZ = /* In (WORDBITSZ/8) units */
	((1024/(WORDBITSZ/8))*(8/RAMCACHEWAYCOUNT));

devtbl #(
	 .WORDBITSZ  (WORDBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.DEVMAPCNT  (WBPI_SLAVECOUNT)
	,.SOCID      (1)
) devtbl (

	 .rst_i (wbpi_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)

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
	 .WORDBITSZ   (WORDBITSZ)
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

serial_uart #(
	 .WORDBITSZ  (WORDBITSZ)
	,.PHYCLKFREQ (WBPI_CLKFREQ)
	,.BUFSZ      (2048)
) serial (

	 .rst_i (!pll_locked || rst_p
		/* wbpi_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)
	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

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

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

assign dev_id_w    [S_WBPI_SERIAL] = 5;
assign dev_useirq_w[S_WBPI_SERIAL] = 1;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge rst_clk_w) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

wire                             dcache_wb_cyc_w;
wire                             dcache_wb_stb_w;
wire                             dcache_wb_we_w;
wire [WBPI_ADDRBITSZ -1 : 0]     dcache_wb_addr_w;
wire [(WBPI_WORDBITSZ/8) -1 : 0] dcache_wb_sel_w;
wire [WBPI_WORDBITSZ -1 : 0]     dcache_wb_dato_w;
wire                             dcache_wb_bsy_w;
wire                             dcache_wb_ack_w;
wire [WBPI_WORDBITSZ -1 : 0]     dcache_wb_dati_w;

dcache #(
	 .WORDBITSZ     (WBPI_WORDBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ/(WBPI_WORDBITSZ/WORDBITSZ))
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (wbpi_clk_w)

	,.conly_i (1'b0)
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

wb4sdram #(

	 .SDRAM_MHZ          (CLK1XFREQ/1000000)
	,.SDRAM_ADDR_W       (CLOG2SDRAMROWCOUNT+CLOG2SDRAMBANKCOUNT+CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_COL_W        (CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_BANK_W       (CLOG2SDRAMBANKCOUNT)
	,.SDRAM_DQM_W        (SDRAMDQBITSIZE/8)
	,.SDRAM_BANKS        (SDRAMBANKCOUNT)
	,.SDRAM_ROW_W        (CLOG2SDRAMROWCOUNT)
	,.SDRAM_READ_LATENCY (SDRAMCASLATENCY)

) wb4sdram (

	 .rst_i (ram_rst_w)

	,.clk_i (wbpi_clk_w)

	,.sdram_clk_o   (sdram_ck)
	,.sdram_cke_o   (sdram_cke)
	,.sdram_ras_o   (sdram_ras_n)
	,.sdram_cas_o   (sdram_cas_n)
	,.sdram_we_o    (sdram_we_n)
	,.sdram_dqm_o   (sdram_dm)
	,.sdram_addr_o  (sdram_addr)
	,.sdram_ba_o    (sdram_ba)
	,.sdram_data_io (sdram_dq)

	,.cyc_i   (dcache_wb_cyc_w)
	,.stb_i   (dcache_wb_stb_w)
	,.we_i    (dcache_wb_we_w)
	,.addr_i  ({dcache_wb_addr_w, {WBPI_CLOG2WORDBITSZBY8{1'b0}}})
	,.sel_i   (dcache_wb_sel_w)
	,.data_i  (dcache_wb_dato_w)
	,.stall_o (dcache_wb_bsy_w)
	,.ack_o   (dcache_wb_ack_w)
	,.data_o  (dcache_wb_dati_w)
);

assign s_wbpi_mapsz_w[S_WBPI_RAM] = (1 << (
	(CLOG2SDRAMROWCOUNT + CLOG2SDRAMBANKCOUNT + (CLOG2SDRAMCOLUMNCOUNT - CLOG2SDRAMBURSTLENGTH)) +
	clog2((SDRAMDQBITSIZE * SDRAMBURSTLENGTH) / 8)));

assign dev_id_w    [S_WBPI_RAM] = 1;
assign dev_useirq_w[S_WBPI_RAM] = 0;

bootldr #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
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
