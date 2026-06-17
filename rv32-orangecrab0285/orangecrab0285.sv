// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/rstctrl.sv"

`define PURV32M
`define PURV32ZBA
// PURV32ZBB disabled on FPGA tops: it pushes rv32-orangecrab0285 below 48 MHz
// timing closure (scoreboard-region routing congestion). Still enabled in rv32-sim.
//`define PURV32ZBB
`define PUIMULDSP
`define PUPREDICTJAL
`define PUPREDICTBRANCH
`define PUPREDICTRET
`include "rvxx/cpu.sv"
/* makefile defined *///`define CPU_COUNT 1
/* makefile defined *///`define XWORDBITSZ 32

`include "lib/wb_arbiter.sv"
`include "lib/wb_mux.sv"
`include "lib/wb_dnsizr.sv"

`include "dev/irqctrl.sv"

`include "dev/serial_usb.sv"

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

localparam CLKFREQ48MHZ = 48000000;
wire clk48mhz_w = clk48mhz_i;

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
localparam S_WBPI_IRQCTRL = 0;
localparam S_WBPI_SERIAL  = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_SRAM    = (S_WBPI_SERIAL + 1);
localparam S_WBPI_DEFAULT = (S_WBPI_SRAM + 1);

localparam WBPI_MDEVCOUNT = (M_WBPI_LAST + 1);
localparam WBPI_SDEVCOUNT = (S_WBPI_DEFAULT + 1);

localparam [0:(WBPI_SDEVCOUNT*2*32)-1] WBPI_SDEVS = {
	/* S_WBPI_IRQCTRL */ 32'hf00,  32'(WORDBITSZ/8),
	/* S_WBPI_SERIAL  */ 32'hf80,  32'(2*(WORDBITSZ/8)),
	/* S_WBPI_SRAM    */ 32'h1000, 32'(`SRAM_KBSIZE*1024),
	/* S_WBPI_DEFAULT */ 32'h0,    32'h0};

localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 4'b0011;
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

localparam IRQ_SERIAL = 0;

localparam IRQSRCCOUNT = (IRQ_SERIAL +1); // Number of interrupt source.
localparam IRQDSTCOUNT = CPU_COUNT; // Number of interrupt destination.
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

cpu #(
	 .WORDBITSZ     (WORDBITSZ)
	,.XWORDBITSZ    (WBPI_WORDBITSZ)
	,.ADDRLIMIT     (WBPI_ADDRLIMIT)
	,.CLKFREQ       (WBPI_CLKFREQ)
	,.ICACHESETCNT  ((1024/(WBPI_WORDBITSZ/8))*(ICACHESZ/ICACHEWAYCNT))
	,.DCACHESETCNT  ((1024/(WBPI_WORDBITSZ/8))*(DCACHESZ/DCACHEWAYCNT))
	,.ICACHEWAYCNT  (ICACHEWAYCNT)
	,.DCACHEWAYCNT  (DCACHEWAYCNT)
	,.IMULCNT       (2)
	,.IDIVCNT       (2)
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
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_IRQCTRL])
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
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz or 60MHz.
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
