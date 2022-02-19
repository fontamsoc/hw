// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/ram/dram.v"

`ifdef SIMULATION
`include "./sdcard_sim_phy.v"
`else
`include "./sdcard_spi_phy.v"
`endif

`include "lib/perint/pi1q.v"

module sdcard_spi (

	 rst_i

	,clk_mem_i
	,clk_i
	,clk_phy_i

`ifndef SIMULATION
	,sclk_o
	,di_o
	,do_i
	,cs_o
`endif

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqst_o
	,intrdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter PHYCLKFREQ = 1;
`ifdef SIMULATION
parameter SRCFILE = "";
parameter SIMSTORAGESZ = 4096;
`endif

localparam PHYBLKSZ = 512;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_mem_i;
input wire clk_i;
input wire clk_phy_i;

`ifndef SIMULATION
output wire sclk_o;
output wire di_o;
input  wire do_i;
output wire cs_o;
`endif

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output reg  intrqst_o = 0;
input  wire intrdy_i;

assign pi1_mapsz_o = (PHYBLKSZ/(ARCHBITSZ/8));

localparam CLOG2PHYBLKSZ = clog2(PHYBLKSZ);

localparam PI1QMASTERCOUNT = 1;
localparam PI1QARCHBITSZ   = ARCHBITSZ;
wire pi1q_rst_w = rst_i;
wire m_pi1q_clk_w = clk_mem_i;
wire s_pi1q_clk_w = clk_i;
`include "lib/perint/inst.pi1q.v"

assign m_pi1q_op_w[0] = pi1_op_i;
assign m_pi1q_addr_w[0] = pi1_addr_i;
assign m_pi1q_data_w1[0] = pi1_data_i;
assign pi1_data_o = m_pi1q_data_w0[0];
assign m_pi1q_sel_w[0] = pi1_sel_i;
assign pi1_rdy_o = m_pi1q_rdy_w[0];

reg [ARCHBITSZ -1 : 0] s_pi1q_data_w1_ = 0;
assign s_pi1q_data_w1 = s_pi1q_data_w1_;

assign s_pi1q_rdy_w = 1;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDRESET = 0;
localparam CMDSWAP  = 1;
localparam CMDREAD  = 2;
localparam CMDWRITE = 3;
localparam CMD_CNT  = 4;

localparam STATUSPOWEROFF = 0;
localparam STATUSREADY    = 1;
localparam STATUSBUSY     = 2;
localparam STATUSERROR    = 3;

wire phy_tx_pop_w, phy_rx_push_w;

wire [8 -1 : 0] phy_rx_data_w;
reg  [8 -1 : 0] phy_tx_data_w;

reg phy_cmd = 0;

reg [ADDRBITSZ -1 : 0] phy_cmdaddr = 0;

wire [ADDRBITSZ -1 : 0] phy_blkcnt_w;

wire phy_err_w;

wire phy_rst_w = (rst_i | (s_pi1q_op_w == PIRWOP && s_pi1q_addr_w == CMDRESET && s_pi1q_data_w0));

reg phy_cmd_pending = 0;

wire phy_cmd_pop_w;

wire phy_bsy = (phy_cmd_pending || !phy_cmd_pop_w);

`ifdef SIMULATION
sdcard_sim_phy
`else
sdcard_spi_phy
`endif
#(
	`ifndef SIMULATION
	 .PHYCLKFREQ (PHYCLKFREQ)
	`else
	 .SRCFILE      (SRCFILE)
	,.SIMSTORAGESZ (SIMSTORAGESZ)
	`endif
) phy (

	 .rst_i (phy_rst_w)

	,.clk_i (clk_i)

`ifndef SIMULATION
	,.clk_phy_i (clk_phy_i)

	,.sclk_o (sclk_o)
	,.di_o   (di_o)
	,.do_i   (do_i)
	,.cs_o   (cs_o)
`endif

	,.cmd_pop_o      (phy_cmd_pop_w)
	,.cmd_data_i     (phy_cmd)
	,.cmd_addr_i     (phy_cmdaddr)
	,.cmd_empty_i    (!phy_cmd_pending)

	,.rx_push_o (phy_rx_push_w)
	,.rx_data_o (phy_rx_data_w)

	,.tx_pop_o   (phy_tx_pop_w)
	,.tx_data_i  (phy_tx_data_w)

	,.blkcnt_o (phy_blkcnt_w)

	,.err_o (phy_err_w)
);

wire pi1_op_is_rdop = (s_pi1q_op_w == PIRDOP || (s_pi1q_op_w == PIRWOP && s_pi1q_addr_w >= CMD_CNT));
wire pi1_op_is_wrop = (s_pi1q_op_w == PIWROP || (s_pi1q_op_w == PIRWOP && s_pi1q_addr_w >= CMD_CNT));

reg cacheselect = 0;

reg [CLOG2PHYBLKSZ -1 : 0] cachephyaddr = 0;

wire [(CLOG2PHYBLKSZ-CLOG2ARCHBITSZBY8) -1 : 0] cache0addr =
	cacheselect ? s_pi1q_addr_w : cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2ARCHBITSZBY8];
wire [(CLOG2PHYBLKSZ-CLOG2ARCHBITSZBY8) -1 : 0] cache1addr =
	cacheselect ? cachephyaddr[CLOG2PHYBLKSZ -1 : CLOG2ARCHBITSZBY8] : s_pi1q_addr_w;

localparam ARCHBITSZMAX = 64;

wire [ARCHBITSZMAX -1 : 0] cache0dato;
wire [ARCHBITSZMAX -1 : 0] cache1dato;

wire [ARCHBITSZMAX -1 : 0] cachephydata = cacheselect ? cache1dato : cache0dato;

wire [ARCHBITSZMAX -1 : 0] phy_rx_data_w_byteselected =
	(ARCHBITSZ == 16) ? (
		(cachephyaddr[0] == 0) ? {cachephydata[15:8], phy_rx_data_w} :
					 {phy_rx_data_w, cachephydata[7:0]}) :
	(ARCHBITSZ == 32) ? (
		(cachephyaddr[1:0] == 0) ? {cachephydata[31:8], phy_rx_data_w} :
		(cachephyaddr[1:0] == 1) ? {cachephydata[31:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[1:0] == 2) ? {cachephydata[31:24], phy_rx_data_w, cachephydata[15:0]} :
					   {phy_rx_data_w, cachephydata[23:0]}) : (
		(cachephyaddr[2:0] == 0) ? {cachephydata[63:8], phy_rx_data_w} :
		(cachephyaddr[2:0] == 1) ? {cachephydata[63:16], phy_rx_data_w, cachephydata[7:0]} :
		(cachephyaddr[2:0] == 2) ? {cachephydata[63:24], phy_rx_data_w, cachephydata[15:0]} :
		(cachephyaddr[2:0] == 3) ? {cachephydata[63:32], phy_rx_data_w, cachephydata[23:0]} :
		(cachephyaddr[2:0] == 4) ? {cachephydata[63:40], phy_rx_data_w, cachephydata[31:0]} :
		(cachephyaddr[2:0] == 5) ? {cachephydata[63:48], phy_rx_data_w, cachephydata[39:0]} :
		(cachephyaddr[2:0] == 6) ? {cachephydata[63:56], phy_rx_data_w, cachephydata[47:0]} :
					   {phy_rx_data_w, cachephydata[55:0]});

wire [ARCHBITSZ -1 : 0] cache0dati = cacheselect ? s_pi1q_data_w0 : phy_rx_data_w_byteselected[ARCHBITSZ -1 : 0];
wire [ARCHBITSZ -1 : 0] cache1dati = cacheselect ? phy_rx_data_w_byteselected[ARCHBITSZ -1 : 0] : s_pi1q_data_w0;

always @* begin
	if (ARCHBITSZ == 16) begin
		if (cachephyaddr[0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
	end else if (ARCHBITSZ == 32) begin
		if (cachephyaddr[1:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[1:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[1:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
	end else begin
		if (cachephyaddr[2:0] == 0)
			phy_tx_data_w = cacheselect ? cache1dato[7:0] : cache0dato[7:0];
		else if (cachephyaddr[2:0] == 1)
			phy_tx_data_w = cacheselect ? cache1dato[15:8] : cache0dato[15:8];
		else if (cachephyaddr[2:0] == 2)
			phy_tx_data_w = cacheselect ? cache1dato[23:16] : cache0dato[23:16];
		else if (cachephyaddr[2:0] == 3)
			phy_tx_data_w = cacheselect ? cache1dato[31:24] : cache0dato[31:24];
		else if (cachephyaddr[2:0] == 4)
			phy_tx_data_w = cacheselect ? cache1dato[39:32] : cache0dato[39:32];
		else if (cachephyaddr[2:0] == 5)
			phy_tx_data_w = cacheselect ? cache1dato[47:40] : cache0dato[47:40];
		else if (cachephyaddr[2:0] == 6)
			phy_tx_data_w = cacheselect ? cache1dato[55:48] : cache0dato[55:48];
		else
			phy_tx_data_w = cacheselect ? cache1dato[63:56] : cache0dato[63:56];
	end
end

reg  intrdy_i_sampled = 0;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_sampled);

reg  phy_err_w_sampled = 0;
wire phy_err_w_posedge = (phy_err_w && !phy_err_w_sampled);

reg  phy_bsy_sampled = 0;
wire phy_bsy_negedge = (!phy_bsy && phy_bsy_sampled);

wire cache0read  = cacheselect ? pi1_op_is_rdop : phy_tx_pop_w;
wire cache1read  = cacheselect ? phy_tx_pop_w : pi1_op_is_rdop;
wire cache0write = cacheselect ? pi1_op_is_wrop : phy_rx_push_w;
wire cache1write = cacheselect ? phy_rx_push_w : pi1_op_is_wrop;

dram #(

	 .SZ (PHYBLKSZ/(ARCHBITSZ/8))
	,.DW (ARCHBITSZ)

) cache0 (

	 .clk1_i  (clk_mem_i)
	,.we1_i   (cache0write)
	,.addr1_i (cache0addr)
	,.i1      (cache0dati)
	,.o1      (cache0dato)
);

dram #(

	 .SZ (PHYBLKSZ/(ARCHBITSZ/8))
	,.DW (ARCHBITSZ)

) cache1 (

	 .clk1_i  (clk_mem_i)
	,.we1_i   (cache1write)
	,.addr1_i (cache1addr)
	,.i1      (cache1dati)
	,.o1      (cache1dato)
);

reg [2 -1 : 0] status;

always @* begin
	if (rst_i)
		status = STATUSPOWEROFF;
	else if (phy_err_w)
		status = STATUSERROR;
	else if (phy_rst_w || phy_bsy)
		status = STATUSBUSY;
	else
		status = STATUSREADY;
end

always @ (posedge clk_i) begin

	intrqst_o <= intrqst_o ? ~intrdy_i_negedge : (phy_err_w_posedge || phy_bsy_negedge);

	if (s_pi1q_op_w == PIRWOP && s_pi1q_addr_w == CMDSWAP)
		cacheselect <= ~cacheselect;

	if (pi1_op_is_rdop)
		s_pi1q_data_w1_ <= cacheselect ? cache0dato : cache1dato;
	else if (s_pi1q_op_w == PIRWOP) begin
		if (s_pi1q_addr_w == CMDRESET)
			s_pi1q_data_w1_ <= {{30{1'b0}}, status};
		else if (s_pi1q_addr_w == CMDSWAP)
			s_pi1q_data_w1_ <= PHYBLKSZ;
		else if (s_pi1q_addr_w == CMDREAD || s_pi1q_addr_w == CMDWRITE)
			s_pi1q_data_w1_ <= phy_blkcnt_w;
	end

	if (!phy_bsy)
		cachephyaddr <= 0;
	else if (cacheselect ? (cache1read | cache1write) : (cache0read | cache0write))
		cachephyaddr <= cachephyaddr + 1'b1;

	if (rst_i || (phy_cmd_pop_w && phy_cmd_pending))
		phy_cmd_pending <= 0;
	else if (s_pi1q_op_w == PIRWOP && (s_pi1q_addr_w == CMDREAD || s_pi1q_addr_w == CMDWRITE))
		phy_cmd_pending <= 1;

	if (s_pi1q_op_w == PIRWOP && (s_pi1q_addr_w == CMDREAD || s_pi1q_addr_w == CMDWRITE)) begin
		phy_cmd <= (s_pi1q_addr_w == CMDWRITE);
		phy_cmdaddr <= s_pi1q_data_w0;
	end

	intrdy_i_sampled  <= intrdy_i;
	phy_err_w_sampled <= phy_err_w;
	phy_bsy_sampled   <= phy_bsy;
end

endmodule
