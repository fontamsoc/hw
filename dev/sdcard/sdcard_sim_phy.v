// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SDCARD_PHY_SIM_V
`define SDCARD_PHY_SIM_V

`ifdef SDCARD_PHY_RCVE_CMD
`include "lib/fifo_fwft.v"
`endif

module sdcard_sim_phy (

	 rst_i

	,clk_i

`ifdef SDCARD_PHY_RCVE_CMD

	,cmd_push_i
	,cmd_data_i
	,cmdaddr_data_i
	,cmd_full_o

	,rx_pop_i
	,rx_data_o
	,rx_empty_o

	,tx_push_i
	,tx_data_i
	,tx_full_o

`else

	,cmd_pop_o
	,cmd_data_i
	,cmdaddr_data_i
	,cmd_empty_i

	,rx_push_o
	,rx_data_o
	,rx_full_i

	,tx_pop_o
	,tx_data_i
	,tx_empty_i

`endif

	,blkcnt

	,err
);

`include "lib/clog2.v"

`ifdef SDCARD_PHY_RCVE_CMD
parameter CMDBUFDEPTH = 2;
`endif

parameter SRCFILE = "";
parameter SIMSTORAGESZ = 4096;

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
`else
input wire [1 -1 : 0] clk_i;
`endif

localparam ADDRBITSZ = 32;

`ifdef SDCARD_PHY_RCVE_CMD

input  wire                    cmd_push_i;
input  wire                    cmd_data_i;
input  wire [ADDRBITSZ -1 : 0] cmdaddr_data_i;
output wire                    cmd_full_o;

input  wire            rx_pop_i;
output wire [8 -1 : 0] rx_data_o;
output wire            rx_empty_o;

input  wire            tx_push_i;
input  wire [8 -1 : 0] tx_data_i;
output wire            tx_full_o;

`else

output wire                    cmd_pop_o;
input  wire                    cmd_data_i;
input  wire [ADDRBITSZ -1 : 0] cmdaddr_data_i;
input  wire                    cmd_empty_i;

output wire            rx_push_o;
output wire [8 -1 : 0] rx_data_o;
input  wire            rx_full_i;

output wire            tx_pop_o;
input  wire [8 -1 : 0] tx_data_i;
input  wire            tx_empty_i;

`endif

output wire [ADDRBITSZ -1 : 0] blkcnt;
assign blkcnt = SIMSTORAGESZ;

output wire err;
assign err = 1'b0;

reg [8 -1 : 0] u [(SIMSTORAGESZ*512) -1 : 0];
initial begin
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		$display ("%s loaded", SRCFILE);
	end
end

localparam READY     = 1;
localparam CMD17RESP = 22;
localparam CMD24RESP = 23;

localparam STATEBITSZ = clog2(64);

reg [STATEBITSZ -1 : 0] state;

reg [ADDRBITSZ -1 : 0] cmdaddr;

reg [clog2(512) -1 : 0] cntr;

wire tx_pop_w  = (state == CMD24RESP);
wire rx_push_w = (state == CMD17RESP);

wire cmd_pop_w = (state == READY);
wire cmd_data_w;
wire cmd_empty_w;

wire [ADDRBITSZ -1 : 0] cmdaddr_data_w;

wire [ADDRBITSZ -1 : 0] cmdaddr_plus_cntr = (cmdaddr+cntr);

wire [8 -1 : 0] rx_data_w = u[cmdaddr_plus_cntr];
wire [8 -1 : 0] tx_data_w;

wire rx_full_w;
wire tx_empty_w;

always @ (posedge clk_i[0]) begin
	if (rst_i)
		state <= READY;
	else if (state == READY) begin
		if (!cmd_empty_w) begin
			cmdaddr <= (cmdaddr_data_w << 9);
			if (cmd_data_w)
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
			u[cmdaddr_plus_cntr] <= tx_data_w;
	end
end

`ifdef SDCARD_PHY_RCVE_CMD

fifo_fwft #(

	 .WIDTH (1)
	,.DEPTH (CMDBUFDEPTH)

) cmdbuf (

	 .rst_i (cmd_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (cmd_pop_w)
	,.data_o    (cmd_data_w)
	,.empty_o   (cmd_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (cmd_push_i)
	,.data_i     (cmd_data_i)
	,.full_o     (cmd_full_o)
);

fifo_fwft #(

	 .WIDTH (ADDRBITSZ)
	,.DEPTH (CMDBUFDEPTH)

) cmdaddrbuf (

	 .rst_i (cmd_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (cmd_pop_w)
	,.data_o    (cmdaddr_data_w)
	,.empty_o   (cmd_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (cmd_push_i)
	,.data_i     (cmdaddr_data_i)
	,.full_o     (cmd_full_o)
);

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (512*CMDBUFDEPTH)

) rx (

	 .rst_i (rx_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (rx_pop_i)
	,.data_o    (rx_data_o)
	,.empty_o   (rx_empty_o)

	,.clk_push_i (clk_i)
	,.push_i     (rx_push_w)
	,.data_i     (rx_data_w)
	,.full_o     (rx_full_w)
);

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (512*CMDBUFDEPTH)

) tx (

	 .rst_i (tx_rst_i)

	,.usage_o ()

	,.clk_pop_i (clk_i)
	,.pop_i     (tx_pop_w)
	,.data_o    (tx_data_w)
	,.empty_o   (tx_empty_w)

	,.clk_push_i (clk_i)
	,.push_i     (tx_push_i)
	,.data_i     (tx_data_i)
	,.full_o     (tx_full_o)
);

`else

assign cmd_pop_o      = cmd_pop_w;
assign cmd_data_w     = cmd_data_i;
assign cmdaddr_data_w = cmdaddr_data_i;
assign cmd_empty_w    = cmd_empty_i;

assign rx_push_o = rx_push_w;
assign rx_data_o = rx_data_w;
assign rx_full_w = rx_full_i;

assign tx_pop_o   = tx_pop_w;
assign tx_data_w  = tx_data_i;
assign tx_empty_w = tx_empty_i;

`endif

endmodule

`endif
