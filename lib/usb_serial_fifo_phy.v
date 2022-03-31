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
// rx_read_i
// rx_data_o
// rx_empty_o
// rx_usage_o
// 	FIFO interface to receive data.
//
// tx_clk_i
// tx_write_i
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

`include "lib/fifo.v"
`include "lib/usb_serial_phy.v"

module usb_serial_fifo_phy (

	 rst_i

	,rx_clk_i
	,rx_read_i
	,rx_data_o
	,rx_empty_o
	,rx_usage_o

	,tx_clk_i
	,tx_write_i
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

input  wire                          rx_clk_i;
input  wire                          rx_read_i;
output wire [8 -1 : 0]               rx_data_o;
output wire                          rx_empty_o;
output wire [(CLOG2DEPTH +1) -1 : 0] rx_usage_o;

input  wire                          tx_clk_i;
input  wire                          tx_write_i;
input  wire [8 -1 : 0]               tx_data_i;
output wire                          tx_full_o;
output wire [(CLOG2DEPTH +1) -1 : 0] tx_usage_o;

input wire clk_phy_i;
inout wire usb_dp_io;
inout wire usb_dn_io;

wire            rx_full_w;
wire [8 -1 : 0] rx_data_w;
wire            rx_write_w;

fifo #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) rx (

	 .rst_i (rst_i)

	,.clk_read_i (rx_clk_i)
	,.read_i     (rx_read_i)
	,.data_o     (rx_data_o)
	,.empty_o    (rx_empty_o)
	,.usage_o    (rx_usage_o)

	,.clk_write_i (clk_phy_i)
	,.write_i     (rx_write_w)
	,.data_i      (rx_data_w)
	,.full_o      (rx_full_w)
);

// This register is set to 1, when data was read from fifo.
reg tx_read_done = 0;

wire tx_read_stb = (tx_usage_o && !tx_read_done);

wire            tx_empty_w;
wire [8 -1 : 0] tx_data_w;

fifo #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) tx (

	 .rst_i (rst_i)

	,.clk_read_i (clk_phy_i)
	,.read_i     (tx_read_stb)
	,.data_o     (tx_data_w)
	,.empty_o    (tx_empty_w)

	,.clk_write_i (tx_clk_i)
	,.write_i     (tx_write_i)
	,.data_i      (tx_data_i)
	,.full_o      (tx_full_o)
	,.usage_o     (tx_usage_o)
);

wire tx_phy_rdy_w;

usb_serial_phy #(

	 .PHYCLKFREQ (PHYCLKFREQ)

) phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.rcvd_o (rx_write_w)
	,.data_o (rx_data_w)
	,.rdy_i  (~rx_full_w)

	,.stb_i  (tx_phy_rdy_w && tx_read_done)
	,.data_i (tx_data_w)
	,.rdy_o  (tx_phy_rdy_w)

	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

// Register used to save the state of tx_phy_rdy_w
// in order to detect its falling edge.
reg tx_phy_rdy_w_sampled;

// Logic that set the net tx_phy_rdy_w_negedge
// when a falling edge of tx_phy_rdy_w occurs.
wire tx_phy_rdy_w_negedge = (tx_phy_rdy_w < tx_phy_rdy_w_sampled);

always @(posedge clk_phy_i) begin
	// Logic that update tx_read_done.
	if (rst_i || (tx_read_done && tx_phy_rdy_w_negedge))
		tx_read_done <= 0;
	else if (tx_read_stb)
		tx_read_done <= 1;

	// Save the current state of tx_phy_rdy_w;
	tx_phy_rdy_w_sampled <= tx_phy_rdy_w;
end

endmodule

`endif /* USB_SERIAL_FIFO_PHY_V */
