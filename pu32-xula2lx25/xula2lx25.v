// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`default_nettype none

`include "lib/perint/pi1r.v"

`define PUMMU
`define PUHPTW
`include "pu/multipu.v"

`include "dev/intctrl.v"

`include "dev/bootldr.v"

`include "dev/sdcard/sdcard_spi.v"

`include "dev/uart_hw.v"

`include "dev/pi1_dcache.v"

`include "dev/pi1_to_wb4.v"
`include "lib/wb4sdram.v"

`include "devtbl.xula2lx25.v"

`include "./pll_12_to_120_mhz.xula2lx25.v"

module xula2lx25 (

	 rst_p

	,clk12mhz_i

	,flash_sclk
	,flash_di
	,flash_do
	,flash_cs
	,flash_cs2

	,uart_rx
	,uart_tx

	,sdram_ck
	,sdram_cke
	,sdram_ras_n
	,sdram_cas_n
	,sdram_we_n
	,sdram_ba
	,sdram_addr
	,sdram_dq
	,sdram_dm
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_p;

input wire clk12mhz_i;

output wire flash_sclk;
output wire flash_di;
input  wire flash_do;
output wire flash_cs;
output wire flash_cs2;

input  wire uart_rx;
output wire uart_tx;

localparam SDRAMCASLATENCY       = 2;
localparam SDRAMBURSTLENGTH      = 4;
localparam SDRAMBANKCOUNT        = 4;
localparam SDRAMROWCOUNT         = 8192;
localparam SDRAMCOLUMNCOUNT      = 512;
localparam SDRAMABITSIZE         = 13;
localparam SDRAMDQBITSIZE        = 16;
localparam CLOG2SDRAMBURSTLENGTH = clog2(SDRAMBURSTLENGTH);
localparam CLOG2SDRAMBANKCOUNT   = clog2(SDRAMBANKCOUNT);
localparam CLOG2SDRAMROWCOUNT    = clog2(SDRAMROWCOUNT);
localparam CLOG2SDRAMCOLUMNCOUNT = clog2(SDRAMCOLUMNCOUNT);
localparam RAMSZ = (1 << ((CLOG2SDRAMROWCOUNT + CLOG2SDRAMBANKCOUNT + (CLOG2SDRAMCOLUMNCOUNT - CLOG2SDRAMBURSTLENGTH)) + (((SDRAMDQBITSIZE * SDRAMBURSTLENGTH) > ARCHBITSZ) ? clog2((SDRAMDQBITSIZE * SDRAMBURSTLENGTH) / ARCHBITSZ) : 0)));
output wire                               sdram_ck;
output wire                               sdram_cke;
output wire                               sdram_ras_n;
output wire                               sdram_cas_n;
output wire                               sdram_we_n;
output wire [CLOG2SDRAMBANKCOUNT -1 : 0]  sdram_ba;
output wire [SDRAMABITSIZE -1 : 0]        sdram_addr;
inout  wire [SDRAMDQBITSIZE -1 : 0]       sdram_dq;
output wire [(SDRAMDQBITSIZE / 8) -1 : 0] sdram_dm;

assign flash_cs2 = 1;

localparam CLKFREQ = 30000000;

wire pll_locked;

wire clk120mhz_;
pll_12_to_120_mhz pll (
	 .RESET    (1'b0)
	,.LOCKED   (pll_locked)
	,.CLK_IN1  (clk12mhz_i)
	,.CLK_OUT1 (clk120mhz_)
);
(* keep = "true" *) wire clk120mhz;
BUFG bufg0 (.O (clk120mhz), .I (clk120mhz_));
reg [1:0] clkdiv;
always @ (posedge clk120mhz) begin
	clkdiv <= clkdiv - 1'b1;
end
(* keep = "true" *) wire clk60mhz;
(* keep = "true" *) wire clk30mhz;
BUFG bufg1 (.O (clk60mhz), .I (clkdiv[0]));
BUFG bufg2 (.O (clk30mhz), .I (clkdiv[1]));
wire [2 -1 : 0] clk_w = {clk60mhz, clk30mhz};

wire multipu_rst_ow;

wire devtbl_rst0_w;
reg  devtbl_rst0_r = 0;
wire devtbl_rst1_w;

wire swcoldrst = (devtbl_rst0_w && devtbl_rst1_w);
wire swwarmrst = (!devtbl_rst0_w && devtbl_rst1_w);
wire swpwroff  = (devtbl_rst0_w && !devtbl_rst1_w);

localparam RST_CNTR_BITSZ = 4;

reg [RST_CNTR_BITSZ -1 : 0] rst_cntr = {RST_CNTR_BITSZ{1'b1}};
wire rst = (!pll_locked || devtbl_rst0_r || (|rst_cntr));
always @ (posedge clk120mhz) begin
	if (multipu_rst_ow || swwarmrst || rst_p)
		rst_cntr <= {RST_CNTR_BITSZ{1'b1}};
	else if (rst_cntr)
		rst_cntr <= rst_cntr - 1'b1;
end

always @ (posedge clk120mhz) begin
	if (rst_p)
		devtbl_rst0_r <= 0;
	if (swpwroff)
		devtbl_rst0_r <= 1;
end

STARTUP_SPARTAN6 (.CLK (clk12mhz_i), .GSR (swcoldrst));

localparam PUCOUNT = 1;

localparam INTCTRLSRCCOUNT = 2;
localparam INTCTRLDSTCOUNT = PUCOUNT;
wire [INTCTRLSRCCOUNT -1 : 0] intrqstsrc_w;
wire [INTCTRLSRCCOUNT -1 : 0] intrdysrc_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrqstdst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intrdydst_w;
wire [INTCTRLDSTCOUNT -1 : 0] intbestdst_w;

localparam PI1RMASTERCOUNT       = 1;
localparam PI1RSLAVECOUNT        = 6;
localparam PI1RDEFAULTSLAVEINDEX = 5;
localparam PI1RFIRSTSLAVEADDR    = 0;
localparam PI1RARCHBITSZ         = ARCHBITSZ;
wire pi1r_rst_w = rst;
wire pi1r_clk_w = clk_w;
`include "lib/perint/inst.pi1r.v"

localparam DCACHESZ = 4;

localparam ICACHEWAYCOUNT = 1;

multipu #(

	 .CLKFREQ        (CLKFREQ)
	,.PUCOUNT        (PUCOUNT)
	,.ICACHESETCOUNT ((1024/(ARCHBITSZ/8))*((32/ICACHEWAYCOUNT)/PUCOUNT))
	,.TLBSETCOUNT    (256/PUCOUNT)
	,.ICACHEWAYCOUNT (ICACHEWAYCOUNT)
	,.MULDIVCNT      (4)

) multipu (

	 .rst_i (rst)

	,.rst_o (multipu_rst_ow)

	,.clk_i     (clk_w)
	,.clk_mem_i (clk_w)

	,.pi1_op_o   (m_pi1r_op_w[0])
	,.pi1_addr_o (m_pi1r_addr_w[0])
	,.pi1_data_o (m_pi1r_data_w1[0])
	,.pi1_data_i (m_pi1r_data_w0[0])
	,.pi1_sel_o  (m_pi1r_sel_w[0])
	,.pi1_rdy_i  (m_pi1r_rdy_w[0])

	,.intrqst_i (intrqstdst_w)
	,.intrdy_o  (intrdydst_w)
	,.halted_o  (intbestdst_w)

	,.rstaddr_i  (0)
	,.rstaddr2_i (('h4000-14)>>1)

	,.id_i (0)
);

wire [2 -1 : 0]             bootldr_op_w;
wire [ADDRBITSZ -1 : 0]     bootldr_addr_w;
wire [ARCHBITSZ -1 : 0]     bootldr_data_w1;
wire [ARCHBITSZ -1 : 0]     bootldr_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] bootldr_sel_w;
wire                        bootldr_rdy_w;

bootldr #(

	.BOOTBLOCK (0)

) bootldr (

	 .rst_i (rst)

	,.clk_i (clk_w)

	,.m_pi1_op_i   (s_pi1r_op_w[0])
	,.m_pi1_addr_i (s_pi1r_addr_w[0])
	,.m_pi1_data_i (s_pi1r_data_w0[0])
	,.m_pi1_data_o (s_pi1r_data_w1[0])
	,.m_pi1_sel_i  (s_pi1r_sel_w[0])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[0])

	,.s_pi1_op_o   (bootldr_op_w)
	,.s_pi1_addr_o (bootldr_addr_w)
	,.s_pi1_data_i (bootldr_data_w1)
	,.s_pi1_data_o (bootldr_data_w0)
	,.s_pi1_sel_o  (bootldr_sel_w)
	,.s_pi1_rdy_i  (bootldr_rdy_w)
);

sdcard_spi #(

	.PHYCLKFREQ (CLKFREQ)

) sdcard (

	 .rst_i (rst)

	,.clk_mem_i (clk_w)
	,.clk_i     (clk_w)
	,.clk_phy_i (clk_w)

	,.sclk_o (flash_sclk)
	,.di_o   (flash_di)
	,.do_i   (flash_do)
	,.cs_o   (flash_cs)

	,.pi1_op_i    (bootldr_op_w)
	,.pi1_addr_i  (bootldr_addr_w)
	,.pi1_data_i  (bootldr_data_w0)
	,.pi1_data_o  (bootldr_data_w1)
	,.pi1_sel_i   (bootldr_sel_w)
	,.pi1_rdy_o   (bootldr_rdy_w)
	,.pi1_mapsz_o (s_pi1r_mapsz_w[0])

	,.intrqst_o (intrqstsrc_w[0])
	,.intrdy_i  (intrdysrc_w[0])
);

localparam RAMCACHEWAYCOUNT = 1;

localparam RAMCACHESZ = ((1024/(ARCHBITSZ/8))*(DCACHESZ/RAMCACHEWAYCOUNT));

devtbl #(

	 .RAMSZ      (RAMSZ)
	,.RAMCACHESZ (RAMCACHESZ)

) devtbl (

	 .rst_i (rst)

	,.rst0_o (devtbl_rst0_w)
	,.rst1_o (devtbl_rst1_w)

	,.clk_i (clk_w)

	,.pi1_op_i    (s_pi1r_op_w[1])
	,.pi1_addr_i  (s_pi1r_addr_w[1])
	,.pi1_data_i  (s_pi1r_data_w0[1])
	,.pi1_data_o  (s_pi1r_data_w1[1])
	,.pi1_sel_i   (s_pi1r_sel_w[1])
	,.pi1_rdy_o   (s_pi1r_rdy_w[1])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[1])
);

intctrl #(

	 .INTSRCCOUNT (INTCTRLSRCCOUNT)
	,.INTDSTCOUNT (INTCTRLDSTCOUNT)

) intctrl (

	 .rst_i (rst)

	,.clk_i (clk_w)

	,.pi1_op_i    (s_pi1r_op_w[2])
	,.pi1_addr_i  (s_pi1r_addr_w[2])
	,.pi1_data_i  (s_pi1r_data_w0[2])
	,.pi1_data_o  (s_pi1r_data_w1[2])
	,.pi1_sel_i   (s_pi1r_sel_w[2])
	,.pi1_rdy_o   (s_pi1r_rdy_w[2])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[2])

	,.intrqstdst_o (intrqstdst_w)
	,.intrdydst_i  (intrdydst_w)
	,.intbestdst_i (intbestdst_w)

	,.intrqstsrc_i (intrqstsrc_w)
	,.intrdysrc_o  (intrdysrc_w)
);

uart_hw #(

	 .PHYCLKFREQ (CLKFREQ)
	,.BUFSZ      (2048)

) uart (

	 .rst_i (!pll_locked || rst_p)

	,.clk_i     (clk_w)
	,.clk_phy_i (clk_w)

	,.pi1_op_i    (s_pi1r_op_w[3])
	,.pi1_addr_i  (s_pi1r_addr_w[3])
	,.pi1_data_i  (s_pi1r_data_w0[3])
	,.pi1_data_o  (s_pi1r_data_w1[3])
	,.pi1_sel_i   (s_pi1r_sel_w[3])
	,.pi1_rdy_o   (s_pi1r_rdy_w[3])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[3])

	,.intrqst_o (intrqstsrc_w[1])
	,.intrdy_i  (intrdysrc_w[1])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

reg [RST_CNTR_BITSZ -1 : 0] ram_rst_cntr = {RST_CNTR_BITSZ{1'b1}};
always @ (posedge clk120mhz) begin
	if (pll_locked && ram_rst_cntr)
		ram_rst_cntr <= ram_rst_cntr - 1'b1;
end
wire ram_rst_w = (|ram_rst_cntr);

wire [2 -1 : 0]             dcache_op_w;
wire [ADDRBITSZ -1 : 0]     dcache_addr_w;
wire [ARCHBITSZ -1 : 0]     dcache_data_w1;
wire [ARCHBITSZ -1 : 0]     dcache_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] dcache_sel_w;
wire                        dcache_rdy_w;

pi1_dcache #(

	 .CACHESETCOUNT (RAMCACHESZ)
	,.CACHEWAYCOUNT (RAMCACHEWAYCOUNT)

) dcache (

	 .rst_i (ram_rst_w)

	,.clk_i (clk_w)

	,.crst_i    (ram_rst_w)
	,.cenable_i (1'b1)
	,.cmiss_i   (1'b0)
	,.conly_i   (1'b0)

	,.m_pi1_op_i   (s_pi1r_op_w[4])
	,.m_pi1_addr_i (s_pi1r_addr_w[4])
	,.m_pi1_data_i (s_pi1r_data_w0[4])
	,.m_pi1_data_o (s_pi1r_data_w1[4])
	,.m_pi1_sel_i  (s_pi1r_sel_w[4])
	,.m_pi1_rdy_o  (s_pi1r_rdy_w[4])

	,.s_pi1_op_o   (dcache_op_w)
	,.s_pi1_addr_o (dcache_addr_w)
	,.s_pi1_data_i (dcache_data_w1)
	,.s_pi1_data_o (dcache_data_w0)
	,.s_pi1_sel_o  (dcache_sel_w)
	,.s_pi1_rdy_i  (dcache_rdy_w)
);

wire                        wb4_cyc_w;
wire                        wb4_stb_w;
wire                        wb4_we_w;
wire [ARCHBITSZ -1 : 0]     wb4_addr_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_w0;
wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_w;
wire                        wb4_stall_w;
wire                        wb4_ack_w;
wire [ARCHBITSZ -1 : 0]     wb4_data_w1;

pi1_to_wb4 #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1_to_wb4 (

	 .rst_i (ram_rst_w)

	,.clk_i (clk_w)

	,.pi1_op_i   (dcache_op_w)
	,.pi1_addr_i (dcache_addr_w)
	,.pi1_data_i (dcache_data_w0)
	,.pi1_data_o (dcache_data_w1)
	,.pi1_sel_i  (dcache_sel_w)
	,.pi1_rdy_o  (dcache_rdy_w)

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

wb4sdram #(

	 .SDRAM_MHZ          (CLKFREQ/1000000)
	,.SDRAM_ADDR_W       (CLOG2SDRAMROWCOUNT+CLOG2SDRAMBANKCOUNT+CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_COL_W        (CLOG2SDRAMCOLUMNCOUNT)
	,.SDRAM_BANK_W       (CLOG2SDRAMBANKCOUNT)
	,.SDRAM_DQM_W        (SDRAMDQBITSIZE/8)
	,.SDRAM_BANKS        (SDRAMBANKCOUNT)
	,.SDRAM_ROW_W        (CLOG2SDRAMROWCOUNT)
	,.SDRAM_READ_LATENCY (SDRAMCASLATENCY)

) wb4sdram (

	 .rst_i (ram_rst_w)

	,.clk_i (clk_w)

	,.sdram_clk_o   (sdram_ck)
	,.sdram_cke_o   (sdram_cke)
	,.sdram_ras_o   (sdram_ras_n)
	,.sdram_cas_o   (sdram_cas_n)
	,.sdram_we_o    (sdram_we_n)
	,.sdram_dqm_o   (sdram_dm)
	,.sdram_addr_o  (sdram_addr)
	,.sdram_ba_o    (sdram_ba)
	,.sdram_data_io (sdram_dq)

	,.stb_i   (wb4_stb_w)
	,.we_i    (wb4_we_w)
	,.sel_i   (wb4_sel_w)
	,.cyc_i   (wb4_cyc_w)
	,.addr_i  (wb4_addr_w)
	,.data_i  (wb4_data_w0)
	,.data_o  (wb4_data_w1)
	,.stall_o (wb4_stall_w)
	,.ack_o   (wb4_ack_w)
);

assign s_pi1r_mapsz_w[4] = RAMSZ;

localparam INVALIDDEVMAPSZ = 'h4000;
assign s_pi1r_data_w1[5] = {ARCHBITSZ{1'b0}};
assign s_pi1r_rdy_w[5]   = 1'b1;
assign s_pi1r_mapsz_w[5] = INVALIDDEVMAPSZ;

endmodule
