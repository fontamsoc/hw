// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Serial peripheral through USB.
//
// The device memory mapping usage is similar to uart_hw peripheral,
// with the difference that command CMDSETSPEED "arg" is ignnored.

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
// 	Must be 48000000 or 60000000 for full speed,
// 	60000000 for high speed.
//
// BUFSZ
// 	Size in bytes of the receive and transmit buffer.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock input used by the memory interface.
//
// clk_phy_i
// 	Clock input used by the internal module which transmit
// 	and receive each bit; due to usb_cdc_core requirements,
// 	its frequency must be 48 MHz or 60 MHz for full speed,
// 	60 MHz for high speed.
//
// wb_cyc_i
// wb_stb_i
// wb_we_i
// wb_addr_i
// wb_sel_i
// wb_dat_i
// wb_bsy_o
// wb_ack_o
// wb_dat_o
// 	Slave memory interface.
//
// wb_mapsz_o
// 	Memory map size in bytes.
//
// irq_stb_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised if enabled and the receive
// 	buffer usage interrupt threshold is reached.
//
// irq_rdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower irq_stb_o and disable interrupt.
//
// usb_dp_io
// usb_dn_io
// 	USB signals.

// On reset, interrupt is disabled, and must be explicitely enabled.
// It prevent an unwanted interrupt after reset.
// When enabled, an interrupt request is raised if the receive buffer
// usage interrupt threshold is reached; interrupt get disabled when
// the raised interrupt get acknowledged.

// Writing a byte when there is no space left
// in the transmit buffer silently fail.
// Similarly, reading a byte when there is no byte left
// in the receive buffer return garbage.

`include "lib/usb_serial_fifo_phy.v"

module usb_serial (

	 rst_i

	,clk_i
	,clk_phy_i

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o
	,wb_mapsz_o

	,irq_stb_o
	,irq_rdy_i

	,usb_dp_io
	,usb_dn_io
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter PHYCLKFREQ = 48000000;
parameter BUFSZ      = 2;

initial begin
	if (!(  PHYCLKFREQ == 48000000 ||
		PHYCLKFREQ == 60000000)) begin
		$finish;
	end
end

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output wire [ARCHBITSZ -1 : 0]     wb_dat_o;
output wire [ARCHBITSZ -1 : 0]     wb_mapsz_o;

output wire irq_stb_o;
input  wire irq_rdy_i;

inout wire usb_dp_io;
inout wire usb_dn_io;

assign wb_bsy_o = 1'b0;

assign wb_mapsz_o = ((128/ARCHBITSZ)*(ARCHBITSZ/8));

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ADDRBITSZ -1 : 0] wb_addr_r;
reg [ARCHBITSZ -1 : 0] wb_dat_r;

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

localparam CMDDEVRDY         = 0;
localparam CMDGETBUFFERUSAGE = 1;
localparam CMDSETINTERRUPT   = 2;
localparam CMDSETSPEED       = 3;

reg [ARCHBITSZ -1 : 0] wb_dat_o_;

// Half the memory mapping is used to send/receive data,
// while the other half is used to issue commands.
localparam CLOG264BYARCHBITSZ = clog2(64/ARCHBITSZ);

wire iscmd = (!rst_i && wb_stb_r && wb_we_r && wb_addr_r[CLOG264BYARCHBITSZ]);

wire prevcmdisdevrdy = (wb_dat_o_[1:0] == CMDDEVRDY);

wire prevcmddone = (iscmd && prevcmdisdevrdy);

wire cmddevrdy = (iscmd && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdgetbuf = (prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmdsetint = (prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmdsetspd = (prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire devrd = (!rst_i && wb_stb_r && !wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ] && prevcmdisdevrdy);
wire devwr = (!rst_i && wb_stb_r &&  wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ] && prevcmdisdevrdy);

wire            rx_read_w = devrd;
wire [8 -1 : 0] rx_data_w0;

wire            tx_write_w = devwr;
wire [8 -1 : 0] tx_data_w1 = wb_dat_r[8 -1 : 0];

wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w;
wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_w;

reg [(ARCHBITSZ-2) -1 : 0] intrqstthresh;

assign irq_stb_o = (|intrqstthresh && (rx_usage_w >= intrqstthresh) &&
	// Raise intrqst only when the device is ready for the next command,
	// otherwise an interrupt would cause software to send the device a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

reg rx_read_w_sampled;

assign wb_dat_o = (rx_read_w_sampled ? rx_data_w0 : wb_dat_o_);

always @ (posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitely enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (cmdsetint) begin
		intrqstthresh <= wb_dat_r[ARCHBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		intrqstthresh <= 0;
	end

	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {ARCHBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {BUFSZ[(ARCHBITSZ-2)-1:0], wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((ARCHBITSZ-2)-(CLOG2BUFSZ+1)){1'b0}},
			(wb_dat_r[2] ? tx_usage_w : rx_usage_w),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {PHYCLKFREQ[(ARCHBITSZ-2)-1:0], wb_dat_r[1:0]};
	end

	rx_read_w_sampled <= rx_read_w;

	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

usb_serial_fifo_phy #(

	 .PHYCLKFREQ (PHYCLKFREQ)
	,.DEPTH      (BUFSZ)

) phy (

	 .rst_i (rst_i)

	,.rx_clk_i   (clk_i)
	,.rx_read_i  (rx_read_w)
	,.rx_data_o  (rx_data_w0)
	,.rx_usage_o (rx_usage_w)

	,.tx_clk_i   (clk_i)
	,.tx_write_i (tx_write_w)
	,.tx_data_i  (tx_data_w1)
	,.tx_usage_o (tx_usage_w)

	,.clk_phy_i (clk_phy_i)
	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

endmodule
