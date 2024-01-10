// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "./pll_12_to_120_mhz.v"

`include "lib/perint/pi1r.v"

`define PUMMU
`define PUHPTW
`define PUIMULCLK
`define PUIDIVCLK
`define PUIMULDSP
`define PUDCACHE
`include "pu/cpu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/intctrl.v"

`include "dev/uart_hw.v"

// wb4sdram is 32bits only.
`include "dev/pi1_dcache.v"
`include "dev/pi1_to_wb4.v"
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

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

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

localparam RST_CNTR_BITSZ = 4;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk120mhz) begin
	if (cpu_rst_ow || swwarmrst || rst_p)
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
	else if (rst_cntr)
		rst_cntr <= rst_cntr - 1'b1;
end

always @ (posedge clk120mhz) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

STARTUP_SPARTAN6 (.CLK (clk12mhz_i), .GSR (swcoldrst));

localparam CLKFREQ   = 30000000 /* 30 MHz */; // Frequency of clk_w.
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

wire clk_w    = clk30mhz;
wire clk_2x_w = clk60mhz;

wire rst_w = (!pll_locked || devtbl_rst0_r || (|rst_cntr));

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_UART   = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRCCOUNT   = (INTCTRLSRC_UART +1); // Number of interrupt source.
localparam INTCTRLDSTCOUNT   = 1; // Number of interrupt destination.
wire [INTCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [INTCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam M_PI1R_CPU        = 0;
localparam M_PI1R_LAST       = M_PI1R_CPU;
localparam S_PI1R_SDCARD     = 0;
localparam S_PI1R_DEVTBL     = (S_PI1R_SDCARD + 1);
localparam S_PI1R_INTCTRL    = (S_PI1R_DEVTBL + 1);
localparam S_PI1R_UART       = (S_PI1R_INTCTRL + 1);
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_BOOTLDR    = (S_PI1R_RAM + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_BOOTLDR + 1);

localparam PI1RMASTERCOUNT       = (M_PI1R_LAST + 1);
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ARCHBITSZ;
localparam CLOG2PI1RARCHBITSZBY8 = clog2(PI1RARCHBITSZ/8);
localparam PI1RADDRBITSZ         = (PI1RARCHBITSZ-CLOG2PI1RARCHBITSZBY8);
localparam PI1RCLKFREQ           = CLKFREQ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_w;
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

localparam ICACHESZ = 32;
localparam DCACHESZ = 4;
localparam TLBSZ    = 128;

localparam ICACHEWAYCOUNT = 2;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 2;

cpu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (PI1RARCHBITSZ)
	,.CLKFREQ        (CLKFREQ)
	,.ICACHESETCOUNT ((1024/(PI1RARCHBITSZ/8))*(ICACHESZ/ICACHEWAYCOUNT))
	,.DCACHESETCOUNT ((1024/(PI1RARCHBITSZ/8))*(DCACHESZ/DCACHEWAYCOUNT))
	,.TLBSETCOUNT    (TLBSZ/TLBWAYCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.DCACHEWAYCOUNT (DCACHEWAYCOUNT)
	,.TLBWAYCOUNT    (TLBWAYCOUNT)
	,.IMULCNT        (2)
	,.IDIVCNT        (2)

) cpu (

	 .rst_i (rst_w)

	,.rst_o (cpu_rst_ow)

	,.clk_i      (pi1r_clk_w)
	,.clk_imul_i (clk_2x_w)
	,.clk_idiv_i (clk_2x_w)

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_CPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_CPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_CPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_CPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_CPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_CPU])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  ((('h1000)>>1) +
		(s_pi1r_mapsz_w[S_PI1R_RAM]>>1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)
);

sdcard_spi #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.CLKFREQ    (PI1RCLKFREQ)
	,.PHYCLKFREQ (CLK2XFREQ)

) sdcard (

	 .rst_i (pi1r_rst_w)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk_2x_w)

	,.sclk_o (flash_sclk)
	,.di_o   (flash_di)
	,.do_i   (flash_do)
	,.cs_o   (flash_cs)

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

localparam RAMCACHEWAYCOUNT = 2;

localparam RAMCACHESZ = /* In (ARCHBITSZ/8) units */
	((1024/(ARCHBITSZ/8))*(8/RAMCACHEWAYCOUNT));

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.RAMCACHESZ (RAMCACHESZ)
	,.DEVMAPCNT  (PI1RSLAVECOUNT)
	,.SOCID      (1)

) devtbl (

	 .rst_i (pi1r_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)

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

uart_hw #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ)
	,.BUFSZ      (2048)

) uart (

	 .rst_i (!pll_locked || rst_p
		/* pi1r_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_UART])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_UART])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_UART])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_UART])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_UART])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_UART])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_UART])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_UART])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

assign devtbl_id_w     [S_PI1R_UART] = 5;
assign devtbl_useintr_w[S_PI1R_UART] = 1;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk120mhz) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]             dcache_op_w;
wire [ADDRBITSZ -1 : 0]     dcache_addr_w;
wire [ARCHBITSZ -1 : 0]     dcache_data_w1;
wire [ARCHBITSZ -1 : 0]     dcache_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] dcache_sel_w;
wire                        dcache_rdy_w;

pi1_dcache #(

	 .ARCHBITSZ     (ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ)
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.BUFFERDEPTH   (64)

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.crst_i    (ram_rst_w)
	,.cenable_i (1'b1)
	,.cmiss_i   (1'b0)
	,.conly_i   (1'b0)

	,.m_pi1_op_i   (s_pi1r_op_w[S_PI1R_RAM])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_RAM])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_RAM])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_RAM])
	,.m_pi1_sel_i  (s_pi1r_sel_w[S_PI1R_RAM])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[S_PI1R_RAM])

	,.s_pi1_op_o   (dcache_op_w)
	,.s_pi1_addr_o (dcache_addr_w)
	,.s_pi1_data_i (dcache_data_w1)
	,.s_pi1_data_o (dcache_data_w0)
	,.s_pi1_sel_o  (dcache_sel_w)
	,.s_pi1_rdy_i  (dcache_rdy_w)
);

wire                        wb4_cyc_w;
wire                        wb4_stb_w;
wire                        wb4_we_w;
wire [ARCHBITSZ -1 : 0]     wb4_addr_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_w;
wire                        wb4_stall_w;
wire                        wb4_ack_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_w1;

pi1_to_wb4 #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1_to_wb4 (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i   (dcache_op_w)
	,.pi1_addr_i (dcache_addr_w)
	,.pi1_data_i (dcache_data_w0)
	,.pi1_data_o (dcache_data_w1)
	,.pi1_sel_i  (dcache_sel_w)
	,.pi1_rdy_o  (dcache_rdy_w)

	,.wb4_cyc_o   (wb4_cyc_w)
	,.wb4_stb_o   (wb4_stb_w)
	,.wb4_we_o    (wb4_we_w)
	,.wb4_addr_o  (wb4_addr_w)
	,.wb4_data_o  (wb4_data_w0)
	,.wb4_sel_o   (wb4_sel_w)
	,.wb4_stall_i (wb4_stall_w)
	,.wb4_ack_i   (wb4_ack_w)
	,.wb4_data_i  (wb4_data_w1)
);

wb4sdram #(

	 .SDRAM_MHZ          (CLKFREQ/1000000)
	,.SDRAM_ADDR_W       (CLOG2SDRAMROWCOUNT+CLOG2SDRAMBANKCOUNT+CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_COL_W        (CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_BANK_W       (CLOG2SDRAMBANKCOUNT)
	,.SDRAM_DQM_W        (SDRAMDQBITSIZE/8)
	,.SDRAM_BANKS        (SDRAMBANKCOUNT)
	,.SDRAM_ROW_W        (CLOG2SDRAMROWCOUNT)
	,.SDRAM_READ_LATENCY (SDRAMCASLATENCY)

) wb4sdram (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.sdram_clk_o   (sdram_ck)
	,.sdram_cke_o   (sdram_cke)
	,.sdram_ras_o   (sdram_ras_n)
	,.sdram_cas_o   (sdram_cas_n)
	,.sdram_we_o    (sdram_we_n)
	,.sdram_dqm_o   (sdram_dm)
	,.sdram_addr_o  (sdram_addr)
	,.sdram_ba_o    (sdram_ba)
	,.sdram_data_io (sdram_dq)

	,.stb_i   (wb4_stb_w)
	,.we_i    (wb4_we_w)
	,.sel_i   (wb4_sel_w)
	,.cyc_i   (wb4_cyc_w)
	,.addr_i  (wb4_addr_w)
	,.data_i  (wb4_data_w0)
	,.data_o  (wb4_data_w1)
	,.stall_o (wb4_stall_w)
	,.ack_o   (wb4_ack_w)
);

assign s_pi1r_mapsz_w[S_PI1R_RAM] = (1 << (
	(CLOG2SDRAMROWCOUNT + CLOG2SDRAMBANKCOUNT + (CLOG2SDRAMCOLUMNCOUNT - CLOG2SDRAMBURSTLENGTH)) +
	clog2((SDRAMDQBITSIZE * SDRAMBURSTLENGTH) / 8)));

assign devtbl_id_w     [S_PI1R_RAM] = 1;
assign devtbl_useintr_w[S_PI1R_RAM] = 0;

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
