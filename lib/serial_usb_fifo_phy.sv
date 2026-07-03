// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef USB_SERIAL_FIFO_PHY_V
`define USB_SERIAL_FIFO_PHY_V

// Module implementing USB serial FIFO-PHY.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the phy clock "clk_phy_i" in Hz.
// 	Must be 48000000.
//
// PORTCOUNT
// 	Number of COM ports presented to the host through the same
// 	USB link; it must be at least 1 and at most 5.
// 	Each port has its own receive and transmit fifos; the port
// 	"p" uses the bit "p" of each single-bit-per-port signal, the
// 	byte slice [((p+1)*8)-1:(p*8)] of "rx_data_o" and "tx_data_i",
// 	and the slice [((p+1)*(clog2(DEPTH)+1))-1:(p*(clog2(DEPTH)+1))]
// 	of "rx_usage_o" and "tx_usage_o".
//
// DEPTH
// 	Max number of data that each fifo can contain.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	This input resets the module.
// 	It must be held low for normal operation.
//
// rx_clk_i
// rx_read_i
// rx_data_o
// rx_empty_o
// rx_usage_o
// 	Per-port FIFO interfaces to receive data.
//
// tx_clk_i
// tx_write_i
// tx_data_i
// tx_near_full_o
// tx_full_o
// tx_usage_o
// 	Per-port FIFO interfaces to transmit data.
//
// clk_phy_i
// 	Clock input used by the internal module which transmits
// 	and receives each bit; due to usb_fs_phy requirements,
// 	its frequency must be 48 MHz.
//
// usb_dp_io
// usb_dn_io
// 	USB signals.

`include "lib/fifo.sv"
`include "lib/serial_usb_phy.sv"

module serial_usb_fifo_phy (

	 rst_i

	,rx_clk_i
	,rx_read_i
	,rx_data_o
	,rx_empty_o
	,rx_usage_o

	,tx_clk_i
	,tx_write_i
	,tx_data_i
	,tx_near_full_o
	,tx_full_o
	,tx_usage_o

	,clk_phy_i
	,usb_dp_io
	,usb_dn_io
);

`include "lib/clog2.sv"

parameter PHYCLKFREQ = 48000000;
parameter PORTCOUNT  = 1;
parameter DEPTH      = 2;

localparam CLOG2DEPTH = clog2(DEPTH);

initial begin
	if (!(  PHYCLKFREQ == 48000000 ||
		PHYCLKFREQ == 60000000)) begin
		$finish;
	end
	if (!(PORTCOUNT >= 1 && PORTCOUNT <= 5)) begin
		$finish;
	end
end

input wire rst_i;

input  wire                                      rx_clk_i;
input  wire [PORTCOUNT -1 : 0]                   rx_read_i;
output wire [(8*PORTCOUNT) -1 : 0]               rx_data_o;
output wire [PORTCOUNT -1 : 0]                   rx_empty_o;
output wire [((CLOG2DEPTH +1)*PORTCOUNT) -1 : 0] rx_usage_o;

input  wire                                      tx_clk_i;
input  wire [PORTCOUNT -1 : 0]                   tx_write_i;
input  wire [(8*PORTCOUNT) -1 : 0]               tx_data_i;
output wire [PORTCOUNT -1 : 0]                   tx_near_full_o;
output wire [PORTCOUNT -1 : 0]                   tx_full_o;
output wire [((CLOG2DEPTH +1)*PORTCOUNT) -1 : 0] tx_usage_o;

input wire clk_phy_i;
inout wire usb_dp_io;
inout wire usb_dn_io;

wire [PORTCOUNT -1 : 0]     rx_full_w;
wire [(8*PORTCOUNT) -1 : 0] rx_data_w;
wire [PORTCOUNT -1 : 0]     rx_write_w;

wire [(8*PORTCOUNT) -1 : 0] tx_data_w;
wire [PORTCOUNT -1 : 0]     tx_phy_rdy_w;
wire [PORTCOUNT -1 : 0]     tx_read_done_w;

genvar gen_port;
generate for (gen_port = 0; gen_port < PORTCOUNT; gen_port = gen_port + 1)
begin :gen_ports

fifo #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) rx (

	 .rst_i (rst_i)

	,.clk_read_i (rx_clk_i)
	,.read_i     (rx_read_i[gen_port])
	,.data_o     (rx_data_o[((gen_port+1)*8) -1 : (gen_port*8)])
	,.empty_o    (rx_empty_o[gen_port])
	,.usage_o    (rx_usage_o[((gen_port+1)*(CLOG2DEPTH +1)) -1 : (gen_port*(CLOG2DEPTH +1))])

	,.clk_write_i (clk_phy_i)
	,.write_i     (rx_write_w[gen_port])
	,.data_i      (rx_data_w[((gen_port+1)*8) -1 : (gen_port*8)])
	,.full_o      (rx_full_w[gen_port])
);

// Usage of this port transmit fifo.
wire [(CLOG2DEPTH +1) -1 : 0] tx_usage_w;

// This register is set to 1, when data was read from fifo.
reg tx_read_done;

assign tx_read_done_w[gen_port] = tx_read_done;

wire tx_read_stb = (tx_usage_w && !tx_read_done);

wire tx_empty_w;

fifo #(

	 .WIDTH (8)
	,.DEPTH (DEPTH)

) tx (

	 .rst_i (rst_i)

	,.clk_read_i (clk_phy_i)
	,.read_i     (tx_read_stb)
	,.data_o     (tx_data_w[((gen_port+1)*8) -1 : (gen_port*8)])
	,.empty_o    (tx_empty_w)

	,.clk_write_i (tx_clk_i)
	,.write_i     (tx_write_i[gen_port])
	,.data_i      (tx_data_i[((gen_port+1)*8) -1 : (gen_port*8)])
	,.near_full_o (tx_near_full_o[gen_port])
	,.full_o      (tx_full_o[gen_port])
	,.usage_o     (tx_usage_w)
);

assign tx_usage_o[((gen_port+1)*(CLOG2DEPTH +1)) -1 : (gen_port*(CLOG2DEPTH +1))] = tx_usage_w;

// Register used to save the state of tx_phy_rdy_w
// in order to detect its falling edge.
reg tx_phy_rdy_w_sampled;

// Logic that set the net tx_phy_rdy_w_negedge
// when a falling edge of tx_phy_rdy_w occurs.
wire tx_phy_rdy_w_negedge = (!tx_phy_rdy_w[gen_port] && tx_phy_rdy_w_sampled);

always_ff @(posedge clk_phy_i) begin
	// Logic that update tx_read_done.
	if (rst_i || (tx_read_done && tx_phy_rdy_w_negedge))
		tx_read_done <= 0;
	else if (tx_read_stb)
		tx_read_done <= 1;
end

always_ff @(posedge clk_phy_i) begin
	// Save the current state of tx_phy_rdy_w;
	tx_phy_rdy_w_sampled <= tx_phy_rdy_w[gen_port];
end

end endgenerate

serial_usb_phy #(

	 .PHYCLKFREQ (PHYCLKFREQ)
	,.PORTCOUNT  (PORTCOUNT)

) phy (

	 .rst_i (rst_i)

	,.clk_i (clk_phy_i)

	,.rcvd_o (rx_write_w)
	,.data_o (rx_data_w)
	,.rdy_i  (~rx_full_w)

	,.stb_i  (tx_phy_rdy_w & tx_read_done_w)
	,.data_i (tx_data_w)
	,.rdy_o  (tx_phy_rdy_w)

	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

endmodule

`endif /* USB_SERIAL_FIFO_PHY_V */
