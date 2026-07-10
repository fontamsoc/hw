// SPDX-License-Identifier: GPL-2.0-only
// 20260420 (c) William Fonkou Tambe

// Serial peripheral through USB.
//
// The device memory mapping usage is similar to serial_uart peripheral,
// with the difference that command CMDSETSPEED "arg" is ignored.
//
// The device implements PORTCOUNT COM ports through the same USB link;
// the port "p" is an independent instance of the serial_uart peripheral
// memory mapping usage, with its data word at the word offset (2*p) and
// its command word at the word offset ((2*p)+1).

// Parameters:
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
// 	Must be 48000000.
//
// PORTCOUNT
// 	Number of COM ports presented to the host through the same
// 	USB link; it must be at least 1 and at most 5.
//
// BUFSZ
// 	Size in bytes of the receive and transmit buffer of each port.
// 	It must be at least 2 and a power of 2.

// Ports:
//
// rst_i
// 	This input resets this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock input used by the memory interface.
//
// clk_phy_i
// 	Clock input used by the internal module which transmits
// 	and receives each bit; due to usb_fs_phy requirements,
// 	its frequency must be 48 MHz.
//
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
// irq_stb_o
// 	The bit "p" of this signal is set high to request an interrupt
// 	for the port "p"; an interrupt is raised if enabled and the
// 	receive buffer usage interrupt threshold is reached.
//
// irq_rdy_i
// 	The bit "p" of this signal becomes low when the port "p"
// 	interrupt request has been acknowledged, and is used by this
// 	module to lower the bit "p" of irq_stb_o and disable interrupt.
//
// usb_dp_io
// usb_dn_io
// 	USB signals.

`include "lib/serial_usb_fifo_phy.sv"

module serial_usb (

	 rst_i

	,clk_i
	,clk_phy_i

	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,irq_stb_o
	,irq_rdy_i

	,usb_dp_io
	,usb_dn_io
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;

parameter PHYCLKFREQ = 48000000;
parameter PORTCOUNT  = 1;
parameter BUFSZ      = 2;

initial begin
	if (!(  PHYCLKFREQ == 48000000 ||
		PHYCLKFREQ == 60000000)) begin
		$finish;
	end
	if (!(PORTCOUNT >= 1 && PORTCOUNT <= 5)) begin
		$finish;
	end
end

localparam CLOG2BUFSZ = clog2(BUFSZ);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (2*(WORDBITSZ/8)*PORTCOUNT);

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;
input wire clk_phy_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output wire [WORDBITSZ -1 : 0]            wb_dat_o;

output wire [PORTCOUNT -1 : 0] irq_stb_o;
input  wire [PORTCOUNT -1 : 0] irq_rdy_i;

inout wire usb_dp_io;
inout wire usb_dn_io;

reg                               wb_stb_r;
reg                               wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;

wire wb_stb_r_ = (wb_stb_i && !wb_bsy_o);

always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_r_;
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

// Within each port pair of words, the first word is used to
// send/receive data, while the second word is used to issue commands.
localparam ISCMDBIT = 0;

// Index of the port being addressed, computed from the word address;
// the port "p" data word is at the word offset (2*p), and its command
// word at the word offset ((2*p)+1).
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] portidx_w_ = (wb_addr_i >> 1);
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] portidx_w  = (wb_addr_r >> 1);

wire [PORTCOUNT -1 : 0]             rx_read_w;
wire [(8*PORTCOUNT) -1 : 0]         rx_data_w0;

wire [PORTCOUNT -1 : 0]             tx_write_w;
wire [(8*PORTCOUNT) -1 : 0]         tx_data_w1 = {PORTCOUNT{wb_dat_r[8 -1 : 0]}};

wire [((CLOG2BUFSZ +1)*PORTCOUNT) -1 : 0] rx_usage_w;
wire [((CLOG2BUFSZ +1)*PORTCOUNT) -1 : 0] tx_usage_w;

wire [PORTCOUNT -1 : 0] tx_near_full_w;

assign wb_bsy_o = (!wb_addr_i[ISCMDBIT] && (wb_we_i ?
	tx_near_full_w[portidx_w_] :
	(rx_usage_w[(portidx_w_*(CLOG2BUFSZ +1)) +: (CLOG2BUFSZ +1)] == 0)));

// Per-port command result words and sampled data-read strobes,
// out of which the addressed port slice drives wb_dat_o.
wire [(WORDBITSZ*PORTCOUNT) -1 : 0] wb_dat_o_w;
wire [PORTCOUNT -1 : 0]             rx_read_sampled_w;

assign wb_dat_o = (rx_read_sampled_w[portidx_w] ?
	rx_data_w0[(portidx_w*8) +: 8] :
	wb_dat_o_w[(portidx_w*WORDBITSZ) +: WORDBITSZ]);

genvar gen_port;
generate for (gen_port = 0; gen_port < PORTCOUNT; gen_port = gen_port + 1)
begin :gen_ports

reg [WORDBITSZ -1 : 0] wb_dat_o_;

assign wb_dat_o_w[((gen_port+1)*WORDBITSZ) -1 : (gen_port*WORDBITSZ)] = wb_dat_o_;

wire portmatch = (portidx_w == gen_port);

wire iscmd = (wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT] && portmatch);

wire prevcmdisdevrdy = (wb_dat_o_[1:0] == CMDDEVRDY);

wire prevcmddone = (iscmd && prevcmdisdevrdy);

wire cmddevrdy = (iscmd       && wb_dat_r[1:0] == CMDDEVRDY);
wire cmdgetbuf = (prevcmddone && wb_dat_r[1:0] == CMDGETBUFFERUSAGE);
wire cmdsetint = (prevcmddone && wb_dat_r[1:0] == CMDSETINTERRUPT);
wire cmdsetspd = (prevcmddone && wb_dat_r[1:0] == CMDSETSPEED);

wire devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT] && portmatch && prevcmdisdevrdy);
wire devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT] && portmatch && prevcmdisdevrdy);

assign rx_read_w[gen_port]  = devrd;
assign tx_write_w[gen_port] = devwr;

// This port receive/transmit buffer usage.
wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w_ = rx_usage_w[((gen_port+1)*(CLOG2BUFSZ +1)) -1 : (gen_port*(CLOG2BUFSZ +1))];
wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_w_ = tx_usage_w[((gen_port+1)*(CLOG2BUFSZ +1)) -1 : (gen_port*(CLOG2BUFSZ +1))];

reg [(CLOG2BUFSZ +1) -1 : 0] intrqstthresh;

assign irq_stb_o[gen_port] = (|intrqstthresh && (rx_usage_w_ >= intrqstthresh) &&
	// Raise intrqst only when the device is ready for the next command,
	// otherwise an interrupt would cause software to send the device a new
	// command while it is not ready, waiting indefinitely for it to be ready.
	prevcmdisdevrdy);

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i[gen_port] && irq_rdy_i_r);

reg rx_read_w_sampled;

assign rx_read_sampled_w[gen_port] = rx_read_w_sampled;

always_ff @(posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitly enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (cmdsetint) begin
		intrqstthresh <= wb_dat_r[WORDBITSZ-1:2];
	end else if (irq_rdy_i_negedge) begin
		intrqstthresh <= 0;
	end
end

always_ff @(posedge clk_i) begin
	if (rst_i || cmddevrdy) begin
		wb_dat_o_ <= {WORDBITSZ{1'b0}};
	end else if (cmdsetint) begin
		wb_dat_o_ <= {BUFSZ[(WORDBITSZ-2)-1:0], wb_dat_r[1:0]};
	end else if (cmdgetbuf) begin
		wb_dat_o_ <= {
			{((WORDBITSZ-2)-(CLOG2BUFSZ+1)){1'b0}},
			(wb_dat_r[2] ? tx_usage_w_ : rx_usage_w_),
			wb_dat_r[1:0]};
	end else if (cmdsetspd) begin
		wb_dat_o_ <= {PHYCLKFREQ[(WORDBITSZ-2)-1:0], wb_dat_r[1:0]};
	end
end

always_ff @(posedge clk_i) begin
	rx_read_w_sampled <= devrd;
	irq_rdy_i_r <= irq_rdy_i[gen_port]; // Sampling used for edge detection.
end

end endgenerate

serial_usb_fifo_phy #(

	 .PHYCLKFREQ (PHYCLKFREQ)
	,.PORTCOUNT  (PORTCOUNT)
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

	,.tx_near_full_o (tx_near_full_w)

	,.clk_phy_i (clk_phy_i)
	,.usb_dp_io (usb_dp_io)
	,.usb_dn_io (usb_dn_io)
);

endmodule
