// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef LIBSPIMASTER
`define LIBSPIMASTER

`include "lib/fifo.v"

`include "./spi_master_phy.v"

module spi_master (

	rst_i,

	clk_i, clk_phy_i,

	sclk, mosi, miso, ss,

	sclkdivide,

	txbufferwriteenable, txbufferdatain, txbufferusage, txbufferfull,

	rxbufferreadenable, rxbufferdataout, rxbufferusage, rxbufferempty,
);

`include "lib/clog2.v"

parameter BUFFERSIZE = 2;
parameter DATABITSIZE = 2;
parameter SCLKDIVIDELIMIT = 1;

localparam CLOG2BUFFERSIZE = clog2(BUFFERSIZE);
localparam CLOG2SCLKDIVIDELIMIT = clog2(SCLKDIVIDELIMIT);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

output wire sclk;
output wire mosi;
input wire miso;
output wire ss;

input wire[CLOG2SCLKDIVIDELIMIT -1 : 0] sclkdivide;

input wire txbufferwriteenable;
input wire[DATABITSIZE -1 : 0] txbufferdatain;
output wire[(CLOG2BUFFERSIZE +1) -1 : 0] txbufferusage;
output wire txbufferfull;

input wire rxbufferreadenable;
output wire[DATABITSIZE -1 : 0] rxbufferdataout;
output wire[(CLOG2BUFFERSIZE +1) -1 : 0] rxbufferusage;
output wire rxbufferempty;

reg txfifowasread = 0;

wire phydataneeded;

wire phydatareceived;

wire[DATABITSIZE -1 : 0] phydataout;

wire[DATABITSIZE -1 : 0] txfifodataout;

spi_master_phy #(

	.SCLKDIVIDELIMIT (SCLKDIVIDELIMIT),
	.DATABITSIZE (DATABITSIZE)

) phy (

	.clk_i (clk_phy_i),

	.sclk (sclk),
	.mosi (mosi),
	.miso (miso),
	.ss (ss),

	.transmit (phydataneeded && txfifowasread),
	.dataneeded (phydataneeded),
	.datareceived (phydatareceived),
	.sclkdivide (sclkdivide),
	.dataout (phydataout),
	.datain (txfifodataout)
);

fifo #(
	.WIDTH (DATABITSIZE),
	.DEPTH (BUFFERSIZE)

) rxfifo (

	.rst_i (rst_i),

	.usage_o (rxbufferusage),

	.clk_read_i (clk_i),
	.read_i (rxbufferreadenable),
	.data_o (rxbufferdataout),
	.empty_o (rxbufferempty),

	.clk_write_i (clk_phy_i),
	.write_i (phydatareceived),
	.data_i (phydataout),
	.full_o ()
);

wire txbufferempty;

wire txfiforeadenable = (!txbufferempty && !txfifowasread);

fifo #(
	.WIDTH (DATABITSIZE),
	.DEPTH (BUFFERSIZE)

) txfifo (

	.rst_i (rst_i),

	.usage_o (txbufferusage),

	.clk_read_i (clk_phy_i),
	.read_i (txfiforeadenable),
	.data_o (txfifodataout),
	.empty_o (txbufferempty),

	.clk_write_i (clk_i),
	.write_i (txbufferwriteenable),
	.data_i (txbufferdatain),
	.full_o (txbufferfull)
);

reg phydataneededsampled = 1;

wire phydataneedednegedge = (phydataneeded < phydataneededsampled);

always @ (posedge clk_phy_i) begin

	if (rst_i || (txfifowasread && phydataneedednegedge)) txfifowasread <= 0;
	else if (txfiforeadenable) txfifowasread <= 1;

	phydataneededsampled <= phydataneeded;
end

endmodule

`endif
