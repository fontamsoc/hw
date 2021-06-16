// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_TX_V
`define UART_TX_V

`include "lib/fifo_fwft.v"
`include "lib/uart/uart_tx_phy.v"

module uart_tx (

	 rst_i

	,clk_i
	,clk_phy_i

	,clockcyclesperbit_i

	,push_i
	,data_i
	,full_o
	,usage_o

	,tx_o
);

`include "lib/clog2.v"

parameter BUFSZ                  = 2;
parameter CLOCKCYCLESPERBITLIMIT = 2;

localparam CLOG2BUFSZ                  = clog2(BUFSZ);
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
input wire [2 -1 : 0] clk_phy_i;
`else
input wire [1 -1 : 0] clk_i;
input wire [1 -1 : 0] clk_phy_i;
`endif

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire                          push_i;
input  wire [8 -1 : 0]               data_i;
output wire                          full_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_o;

output wire tx_o;

wire tx_phy_rdy_w;

wire            tx_empty_w;
wire [8 -1 : 0] tx_data_w;
wire            tx_pop_w = (tx_phy_rdy_w && !tx_empty_w);

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (BUFSZ)

) tx (

	 .rst_i (rst_i)

	,.usage_o (usage_o)

	,.clk_pop_i (clk_phy_i)
	,.pop_i     (tx_pop_w)
	,.data_o    (tx_data_w)
	,.empty_o   (tx_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (push_i)
	,.data_i     (data_i)
	,.full_o     (full_o)
);

uart_tx_phy #(

	.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) tx_phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.clockcyclesperbit_i (clockcyclesperbit_i)

	,.stb_i  (tx_pop_w)
	,.data_i (tx_data_w)
	,.rdy_o  (tx_phy_rdy_w)
	,.tx_o   (tx_o)
);

endmodule

`endif
