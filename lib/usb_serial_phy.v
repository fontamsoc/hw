// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef USB_SERIAL_PHY_V
`define USB_SERIAL_PHY_V

// Module implementing USB serial PHY.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_i" in Hz.
// 	Must be 48000000 or 60000000 for full speed,
// 	60000000 for high speed.

// Ports:
//
// rst_i
// 	This input reset the module.
// 	It must be held low for normal operation.
//
// clk_i
// 	Clock signal.
//
// rcvd_o
// 	Signal high for one clock cycle when a byte has been received.
//
// data_o
// 	Byte received which is valid only when "rcvd_o" is high.
//
// rdy_i
// 	Signal high when ready to receive through "data_o".
//
// stb_i
// 	Signal to be set high to transmit "data_i" if "rdy_o" is high.
//
// data_i
// 	Byte value to transmit when (stb_i && rdy_o) is true.
//
// rdy_o
// 	Signal high when ready to transmit through "data_i".

`include "lib/core_usb_cdc/src_v/usb_cdc_core.v"
`include "lib/core_usb_cdc/src_v/usb_desc_rom.v"
`include "lib/core_usb_cdc/src_v/usbf_device_core.v"
`include "lib/core_usb_cdc/src_v/usbf_sie_rx.v"
`include "lib/core_usb_cdc/src_v/usbf_sie_tx.v"
`include "lib/core_usb_cdc/src_v/usbf_crc16.v"
`include "lib/core_usb_fs_phy/src_v/usb_fs_phy.v"
`include "lib/core_usb_fs_phy/src_v/usb_transceiver.v"

module usb_serial_phy (

	 rst_i

	,clk_i

	,rcvd_o
	,data_o
	,rdy_i

	,stb_i
	,data_i
	,rdy_o

	,usb_dp_io
	,usb_dn_io
);

parameter PHYCLKFREQ = 48000000;

initial begin
	if (!(  PHYCLKFREQ == 48000000 ||
		PHYCLKFREQ == 60000000)) begin
		$finish;
	end
end

input wire rst_i;

input wire clk_i;

output wire            rcvd_o;
output wire [8 -1 : 0] data_o;
input  wire            rdy_i;

input  wire            stb_i;
input  wire [8 -1 : 0] data_i;
output wire            rdy_o;

inout wire usb_dp_io;
inout wire usb_dn_io;

wire [8 -1 : 0] utmi_data_in_w;
wire            utmi_txready_w;
wire            utmi_rxvalid_w;
wire            utmi_rxactive_w;
wire            utmi_rxerror_w;
wire [2 -1 : 0] utmi_linestate_w;
wire [8 -1 : 0] utmi_data_out_w;
wire            utmi_txvalid_w;
wire [2 -1 : 0] utmi_op_mode_w;
wire [2 -1 : 0] utmi_xcvrselect_w;
wire            utmi_termselect_w;
wire            utmi_dppulldown_w;
wire            utmi_dmpulldown_w;

usb_cdc_core #(

	.USB_SPEED_HS (PHYCLKFREQ == 60000000 ? "True" : "False")

) usb_cdc_core0 (

	 .clk_i (clk_i)

	,.rst_i (rst_i)

	,.enable_i (1'b1)

	,.inport_valid_i  (stb_i)
	,.inport_data_i   (data_i)
	,.inport_accept_o (rdy_o)

	,.outport_valid_o  (rcvd_o)
	,.outport_data_o   (data_o)
	,.outport_accept_i (rdy_i)

	,.utmi_data_in_i    (utmi_data_in_w)
	,.utmi_txready_i    (utmi_txready_w)
	,.utmi_rxvalid_i    (utmi_rxvalid_w)
	,.utmi_rxactive_i   (utmi_rxactive_w)
	,.utmi_rxerror_i    (utmi_rxerror_w)
	,.utmi_linestate_i  (utmi_linestate_w)
	,.utmi_data_out_o   (utmi_data_out_w)
	,.utmi_txvalid_o    (utmi_txvalid_w)
	,.utmi_op_mode_o    (utmi_op_mode_w)
	,.utmi_xcvrselect_o (utmi_xcvrselect_w)
	,.utmi_termselect_o (utmi_termselect_w)
	,.utmi_dppulldown_o (utmi_dppulldown_w)
	,.utmi_dmpulldown_o (utmi_dmpulldown_w)
);

wire usb_pads_rx_rcv_w;
wire usb_pads_rx_dp_w;
wire usb_pads_rx_dn_w;
wire usb_pads_tx_dp_w;
wire usb_pads_tx_dn_w;
wire usb_pads_tx_oen_w;

usb_fs_phy usb_fs_phy0 (

	 .clk_i (clk_i)

	,.rst_i (rst_i)

	,.usb_reset_assert_i (1'b0)
	,.usb_reset_detect_o ()
	,.usb_en_o           ()

	,.utmi_data_in_o    (utmi_data_in_w)
	,.utmi_txready_o    (utmi_txready_w)
	,.utmi_rxvalid_o    (utmi_rxvalid_w)
	,.utmi_rxactive_o   (utmi_rxactive_w)
	,.utmi_rxerror_o    (utmi_rxerror_w)
	,.utmi_linestate_o  (utmi_linestate_w)
	,.utmi_data_out_i   (utmi_data_out_w)
	,.utmi_txvalid_i    (utmi_txvalid_w)
	,.utmi_op_mode_i    (utmi_op_mode_w)
	,.utmi_xcvrselect_i (utmi_xcvrselect_w)
	,.utmi_termselect_i (utmi_termselect_w)
	,.utmi_dppulldown_i (utmi_dppulldown_w)
	,.utmi_dmpulldown_i (utmi_dmpulldown_w)

	,.usb_rx_rcv_i (usb_pads_rx_rcv_w)
	,.usb_rx_dp_i  (usb_pads_rx_dp_w)
	,.usb_rx_dn_i  (usb_pads_rx_dn_w)
	,.usb_tx_dp_o  (usb_pads_tx_dp_w)
	,.usb_tx_dn_o  (usb_pads_tx_dn_w)
	,.usb_tx_oen_o (usb_pads_tx_oen_w)
);

usb_transceiver usb_transceiver0 (

	 .mode_i (1'b1)

	,.usb_phy_rx_rcv_o (usb_pads_rx_rcv_w)
	,.usb_phy_rx_dp_o  (usb_pads_rx_dp_w)
	,.usb_phy_rx_dn_o  (usb_pads_rx_dn_w)
	,.usb_phy_tx_dp_i  (usb_pads_tx_dp_w)
	,.usb_phy_tx_dn_i  (usb_pads_tx_dn_w)
	,.usb_phy_tx_oen_i (usb_pads_tx_oen_w)

	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

endmodule

`endif /* USB_SERIAL_PHY_V */
