// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/xc7pll_100_to_50_100_200.sv"

`include "lib/rstbtnctrl.sv"

`define PURV32M
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

`include "dev/serial_uart.sv"

`include "dev/sram.sv"
/* makefile defined *///`define SRAM_KBSIZE (256/*KB*/)
/* makefile defined *///`define SRAM_INITFILE "artya7100.sram.hex"

module artya7100 (

	 rst_n

	,clk100mhz_i

	// UART signals.
	,uart_rx
	,uart_tx
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

localparam CLK1XFREQ = ( 50000000) /*  50 MHz */; // Frequency of clk_1x_w.
localparam CLK2XFREQ = (100000000) /* 100 MHz */; // Frequency of clk_2x_w.
localparam CLK4XFREQ = (200000000) /* 200 MHz */; // Frequency of clk_4x_w.
wire pll_locked;
wire clk50mhz;
wire clk100mhz;
wire clk200mhz;
xc7pll_100_to_50_100_200 pll (
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

(* direct_reset = "true" *) wire rst_w;
rstbtnctrl #(
	 .RSTDURATION (CLK2XFREQ/1000000) // 1us
	,.RSTTHRESH   (4*CLK2XFREQ) // 4s
) rstbtnctrl (
	 .clk_i (clk_2x_w)
	,.i     (~rst_n)
	,.o     (rst_w)
);

localparam CPU_COUNT = `CPU_COUNT;

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_IRQCTRL    = 0;
localparam S_WBPI_SERIAL     = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_SRAM       = (S_WBPI_SERIAL + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_SRAM + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = /* set in such a way that S_WBPI_SRAM starts at 0x1000 */
                                    ('h1000 - (128/*SERIAL_MAPSZ*/) - (128/*IRQCTRL_MAPSZ*/));
localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 4'b0011;
localparam WBPI_WORDBITSZ         = `XWORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_ADDRLIMIT         = ('h2000 + (`SRAM_KBSIZE * 1024));
localparam WBPI_CLKFREQ           = CLK2XFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_2x_w;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                                          m_wbpi_stb_w  [WBPI_MASTERCOUNT];
// 	input                                          m_wbpi_lock_w [WBPI_MASTERCOUNT];
// 	input                                          m_wbpi_we_w   [WBPI_MASTERCOUNT];
// 	input  [(WBPI_ADDRBITSZ-WBPI_MSBSZIGN) -1 : 0] m_wbpi_addr_w [WBPI_MASTERCOUNT];
// 	input  [(WBPI_WORDBITSZ/8) -1 : 0]             m_wbpi_sel_w  [WBPI_MASTERCOUNT];
// 	input  [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dati_w [WBPI_MASTERCOUNT];
// 	output                                         m_wbpi_bsy_w  [WBPI_MASTERCOUNT];
// 	output                                         m_wbpi_ack_w  [WBPI_MASTERCOUNT];
// 	output [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dato_w [WBPI_MASTERCOUNT];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                                         s_wbpi_stb_w   [WBPI_SLAVECOUNT];
// 	output                                         s_wbpi_lock_w  [WBPI_SLAVECOUNT];
// 	output                                         s_wbpi_we_w    [WBPI_SLAVECOUNT];
// 	output [(WBPI_ADDRBITSZ-WBPI_MSBSZIGN) -1 : 0] s_wbpi_addr_w  [WBPI_SLAVECOUNT];
// 	output [(WBPI_WORDBITSZ/8) -1 : 0]             s_wbpi_sel_w   [WBPI_SLAVECOUNT];
// 	output [WBPI_WORDBITSZ -1 : 0]                 s_wbpi_dato_w  [WBPI_SLAVECOUNT];
// 	input                                          s_wbpi_bsy_w   [WBPI_SLAVECOUNT];
// 	input                                          s_wbpi_ack_w   [WBPI_SLAVECOUNT];
// 	input  [WBPI_WORDBITSZ -1 : 0]                 s_wbpi_dati_w  [WBPI_SLAVECOUNT];
// 	input  [(WBPI_WORDBITSZ-WBPI_MSBSZIGN) -1 : 0] s_wbpi_mapsz_w [WBPI_SLAVECOUNT];
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

	,.spval_i ('h1000 + s_wbpi_mapsz_w[S_WBPI_SRAM])
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
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_IRQCTRL])

	,.irq_dst_stb_o (irq_dst_stb_w0)
	,.irq_dst_stb_i (irq_dst_stb_w1)
	,.irq_dst_rdy_i (irq_dst_rdy_w)
	,.irq_dst_pri_i (irq_dst_pri_w)

	,.irq_src_stb_i (irq_src_stb_w)
	,.irq_src_rdy_o (irq_src_rdy_w)
);

serial_uart #(
	 .WORDBITSZ   (WORDBITSZ)
	,.PHYCLKFREQ  (WBPI_CLKFREQ)
	,.DEFAULTBAUD (115200)
	,.BUFSZ       (4096)
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
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_SERIAL])

	,.irq_stb_o (irq_src_stb_w[IRQ_SERIAL])
	,.irq_rdy_i (irq_src_rdy_w[IRQ_SERIAL])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
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
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_SRAM])
);

// WBPI_DEFAULTSLAVEINDEX to catch invalid physical address space access.
assign s_wbpi_bsy_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_ack_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_mapsz_w[S_WBPI_INVALIDDEV] = ('h1000/* 4KB */);

genvar gen_cpu_dcache_miss_w_idx;
generate for (
	gen_cpu_dcache_miss_w_idx = 0;
	gen_cpu_dcache_miss_w_idx < CPU_COUNT;
	gen_cpu_dcache_miss_w_idx = gen_cpu_dcache_miss_w_idx + 1) begin :gen_cpu_dcache_miss_w
	wire [(WBPI_WORDBITSZ-WBPI_MSBSZIGN) -1 : 0] addr_w = cpu_dcache_addr_w[(gen_cpu_dcache_miss_w_idx*(WBPI_WORDBITSZ-WBPI_MSBSZIGN))+:(WBPI_WORDBITSZ-WBPI_MSBSZIGN)];
assign cpu_dcache_miss_w[gen_cpu_dcache_miss_w_idx] = (
	(addr_w < 'h1000) || (addr_w >= ('h1000 + s_wbpi_mapsz_w[S_WBPI_SRAM])));
end endgenerate

endmodule
