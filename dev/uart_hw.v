// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// UART peripheral.
//
// The device transfer data byte at a time.
// The memory operations PIRDOP, PIWROP
// respectively read, write a single byte.
// The memory operation PIRWOP is used to send commands
// to the device, and must read-write an ARCHBITSZ bits value,
// where the value to write encode both the command and its argument
// as follow: |cmd: 2 bits|arg: (ARCHBITSZ-2) bits|
// while the value read is the return value of the command.
// Failling to use an 8 bits memory access when using PIRDOP
// and PIWROP, or an ARCHBITSZ bits memory access when using
// PIRWOP will result in an undefined behavior.

// Description of commands:
//
// CMDGETBUFFERUSAGE
// 	Cmd value is 0.
// 	Arg[0] value encode which buffer should the usage be returned.
// 	When Arg[0] is 0, the receive buffer usage is returned;
// 	when Arg[0] is 1, the transmit buffer usage is returned.
// 	The usage is in number of bytes.
//
// CMDSETINTERRUPT
// 	Cmd value is 1.
// 	Arg value which when 0 disable interrupt, and when non-null,
// 	enables interrupt and set the minimum receive buffer usage
// 	that would trigger an interrupt.
// 	Return value is the size in bytes of the transmit and receive buffer.
//
// CMDSETSPEED
// 	Cmd value is 2.
// 	Arg value is the speed.
// 	Return value is PHYCLKFREQ.
// 	This command set the speed to use when sending and receiving bytes.
// 	The speed is to be computed as follow: (PHYCLKFREQ/bitrate);
// 	ei: For a PHYCLKFREQ of 100 Mhz and a bitrate of 115200 bps,
// 	the above formula yield 867.

// Parameters:
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
// pi1_op_i
// pi1_addr_i
// pi1_data_i
// pi1_data_o
// pi1_sel_i
// pi1_rdy_o
// pi1_mapsz_o
// 	PerInt slave memory interface.
//
// intrqst_o
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised if enabled and the receive
// 	buffer usage interrupt threshold is reached.
//
// intrdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower intrqst_o and disable interrupt.
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

	,pi1_op_i
	,pi1_addr_i /* not used */
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i  /* not used */
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqst_o
	,intrdy_i

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

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i; /* not used */
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = 0;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;  /* not used */
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire intrqst_o;
input  wire intrdy_i;

input  wire rx_i;
output wire tx_o;

assign pi1_rdy_o = 1;

// Actual mapsz is 1, but aligning to 64bits.
assign pi1_mapsz_o = ((ARCHBITSZ<64)?(64/ARCHBITSZ):1);

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Note that (ARCHBITSZ-2) is the number of bits used by a command argument.
localparam CLOCKCYCLESPERBITLIMIT = (1<<(ARCHBITSZ-2));
localparam CLOG2CLOCKCYCLESPERBITLIMIT = (ARCHBITSZ-2);

reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] rxclockcyclesperbit = 0;
reg [CLOG2CLOCKCYCLESPERBITLIMIT -1 : 0] txclockcyclesperbit = 0;

wire            rx_empty_w;
wire            rx_pop_w = (pi1_op_i == PIRDOP && pi1_rdy_o && !rx_empty_w);
wire [8 -1 : 0] rx_data_w0;

wire            tx_full_w;
wire            tx_push_w = (pi1_op_i == PIWROP && pi1_rdy_o && !tx_full_w);
wire [8 -1 : 0] tx_data_w1 = pi1_data_i[8 -1 : 0];

wire [(CLOG2BUFSZ +1) -1 : 0] rx_usage_w;
wire [(CLOG2BUFSZ +1) -1 : 0] tx_usage_w;

reg [(ARCHBITSZ-2) -1 : 0] intrqstthresh = 0;

assign intrqst_o = (|intrqstthresh && (rx_usage_w >= intrqstthresh));

// Register used to detect a falling edge on "intrdy_i".
reg  intrdysampled = 0;
wire intrdynegedge = (!intrdy_i && intrdysampled);

localparam CMDGETBUFFERUSAGE = 0;
localparam CMDSETINTERRUPT   = 1;
localparam CMDSETSPEED       = 2;

always @ (posedge clk_i) begin
	// Logic enabling/disabling interrupt.
	if (rst_i) begin
		// On reset, interrupt is disabled, and must be explicitely enabled.
		// It prevents unwanted interrupt after reset.
		intrqstthresh <= 0;
	end else if (pi1_op_i == PIRWOP && pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT)
		intrqstthresh <= pi1_data_i[(ARCHBITSZ-2)-1:0];
	else if (intrdynegedge)
		intrqstthresh <= 0;

	if (rx_pop_w)
		pi1_data_o <= rx_data_w0;

	if (pi1_op_i == PIRWOP && pi1_rdy_o) begin
		if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETINTERRUPT)
			pi1_data_o <= BUFSZ;
		else if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDGETBUFFERUSAGE)
			pi1_data_o <= pi1_data_i[0] ? tx_usage_w : rx_usage_w;
		else if (pi1_data_i[(ARCHBITSZ-1):(ARCHBITSZ-2)] == CMDSETSPEED) begin
			// Normally the formula to use is:
			// ((PHYCLKFREQ/bitrate) + ((PHYCLKFREQ/bitrate)/10/2));
			// so this is an approximation.
			rxclockcyclesperbit <= (pi1_data_i[(ARCHBITSZ-2)-1:0] + (pi1_data_i[(ARCHBITSZ-2)-1:0] >> 5));
			txclockcyclesperbit <=  pi1_data_i[(ARCHBITSZ-2)-1:0];
			pi1_data_o <= PHYCLKFREQ;
		end
	end

	intrdysampled <= intrdy_i; // Sampling used for edge detection.
end

uart_rx #(

	 .BUFSZ                  (BUFSZ)
	,.CLOCKCYCLESPERBITLIMIT (CLOCKCYCLESPERBITLIMIT)

) uart_rx (

	 .rst_i (rst_i)

	,.clk_i     (clk_i)
	,.clk_phy_i (clk_phy_i)

	,.clockcyclesperbit_i (rxclockcyclesperbit)

	,.pop_i   (rx_pop_w)
	,.data_o  (rx_data_w0)
	,.empty_o (rx_empty_w)
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

	,.push_i  (tx_push_w)
	,.data_i  (tx_data_w1)
	,.full_o  (tx_full_w)
	,.usage_o (tx_usage_w)

	,.tx_o (tx_o)
);

endmodule
