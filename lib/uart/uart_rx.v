// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_RX_V
`define UART_RX_V

`include "lib/fifo_fwft.v"
`include "lib/uart/uart_rx_phy.v"

module uart_rx (

	 rst_i

	,clk_i
	,clk_phy_i

	,clockcyclesperbit_i

	,pop_i
	,data_o
	,empty_o
	,usage_o

	,rx_i
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

input  wire                          pop_i;
output wire [8 -1 : 0]               data_o;
output wire                          empty_o;
output wire [(CLOG2BUFSZ +1) -1 : 0] usage_o;

input wire rx_i;

wire [8 -1 : 0] rx_data_w;
wire            rx_push_w;

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (BUFSZ)

) rx (

	 .rst_i (rst_i)

	,.usage_o (usage_o)

	,.clk_pop_i (clk_i)
	,.pop_i     (pop_i)
	,.data_o    (data_o)
	,.empty_o   (empty_o)

	,.clk_push_i (clk_phy_i)
	,.push_i     (rx_push_w)
	,.data_i     (rx_data_w)
);

uart_rx_phy #(

	.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) rx_phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.clockcyclesperbit_i (clockcyclesperbit_i)

	,.rx_i   (rx_i)
	,.rcvd_o (rx_push_w)
	,.data_o (rx_data_w)
);

endmodule

`endif
