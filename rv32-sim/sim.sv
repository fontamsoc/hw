// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`define SIMULATION

`define PURV32M
`define PUIMULDSP
`define PUPREDICTJAL
`define PUPREDICTBRANCH
`define PUPREDICTRET
`include "rvxx/cpu.sv"
/* makefile defined *///`define CPU_COUNT 1

`include "lib/wb_arbiter.sv"
`include "lib/wb_mux.sv"
`include "lib/wb_dnsizr.sv"

`include "dev/irqctrl.sv"

`include "dev/serial_sim.sv"

`include "dev/sram.sv"
/* makefile defined *///`define SRAM_INITFILE "apps/helloworld/helloworld.hex"
/* makefile defined *///`define SRAM_KBSIZE (256/*KB*/)

/* makefile defined *///`define CLKFREQ (100000000/* 100 Mhz */)

module sim (
	 rst_i
	,clk_i
);

`include "lib/clog2.sv"

localparam WORDBITSZ = 32;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

input wire rst_i;
input wire clk_i;

wire clk_1x_w = clk_i;

wire rst_w = rst_i;

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
localparam WBPI_WORDBITSZ         = WORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_ADDRLIMIT         = ('h2000 + (`SRAM_KBSIZE * 1024));
localparam WBPI_WBTAGBITSZ        = 1;
localparam WBPI_CLKFREQ           = `CLKFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_i;
// The peripheral interconnect is instantiated in a separate file to keep this file clean.
// Master devices must use the following signals to plug onto the peripheral interconnect:
// 	input                                          m_wbpi_stb_w  [WBPI_MASTERCOUNT];
// 	input  [WBPI_WBTAGBITSZ -1 : 0]                m_wbpi_tag_w  [WBPI_MASTERCOUNT];
// 	input                                          m_wbpi_we_w   [WBPI_MASTERCOUNT];
// 	input  [(WBPI_ADDRBITSZ-WBPI_MSBSZIGN) -1 : 0] m_wbpi_addr_w [WBPI_MASTERCOUNT];
// 	input  [(WBPI_WORDBITSZ/8) -1 : 0]             m_wbpi_sel_w  [WBPI_MASTERCOUNT];
// 	input  [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dati_w [WBPI_MASTERCOUNT];
// 	output                                         m_wbpi_bsy_w  [WBPI_MASTERCOUNT];
// 	output                                         m_wbpi_ack_w  [WBPI_MASTERCOUNT];
// 	output [WBPI_WORDBITSZ -1 : 0]                 m_wbpi_dato_w [WBPI_MASTERCOUNT];
// Slave devices must use the following signals to plug onto the peripheral interconnect:
// 	output                                         s_wbpi_stb_w   [WBPI_SLAVECOUNT];
// 	output [WBPI_WBTAGBITSZ -1 : 0]                s_wbpi_tag_w   [WBPI_SLAVECOUNT];
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

localparam ICACHEWAYCNT = 2;
localparam DCACHEWAYCNT = 2;

// cpu_dcache_miss_w must be combinationally set high if
// cpu_dcache_addr_w is an address that must not be cached.
wire [((WBPI_WORDBITSZ-WBPI_MSBSZIGN)*CPU_COUNT) -1 : 0] cpu_dcache_addr_w;
wire [CPU_COUNT -1 : 0]                                  cpu_dcache_miss_w;

reg [WORDBITSZ -1 : 0] spval_r;
always @ (posedge wbpi_clk_w)
	spval_r <= ('h1000 + s_wbpi_mapsz_w[S_WBPI_SRAM]);

cpu #(
	 .WORDBITSZ     (WORDBITSZ)
	,.XWORDBITSZ    (WBPI_WORDBITSZ)
	,.ADDRLIMIT     (WBPI_ADDRLIMIT)
	,.WBTAGBITSZ    (WBPI_WBTAGBITSZ)
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
	,.wb_tag_o  (m_wbpi_tag_w[M_WBPI_CPU])
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

	,.spval_i (spval_r)

	,.id_i (0)
);

// Logic used by sim_use_vcd verilator testbench.
wire [WORDBITSZ -1 : 0] pc_w [CPU_COUNT -1 : 0] /* verilator public */;
genvar gen_pc_w_idx;
generate for (gen_pc_w_idx = 0; gen_pc_w_idx < CPU_COUNT; gen_pc_w_idx = gen_pc_w_idx + 1) begin :gen_pc_w
assign pc_w[gen_pc_w_idx] =
	cpu.genpu[gen_pc_w_idx].pu.eX_JumpOrBranch ? cpu.genpu[gen_pc_w_idx].pu.iF_pc :
	                                             cpu.genpu[gen_pc_w_idx].pu.iD_pc;
end endgenerate

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

serial_sim #(
	.WORDBITSZ (WORDBITSZ)
) serial (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

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
always @ (posedge wbpi_clk_w) begin
	if (s_wbpi_stb_w[S_WBPI_INVALIDDEV]) begin
		$write("!!! s_wbpi_addr_w[S_WBPI_INVALIDDEV] == 0x%x\n",
			{{WBPI_CLOG2WORDBITSZBY8{1'b0}}, s_wbpi_addr_w[S_WBPI_INVALIDDEV]}<<WBPI_CLOG2WORDBITSZBY8);
		$fflush(1);
		$finish;
	end
end

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
