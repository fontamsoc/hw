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
`define SRAM_INITFILE "../../../../rv32-sim/apps/coremark/rv32/coremark.32.hex"
`endif

`default_nettype none

`include "lib/xc7pll_100_to_50_100_200.sv"

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
`define PUDCACHEREGRQST
`define PUDCACHEREGRESP
//`define PUAMOREGWB
`include "cpu/ccx.sv"

`include "lib/wb_arbiter.sv"
`include "lib/wb_mux.sv"
`include "lib/wb_dnsizr.sv"

`include "dev/irqctrl.sv"

`include "dev/serial_uart.sv"

`include "dev/serial_jtag.sv"

`include "dev/sram.sv"

`include "dev/sdio.sv"

`include "dev/spi.sv"

`include "dev/dfltdev.sv"

`include "rv32-nexysa7100/dev/sdram_ddr2.v"

module nexysa7100 (

	 rst_n

	,clk100mhz_i

	// UART signals.
	,uart_rx
	,uart_tx

	// SD signals.
	,sdsdio_clk_o
	,sdsdio_cmd_io
	,sdsdio_dat_io
	,sd_reset_o

	// Used in order to keep the seven-segment-display off.
	,an

	// SPI flash signals.
	,spiflash_cs_o
	,spiflash_mosi_o
	,spiflash_miso_i
	,spiflash_wp_o
	,spiflash_hold_o

	// DDR2 signals.
	,ddr2_ck_p
	,ddr2_ck_n
	,ddr2_cke
	,ddr2_odt
	,ddr2_cs_n
	,ddr2_ras_n
	,ddr2_cas_n
	,ddr2_we_n
	,ddr2_ba
	,ddr2_addr
	,ddr2_dq
	,ddr2_dm
	,ddr2_dqs_p
	,ddr2_dqs_n
);

`include "lib/clog2.sv"

localparam WORDBITSZ = 32;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

input wire rst_n;

(* clock_buffer_type = "BUFG" *)
input wire clk100mhz_i;

// UART signals.
input  wire uart_rx;
output wire uart_tx;

// SD signals.
output wire            sdsdio_clk_o;
inout  wire            sdsdio_cmd_io;
inout  wire [4 -1 : 0] sdsdio_dat_io;
// Held low, which powers the microSD slot. The board keeps the slot
// unpowered until the FPGA is configured, hence loading a bitstream
// power-cycles the card, which returns it to SD mode if it was left in SPI
// mode, whereas a reset of the design does not.
output wire sd_reset_o;
assign sd_reset_o = 1'b0;

// Used in order to keep the seven-segment-display off.
output wire [8 -1 : 0] an;
assign an = {8{1'b1}};

// SPI flash signals; the clock of the flash is the configuration clock
// CCLK, which STARTUPE2 drives.
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

// DDR2 signals, of the MT47H64M16 of 128 MiB.
output wire             ddr2_ck_p;
output wire             ddr2_ck_n;
output wire             ddr2_cke;
output wire             ddr2_odt;
output wire             ddr2_cs_n;
output wire             ddr2_ras_n;
output wire             ddr2_cas_n;
output wire             ddr2_we_n;
output wire [3 -1 : 0]  ddr2_ba;
output wire [13 -1 : 0] ddr2_addr;
inout  wire [16 -1 : 0] ddr2_dq;
output wire [2 -1 : 0]  ddr2_dm;
inout  wire [2 -1 : 0]  ddr2_dqs_p;
inout  wire [2 -1 : 0]  ddr2_dqs_n;

localparam CLKFREQ50MHZ  = 50000000;
localparam CLKFREQ100MHZ = 100000000;
localparam CLKFREQ200MHZ = 200000000;
wire pll_locked, clk50mhz_w, clk100mhz_w, clk200mhz_w;
xc7pll_100_to_50_100_200 pll (
	 .locked      (pll_locked)
	,.clk100mhz_i (clk100mhz_i)
	,.clk50mhz_o  (clk50mhz_w)
	,.clk100mhz_o (clk100mhz_w)
	,.clk200mhz_o (clk200mhz_w)
);

// Clock of the system, at 100 MHz, which litedram derives from clk100mhz_i
// using its own PLL, as rv32-nexysa7100/dev/sdram_ddr2.v describes; and its
// reset, which is high until that clock is stable.
wire sdram_ddr2_clk_w;
wire sdram_ddr2_rst_w;

(* direct_reset = "true" *) wire rst_w;
wire irqctrl_rst_rqst_w;
rstctrl #(
	 .RSTDURATION (CLKFREQ100MHZ/1000000) // 1us
	,.RSTTHRESH   (4*CLKFREQ100MHZ) // 4s
) rstctrl (
	 .clk_i (sdram_ddr2_clk_w)
	,.i     (~rst_n)
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
localparam S_WBPI_SDSDIO       = (S_WBPI_LITEDRAMCTRL + 1);
localparam S_WBPI_SPIFLASH     = (S_WBPI_SDSDIO + 1);
localparam S_WBPI_SERIAL_JTAG  = (S_WBPI_SPIFLASH + 1);
// Count of serial_jtag channels; the xc7 supports one BSCANE2
// per USER1-4 instruction.
localparam SERIAL_JTAG_COUNT   = 4;
localparam S_WBPI_DEFAULT      = (S_WBPI_SERIAL_JTAG + SERIAL_JTAG_COUNT);

localparam WBPI_MDEVCOUNT = (M_WBPI_LAST + 1);
localparam WBPI_SDEVCOUNT = (S_WBPI_DEFAULT + 1);

// The DDR2 SDRAM, and the registers of litedram which litedram_init() uses.
localparam LITEDRAM_MAPSZ     = 'h8000000;
localparam LITEDRAMCTRL_MAPSZ = 'h10000;

localparam [0:(WBPI_SDEVCOUNT*2*32)-1] WBPI_SDEVS = {
	/* S_WBPI_IRQCTRL       */ 32'hf00,  32'(WORDBITSZ/8),
	/* S_WBPI_SERIAL        */ 32'hf80,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SRAM          */ 32'h1000, 32'(`SRAM_KBSIZE*1024),
	/* S_WBPI_LITEDRAM      */ 32'('h1000+(`SRAM_KBSIZE*1024)), 32'(LITEDRAM_MAPSZ),
	/* S_WBPI_LITEDRAMCTRL  */ 32'('h1000+(`SRAM_KBSIZE*1024)+LITEDRAM_MAPSZ), 32'(LITEDRAMCTRL_MAPSZ),
	/* S_WBPI_SDSDIO        */ 32'he00,  32'(4*(WORDBITSZ/8)),
	/* S_WBPI_SPIFLASH      */ 32'he40,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SERIAL_JTAG+0 */ 32'he80,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SERIAL_JTAG+1 */ 32'hea0,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SERIAL_JTAG+2 */ 32'hec0,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SERIAL_JTAG+3 */ 32'hee0,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_DEFAULT       */ 32'h0,    32'h0};

localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 12'b011111110011;
localparam WBPI_WORDBITSZ         = `XWORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_ADDRLIMIT         = ('h1000+(`SRAM_KBSIZE*1024)+LITEDRAM_MAPSZ+LITEDRAMCTRL_MAPSZ);
localparam WBPI_CLKFREQ           = CLKFREQ100MHZ;
(* direct_reset = "true" *) wire wbpi_rst_w = (rst_w || sdram_ddr2_rst_w);
wire wbpi_clk_w = sdram_ddr2_clk_w;
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
localparam IRQ_SERIAL = (IRQ_DFLTDEV + 1);
localparam IRQ_SDSDIO = (IRQ_SERIAL + 1);
localparam IRQ_SPIFLASH = (IRQ_SDSDIO + 1);
localparam IRQ_SERIAL_JTAG = (IRQ_SPIFLASH + 1);

localparam IRQSRCCOUNT = (IRQ_SERIAL_JTAG + SERIAL_JTAG_COUNT); // Number of interrupt sources.
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

serial_uart #(
	 .WORDBITSZ   (WORDBITSZ)
	,.PHYCLKFREQ  (WBPI_CLKFREQ)
	,.DEFAULTBAUD (115200)
	,.BUFSZ       (2048)
) serial (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SERIAL])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SERIAL])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SERIAL])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SERIAL])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SERIAL])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SERIAL])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SERIAL])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SERIAL])

	,.irq_stb_o (irq_src_stb_w[IRQ_SERIAL])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SERIAL])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

// JTAG USER1-4 boundary-scan primitives through which the four
// serial_jtag channels are accessed; there is no pin constraint to
// add, as they tap the dedicated JTAG pins internally. All BSCANE2
// instances output the same TAP signals except SEL, which decodes
// the USER instruction of the instance JTAG_CHAIN, and TDO which is
// muxed per instruction; hence TCK/TDI/SHIFT/CAPTURE/RESET are used
// from instance 0 only, and the single TCK clocking fabric logic is
// buffered through a BUFG for deterministic low-skew routing; see
// the create_clock constraint in the xdc file.
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_capture_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_reset_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_sel_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_shift_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_tck_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_tdi_w;
wire [SERIAL_JTAG_COUNT -1 : 0] bscane2_tdo_w;

wire tap_tck_w;
BUFG bscane2_tck_bufg (
	 .I (bscane2_tck_w[0])
	,.O (tap_tck_w)
);

genvar gen_serial_jtag_idx;
generate for (
	gen_serial_jtag_idx = 0;
	gen_serial_jtag_idx < SERIAL_JTAG_COUNT;
	gen_serial_jtag_idx = gen_serial_jtag_idx + 1) begin :gen_serial_jtag

BSCANE2 #(
	 .JTAG_CHAIN (gen_serial_jtag_idx + 1)
) bscane2 (
	 .CAPTURE (bscane2_capture_w[gen_serial_jtag_idx])
	,.DRCK    ()
	,.RESET   (bscane2_reset_w[gen_serial_jtag_idx])
	,.RUNTEST ()
	,.SEL     (bscane2_sel_w[gen_serial_jtag_idx])
	,.SHIFT   (bscane2_shift_w[gen_serial_jtag_idx])
	,.TCK     (bscane2_tck_w[gen_serial_jtag_idx])
	,.TDI     (bscane2_tdi_w[gen_serial_jtag_idx])
	,.TMS     ()
	,.UPDATE  ()
	,.TDO     (bscane2_tdo_w[gen_serial_jtag_idx])
);

serial_jtag #(
	 .WORDBITSZ (WORDBITSZ)
	,.BUFSZ     (64)
) serial_jtag (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SERIAL_JTAG + gen_serial_jtag_idx])

	,.irq_stb_o (irq_src_stb_w[IRQ_SERIAL_JTAG + gen_serial_jtag_idx])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SERIAL_JTAG + gen_serial_jtag_idx])

	,.tap_tck_i     (tap_tck_w)
	,.tap_reset_i   (bscane2_reset_w[0])
	,.tap_sel_i     (bscane2_sel_w[gen_serial_jtag_idx])
	,.tap_capture_i (bscane2_capture_w[0])
	,.tap_shift_i   (bscane2_shift_w[0])
	,.tap_tdi_i     (bscane2_tdi_w[0])
	,.tap_tdo_o     (bscane2_tdo_w[gen_serial_jtag_idx])
);
end endgenerate

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

sdram_ddr2 #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
) sdram_ddr2 (

	 .rst_i (wbpi_rst_w)

	,.clk_i (clk100mhz_i)

	,.clk_o (sdram_ddr2_clk_w)
	,.rst_o (sdram_ddr2_rst_w)

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

	,.ddr2_ck_p  (ddr2_ck_p)
	,.ddr2_ck_n  (ddr2_ck_n)
	,.ddr2_cke   (ddr2_cke)
	,.ddr2_odt   (ddr2_odt)
	,.ddr2_cs_n  (ddr2_cs_n)
	,.ddr2_ras_n (ddr2_ras_n)
	,.ddr2_cas_n (ddr2_cas_n)
	,.ddr2_we_n  (ddr2_we_n)
	,.ddr2_ba    (ddr2_ba)
	,.ddr2_addr  (ddr2_addr)
	,.ddr2_dm    (ddr2_dm)
	,.ddr2_dq    (ddr2_dq)
	,.ddr2_dqs_p (ddr2_dqs_p)
	,.ddr2_dqs_n (ddr2_dqs_n)
);

wire            sdsdio_cmd_o_w;
wire            sdsdio_cmd_e_w;
wire [4 -1 : 0] sdsdio_dat_o_w;
wire [4 -1 : 0] sdsdio_dat_e_w;

sdio #(
	 .WORDBITSZ      (WORDBITSZ)
	,.PHYCLKFREQ     (WBPI_CLKFREQ)
	,.DEFAULTBITRATE (400000)
	,.CMDBUFSZ       (32)
	,.DATBUFSZ       (2048)
) sdsdio (

	 .rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_SDSDIO])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_SDSDIO])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_SDSDIO])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_SDSDIO])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_SDSDIO])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_SDSDIO])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_SDSDIO])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_SDSDIO])

	,.irq_stb_o (irq_src_stb_w[IRQ_SDSDIO])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SDSDIO])

	,.sdclk_o (sdsdio_clk_o)
	,.sdcmd_i (sdsdio_cmd_io)
	,.sdcmd_o (sdsdio_cmd_o_w)
	,.sdcmd_e (sdsdio_cmd_e_w)
	,.sddat_i (sdsdio_dat_io)
	,.sddat_o (sdsdio_dat_o_w)
	,.sddat_e (sdsdio_dat_e_w)
);

// Tristate per pad, driven while its enable from the device is high;
// a single ternary on the vector would reduce the enable to one bit.
assign sdsdio_cmd_io = (sdsdio_cmd_e_w ? sdsdio_cmd_o_w : 1'bz);
genvar gen_sdsdio_dat_io_idx;
generate for (
	gen_sdsdio_dat_io_idx = 0;
	gen_sdsdio_dat_io_idx < 4;
	gen_sdsdio_dat_io_idx = gen_sdsdio_dat_io_idx + 1) begin :gen_sdsdio_dat_io
	assign sdsdio_dat_io[gen_sdsdio_dat_io_idx] = (sdsdio_dat_e_w[gen_sdsdio_dat_io_idx] ?
		sdsdio_dat_o_w[gen_sdsdio_dat_io_idx] : 1'bz);
end endgenerate

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

// The clock of the flash is the configuration clock CCLK, a dedicated pin which
// user logic drives after configuration only through STARTUPE2; its first three
// cycles after configuration only switch CCLK over and are not output, which the
// 32 clock cycles with cs_o high of each control word absorb.
STARTUPE2 #(
	 .PROG_USR      ("FALSE")
	,.SIM_CCLK_FREQ (0.0)
) startupe2 (

	 .CFGCLK  ()
	,.CFGMCLK ()
	,.EOS     ()
	,.PREQ    ()

	,.CLK       (1'b0)
	,.GSR       (1'b0)
	,.GTS       (1'b0)
	,.KEYCLEARB (1'b1)
	,.PACK      (1'b0)

	,.USRCCLKO  (spiflash_sclk_w)
	,.USRCCLKTS (1'b0)

	,.USRDONEO  (1'b1)
	,.USRDONETS (1'b1)
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
