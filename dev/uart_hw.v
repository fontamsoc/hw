// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// UART peripheral.
//
// The device transfer data byte at a time.
// The first half of the device memory mapping is used to send/receive
// bytes while, the second half is used to send commands to the device.
//
// Commands sent to the device expect following format
// | arg: (ARCHBITSZ-2) bits | cmd: 2 bit | where the field "cmd" values
// are CMDDEVRDY(2'b00), CMDGETBUFFERUSAGE(2'b01), CMDSETINTERRUPT(2'b10)
// and CMDSETSPEED(2'b11). The result of a previously sent command is
// retrieved from the device reading from it and has the following format
// | resp: (ARCHBITSZ-2) bits | cmd: 2 bit | where the fields "cmd" and
// "resp" are the command and its result.
// Two memory operations, a write followed by a read are needed to send
// a command to the device and retrieve its result.
// The device has accepted a command only if "cmd" in its result
// is CMDDEVRDY, otherwise sending the command CMDDEVRDY is needed.
//
// The description of commands is as follow:
// 	CMDDEVRDY: Make the device accept a new command.
// 	"resp" in the result get set to 0.
// 	CMDGETBUFFERUSAGE: Get receive/transmit buffer usage.
// 	"arg" value encode which buffer should the usage be returned.
// 	When "arg" is 0, the receive buffer usage is returned;
// 	when "arg" is 1, the transmit buffer usage is returned.
// 	"resp" in the result get set to the usage in number of bytes.
// 	CMDSETINTERRUPT: enable/disable interrupt.
// 	"arg" value when 0 disable interrupt, and when non-null, enables
// 	interrupt and set the minimum receive buffer usage that would
// 	trigger an interrupt.
// 	"resp" in the result get set to the size in bytes of the transmit
// 	and receive buffer.
// 	CMDSETSPEED: Set the speed to use when sending and receiving bytes.
// 	"arg" value is the speed computed as follow: (PHYCLKFREQ/bitrate);
// 	ei: For a PHYCLKFREQ of 100 Mhz and a bitrate of 115200 bps,
// 	the above formula yield 867.
// 	"resp" in the result get set to PHYCLKFREQ.
//
// To be multi core proof, an atomic read-write must be used to send
// a command to the device until CMDDEVRDY is returned, then another
// atomic read-write sending CMDDEVRDY must be used to retrieve the
// result while making the device ready for the next command.

// Parameters:
//
// ARCHBITSZ
// 	Must be a power-of-2 and <= 64.
//
// PHYCLKFREQ
// 	Frequency of the clock input "clk_phy_i" in Hz.
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
// 	Clock input used by PHYs which transmit and
// 	receive bits; its frequency must always be higher
// 	than the desired transmission bitrate.
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
// rx_i
// 	Incoming serial line.
//
// tx_o
// 	Outgoing serial line.

// On reset, interrupt is disabled, and must be explicitely enabled.
// It prevent an unwanted interrupt after reset.
// When enabled, an interrupt request is raised if the receive buffer
// usage interrupt threshold is reached; interrupt get disabled when
// the raised interrupt get acknowledged.

// Writing a byte when there is no space left
// in the transmit buffer silently fail.
// Similarly, reading a byte when there is no byte left
// in the receive buffer return garbage.

`include "lib/uart/uart_rx.v"
`include "lib/uart/uart_tx.v"

module uart_hw (

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

	,rx_i
	,tx_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter PHYCLKFREQ = 1;
parameter BUFSZ      = 2;

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

input  wire rx_i;
output wire tx_o;

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

// Note that (ARCHBITSZ-2) is the number of bits used by a command argument.
localparam CLOCKCYCLESPERBITLIMIT = (1<<(ARCHBITSZ-2));
localparam CLOG2CLOCKCYCLESPERBITLIMIT = (ARCHBITSZ-2);

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] rxclockcyclesperbit;
reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] txclockcyclesperbit;

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
		// Normally the formula to use is:
		// ((PHYCLKFREQ/bitrate) + ((PHYCLKFREQ/bitrate)/10/2));
		// so this is an approximation.
		rxclockcyclesperbit <= (wb_dat_r[ARCHBITSZ-1:2] + (wb_dat_r[ARCHBITSZ-1:2] >> 5));
		txclockcyclesperbit <=  wb_dat_r[ARCHBITSZ-1:2];
		wb_dat_o_ <= {PHYCLKFREQ[(ARCHBITSZ-2)-1:0], wb_dat_r[1:0]};
	end

	rx_read_w_sampled <= rx_read_w;

	irq_rdy_i_r <= irq_rdy_i; // Sampling used for edge detection.
end

uart_rx #(

	 .BUFSZ                  (BUFSZ)
	,.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) uart_rx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.clockcyclesperbit_i (rxclockcyclesperbit)

	,.read_i  (rx_read_w)
	,.data_o  (rx_data_w0)
	,.usage_o (rx_usage_w)

	,.rx_i (rx_i)
);

uart_tx #(

	 .BUFSZ                  (BUFSZ)
	,.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) uart_tx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.clockcyclesperbit_i (txclockcyclesperbit)

	,.write_i (tx_write_w)
	,.data_i  (tx_data_w1)
	,.usage_o (tx_usage_w)

	,.tx_o (tx_o)
);

endmodule
