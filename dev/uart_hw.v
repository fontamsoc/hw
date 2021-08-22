// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/uart/uart_rx.v"
`include "lib/uart/uart_tx.v"

module uart_hw (

	 rst_i

	,clk_i
	,clk_phy_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqst_o
	,intrdy_i

	,rx_i
	,tx_o
);

`include "lib/clog2.v"

parameter PHYCLKFREQ = 1;
parameter BUFSZ      = 2;

localparam CLOG2BUFSZ = clog2(BUFSZ);

parameter ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
input wire [2 -1 : 0] clk_phy_i;
`else
input wire [1 -1 : 0] clk_i;
input wire [1 -1 : 0] clk_phy_i;
`endif

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = 0;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire intrqst_o;
input  wire intrdy_i;

input  wire rx_i;
output wire tx_o;

assign pi1_rdy_o = 1;

assign pi1_mapsz_o = 2;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CLOCKCYCLESPERBITLIMIT = (1<<(ARCHBITSZ-2));
localparam CLOG2CLOCKCYCLESPERBITLIMIT = (ARCHBITSZ-2);

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] rxclockcyclesperbit = 0;
reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] txclockcyclesperbit = 0;

wire            rx_empty_w;
wire            rx_pop_w = (pi1_op_i == PIRDOP && pi1_rdy_o && !rx_empty_w);
wire [8 -1 : 0] rx_data_w0;

wire            tx_full_w;
wire            tx_push_w = (pi1_op_i == PIWROP && pi1_rdy_o && !tx_full_w);
wire [8 -1 : 0] tx_data_w1 = pi1_data_i[8 -1 : 0];

wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w;
wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_w;

reg [(ARCHBITSZ-2) -1 : 0] intrqstthresh = 0;

assign intrqst_o = (|intrqstthresh && (rx_usage_w >= intrqstthresh));

reg  intrdysampled = 0;
wire intrdynegedge = (!intrdy_i && intrdysampled);

localparam CMDGETBUFFERUSAGE = 0;
localparam CMDSETINTERRUPT   = 1;
localparam CMDSETSPEED       = 2;

always @ (posedge clk_i[0]) begin

	if (rst_i) begin
		intrqstthresh <= 0;
	end else if (pi1_op_i == PIRWOP && pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT)
		intrqstthresh <= pi1_data_i[(ARCHBITSZ-2)-1:0];
	else if (intrdynegedge)
		intrqstthresh <= 0;

	if (rx_pop_w)
		pi1_data_o <= rx_data_w0;

	if (pi1_op_i == PIRWOP && pi1_rdy_o) begin
		if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT)
			pi1_data_o <= BUFSZ;
		else if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDGETBUFFERUSAGE)
			pi1_data_o <= pi1_data_i[0] ? tx_usage_w : rx_usage_w;
		else if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETSPEED) begin
			rxclockcyclesperbit <= (pi1_data_i[(ARCHBITSZ-2)-1:0] + (pi1_data_i[(ARCHBITSZ-2)-1:0] >> 5));
			txclockcyclesperbit <=  pi1_data_i[(ARCHBITSZ-2)-1:0];
			pi1_data_o <= PHYCLKFREQ;
		end
	end

	intrdysampled <= intrdy_i;
end

uart_rx #(

	 .BUFSZ                  (BUFSZ)
	,.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) uart_rx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.clockcyclesperbit_i (rxclockcyclesperbit)

	,.pop_i   (rx_pop_w)
	,.data_o  (rx_data_w0)
	,.empty_o (rx_empty_w)
	,.usage_o (rx_usage_w)

	,.rx_i (rx_i)
);

uart_tx #(

	 .BUFSZ                  (BUFSZ)
	,.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) uart_tx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.clockcyclesperbit_i (txclockcyclesperbit)

	,.push_i  (tx_push_w)
	,.data_i  (tx_data_w1)
	,.full_o  (tx_full_w)
	,.usage_o (tx_usage_w)

	,.tx_o (tx_o)
);

endmodule
