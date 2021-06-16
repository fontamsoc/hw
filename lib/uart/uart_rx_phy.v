// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_RX_PHY_V
`define UART_RX_PHY_V

module uart_rx_phy (

	 rst_i

	,clk_i

	,clockcyclesperbit_i

	,rx_i
	,rcvd_o
	,data_o
);

`include "lib/clog2.v"

parameter CLOCKCYCLESPERBITLIMIT       = 2;
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

input wire clk_i;

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire           rx_i;
output reg            rcvd_o = 0;
output reg [8 -1 : 0] data_o = 0;

localparam RXIDLE = 0;

localparam RXRCVD = 1;

localparam RXSTOP = 2;

reg [2 -1 : 0] rxstate = RXIDLE;

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] cntr = 0;

reg [3 -1 : 0] bitcnt = 0;

always @ (posedge clk_i) begin

	if (rst_i || rxstate == RXIDLE || cntr >= clockcyclesperbit_i)
		cntr <= 0;
	else cntr <= cntr + 1'b1;

	if (rxstate == RXRCVD) begin
		if (cntr >= clockcyclesperbit_i) begin
			bitcnt <= bitcnt - 1'b1;
			data_o <= {rx_i, data_o[7:1]};
		end
	end else bitcnt <= 7;

	if (rst_i)
		rxstate <= RXIDLE;
	else if (rxstate == RXIDLE) begin

		if (!rx_i)
			rxstate <= RXRCVD;

		rcvd_o <= 0;

	end else if (cntr >= clockcyclesperbit_i) begin

		if (rxstate == RXSTOP) begin

			if (rx_i) rcvd_o <= 1;

			rxstate <= RXIDLE;

		end else if (rxstate == RXRCVD) begin

			if (!bitcnt)
				rxstate <= RXSTOP;

		end else
			rxstate <= RXIDLE;
	end
end

endmodule

`endif
