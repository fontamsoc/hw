// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef USB_SERIAL_FIFO_PHY_V
`define USB_SERIAL_FIFO_PHY_V

// Module implementing USB serial FIFO-PHY.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the phy clock "clk_phy_i" in Hz.
// 	Must be 48000000 or 60000000 for full speed,
// 	60000000 for high speed.
//
// DEPTH
// 	Max number of data that the fifo can contain.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	This input reset the module.
// 	It must be held low for normal operation.
//
// rx_clk_i
// rx_pop_i
// rx_data_o
// rx_empty_o
// rx_usage_o
// 	FIFO interface to receive data.
//
// tx_clk_i
// tx_push_i
// tx_data_i
// tx_full_o
// tx_usage_o
// 	FIFO interface to transmit data.
//
// clk_phy_i
// 	Clock input used by the internal module which transmit
// 	and receive each bit; due to usb_cdc_core requirements,
// 	its frequency must be 48 MHz or 60 MHz for full speed,
// 	60 MHz for high speed.
//
// usb_dp_io
// usb_dn_io
// 	USB signals.

`include "lib/fifo_fwft.v"
`include "lib/usb_serial_phy.v"

module usb_serial_fifo_phy (

	 rst_i

	,rx_clk_i
	,rx_pop_i
	,rx_data_o
	,rx_empty_o
	,rx_usage_o

	,tx_clk_i
	,tx_push_i
	,tx_data_i
	,tx_full_o
	,tx_usage_o

	,clk_phy_i
	,usb_dp_io
	,usb_dn_io
);

`include "lib/clog2.v"

parameter PHYCLKFREQ = 48000000;
parameter DEPTH      = 2;

localparam CLOG2DEPTH = clog2(DEPTH);

initial begin
	if (!(  PHYCLKFREQ == 48000000 ||
		PHYCLKFREQ == 60000000)) begin
		$finish;
	end
end

input wire rst_i;

`ifdef USE2CLK
input  wire [2 -1 : 0]               rx_clk_i;
`else
input  wire [1 -1 : 0]               rx_clk_i;
`endif
input  wire                          rx_pop_i;
output wire [8 -1 : 0]               rx_data_o;
output wire                          rx_empty_o;
output wire [(CLOG2DEPTH +1) -1 : 0] rx_usage_o;

`ifdef USE2CLK
input  wire [2 -1 : 0]               tx_clk_i;
`else
input  wire [1 -1 : 0]               tx_clk_i;
`endif
input  wire                          tx_push_i;
input  wire [8 -1 : 0]               tx_data_i;
output wire                          tx_full_o;
output wire [(CLOG2DEPTH +1) -1 : 0] tx_usage_o;

input wire clk_phy_i;
inout wire usb_dp_io;
inout wire usb_dn_io;

wire            rx_full_w;
wire [8 -1 : 0] rx_data_w;
wire            rx_push_w;

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) rx (

	 .rst_i (rst_i)

	,.clk_pop_i (rx_clk_i)
	,.pop_i     (rx_pop_i)
	,.data_o    (rx_data_o)
	,.empty_o   (rx_empty_o)
	,.usage_o   (rx_usage_o)

	,.clk_push_i (clk_phy_i)
	,.push_i     (rx_push_w)
	,.data_i     (rx_data_w)
	,.full_o     (rx_full_w)
);

wire            tx_empty_w;
wire [8 -1 : 0] tx_data_w;
wire            tx_pop_w;

fifo_fwft #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) tx (

	 .rst_i (rst_i)

	,.clk_pop_i (clk_phy_i)
	,.pop_i     (tx_pop_w)
	,.data_o    (tx_data_w)
	,.empty_o   (tx_empty_w)

	,.clk_push_i (tx_clk_i)
	,.push_i     (tx_push_i)
	,.data_i     (tx_data_i)
	,.full_o     (tx_full_o)
	,.usage_o    (tx_usage_o)
);

usb_serial_phy #(

	 .PHYCLKFREQ (PHYCLKFREQ)

) phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.rcvd_o (rx_push_w)
	,.data_o (rx_data_w)
	,.rdy_i  (~rx_full_w)

	,.stb_i  (~tx_empty_w)
	,.data_i (tx_data_w)
	,.rdy_o  (tx_pop_w)

	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

endmodule

`endif /* USB_SERIAL_FIFO_PHY_V */
