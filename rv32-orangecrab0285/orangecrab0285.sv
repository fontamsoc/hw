// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
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
//`define  PUFDIVDSP2
//`define  PUFSQRTDSP
//`define  PUFSQRTDSP2
`define PUPREDICTJAL
`define PUPREDICTBRANCH
`define PUPREDICTRET
//`define PUDCACHEREGRQST
`define PUDCACHEREGRESP
`include "cpu/ccx.sv"
/* makefile defined *///`define CPU_COUNT 1
/* makefile defined *///`define XWORDBITSZ 32

`include "lib/wb_arbiter.sv"
`include "lib/wb_mux.sv"
`include "lib/wb_dnsizr.sv"

`include "dev/irqctrl.sv"

`include "dev/serial_usb.sv"

`include "lib/serial_jtag_jtagg.sv"

`include "dev/serial_jtag.sv"

`include "dev/sram.sv"
/* makefile defined *///`define SRAM_KBSIZE (256/*KB*/)
/* makefile defined *///`define SRAM_INITFILE "orangecrab0285.sram.hex"

module orangecrab0285 (

	 usr_btn_n

	,clk48mhz_i

	// USB signals.
	,usb_d_p
	,usb_d_n
	,usb_pullup

	// LED signals.
	,led_red_n
	,led_green_n
	,led_blue_n
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

// LED signals.
output wire led_red_n;
output wire led_green_n;
output wire led_blue_n;
assign led_red_n = 1'b1;
assign led_green_n = 1'b1;
assign led_blue_n = 1'b1;

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

wire rst_w;
rstctrl #(
	 .RSTDURATION (CLKFREQ48MHZ/1000000) // 1us
	,.RSTTHRESH   (4*CLKFREQ48MHZ) // 4s
) rstctrl (
	 .clk_i (clk48mhz_w)
	,.i     (~usr_btn_n)
	,.o     (rst_w)
);

localparam CPU_COUNT = `CPU_COUNT;

localparam M_WBPI_CPU     = 0;
localparam M_WBPI_LAST    = M_WBPI_CPU;
localparam S_WBPI_SERIAL_JTAG = 0;
// Count of serial_jtag channels; the ecp5 JTAGG primitive
// has two user data-registers, ER1 and ER2.
localparam SERIAL_JTAG_COUNT  = 2;
localparam S_WBPI_IRQCTRL     = (S_WBPI_SERIAL_JTAG + SERIAL_JTAG_COUNT);
localparam S_WBPI_SERIAL      = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_SRAM        = (S_WBPI_SERIAL + 1);
localparam S_WBPI_DEFAULT     = (S_WBPI_SRAM + 1);

localparam WBPI_MDEVCOUNT = (M_WBPI_LAST + 1);
localparam WBPI_SDEVCOUNT = (S_WBPI_DEFAULT + 1);

localparam [0:(WBPI_SDEVCOUNT*2*32)-1] WBPI_SDEVS = {
	/* S_WBPI_SERIAL_JTAG+0 */ 32'he80,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SERIAL_JTAG+1 */ 32'hea0,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_IRQCTRL       */ 32'hf00,  32'(WORDBITSZ/8),
	/* S_WBPI_SERIAL        */ 32'hf80,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SRAM          */ 32'h1000, 32'(`SRAM_KBSIZE*1024),
	/* S_WBPI_DEFAULT       */ 32'h0,    32'h0};

localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 6'b001111;
localparam WBPI_WORDBITSZ         = `XWORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_ADDRLIMIT         = ('h1000+(`SRAM_KBSIZE*1024));
localparam WBPI_CLKFREQ           = CLKFREQ48MHZ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk48mhz_w;
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

localparam IRQ_SERIAL      = 0;
localparam IRQ_SERIAL_JTAG = (IRQ_SERIAL + 1);

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
	,.IMULCNT       (2)
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
);

reg [7:0] serial_rst_r = -1;
always_ff @(posedge clk48mhz_w) begin
	if (serial_rst_r)
		serial_rst_r <= serial_rst_r - 1'b1;
end

serial_usb #(
	 .WORDBITSZ  (WORDBITSZ)
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz.
	,.BUFSZ      (4096)
) serial (

	 .rst_i ((|serial_rst_r)
		/* wbpi_rst_w is not used because subsequent
		   resets break the usb connection */)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (clk48mhz_w)

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

	,.usb_dp_io (usb_d_p)
	,.usb_dn_io (usb_d_n)
);

// JTAG boundary-scan primitive through which the serial_jtag
// channels are accessed, channel 0 through the ER1 (0x32) user
// data-register and channel 1 through ER2 (0x38); there is no pin
// constraint to add, as it taps the dedicated JTAG pins internally
// (its pad ports TCK/TMS/TDI/TDO are implicit and left unconnected).
// The JTAGG signals differ from the Xilinx BSCANE2's (registered
// JTDI, combinational TDO pin, no CAPTURE decode, raw-TCK timing
// racing the fabric clock) and go through the serial_jtag_jtagg
// adapter which owns that contract, see its header (including the
// no-Pause-DR host limitation); the serial_jtag devices are paired
// with the adapter through their TAPJTAGG parameter.
wire tap_tck_w;
wire tap_tdi_w;
wire [SERIAL_JTAG_COUNT -1 : 0] tap_tdo_w;
wire jtagg_jrstn_w;
wire jtagg_jshift_w;
wire [SERIAL_JTAG_COUNT -1 : 0] jtagg_jce_w;
wire [SERIAL_JTAG_COUNT -1 : 0] jtagg_jtdo_w;

JTAGG jtagg (
	 .JTDO1   (jtagg_jtdo_w[0])
	,.JTDO2   (jtagg_jtdo_w[1])
	,.JTDI    (tap_tdi_w)
	,.JTCK    (tap_tck_w)
	,.JRTI1   ()
	,.JRTI2   ()
	,.JSHIFT  (jtagg_jshift_w)
	,.JUPDATE ()
	,.JRSTN   (jtagg_jrstn_w)
	,.JCE1    (jtagg_jce_w[0])
	,.JCE2    (jtagg_jce_w[1])
);

wire                            tap_jtagg_tck_w;
wire                            tap_jtagg_reset_w;
wire [SERIAL_JTAG_COUNT -1 : 0] tap_jtagg_sel_w;
wire [SERIAL_JTAG_COUNT -1 : 0] tap_jtagg_capture_w;
wire                            tap_jtagg_shift_w;
wire                            tap_jtagg_tdi_w;

serial_jtag_jtagg #(
	 .CHANNELCNT (SERIAL_JTAG_COUNT)
) serial_jtag_jtagg (
	 .jtck_i   (tap_tck_w)
	,.jtdi_i   (tap_tdi_w)
	,.jshift_i (jtagg_jshift_w)
	,.jrstn_i  (jtagg_jrstn_w)
	,.jce_i    (jtagg_jce_w)
	,.jtdo_o   (jtagg_jtdo_w)

	,.tap_tck_o     (tap_jtagg_tck_w)
	,.tap_reset_o   (tap_jtagg_reset_w)
	,.tap_sel_o     (tap_jtagg_sel_w)
	,.tap_capture_o (tap_jtagg_capture_w)
	,.tap_shift_o   (tap_jtagg_shift_w)
	,.tap_tdi_o     (tap_jtagg_tdi_w)
	,.tap_tdo_i     (tap_tdo_w)
);

genvar gen_serial_jtag_idx;
generate for (
	gen_serial_jtag_idx = 0;
	gen_serial_jtag_idx < SERIAL_JTAG_COUNT;
	gen_serial_jtag_idx = gen_serial_jtag_idx + 1) begin :gen_serial_jtag

serial_jtag #(
	 .WORDBITSZ (WORDBITSZ)
	,.BUFSZ     (16
		/* kept small, unlike on the Xilinx boards, because the
		   transmit fifo maps to distributed ram whose area was
		   measured to congest the 48 MHz timing closure */)
	,.TAPJTAGG  (1)
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

	,.tap_tck_i     (tap_jtagg_tck_w)
	,.tap_reset_i   (tap_jtagg_reset_w)
	,.tap_sel_i     (tap_jtagg_sel_w[gen_serial_jtag_idx])
	,.tap_capture_i (tap_jtagg_capture_w[gen_serial_jtag_idx])
	,.tap_shift_i   (tap_jtagg_shift_w)
	,.tap_tdi_i     (tap_jtagg_tdi_w)
	,.tap_tdo_o     (tap_tdo_w[gen_serial_jtag_idx])
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

// Catch invalid physical address space access.
assign s_wbpi_bsy_w[S_WBPI_DEFAULT] = 0;
assign s_wbpi_ack_w[S_WBPI_DEFAULT] = 0;

genvar gen_cpu_dcache_miss_w_idx;
generate for (
	gen_cpu_dcache_miss_w_idx = 0;
	gen_cpu_dcache_miss_w_idx < CPU_COUNT;
	gen_cpu_dcache_miss_w_idx = gen_cpu_dcache_miss_w_idx + 1) begin :gen_cpu_dcache_miss_w
	wire [(WBPI_WORDBITSZ-WBPI_MSBSZIGN) -1 : 0] addr_w = cpu_dcache_addr_w[(gen_cpu_dcache_miss_w_idx*(WBPI_WORDBITSZ-WBPI_MSBSZIGN))+:(WBPI_WORDBITSZ-WBPI_MSBSZIGN)];
assign cpu_dcache_miss_w[gen_cpu_dcache_miss_w_idx] = (
	(addr_w < 'h1000) || (addr_w >= ('h1000+(`SRAM_KBSIZE*1024))));
end endgenerate

endmodule
