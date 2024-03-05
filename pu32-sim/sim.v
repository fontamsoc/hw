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

`define PUMMU
`define PUHPTW
`ifdef SIMUSECLKDIV
`define PUIMULCLK
`define PUIDIVCLK
`define PUFADDFSUBCLK
`define PUFMULCLK
`define PUFDIVCLK
`endif
`define PUIMULDSP
`define PUFADDFSUB
`define PUFMUL
`define PUFMULDSP
`define PUFDIV
`define PUDCACHE
`define PUSC2
`define PUSC2SKIPSC1LI8
`define PUSC2SKIPSC1CPY
`define PUCOUNT 1
`include "pu/cpu.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/devtbl.v"

`include "dev/irqctrl.v"

`include "dev/uart_sim.v"

//`define DCACHESRAM
`ifdef DCACHESRAM
`include "dev/dcache.v"
`endif
`include "dev/sram.v"

`include "dev/bootldr/bootldr.v"

`ifdef SIMUSECLKDIV
module pll (
	 clk_4x_i
	,clk_2x_o
	,clk_1x_o
);

input  wire clk_4x_i;
output wire clk_2x_o;
output wire clk_1x_o;

reg [1:0] cntr = 2'b00;
always @ (posedge clk_4x_i) begin
	cntr <= cntr - 1'b1; // Using substraction to have divided clocks in-phase.
end

assign clk_2x_o = cntr[0];
assign clk_1x_o = cntr[1];

endmodule
`endif

module sim (
	 rst_i
	,clk_i
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;
input wire clk_i;

wire cpu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

always @* begin
	if (swpwroff)
		$finish;
end

localparam RST_CNTR_BITSZ = 4;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk_i) begin
	if (cpu_rst_ow || swwarmrst || rst_i)
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
	else if (rst_cntr)
		rst_cntr <= rst_cntr - 1'b1;
end

always @ (posedge clk_i) begin
	if (rst_i)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

localparam CLK1XFREQ = (100000000) /* 100 Mhz */; // Frequency of clk_1x_w.
localparam CLK2XFREQ = (200000000) /* 200 Mhz */; // Frequency of clk_2x_w.
localparam CLK4XFREQ = (400000000) /* 400 Mhz */; // Frequency of clk_4x_w.

`ifdef SIMUSECLKDIV
wire clk_1x_w;
wire clk_2x_w;
wire clk_4x_w = clk_i;
pll pll (
	 .clk_4x_i (clk_4x_w)
	,.clk_2x_o (clk_2x_w)
	,.clk_1x_o (clk_1x_w)
);
`else
wire clk_1x_w = clk_i;
`endif

wire rst_w = (devtbl_rst0_r || (|rst_cntr));

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

localparam M_WBPI_CPU        = 0;
localparam M_WBPI_LAST       = M_WBPI_CPU;
localparam S_WBPI_SDCARD     = 0;
localparam S_WBPI_DEVTBL     = (S_WBPI_SDCARD + 1);
localparam S_WBPI_IRQCTRL    = (S_WBPI_DEVTBL + 1);
localparam S_WBPI_UART       = (S_WBPI_IRQCTRL + 1);
localparam S_WBPI_RAM        = (S_WBPI_UART + 1);
localparam S_WBPI_BOOTLDR    = (S_WBPI_RAM + 1);
localparam S_WBPI_INVALIDDEV = (S_WBPI_BOOTLDR + 1);

localparam WBPI_MASTERCOUNT       = (M_WBPI_LAST + 1);
localparam WBPI_SLAVECOUNT        = (S_WBPI_INVALIDDEV + 1);
localparam WBPI_DEFAULTSLAVEINDEX = S_WBPI_INVALIDDEV;
localparam WBPI_FIRSTSLAVEADDR    = 0;
localparam WBPI_DNSIZR            = 7'b0001110;
localparam WBPI_ARCHBITSZ         = ARCHBITSZ;
localparam WBPI_CLOG2ARCHBITSZBY8 = clog2(WBPI_ARCHBITSZ/8);
localparam WBPI_ADDRBITSZ         = (WBPI_ARCHBITSZ - WBPI_CLOG2ARCHBITSZBY8);
localparam WBPI_CLKFREQ           = CLK1XFREQ;
wire wbpi_rst_w = rst_w;
wire wbpi_clk_w = clk_1x_w;
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
localparam IRQ_UART   = (IRQ_SDCARD + 1);

localparam IRQCTRLSRCCOUNT = (IRQ_UART +1); // Number of interrupt source.
localparam IRQCTRLDSTCOUNT = PUCOUNT; // Number of interrupt destination.
wire [IRQCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [IRQCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [IRQCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [IRQCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [IRQCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam ICACHESZ = 128;
localparam DCACHESZ = 32;
localparam TLBSZ    = 64;

localparam ICACHEWAYCOUNT = 4;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 1;

wire [(ARCHBITSZ * PUCOUNT) -1 : 0] pc_w_flat;
wire [ARCHBITSZ -1 : 0] pc_w [PUCOUNT -1 : 0] /* verilator public */;
genvar gen_pc_w_idx;
generate for (gen_pc_w_idx = 0; gen_pc_w_idx < PUCOUNT; gen_pc_w_idx = gen_pc_w_idx + 1) begin :gen_pc_w
assign pc_w[gen_pc_w_idx] = pc_w_flat[((gen_pc_w_idx+1) * ARCHBITSZ) -1 : gen_pc_w_idx * ARCHBITSZ];
end endgenerate

cpu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.XARCHBITSZ     (WBPI_ARCHBITSZ)
	,.CLKFREQ        (CLK1XFREQ)
	,.ICACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*(ICACHESZ/ICACHEWAYCOUNT))
	,.DCACHESETCOUNT ((1024/(WBPI_ARCHBITSZ/8))*(DCACHESZ/DCACHEWAYCOUNT))
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

	 .rst_i (rst_w)

	,.rst_o (cpu_rst_ow)

	,.clk_i (clk_1x_w)
	`ifdef SIMUSECLKDIV
	,.clk_imul_i     (clk_4x_w)
	,.clk_idiv_i     (clk_4x_w)
	,.clk_faddfsub_i (clk_4x_w)
	,.clk_fmul_i     (clk_4x_w)
	,.clk_fdiv_i     (clk_4x_w)
	`endif
	`ifdef PUCOUNT
	,.clk_mem_i (wbpi_clk_w)
	`endif

	,.wb_cyc_o  (m_wbpi_cyc_w[M_WBPI_CPU])
	,.wb_stb_o  (m_wbpi_stb_w[M_WBPI_CPU])
	,.wb_we_o   (m_wbpi_we_w[M_WBPI_CPU])
	,.wb_addr_o (m_wbpi_addr_w[M_WBPI_CPU])
	,.wb_sel_o  (m_wbpi_sel_w[M_WBPI_CPU])
	,.wb_dat_o  (m_wbpi_dati_w[M_WBPI_CPU])
	,.wb_bsy_i  (m_wbpi_bsy_w[M_WBPI_CPU])
	,.wb_ack_i  (m_wbpi_ack_w[M_WBPI_CPU])
	,.wb_dat_i  (m_wbpi_dato_w[M_WBPI_CPU])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  ((('h1000)>>1) +
		(s_wbpi_mapsz_w[S_WBPI_RAM]>>1))
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)

	,.pc_o (pc_w_flat)
);

sdcard_spi #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.XARCHBITSZ (WBPI_ARCHBITSZ)
	,.SRCFILE ("pu32.img.hex" /* `hexdump -v -e '/1 "%02x "' /path/to/img > pu32.img.hex` */)
	,.SIMSTORAGESZ (81920*5)

) sdcard (

	.rst_i (wbpi_rst_w)

	,.clk_i     (wbpi_clk_w)
	,.clk_phy_i (wbpi_clk_w)

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

	,.intrqst_o (intrqstsrc_w[IRQ_SDCARD])
	,.intrdy_i  (intrdysrc_w[IRQ_SDCARD])
);

assign dev_id_w    [S_WBPI_SDCARD] = 4;
assign dev_useirq_w[S_WBPI_SDCARD] = 1;

`ifdef DCACHESRAM
localparam RAMCACHEWAYCOUNT = 2;
localparam RAMCACHESZ = ((1024/(WBPI_ARCHBITSZ/8))*(32/RAMCACHEWAYCOUNT)); /* In (WBPI_ARCHBITSZ/8) units */

wire devtbl_rst2_w;
`endif

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	 `ifdef DCACHESRAM
	,.RAMCACHESZ (RAMCACHESZ*(WBPI_ARCHBITSZ/ARCHBITSZ))
	,.PRELDRADDR ('h1000)
	`endif
	,.DEVMAPCNT  (WBPI_SLAVECOUNT)
	,.SOCID      (0)

) devtbl (

	 .rst_i (wbpi_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	`ifdef DCACHESRAM
	,.rst2_o (devtbl_rst2_w)
	`endif

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

	 .ARCHBITSZ   (ARCHBITSZ)
	,.INTSRCCOUNT (IRQCTRLSRCCOUNT)
	,.INTDSTCOUNT (IRQCTRLDSTCOUNT)

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

	,.intrqstdst_o (intrqstdst_w)
	,.intrdydst_i  (intrdydst_w)
	,.intbestdst_i (intbestdst_w)

	,.intrqstsrc_i (intrqstsrc_w)
	,.intrdysrc_o  (intrdysrc_w)
);

assign dev_id_w    [S_WBPI_IRQCTRL] = 3;
assign dev_useirq_w[S_WBPI_IRQCTRL] = 0;

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart (

	 .rst_i (wbpi_rst_w)

	,.clk_i (wbpi_clk_w)

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

	,.intrqst_o (intrqstsrc_w[IRQ_UART])
	,.intrdy_i  (intrdysrc_w[IRQ_UART])
);

assign dev_id_w    [S_WBPI_UART] = 5;
assign dev_useirq_w[S_WBPI_UART] = 1;

localparam RAMSZ = ('h2000000/* 32MB */);

`ifdef DCACHESRAM

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge wbpi_clk_w) begin
	if (ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

reg conly_r;
always @ (posedge wbpi_clk_w) begin
	if (ram_rst_cntr)
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

localparam DCACHE_INITFILE =
	WBPI_ARCHBITSZ == 32 ? "dcacheinit/dcacheinit32.hex" :
	WBPI_ARCHBITSZ == 64 ? "dcacheinit/dcacheinit64.hex" :
	WBPI_ARCHBITSZ == 128 ? "dcacheinit/dcacheinit128.hex" :
	WBPI_ARCHBITSZ == 256 ? "dcacheinit/dcacheinit256.hex" : "";

dcache #(

	 .ARCHBITSZ     (WBPI_ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ)
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.INITFILE      (DCACHE_INITFILE)

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (wbpi_clk_w)

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
	,.s_wb_bsy_i  (dcache_wb_bsy_w)
	,.s_wb_ack_i  (dcache_wb_ack_w)
	,.s_wb_dat_i  (dcache_wb_dati_w)
);

sram #(

	 .ARCHBITSZ (WBPI_ARCHBITSZ)
	,.SIZE      (RAMSZ/(WBPI_ARCHBITSZ/8))
	,.DELAY     (0)

) sram (

	 .rst_i (ram_rst_w)

	,.clk_i (wbpi_clk_w)

	,.wb_cyc_i   (dcache_wb_cyc_w)
	,.wb_stb_i   (dcache_wb_stb_w)
	,.wb_we_i    (dcache_wb_we_w)
	,.wb_addr_i  (dcache_wb_addr_w)
	,.wb_sel_i   (dcache_wb_sel_w)
	,.wb_dat_i   (dcache_wb_dato_w)
	,.wb_bsy_o   (dcache_wb_bsy_w)
	,.wb_ack_o   (dcache_wb_ack_w)
	,.wb_dat_o   (dcache_wb_dati_w)
	,.wb_mapsz_o (s_wbpi_mapsz_w[S_WBPI_RAM])
);

`else /* !DCACHESRAM */

sram #(

	 .ARCHBITSZ (WBPI_ARCHBITSZ)
	,.SIZE      (RAMSZ/(WBPI_ARCHBITSZ/8))
	,.DELAY     (0)

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

`endif /* DCACHESRAM */

assign dev_id_w    [S_WBPI_RAM] = 1;
assign dev_useirq_w[S_WBPI_RAM] = 0;

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
assign dev_id_w[S_WBPI_INVALIDDEV] = 0;
assign dev_useirq_w[S_WBPI_INVALIDDEV] = 0;
always @ (posedge wbpi_clk_w) begin
	if (!wbpi_rst_w && s_wbpi_cyc_w[S_WBPI_INVALIDDEV]) begin
		$write("!!! s_wbpi_addr_w[S_WBPI_INVALIDDEV] == 0x%x\n",
			{{WBPI_CLOG2ARCHBITSZBY8{1'b0}}, s_wbpi_addr_w[S_WBPI_INVALIDDEV]}<<WBPI_CLOG2ARCHBITSZBY8);
		$fflush(1);
		$finish;
	end
end

endmodule
