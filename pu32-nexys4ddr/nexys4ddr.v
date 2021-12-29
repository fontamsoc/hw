// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`default_nettype none

`include "lib/perint/pi1r.v"

`define PUMMU
`define PUHPTW
`define PUMULDIVCLK
`define PUDSPMUL
`include "pu/multipu.v"

`include "dev/gpio.v"

`include "dev/dma.v"

`include "dev/intctrl.v"

`include "dev/bootldr.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/uart_hw.v"

`include "dev/pi1_dcache.v"

`include "dev/pi1_upconverter.v"
`include "dev/pi1q_to_wb4.v"
`include "./litedram/litedram.v"

`include "./devtbl.nexys4ddr.v"

`include "./pll_100_to_50_100_mhz.nexys4ddr.v"

module nexys4ddr (

	 rst_n

	,clk100mhz_i

	,sd_sclk
	,sd_di
	,sd_do
	,sd_cs
	,sd_dat1
	,sd_dat2
	,sd_cd
	,sd_reset

	,gp_i
	,gp_o

	,uart_rx
	,uart_tx

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

	,activity

	,an
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_n;

(* clock_buffer_type = "BUFG" *)
input wire clk100mhz_i;

output wire sd_sclk;
output wire sd_di;
input  wire sd_do;
output wire sd_cs;
output wire sd_dat1;
output wire sd_dat2;
input  wire sd_cd;
output wire sd_reset;

assign sd_dat1 = 1;
assign sd_dat2 = 1;

localparam GPIOCOUNT = 16;
input  wire [GPIOCOUNT -1 : 0] gp_i;;
output wire [GPIOCOUNT -1 : 0] gp_o;

input  wire uart_rx;
output wire uart_tx;

localparam DDR2BANKCOUNT   = 8;
localparam DDR2ABITSIZE    = 13;
localparam DDR2DQBITSIZE   = 16;
output wire                               ddr2_ck_p;
output wire                               ddr2_ck_n;
output wire                               ddr2_cke;
output wire                               ddr2_odt;
output wire                               ddr2_cs_n;
output wire                               ddr2_ras_n;
output wire                               ddr2_cas_n;
output wire                               ddr2_we_n;
output wire [clog2(DDR2BANKCOUNT) -1 : 0] ddr2_ba;
output wire [DDR2ABITSIZE -1 : 0]         ddr2_addr;
inout  wire [DDR2DQBITSIZE -1 : 0]        ddr2_dq;
output wire [(DDR2DQBITSIZE / 8) -1 : 0]  ddr2_dm;
inout  wire [(DDR2DQBITSIZE / 8) -1 : 0]  ddr2_dqs_p;
inout  wire [(DDR2DQBITSIZE / 8) -1 : 0]  ddr2_dqs_n;

output reg activity;

wire litedram_pll_locked;
wire litedram_init_done;
wire litedram_init_error;

output wire [8 -1 : 0] an;

assign an = {8{1'b1}};

localparam CLKFREQ50MHZ = 50000000;

wire pll_locked;

wire clk50mhz;
wire clk100mhz;
pll_100_to_50_100_mhz pll (
	 .reset    (1'b0)
	,.locked   (pll_locked)
	,.clk_in1  (clk100mhz_i)
	,.clk_out1 (clk50mhz)
	,.clk_out2 (clk100mhz)
);

wire multipu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

wire rst_p = !rst_n;

localparam RST_CNTR_BITSZ = 16;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
wire rst = (!pll_locked || devtbl_rst0_r || (|rst_cntr));
always @ (posedge clk100mhz) begin
	if (!multipu_rst_ow && !swwarmrst && rst_n) begin
		if (rst_cntr)
			rst_cntr <= rst_cntr - 1'b1;
	end else
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
end

always @ (posedge clk100mhz) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

assign sd_reset = rst;

`ifdef FONTAMSOC_USE_STARTUPE2
STARTUPE2 startupe (.CLK (clk100mhz_i), .GSR (swcoldrst));
`endif

localparam ACTIVITY_CNTR_BITSZ = 7;
reg [ACTIVITY_CNTR_BITSZ -1 : 0] activity_cntr = 0;
always @ (posedge clk50mhz) begin
	if (activity_cntr) begin
		activity <= 0;
		activity_cntr <= activity_cntr - 1'b1;
	end else if ((~sd_cs || litedram_init_error)) begin
		activity <= 1;
		activity_cntr <= {ACTIVITY_CNTR_BITSZ{1'b1}};
	end
end

localparam PUCOUNT = 1;

localparam INTCTRLSRCCOUNT = 4;
localparam INTCTRLDSTCOUNT = PUCOUNT;
wire [INTCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [INTCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam INTCTRLSRC_SDCARD = 0;
localparam INTCTRLSRC_GPIO   = (INTCTRLSRC_SDCARD + 1);
localparam INTCTRLSRC_DMA    = (INTCTRLSRC_GPIO + 1);
localparam INTCTRLSRC_UART   = (INTCTRLSRC_DMA + 1);

localparam PI1RMASTERCOUNT       = 2;
localparam PI1RSLAVECOUNT        = 9;
localparam PI1RDEFAULTSLAVEINDEX = 8;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ARCHBITSZ;
wire pi1r_rst_w = rst;
wire pi1r_clk_w = clk100mhz;
`include "lib/perint/inst.pi1r.v"

localparam M_PI1R_MULTIPU    = 0;
localparam M_PI1R_DMA        = (M_PI1R_MULTIPU + 1);
localparam S_PI1R_SDCARD     = 0;
localparam S_PI1R_DEVTBL     = (S_PI1R_SDCARD + 1);
localparam S_PI1R_GPIO       = (S_PI1R_DEVTBL + 1);
localparam S_PI1R_DMA        = (S_PI1R_GPIO + 1);
localparam S_PI1R_INTCTRL    = (S_PI1R_DMA + 1);
localparam S_PI1R_UART       = (S_PI1R_INTCTRL + 1);
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_RAMCTRL    = (S_PI1R_RAM + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_RAMCTRL + 1);

localparam ICACHESZ = (256/2);
localparam DCACHESZ = ((PUCOUNT > 2) ? 32 : 64);

localparam ICACHEWAYCOUNT = ((PUCOUNT > 1) ? 2 : 4);

multipu #(

	 .ARCHBITSZ      (ARCHBITSZ)
	,.CLKFREQ        (CLKFREQ50MHZ)
	,.PUCOUNT        (PUCOUNT)
	,.ICACHESETCOUNT ((1024/(ARCHBITSZ/8))*((ICACHESZ/ICACHEWAYCOUNT)/PUCOUNT))
	,.TLBSETCOUNT    (1024/PUCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.MULDIVCNT      ((PUCOUNT > 4) ? 4 : 8)

) multipu (

	 .rst_i (rst || !litedram_pll_locked)

	,.rst_o (multipu_rst_ow)

	,.clk_i        (clk50mhz)
	,.clk_muldiv_i (clk100mhz)
	,.clk_mem_i    (clk100mhz)

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

	,.clk_i (clk100mhz)

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

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ50MHZ)

) sdcard (

	 .rst_i (rst || sd_cd)

	,.clk_mem_i (clk100mhz)
	,.clk_i     (clk50mhz)
	,.clk_phy_i (clk50mhz)

	,.sclk_o (sd_sclk)
	,.di_o   (sd_di)
	,.do_i   (sd_do)
	,.cs_o   (sd_cs)

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

localparam RAMSZ = 'h2000000;

localparam SDRAMCtrlIfSZ = 'h4000;

localparam RAMCACHEWAYCOUNT = 4;

localparam RAMCACHESZ = ((1024/(ARCHBITSZ/8))*(DCACHESZ/RAMCACHEWAYCOUNT));

wire devtbl_rst2_w;

devtbl #(

	 .ARCHBITSZ   (ARCHBITSZ)
	,.RAMSZ       (RAMSZ)
	,.RAMCtrlIfSZ (SDRAMCtrlIfSZ)
	,.RAMCACHESZ  (RAMCACHESZ)
	,.PRELDRADDR  ('h1000)

) devtbl (

	 .rst_i (rst)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)
	,.rst2_o (devtbl_rst2_w)

	,.clk_i (clk100mhz)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_DEVTBL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_DEVTBL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_DEVTBL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_DEVTBL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_DEVTBL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_DEVTBL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_DEVTBL])
);

gpio #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.CLKFREQ    (CLKFREQ50MHZ*2)
	,.IOCOUNT    (GPIOCOUNT)

) gpio (

	 .rst_i (rst)

	,.clk_i (clk100mhz)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_GPIO])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_GPIO])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_GPIO])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_GPIO])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_GPIO])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_GPIO])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_GPIO])

	,.intrqst_o (intrqstsrc_w[INTCTRLSRC_GPIO])
	,.intrdy_i  (intrdysrc_w[INTCTRLSRC_GPIO])

	,.i (gp_i)
	,.o (gp_o)
);

dma #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.CHANNELCNT (1)

) dma (

	 .rst_i (rst)

	,.clk_i (clk100mhz)

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

	,.clk_i (clk100mhz)

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

uart_hw #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ50MHZ*2)
	,.BUFSZ      (4096)

) uart (

	 .rst_i (!pll_locked || rst_p)

	,.clk_i     (clk100mhz)
	,.clk_phy_i (clk100mhz)

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

localparam LITEDRAM_ARCHBITSZ = 64;

wire [2 -1 : 0]                                                  dcache_m_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] dcache_m_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w1;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_m_data_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             dcache_m_sel_w;
wire                                                             dcache_m_rdy_w;

pi1_upconverter #(

	 .MARCHBITSZ (ARCHBITSZ)
	,.SARCHBITSZ (LITEDRAM_ARCHBITSZ)

) pi1_upconverter (

	 .clk_i (clk100mhz)

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
always @ (posedge clk100mhz) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]                                                  dcache_s_op_w;
wire [(LITEDRAM_ARCHBITSZ - clog2(LITEDRAM_ARCHBITSZ/8)) -1 : 0] dcache_s_addr_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_s_data_w1;
wire [LITEDRAM_ARCHBITSZ -1 : 0]                                 dcache_s_data_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0]                             dcache_s_sel_w;
wire                                                             dcache_s_rdy_w;

pi1_dcache #(

	 .ARCHBITSZ     (LITEDRAM_ARCHBITSZ)
	,.CACHESETCOUNT (RAMCACHESZ/(LITEDRAM_ARCHBITSZ/ARCHBITSZ))
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)
	,.INITFILE      ("litedram.hex")

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (clk100mhz)

	,.crst_i    (ram_rst_w || devtbl_rst2_w)
	,.cenable_i (1'b1)
	,.cmiss_i   (1'b0)
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

wire                                 wb4_clk_user_port_w;
wire                                 wb4_rst_user_port_w;
wire                                 wb4_cyc_user_port_w;
wire                                 wb4_stb_user_port_w;
wire                                 wb4_we_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_addr_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_data_user_port_w0;
wire [(LITEDRAM_ARCHBITSZ/8) -1 : 0] wb4_sel_user_port_w;
wire                                 wb4_stall_user_port_w;
wire                                 wb4_ack_user_port_w;
wire [LITEDRAM_ARCHBITSZ -1 : 0]     wb4_data_user_port_w1;

pi1q_to_wb4 #(

	.ARCHBITSZ (LITEDRAM_ARCHBITSZ)

) pi1q_to_wb4_user_port (

	 .wb4_rst_i (wb4_rst_user_port_w)

	,.pi1_clk_i   (clk100mhz)
	,.pi1_op_i    (dcache_s_op_w)
	,.pi1_addr_i  (dcache_s_addr_w)
	,.pi1_data_i  (dcache_s_data_w0)
	,.pi1_data_o  (dcache_s_data_w1)
	,.pi1_sel_i   (dcache_s_sel_w)
	,.pi1_rdy_o   (dcache_s_rdy_w)

	,.wb4_clk_i   (wb4_clk_user_port_w)
	,.wb4_cyc_o   (wb4_cyc_user_port_w)
	,.wb4_stb_o   (wb4_stb_user_port_w)
	,.wb4_we_o    (wb4_we_user_port_w)
	,.wb4_addr_o  (wb4_addr_user_port_w)
	,.wb4_data_o  (wb4_data_user_port_w0)
	,.wb4_sel_o   (wb4_sel_user_port_w)
	,.wb4_stall_i (wb4_stall_user_port_w)
	,.wb4_ack_i   (wb4_ack_user_port_w)
	,.wb4_data_i  (wb4_data_user_port_w1)
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

	 .wb4_rst_i (ram_rst_w)

	,.pi1_clk_i   (clk100mhz)
	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAMCTRL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAMCTRL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAMCTRL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAMCTRL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAMCTRL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAMCTRL])

	,.wb4_clk_i   (clk100mhz_i)
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

assign s_pi1r_mapsz_w[S_PI1R_RAMCTRL] = SDRAMCtrlIfSZ;

litedram litedram (

	 .rst (ram_rst_w)

	,.clk (clk100mhz_i)

	,.pll_locked (litedram_pll_locked)
	,.init_done  (litedram_init_done)
	,.init_error (litedram_init_error)

	,.ddram_a     (ddr2_addr)
	,.ddram_ba    (ddr2_ba)
	,.ddram_ras_n (ddr2_ras_n)
	,.ddram_cas_n (ddr2_cas_n)
	,.ddram_we_n  (ddr2_we_n)
	,.ddram_cs_n  (ddr2_cs_n)
	,.ddram_dm    (ddr2_dm)
	,.ddram_dq    (ddr2_dq)
	,.ddram_dqs_p (ddr2_dqs_p)
	,.ddram_dqs_n (ddr2_dqs_n)
	,.ddram_clk_p (ddr2_ck_p)
	,.ddram_clk_n (ddr2_ck_n)
	,.ddram_cke   (ddr2_cke)
	,.ddram_odt   (ddr2_odt)

	,.user_clk                   (wb4_clk_user_port_w)
	,.user_rst                   (wb4_rst_user_port_w)
	,.user_port_wishbone_0_adr   (wb4_addr_user_port_w[LITEDRAM_ARCHBITSZ -1 : clog2(LITEDRAM_ARCHBITSZ/8)])
	,.user_port_wishbone_0_dat_w (wb4_data_user_port_w0)
	,.user_port_wishbone_0_dat_r (wb4_data_user_port_w1)
	,.user_port_wishbone_0_sel   (wb4_sel_user_port_w)
	,.user_port_wishbone_0_cyc   (wb4_cyc_user_port_w)
	,.user_port_wishbone_0_stb   (wb4_stb_user_port_w)
	,.user_port_wishbone_0_ack   (wb4_ack_user_port_w)
	,.user_port_wishbone_0_we    (wb4_we_user_port_w)

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

localparam INVALIDDEVMAPSZ = 'h4000;
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {ARCHBITSZ{1'b0}};
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;

`ifdef USE2CLK
`error USE2CLK cannot be used because it needs 200MHz clock which fails timing.
`endif

endmodule
