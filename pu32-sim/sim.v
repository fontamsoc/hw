// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`define SIMULATION

`include "lib/perint/pi1r.v"

`include "dev/pi1_downconverter.v"

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

`include "dev/intctrl.v"

`include "dev/uart_sim.v"

//`define PI1QLITEDRAM
//`define WB4SMEM
`ifdef PI1QLITEDRAM
`include "dev/pi1_dcache.v"
`include "dev/pi1q_to_wb4.v"
`include "dev/pi1q_to_litedram.v"
`include "./litedram/litedram.v"
`elsif WB4SMEM
`include "dev/pi1_upconverter.v"
`include "dev/pi1_dcache.v"
`include "dev/pi1_to_wb4.v"
`include "lib/wb4smem.v"
`else
`include "dev/smem.v"
`endif

`include "dev/bootldr/bootldr.v"

`ifdef SIMUSECLKDIV
module clkdiv (
	 clk_4x_i
	,clk_2x_o
	,clk_o
);

input  wire clk_4x_i;
output wire clk_2x_o;
output wire clk_o;

reg [1:0] cntr = 2'b00;
always @ (posedge clk_4x_i) begin
	cntr <= cntr - 1'b1; // Using substraction to have divided clocks in-phase.
end

assign clk_2x_o = cntr[0];
assign clk_o    = cntr[1];

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

localparam CLKFREQ   = (100000000) /* 100 Mhz */; // Frequency of clk_w.
localparam CLK2XFREQ = (200000000) /* 200 Mhz */; // Frequency of clk_2x_w.
localparam CLK4XFREQ = (400000000) /* 400 Mhz */; // Frequency of clk_4x_w.

`ifdef SIMUSECLKDIV
wire clk_w;
wire clk_2x_w;
wire clk_4x_w = clk_i;
clkdiv clkdiv (
	 .clk_4x_i (clk_4x_w)
	,.clk_2x_o (clk_2x_w)
	,.clk_o    (clk_w)
);
`else
wire clk_w = clk_i;
`endif

wire rst_w = (devtbl_rst0_r || (|rst_cntr));

`ifdef PUCOUNT
localparam PUCOUNT = `PUCOUNT;
`else
localparam PUCOUNT = 1;
`endif

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_UART   = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRC_UART1  = (INTCTRLSRC_UART + 1);
localparam INTCTRLSRCCOUNT   = (INTCTRLSRC_UART1 +1); // Number of interrupt source.
localparam INTCTRLDSTCOUNT   = PUCOUNT; // Number of interrupt destination.
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
`ifdef PI1QLITEDRAM
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_RAMCTRL    = (S_PI1R_RAM + 1);
localparam S_PI1R_BOOTLDR    = (S_PI1R_RAMCTRL + 1);
`else
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_BOOTLDR    = (S_PI1R_RAM + 1);
`endif
localparam S_PI1R_UART1      = (S_PI1R_BOOTLDR + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_UART1 + 1);

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

wire [(ARCHBITSZ * PUCOUNT) -1 : 0] pc_w_flat;
wire [ARCHBITSZ -1 : 0]             pc_w      [PUCOUNT -1 : 0] /* verilator public */;
genvar gen_pc_w_idx;
generate for (gen_pc_w_idx = 0; gen_pc_w_idx < PUCOUNT; gen_pc_w_idx = gen_pc_w_idx + 1) begin :gen_pc_w
assign pc_w[gen_pc_w_idx] = pc_w_flat[((gen_pc_w_idx+1) * ARCHBITSZ) -1 : gen_pc_w_idx * ARCHBITSZ];
end endgenerate

localparam ICACHESZ = 128;
localparam DCACHESZ = 32;
localparam TLBSZ    = 64;

localparam ICACHEWAYCOUNT = 4;
localparam DCACHEWAYCOUNT = 2;
localparam TLBWAYCOUNT    = 1;

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
	,.IDIVCNT        (4)
	,.FADDFSUBCNT    (2)
	,.FMULCNT        (2)
	,.FDIVCNT        (4)

) cpu (

	 .rst_i (rst_w)

	,.rst_o (cpu_rst_ow)

	,.clk_i        (clk_w)
	`ifdef SIMUSECLKDIV
	,.clk_imul_i     (clk_4x_w)
	,.clk_idiv_i     (clk_4x_w)
	,.clk_faddfsub_i (clk_4x_w)
	,.clk_fmul_i     (clk_4x_w)
	,.clk_fdiv_i     (clk_4x_w)
	`endif
	`ifdef PUCOUNT
	,.clk_mem_i    (pi1r_clk_w)
	`endif

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_CPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_CPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_CPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_CPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_CPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_CPU])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  ((('h1000)>>1)
		+ (s_pi1r_mapsz_w[S_PI1R_RAM]>>1)
		`ifdef PI1QLITEDRAM
		+ (s_pi1r_mapsz_w[S_PI1R_RAMCTRL]>>1)
		`endif
		)
	,.rstaddr2_i (('h8000-(14/*within parkpu()*/))>>1)

	,.id_i (0)

	,.pc_o (pc_w_flat)
);

sdcard_spi #(

	 .ARCHBITSZ    (ARCHBITSZ)
	,.XARCHBITSZ   (PI1RARCHBITSZ)
	// "pu32.img.hex" generated using `hexdump -v -e '/1 "%02x "' /path/to/img > pu32.img.hex`
	,.SRCFILE      ("pu32.img.hex")
	,.SIMSTORAGESZ (81920*5)

) sdcard (

	.rst_i (pi1r_rst_w)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk_w)

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

assign devtbl_id_w     [S_PI1R_SDCARD] = 4;
assign devtbl_useintr_w[S_PI1R_SDCARD] = 1;

localparam RAMCACHEWAYCOUNT = 2;
localparam RAMCACHESZ       = ((1024/(ARCHBITSZ/8))*(32/RAMCACHEWAYCOUNT)); /* In (ARCHBITSZ/8) units */

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (PI1RARCHBITSZ)
	 `ifdef PI1QLITEDRAM
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	`elsif WB4SMEM
	,.RAMCACHESZ (RAMCACHESZ)
	,.PRELDRADDR ('h1000)
	`endif
	,.DEVMAPCNT  (PI1RSLAVECOUNT)
	,.SOCID      (0)

) devtbl (

	 .rst_i (pi1r_rst_w)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	,.rst2_o (devtbl_rst2_w)

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

always @* begin
	if (swpwroff)
		$finish;
end

wire [2 -1 : 0]             intctrl_op_w;
wire [ADDRBITSZ -1 : 0]     intctrl_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] intctrl_sel_w;
wire [ARCHBITSZ -1 : 0]     intctrl_data_w1;
wire [ARCHBITSZ -1 : 0]     intctrl_data_w0;
wire                        intctrl_rdy_w;
wire [ADDRBITSZ -1 : 0]     intctrl_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_intctrl (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_INTCTRL])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_INTCTRL])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_INTCTRL])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_INTCTRL])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_INTCTRL])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_INTCTRL])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_INTCTRL])
	,.s_pi1_op_o (intctrl_op_w)
	,.s_pi1_addr_o (intctrl_addr_w)
	,.s_pi1_data_o (intctrl_data_w1)
	,.s_pi1_data_i (intctrl_data_w0)
	,.s_pi1_sel_o (intctrl_sel_w)
	,.s_pi1_rdy_i (intctrl_rdy_w)
	,.s_pi1_mapsz_i (intctrl_mapsz_w)
);

intctrl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.INTSRCCOUNT (INTCTRLSRCCOUNT)
	,.INTDSTCOUNT (INTCTRLDSTCOUNT)

) intctrl (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (intctrl_op_w)
	,.pi1_addr_i  (intctrl_addr_w)
	,.pi1_data_i  (intctrl_data_w1)
	,.pi1_data_o  (intctrl_data_w0)
	,.pi1_sel_i   (intctrl_sel_w)
	,.pi1_rdy_o   (intctrl_rdy_w)
	,.pi1_mapsz_o (intctrl_mapsz_w)

	,.intrqstdst_o (intrqstdst_w)
	,.intrdydst_i  (intrdydst_w)
	,.intbestdst_i (intbestdst_w)

	,.intrqstsrc_i (intrqstsrc_w)
	,.intrdysrc_o  (intrdysrc_w)
);

assign devtbl_id_w     [S_PI1R_INTCTRL] = 3;
assign devtbl_useintr_w[S_PI1R_INTCTRL] = 0;

wire [2 -1 : 0]             uart_op_w;
wire [ADDRBITSZ -1 : 0]     uart_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] uart_sel_w;
wire [ARCHBITSZ -1 : 0]     uart_data_w1;
wire [ARCHBITSZ -1 : 0]     uart_data_w0;
wire                        uart_rdy_w;
wire [ADDRBITSZ -1 : 0]     uart_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_uart (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_UART])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_UART])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_UART])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_UART])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_UART])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_UART])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])
	,.s_pi1_op_o (uart_op_w)
	,.s_pi1_addr_o (uart_addr_w)
	,.s_pi1_data_o (uart_data_w1)
	,.s_pi1_data_i (uart_data_w0)
	,.s_pi1_sel_o (uart_sel_w)
	,.s_pi1_rdy_i (uart_rdy_w)
	,.s_pi1_mapsz_i (uart_mapsz_w)
);

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (uart_op_w)
	,.pi1_addr_i  (uart_addr_w)
	,.pi1_data_i  (uart_data_w1)
	,.pi1_data_o  (uart_data_w0)
	,.pi1_sel_i   (uart_sel_w)
	,.pi1_rdy_o   (uart_rdy_w)
	,.pi1_mapsz_o (uart_mapsz_w)

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_UART])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_UART])
);

assign devtbl_id_w     [S_PI1R_UART] = 5;
assign devtbl_useintr_w[S_PI1R_UART] = 1;

wire [2 -1 : 0]             uart1_op_w;
wire [ADDRBITSZ -1 : 0]     uart1_addr_w;
wire [(ARCHBITSZ/8) -1 : 0] uart1_sel_w;
wire [ARCHBITSZ -1 : 0]     uart1_data_w1;
wire [ARCHBITSZ -1 : 0]     uart1_data_w0;
wire                        uart1_rdy_w;
wire [ADDRBITSZ -1 : 0]     uart1_mapsz_w;
pi1_downconverter #(
	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (ARCHBITSZ)
) pi1_downconverter_uart1 (
	 .clk_i (pi1r_clk_w)
	,.m_pi1_op_i (s_pi1r_op_w[S_PI1R_UART1])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_UART1])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_UART1])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_UART1])
	,.m_pi1_sel_i (s_pi1r_sel_w[S_PI1R_UART1])
	,.m_pi1_rdy_o (s_pi1r_rdy_w[S_PI1R_UART1])
	,.m_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART1])
	,.s_pi1_op_o (uart1_op_w)
	,.s_pi1_addr_o (uart1_addr_w)
	,.s_pi1_data_o (uart1_data_w1)
	,.s_pi1_data_i (uart1_data_w0)
	,.s_pi1_sel_o (uart1_sel_w)
	,.s_pi1_rdy_i (uart1_rdy_w)
	,.s_pi1_mapsz_i (uart1_mapsz_w)
);

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart1 (

	 .rst_i (rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (uart1_op_w)
	,.pi1_addr_i  (uart1_addr_w)
	,.pi1_data_i  (uart1_data_w1)
	,.pi1_data_o  (uart1_data_w0)
	,.pi1_sel_i   (uart1_sel_w)
	,.pi1_rdy_o   (uart1_rdy_w)
	,.pi1_mapsz_o (uart1_mapsz_w)

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_UART1])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_UART1])
);

assign devtbl_id_w     [S_PI1R_UART1] = 5;
assign devtbl_useintr_w[S_PI1R_UART1] = 1;

// The RAM ARCHBITSZ must be >= PI1RARCHBITSZ.
`ifdef PI1QLITEDRAM
generate if (ARCHBITSZ == 32 && ARCHBITSZ == PI1RARCHBITSZ) begin :gen_litedram0

assign s_pi1r_mapsz_w[S_PI1R_RAM] = ('h2000000/* 32MB */);

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge pi1r_clk_w) begin
	if (ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]                                dcache_s_op_w;
wire [(ARCHBITSZ - clog2(ARCHBITSZ/8)) -1 : 0] dcache_s_addr_w;
wire [ARCHBITSZ -1 : 0]                        dcache_s_data_w1;
wire [ARCHBITSZ -1 : 0]                        dcache_s_data_w0;
wire [(ARCHBITSZ/8) -1 : 0]                    dcache_s_sel_w;
wire                                           dcache_s_rdy_w;

pi1_dcache #(

	 .ARCHBITSZ     (ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ)
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.BUFFERDEPTH   (64)
	,.INITFILE      ("litedram/litedram.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.crst_i  (ram_rst_w || devtbl_rst2_w)
	,.cmiss_i (1'b0)
	,.conly_i (ram_rst_w)

	,.m_pi1_op_i   (s_pi1r_op_w[S_PI1R_RAM])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_RAM])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_RAM])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_RAM])
	,.m_pi1_sel_i  (s_pi1r_sel_w[S_PI1R_RAM])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[S_PI1R_RAM])

	,.s_pi1_op_o   (dcache_s_op_w)
	,.s_pi1_addr_o (dcache_s_addr_w)
	,.s_pi1_data_i (dcache_s_data_w1)
	,.s_pi1_data_o (dcache_s_data_w0)
	,.s_pi1_sel_o  (dcache_s_sel_w)
	,.s_pi1_rdy_i  (dcache_s_rdy_w)
);

wire                        litedram_user_clk_w;
wire                        litedram_user_rst_w;

wire                                         litedram_cmd_ready_user_port_w;
wire                                         litedram_cmd_valid_user_port_w;
wire                                         litedram_cmd_we_user_port_w;
wire [(ARCHBITSZ-clog2(ARCHBITSZ/8)) -1 : 0] litedram_cmd_addr_user_port_w;
wire                                         litedram_wdata_ready_user_port_w;
wire                                         litedram_wdata_valid_user_port_w;
wire [(ARCHBITSZ/8) -1 : 0]                  litedram_wdata_we_user_port_w;
wire [ARCHBITSZ -1 : 0]                      litedram_wdata_data_user_port_w;
wire                                         litedram_rdata_valid_user_port_w;
wire [ARCHBITSZ -1 : 0]                      litedram_rdata_data_user_port_w;
wire                                         litedram_rdata_ready_user_port_w;

pi1q_to_litedram #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1q_to_litedram (

	 .litedram_rst_i (litedram_user_rst_w)

	,.pi1_clk_i  (pi1r_clk_w)
	,.pi1_op_i   (dcache_s_op_w)
	,.pi1_addr_i (dcache_s_addr_w)
	,.pi1_data_i (dcache_s_data_w0)
	,.pi1_data_o (dcache_s_data_w1)
	,.pi1_sel_i  (dcache_s_sel_w)
	,.pi1_rdy_o  (dcache_s_rdy_w)

	,.litedram_clk_i         (litedram_user_clk_w)
	,.litedram_cmd_ready_i   (litedram_cmd_ready_user_port_w)
	,.litedram_cmd_valid_o   (litedram_cmd_valid_user_port_w)
	,.litedram_cmd_we_o      (litedram_cmd_we_user_port_w)
	,.litedram_cmd_addr_o    (litedram_cmd_addr_user_port_w)
	,.litedram_wdata_ready_i (litedram_wdata_ready_user_port_w)
	,.litedram_wdata_valid_o (litedram_wdata_valid_user_port_w)
	,.litedram_wdata_we_o    (litedram_wdata_we_user_port_w)
	,.litedram_wdata_data_o  (litedram_wdata_data_user_port_w)
	,.litedram_rdata_valid_i (litedram_rdata_valid_user_port_w)
	,.litedram_rdata_data_i  (litedram_rdata_data_user_port_w)
	,.litedram_rdata_ready_o (litedram_rdata_ready_user_port_w)
);

wire                        wb4_cyc_wb_ctrl_w;
wire                        wb4_stb_wb_ctrl_w;
wire                        wb4_we_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_addr_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_wb_ctrl_w0;
wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_wb_ctrl_w;
wire                        wb4_stall_wb_ctrl_w;
wire                        wb4_ack_wb_ctrl_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_wb_ctrl_w1;

pi1q_to_wb4 #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1q_to_wb4_wb_ctrl (

	 .wb4_rst_i (litedram_user_rst_w)

	,.pi1_clk_i   (pi1r_clk_w)
	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAMCTRL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAMCTRL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAMCTRL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAMCTRL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAMCTRL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAMCTRL])

	,.wb4_clk_i   (litedram_user_clk_w)
	,.wb4_cyc_o   (wb4_cyc_wb_ctrl_w)
	,.wb4_stb_o   (wb4_stb_wb_ctrl_w)
	,.wb4_we_o    (wb4_we_wb_ctrl_w)
	,.wb4_addr_o  (wb4_addr_wb_ctrl_w)
	,.wb4_data_o  (wb4_data_wb_ctrl_w0)
	,.wb4_sel_o   (wb4_sel_wb_ctrl_w)
	,.wb4_stall_i (wb4_stall_wb_ctrl_w)
	,.wb4_ack_i   (wb4_ack_wb_ctrl_w)
	,.wb4_data_i  (wb4_data_wb_ctrl_w1)
);

assign s_pi1r_mapsz_w[S_PI1R_RAMCTRL] = ('h10000/* 64KB */);

litedram litedram (

	 .clk (pi1r_clk_w)

	,.init_done  ()
	,.init_error ()

	,.user_clk                       (litedram_user_clk_w)
	,.user_rst                       (litedram_user_rst_w)

	,.user_port_native_0_cmd_valid   (litedram_cmd_valid_user_port_w)
	,.user_port_native_0_cmd_ready   (litedram_cmd_ready_user_port_w)
	,.user_port_native_0_cmd_we      (litedram_cmd_we_user_port_w)
	,.user_port_native_0_cmd_addr    (litedram_cmd_addr_user_port_w)
	,.user_port_native_0_wdata_valid (litedram_wdata_valid_user_port_w)
	,.user_port_native_0_wdata_ready (litedram_wdata_ready_user_port_w)
	,.user_port_native_0_wdata_we    (litedram_wdata_we_user_port_w)
	,.user_port_native_0_wdata_data  (litedram_wdata_data_user_port_w)
	,.user_port_native_0_rdata_valid (litedram_rdata_valid_user_port_w)
	,.user_port_native_0_rdata_ready (litedram_rdata_ready_user_port_w)
	,.user_port_native_0_rdata_data  (litedram_rdata_data_user_port_w)

	,.wb_ctrl_adr   (wb4_addr_wb_ctrl_w[ARCHBITSZ -1 : clog2(ARCHBITSZ/8)])
	,.wb_ctrl_dat_w (wb4_data_wb_ctrl_w0)
	,.wb_ctrl_dat_r (wb4_data_wb_ctrl_w1)
	,.wb_ctrl_sel   (wb4_sel_wb_ctrl_w)
	,.wb_ctrl_cyc   (wb4_cyc_wb_ctrl_w)
	,.wb_ctrl_stb   (wb4_stb_wb_ctrl_w)
	,.wb_ctrl_ack   (wb4_ack_wb_ctrl_w)
	,.wb_ctrl_we    (wb4_we_wb_ctrl_w)
	,.wb_ctrl_cti   (3'b000)
	,.wb_ctrl_bte   (2'b00)
);

assign devtbl_id_w     [S_PI1R_RAMCTRL] = 0;
assign devtbl_useintr_w[S_PI1R_RAMCTRL] = 0;

end else begin  :gen_litedram1
always @* begin
$display("litedram ARCHBITSZ must be 32 and equal to PI1RARCHBITSZ\n");
$finish;
end
end endgenerate
`elsif WB4SMEM

localparam RAMSZ = ('h2000000/* 32MB */);

localparam WB4SMEM_ARCHBITSZ = 256; // Must be >= PI1RARCHBITSZ.

wire [2 -1 : 0]                                                dcache_m_op_w;
wire [(WB4SMEM_ARCHBITSZ - clog2(WB4SMEM_ARCHBITSZ/8)) -1 : 0] dcache_m_addr_w;
wire [WB4SMEM_ARCHBITSZ -1 : 0]                                dcache_m_data_w1;
wire [WB4SMEM_ARCHBITSZ -1 : 0]                                dcache_m_data_w0;
wire [(WB4SMEM_ARCHBITSZ/8) -1 : 0]                            dcache_m_sel_w;
wire                                                           dcache_m_rdy_w;

pi1_upconverter #(

	 .MARCHBITSZ (PI1RARCHBITSZ)
	,.SARCHBITSZ (WB4SMEM_ARCHBITSZ)

) pi1_upconverter (

	 .clk_i (pi1r_clk_w)

	,.m_pi1_op_i   (s_pi1r_op_w[S_PI1R_RAM])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_RAM])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_RAM])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_RAM])
	,.m_pi1_sel_i  (s_pi1r_sel_w[S_PI1R_RAM])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[S_PI1R_RAM])

	,.s_pi1_op_o   (dcache_m_op_w)
	,.s_pi1_addr_o (dcache_m_addr_w)
	,.s_pi1_data_i (dcache_m_data_w0)
	,.s_pi1_data_o (dcache_m_data_w1)
	,.s_pi1_sel_o  (dcache_m_sel_w)
	,.s_pi1_rdy_i  (dcache_m_rdy_w)
);

assign s_pi1r_mapsz_w[S_PI1R_RAM] = RAMSZ;

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge pi1r_clk_w) begin
	if (ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
// Because dcache.INITFILE is used only after a global reset, resetting RAM must happen only then.
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]                                                dcache_s_op_w;
wire [(WB4SMEM_ARCHBITSZ - clog2(WB4SMEM_ARCHBITSZ/8)) -1 : 0] dcache_s_addr_w;
wire [WB4SMEM_ARCHBITSZ -1 : 0]                                dcache_s_data_w1;
wire [WB4SMEM_ARCHBITSZ -1 : 0]                                dcache_s_data_w0;
wire [(WB4SMEM_ARCHBITSZ/8) -1 : 0]                            dcache_s_sel_w;
wire                                                           dcache_s_rdy_w;

localparam WB4SMEM_RAMCACHESZ = (RAMCACHESZ/(WB4SMEM_ARCHBITSZ/ARCHBITSZ));

pi1_dcache #(

	 .ARCHBITSZ     (WB4SMEM_ARCHBITSZ)
	,.CACHESETCOUNT (WB4SMEM_RAMCACHESZ)
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.BUFFERDEPTH   (64)
	,.INITFILE      ("dcacheinit/dcacheinit.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.crst_i    (ram_rst_w || devtbl_rst2_w)
	,.cenable_i (1'b1)
	,.conly_i   (ram_rst_w)

	,.m_pi1_op_i   (dcache_m_op_w)
	,.m_pi1_addr_i (dcache_m_addr_w)
	,.m_pi1_data_i (dcache_m_data_w1)
	,.m_pi1_data_o (dcache_m_data_w0)
	,.m_pi1_sel_i  (dcache_m_sel_w)
	,.m_pi1_rdy_o  (dcache_m_rdy_w)

	,.s_pi1_op_o   (dcache_s_op_w)
	,.s_pi1_addr_o (dcache_s_addr_w)
	,.s_pi1_data_i (dcache_s_data_w1)
	,.s_pi1_data_o (dcache_s_data_w0)
	,.s_pi1_sel_o  (dcache_s_sel_w)
	,.s_pi1_rdy_i  (dcache_s_rdy_w)
);

wire                                wb4_cyc_w;
wire                                wb4_stb_w;
wire                                wb4_we_w;
wire [WB4SMEM_ARCHBITSZ -1 : 0]     wb4_addr_w;
wire [WB4SMEM_ARCHBITSZ -1 : 0]     wb4_data_w0;
wire [(WB4SMEM_ARCHBITSZ/8) -1 : 0] wb4_sel_w;
wire                                wb4_stall_w;
wire                                wb4_ack_w;
wire [WB4SMEM_ARCHBITSZ -1 : 0]     wb4_data_w1;

pi1_to_wb4 #(

	.ARCHBITSZ (WB4SMEM_ARCHBITSZ)

) pi1_to_wb4 (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (dcache_s_op_w)
	,.pi1_addr_i  (dcache_s_addr_w)
	,.pi1_data_i  (dcache_s_data_w0)
	,.pi1_data_o  (dcache_s_data_w1)
	,.pi1_sel_i   (dcache_s_sel_w)
	,.pi1_rdy_o   (dcache_s_rdy_w)

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

wb4smem #(

	 .ARCHBITSZ (WB4SMEM_ARCHBITSZ)
	,.SIZE      (RAMSZ/(WB4SMEM_ARCHBITSZ/ARCHBITSZ))
	,.DELAY     (0)

) wb4smem (

	 .rst_i (ram_rst_w)

	,.clk_i (pi1r_clk_w)

	,.wb4_cyc_i   (wb4_cyc_w)
	,.wb4_stb_i   (wb4_stb_w)
	,.wb4_we_i    (wb4_we_w)
	,.wb4_addr_i  (wb4_addr_w)
	,.wb4_data_o  (wb4_data_w1)
	,.wb4_sel_i   (wb4_sel_w)
	,.wb4_stall_o (wb4_stall_w)
	,.wb4_ack_o   (wb4_ack_w)
	,.wb4_data_i  (wb4_data_w0)
);

`else /* WB4SMEM */

smem #(

	 .ARCHBITSZ (PI1RARCHBITSZ)
	,.SIZE      ('h2000000/* 32MB *//(PI1RARCHBITSZ/8))
	,.DELAY     (0)

) smem (

	 .rst_i (pi1r_rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAM])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAM])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAM])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAM])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAM])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAM])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_RAM])
);

`endif /* WB4SMEM */

assign devtbl_id_w     [S_PI1R_RAM] = 1;
assign devtbl_useintr_w[S_PI1R_RAM] = 0;

bootldr #(

	 .ARCHBITSZ (PI1RARCHBITSZ)

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
always @ (posedge pi1r_clk_w) begin
	if (!rst_i && s_pi1r_op_w[S_PI1R_INVALIDDEV]) begin
		$write("!!! s_pi1r_op_w[S_PI1R_INVALIDDEV] == 0b%b; s_pi1r_addr_w[S_PI1R_INVALIDDEV] == 0x%x\n",
			s_pi1r_op_w[S_PI1R_INVALIDDEV], {2'b00, s_pi1r_addr_w[S_PI1R_INVALIDDEV]}<<CLOG2PI1RARCHBITSZBY8);
		$fflush(1);
		$finish;
	end
end

endmodule
