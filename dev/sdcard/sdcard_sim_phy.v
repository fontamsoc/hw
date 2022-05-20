// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SDCARD_SIM_PHY_V
`define SDCARD_SIM_PHY_V

// Module simulating an sdcard controller.
// Read/Write is expected in a 512Bytes block.

// Parameters:
//
// SRCFILE
// 	File from which memory will be initialized using $readmemh().
//
// SIMSTORAGESZ
// 	Size in 512Bytes of the storage to be initialized using $readmemh().

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// cmd_pop_o
// cmd_data_i
// cmd_addr_i
// cmd_empty_i
// 	FIFO interface to send read/write commands.
// 	cmd_addr_i is the address within the card.
// 	cmd_data_i indicates whether read(0)/write(1).
//
// rx_push_o
// rx_data_o
// rx_full_i
// 	FIFO interface to retrieve data from read commands.
//
// tx_pop_o
// tx_data_i
// tx_empty_i
// 	FIFO interface to buffer data for write commands.
//
// blkcnt_o
// 	This signal is set to the total number of blocks.
//
// err_o
// 	This signal is high when an error occured; a reset is needed to clear the error.

module sdcard_sim_phy (

	 rst_i

	,clk_i

	,cmd_pop_o
	,cmd_data_i
	,cmd_addr_i
	,cmd_empty_i

	,rx_push_o
	,rx_data_o
	,rx_full_i

	,tx_pop_o
	,tx_data_i
	,tx_empty_i

	,blkcnt_o

	,err_o
);

`include "lib/clog2.v"

parameter SRCFILE = "";
parameter SIMSTORAGESZ = 4096;

input wire rst_i;

input wire clk_i;

localparam CMDADDRBITSZ = 32; // Per the spec, read/write address is 32bits.

output wire                    cmd_pop_o;
input  wire                    cmd_data_i;
input  wire [CMDADDRBITSZ -1 : 0] cmd_addr_i;
input  wire                    cmd_empty_i;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;
input  wire            rx_full_i;

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;
input  wire            tx_empty_i;

output wire [CMDADDRBITSZ -1 : 0] blkcnt_o;
assign blkcnt_o = SIMSTORAGESZ;

output wire err_o;
assign err_o = 1'b0;

reg [8 -1 : 0] u [(SIMSTORAGESZ*512) -1 : 0];
initial begin
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		$display ("%s loaded", SRCFILE);
	end
end

// Constants used with the register state.

// When in this state, the controller is not busy.
localparam READY     = 1;
// States that wait for a command's response.
localparam CMD17RESP = 22;
localparam CMD24RESP = 23;

localparam STATEBITSZ = clog2(64);

reg [STATEBITSZ -1 : 0] state;

reg [CMDADDRBITSZ -1 : 0] cmdaddr;

reg [clog2(512) -1 : 0] cntr;

assign tx_pop_o  = (state == CMD24RESP);
assign rx_push_o = (state == CMD17RESP);

assign cmd_pop_o = (state == READY);

wire [CMDADDRBITSZ -1 : 0] cmdaddr_plus_cntr = (cmdaddr+cntr);

assign rx_data_o = u[cmdaddr_plus_cntr];

always @ (posedge clk_i) begin
	if (rst_i)
		state <= READY;
	else if (state == READY) begin
		if (!cmd_empty_i) begin
			cmdaddr <= (cmd_addr_i << 9);
			if (cmd_data_i)
				state <= CMD24RESP;
			else
				state <= CMD17RESP;
		end
		cntr <= 0;
	end else if (state == CMD17RESP || state == CMD24RESP) begin
		if (cntr != 511)
			cntr <= cntr + 1'b1;
		else
			state <= READY;
		if (state == CMD24RESP)
			u[cmdaddr_plus_cntr] <= tx_data_i;
	end
end

endmodule

`endif /* SDCARD_SIM_PHY_V */
