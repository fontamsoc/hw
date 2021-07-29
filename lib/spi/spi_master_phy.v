// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef LIBSPIMASTERPHY
`define LIBSPIMASTERPHY

module spi_master_phy (
	
	clk_i,
	
	sclk, mosi, miso, ss,
	
	transmit, dataneeded, datareceived, sclkdivide,
	
	dataout, datain
);

`include "lib/clog2.v"

parameter DATABITSIZE = 2;
parameter SCLKDIVIDELIMIT = 1;

localparam CLOG2DATABITSIZE = clog2(DATABITSIZE);
localparam CLOG2SCLKDIVIDELIMIT = clog2(SCLKDIVIDELIMIT);

input wire clk_i;

`ifdef SCLKBOTHEDGE
output reg sclk = 0;
`else
output wire sclk;
`endif
output wire mosi;
input wire miso;
output reg ss = 1'b1;

input wire transmit;
output wire dataneeded;
output wire datareceived;
input wire[CLOG2SCLKDIVIDELIMIT -1 : 0] sclkdivide;

output wire[DATABITSIZE -1 : 0] dataout;
input wire[DATABITSIZE -1 : 0] datain;

reg[DATABITSIZE -1 : 0] mosibits = {DATABITSIZE{1'b1}};

assign mosi = mosibits[DATABITSIZE -1];

reg[DATABITSIZE -1 : 0] misobits = {DATABITSIZE{1'b1}};

assign dataout = misobits;

reg[SCLKDIVIDELIMIT -1 : 0] counter = 0;

`ifndef SCLKBOTHEDGE
assign sclk = counter[sclkdivide];
`endif

reg[CLOG2DATABITSIZE -1 : 0] bitcount = 0;

assign dataneeded = !bitcount;

reg dataneededsampled = 1;

wire dataneedednegedge = (dataneeded < dataneededsampled);

reg sssampled = 1;

wire ssnegedge = (ss < sssampled);

wire ssposedge = (ss > sssampled);

assign datareceived = ((dataneedednegedge && !ssnegedge) || ssposedge);

always @ (posedge clk_i) begin

	if (counter == (({{SCLKDIVIDELIMIT{1'b0}}, 1'b1} << sclkdivide) -1)) begin
		
		misobits <= {misobits[DATABITSIZE -2 : 0], miso};
		
		`ifdef SCLKBOTHEDGE
		if (!ss) sclk <= ~sclk;
		`endif
	end
	
	if (ss || counter >= (({{SCLKDIVIDELIMIT{1'b0}}, 2'd2} << sclkdivide) -1)) begin

		if (bitcount) mosibits <= (mosibits << 1);
		else mosibits <= datain;
		
		if (bitcount) bitcount <= bitcount - 1'b1;
		else if (transmit) bitcount <= (DATABITSIZE -1);
		
		ss <= !(bitcount || transmit);
		
		counter <= 0;
		
	end else counter <= counter + 1'b1;
	
	dataneededsampled <= dataneeded;
	
	sssampled <= ss;
end

endmodule

`endif
