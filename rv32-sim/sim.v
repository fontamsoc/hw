// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`define SIMULATION

`include "lib/wb_arbiter.v"
`include "lib/wb_mux.v"
`include "lib/wb_dnsizr.v"

`define PURV32M
`define PUIMULDSP
`define PUPREDICTJAL
`define PUPREDICTBRANCH
`define PUPREDICTRET
`include "rvxx/cpu.v"
/* makefile defined *///`define CPU_COUNT 1

`include "dev/serial_sim.v"

`include "dev/sram.v"
/* makefile defined *///`define SRAM_INITFILE "coremark.hex"
/* makefile defined *///`define SRAM_KBSIZE (256/*KB*/)

/* makefile defined *///`define CLKFREQ (100000000/* 100 Mhz */)

module sim (
	 rst_i
	,clk_i
);

`include "lib/clog2.v"

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
localparam S_WBPI_SERIAL     = 0;
localparam S_WBPI_RAM        = (S_WBPI_SERIAL + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_RAM + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = /* set so memory starts at 0x1000*/ ('h1000 - (128/*SERIAL_MAPSZ*/));
localparam WBPI_MAXPENDINGACK     = 32;
localparam WBPI_DNSIZR            = 3'b001;
localparam WBPI_WORDBITSZ         = WORDBITSZ;
localparam WBPI_CLOG2WORDBITSZBY8 = clog2(WBPI_WORDBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_WORDBITSZ - WBPI_CLOG2WORDBITSZBY8);
localparam WBPI_CLKFREQ           = `CLKFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_i;
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

localparam ICACHESZ = 16;
localparam DCACHESZ = 16;

localparam ICACHEWAYCNT = 2;
localparam DCACHEWAYCNT = 2;

// cpu_dcache_miss_w must be combinationally set high if
// cpu_dcache_addr_w is an address that must not be cached.
wire [(WBPI_WORDBITSZ*CPU_COUNT) -1 : 0] cpu_dcache_addr_w;
wire [CPU_COUNT -1 : 0]                  cpu_dcache_miss_w;

cpu #(
	 .WORDBITSZ     (WORDBITSZ)
	,.XWORDBITSZ    (WBPI_WORDBITSZ)
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

	,.wb_cyc_o  (m_wbpi_cyc_w[M_WBPI_CPU])
	,.wb_stb_o  (m_wbpi_stb_w[M_WBPI_CPU])
	,.wb_we_o   (m_wbpi_we_w[M_WBPI_CPU])
	,.wb_addr_o (m_wbpi_addr_w[M_WBPI_CPU])
	,.wb_sel_o  (m_wbpi_sel_w[M_WBPI_CPU])
	,.wb_dat_o  (m_wbpi_dati_w[M_WBPI_CPU])
	,.wb_bsy_i  (m_wbpi_bsy_w[M_WBPI_CPU])
	,.wb_ack_i  (m_wbpi_ack_w[M_WBPI_CPU])
	,.wb_dat_i  (m_wbpi_dato_w[M_WBPI_CPU])

	,.dcache_addr_o (cpu_dcache_addr_w)
	,.dcache_miss_i (cpu_dcache_miss_w)

	,.rstaddr_i  ('h1000)
	,.rstaddr2_i ()
);

// Logic used by sim_use_vcd verilator testbench.
wire [WORDBITSZ -1 : 0] pc_w [CPU_COUNT -1 : 0] /* verilator public */;
genvar gen_pc_w_idx;
generate for (gen_pc_w_idx = 0; gen_pc_w_idx < CPU_COUNT; gen_pc_w_idx = gen_pc_w_idx + 1) begin :gen_pc_w
assign pc_w[gen_pc_w_idx] =
	cpu.genpu[gen_pc_w_idx].pu.iF_eX_JumpOrBranch ? cpu.genpu[gen_pc_w_idx].pu.iF_pc :
	                                                cpu.genpu[gen_pc_w_idx].pu.iD_pc;
end endgenerate

serial_sim #(
	.WORDBITSZ (WORDBITSZ)
) serial (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

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
);

sram #(
	 .WORDBITSZ (WBPI_WORDBITSZ)
	,.SIZE      ((`SRAM_KBSIZE)*(1024/(WBPI_WORDBITSZ/8)))
	,.INITFILE  (`SRAM_INITFILE)
) sram (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (s_wbpi_cyc_w[S_WBPI_RAM])
	,.wb_stb_i   (s_wbpi_stb_w[S_WBPI_RAM])
	,.wb_we_i    (s_wbpi_we_w[S_WBPI_RAM])
	,.wb_addr_i  (s_wbpi_addr_w[S_WBPI_RAM])
	,.wb_sel_i   (s_wbpi_sel_w[S_WBPI_RAM])
	,.wb_dat_i   (s_wbpi_dato_w[S_WBPI_RAM])
	,.wb_bsy_o   (s_wbpi_bsy_w[S_WBPI_RAM])
	,.wb_ack_o   (s_wbpi_ack_w[S_WBPI_RAM])
	,.wb_dat_o   (s_wbpi_dati_w[S_WBPI_RAM])
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_RAM])
);

// WBPI_DEFAULTSLAVEINDEX to catch invalid physical address space access.
assign s_wbpi_bsy_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_ack_w[S_WBPI_INVALIDDEV] = 0;
assign s_wbpi_mapsz_w[S_WBPI_INVALIDDEV] = ('h1000/* 4KB */);
always @ (posedge wbpi_clk_w) begin
	if (!wbpi_rst_w && s_wbpi_cyc_w[S_WBPI_INVALIDDEV]) begin
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
	wire [WBPI_WORDBITSZ -1 : 0] addr_w = cpu_dcache_addr_w[
		((gen_cpu_dcache_miss_w_idx+1)*WBPI_WORDBITSZ) -1 : gen_cpu_dcache_miss_w_idx*WBPI_WORDBITSZ];
assign cpu_dcache_miss_w[gen_cpu_dcache_miss_w_idx] = (
	(addr_w < 'h1000) || (addr_w >= ('h1000 + s_wbpi_mapsz_w[S_WBPI_RAM])));
end endgenerate

endmodule
