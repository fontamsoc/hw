// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef UART_TX_PHY_V
`define UART_TX_PHY_V

module uart_tx_phy (

	 rst_i

	,clk_i

	,clockcyclesperbit_i

	,stb_i
	,data_i
	,rdy_o
	,tx_o
);

`include "lib/clog2.v"

parameter CLOCKCYCLESPERBITLIMIT       = 2;
localparam CLOG2CLOCKCYCLESPERBITLIMIT = clog2(CLOCKCYCLESPERBITLIMIT);

input wire rst_i;

input wire clk_i;

input wire [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit_i;

input  wire            stb_i;
input  wire [8 -1 : 0] data_i;
output wire            rdy_o;
output reg             tx_o = 1'b1;

localparam TXIDLE = 0;

localparam TXSEND = 1;

reg txstate = TXIDLE;

reg [8 -1 : 0] data = 0;

reg [3 -1 : 0] bitcnt = 0;

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] clockcyclesperbit = 0;

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] cntr = 0;
wire                                     txen = (cntr >= clockcyclesperbit);

wire bsy = (txstate != TXIDLE || bitcnt);

assign rdy_o = !bsy;

always @ (posedge clk_i) begin

	if (rst_i) begin

		txstate <= TXIDLE;
		bitcnt <= 0;
		cntr <= 0;
		tx_o <= 1'b1;

	end else if ((stb_i && !bsy) || (txen && bsy)) begin

		if (txstate == TXIDLE) begin

			if (bitcnt) begin
				bitcnt <= bitcnt - 1'b1;
				tx_o <= 1;
			end else if (stb_i) begin
				txstate <= TXSEND;
				data <= data_i;
				tx_o <= 0;
				bitcnt <= 7;
				clockcyclesperbit <= clockcyclesperbit_i;
			end

		end else begin

			tx_o <= data[0];

			if (bitcnt) begin
				bitcnt <= bitcnt - 1'b1;
				data <= data >> 1'b1;
			end else begin
				txstate <= TXIDLE;
				bitcnt <= 2;
			end
		end

		cntr <= 0;

	end else if (!txen)
		cntr <= cntr + 1'b1;
end

endmodule

`endif
