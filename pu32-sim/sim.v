// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`default_nettype none

`define SIMULATION

`include "lib/perint/pi1r.v"

`define PUMMU
`define PUHPTW
`define PUMULDIVCLK
`define PUDSPMUL
`include "pu/multipu.v"

`include "dev/dma.v"

`include "dev/intctrl.v"

`include "dev/bootldr.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/uart_sim.v"

`include "dev/smem.v"

`include "./devtbl.sim.v"

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
	cntr <= cntr - 1'b1;
end

assign clk_2x_o = cntr[0];
assign clk_o    = cntr[1];

endmodule

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

wire multipu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

localparam RST_CNTR_BITSZ = 4;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
wire rst = (devtbl_rst0_r || (|rst_cntr));
always @ (posedge clk_i) begin
	if (multipu_rst_ow || swwarmrst || rst_i)
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

localparam CLKFREQ   = (50000000);
localparam CLK2XFREQ = (100000000);

wire clk__w;
wire clk_2x__w;
clkdiv clkdiv (
	 .clk_4x_i (clk_i)
	,.clk_2x_o (clk_2x__w)
	,.clk_o    (clk__w)
);

wire [2 -1 : 0] clk_w    = {clk_2x__w, clk__w};
wire [2 -1 : 0] clk_2x_w = {clk_i, clk_2x__w};

localparam PUCOUNT = 1;

localparam INTCTRLSRCCOUNT = 3;
localparam INTCTRLDSTCOUNT = PUCOUNT;
wire [INTCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [INTCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_DMA    = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRC_UART   = (INTCTRLSRC_DMA + 1);

localparam PI1RMASTERCOUNT       = 2;
localparam PI1RSLAVECOUNT        = 7;
localparam PI1RDEFAULTSLAVEINDEX = 6;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ARCHBITSZ;
wire pi1r_rst_w = rst;
wire pi1r_clk_w = clk_2x_w;
`include "lib/perint/inst.pi1r.v"

localparam M_PI1R_MULTIPU    = 0;
localparam M_PI1R_DMA        = (M_PI1R_MULTIPU + 1);
localparam S_PI1R_SDCARD     = 0;
localparam S_PI1R_DEVTBL     = (S_PI1R_SDCARD + 1);
localparam S_PI1R_DMA        = (S_PI1R_DEVTBL + 1);
localparam S_PI1R_INTCTRL    = (S_PI1R_DMA + 1);
localparam S_PI1R_UART       = (S_PI1R_INTCTRL + 1);
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_RAM + 1);

wire [(ARCHBITSZ * PUCOUNT) -1 : 0] pc_w_flat;
wire [ARCHBITSZ -1 : 0]             pc_w      [PUCOUNT -1 : 0] /* verilator public */;
genvar gen_pc_w_idx;
generate for (gen_pc_w_idx = 0; gen_pc_w_idx < PUCOUNT; gen_pc_w_idx = gen_pc_w_idx + 1) begin :gen_pc_w
assign pc_w[gen_pc_w_idx] = pc_w_flat[((gen_pc_w_idx+1) * ARCHBITSZ) -1 : gen_pc_w_idx * ARCHBITSZ];
end endgenerate

localparam ICACHEWAYCOUNT = 2;

multipu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.CLKFREQ        (CLKFREQ)
	,.PUCOUNT        (PUCOUNT)
	,.ICACHESETCOUNT ((1024/(ARCHBITSZ/8))*(4/ICACHEWAYCOUNT))
	,.TLBSETCOUNT    (16)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.MULDIVCNT      (8)

) multipu (

	 .rst_i (rst)

	,.rst_o (multipu_rst_ow)

	,.clk_i        (clk_w)
	`ifdef USE2CLK
	,.clk_muldiv_i (clk_2x_w)
	`else
	,.clk_muldiv_i (clk_2x_w[1])
	`endif
	,.clk_mem_i    (clk_2x_w)

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_MULTIPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_MULTIPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_MULTIPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_MULTIPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_MULTIPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_MULTIPU])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  (0)
	,.rstaddr2_i (('h8000-14)>>1)

	,.id_i (0)

	,.pc_o (pc_w_flat)
);

wire [2 -1 : 0]             bootldr_op_w;
wire [ADDRBITSZ -1 : 0]     bootldr_addr_w;
wire [ARCHBITSZ -1 : 0]     bootldr_data_w1;
wire [ARCHBITSZ -1 : 0]     bootldr_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] bootldr_sel_w;
wire                        bootldr_rdy_w;

bootldr #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BOOTBLOCK (0)

) bootldr (

	.rst_i (rst)

	,.clk_i (clk_2x_w)

	,.m_pi1_op_i   (s_pi1r_op_w[S_PI1R_SDCARD])
	,.m_pi1_addr_i (s_pi1r_addr_w[S_PI1R_SDCARD])
	,.m_pi1_data_i (s_pi1r_data_w0[S_PI1R_SDCARD])
	,.m_pi1_data_o (s_pi1r_data_w1[S_PI1R_SDCARD])
	,.m_pi1_sel_i  (s_pi1r_sel_w[S_PI1R_SDCARD])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[S_PI1R_SDCARD])

	,.s_pi1_op_o   (bootldr_op_w)
	,.s_pi1_addr_o (bootldr_addr_w)
	,.s_pi1_data_i (bootldr_data_w1)
	,.s_pi1_data_o (bootldr_data_w0)
	,.s_pi1_sel_o  (bootldr_sel_w)
	,.s_pi1_rdy_i  (bootldr_rdy_w)
);

sdcard_spi #(

	 .ARCHBITSZ    (ARCHBITSZ)
	,.SRCFILE      ("img.hex")
	,.SIMSTORAGESZ (81920*5)

) sdcard (

	.rst_i (rst)

	,.clk_mem_i (clk_2x_w)
	,.clk_i     (clk_w)
	,.clk_phy_i (clk_w)

	,.pi1_op_i    (bootldr_op_w)
	,.pi1_addr_i  (bootldr_addr_w)
	,.pi1_data_i  (bootldr_data_w0)
	,.pi1_data_o  (bootldr_data_w1)
	,.pi1_sel_i   (bootldr_sel_w)
	,.pi1_rdy_o   (bootldr_rdy_w)
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_SDCARD])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_SDCARD])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_SDCARD])
);

localparam RAMSZ = (8388608);

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.RAMSZ      (RAMSZ)

) devtbl (

	 .rst_i (rst)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	,.rst2_o (devtbl_rst2_w)

	,.clk_i (clk_2x_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_DEVTBL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_DEVTBL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_DEVTBL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_DEVTBL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_DEVTBL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_DEVTBL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_DEVTBL])
);

always @* begin
	if (swpwroff)
		$finish;
end

dma #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.CHANNELCNT (1)

) dma (

	 .rst_i (rst)

	,.clk_i (clk_2x_w)

	,.m_pi1_op_o   (m_pi1r_op_w[M_PI1R_DMA])
	,.m_pi1_addr_o (m_pi1r_addr_w[M_PI1R_DMA])
	,.m_pi1_data_o (m_pi1r_data_w1[M_PI1R_DMA])
	,.m_pi1_data_i (m_pi1r_data_w0[M_PI1R_DMA])
	,.m_pi1_sel_o  (m_pi1r_sel_w[M_PI1R_DMA])
	,.m_pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_DMA])

	,.s_pi1_op_i    (s_pi1r_op_w[S_PI1R_DMA])
	,.s_pi1_addr_i  (s_pi1r_addr_w[S_PI1R_DMA])
	,.s_pi1_data_i  (s_pi1r_data_w0[S_PI1R_DMA])
	,.s_pi1_data_o  (s_pi1r_data_w1[S_PI1R_DMA])
	,.s_pi1_sel_i   (s_pi1r_sel_w[S_PI1R_DMA])
	,.s_pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_DMA])
	,.s_pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_DMA])

	,.wait_i (|m_pi1r_op_w[M_PI1R_MULTIPU])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_DMA])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_DMA])
);

intctrl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.INTSRCCOUNT (INTCTRLSRCCOUNT)
	,.INTDSTCOUNT (INTCTRLDSTCOUNT)

) intctrl (

	 .rst_i (rst)

	,.clk_i (clk_2x_w)

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

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart (

	 .rst_i (rst)

	,.clk_i (clk_2x_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_UART])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_UART])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_UART])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_UART])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_UART])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_UART])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_UART])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_UART])
);

smem #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.SIZE      (RAMSZ)
	,.DELAY     (0)

) smem (

	 .rst_i (rst)

	,.clk_i (clk_2x_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAM])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAM])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAM])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAM])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAM])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAM])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_RAM])
);

localparam INVALIDDEVMAPSZ = 'h4000;
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {ARCHBITSZ{1'b0}};
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;
always @ (posedge clk_2x_w[0]) begin
	if (!rst_i && s_pi1r_op_w[S_PI1R_INVALIDDEV]) begin
		$write("!!! s_pi1r_op_w[S_PI1R_INVALIDDEV] == 0b%b; s_pi1r_addr_w[S_PI1R_INVALIDDEV] == 0x%x\n",
			s_pi1r_op_w[S_PI1R_INVALIDDEV], {2'b00, s_pi1r_addr_w[S_PI1R_INVALIDDEV]}<<CLOG2ARCHBITSZBY8);
		$fflush(1);
		$finish;
	end
end

endmodule
