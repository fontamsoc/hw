// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// GPIO peripheral.

// The device provides IOs that can be configured as either input or output.
// The memory operation PIRDOP returns a value which is a snapshot of the IOs state.
// Each bit in the value returned correspond to a signal within the inout [IOCOUNT] io;
// the corresponding bits of the IOs that were configured as output are always 0.
// The memory operation PIWROP write a value that set IOs configured as output;
// each bit in the value written corresponds to a signal within the inout [IOCOUNT] io.
// The memory operation PIRWOP send commands, where the value to write encodes both
// the command and its argument as follow: |cmd: 1bits|arg: (ARCHBITSZ-1)bits|
// while the value read is the return value of the command.

// Description of commands:
//
// CMDCONFIGUREIO:
// 	Cmd value is 0.
// 	Arg value is a bitmap where each bit 0/1 configures
// 	the corresponding input "i" as an input/output.
// 	Signals of input "i" that are configured as output read low.
// 	Return value is the IO count.
// CMDSETDEBOUNCE:
// 	Cmd value is 1.
// 	Arg value set the clockcycle count used to debounce inputs.
// 	Return value is the clock frequency in Hz used by the device.

// Parameters:
//
// CLKFREQ:
// 	Frequency of the clock input "clk_i" in Hz.
//
// IOCOUNT:
// 	Number of IOs.
// 	It must be non-null and <= ARCHBITSZ.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
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
// 	an interrupt is raised when any of the input "i" state changes.
//
// intrdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower intrqst_o.
//
// i, o, t
// 	GPIOs.

`include "lib/dbncr.v"

module gpio (

	rst_i,

	clk_i,

	pi1_op_i,
	pi1_addr_i, /* not used */
	pi1_data_i,
	pi1_data_o,
	pi1_sel_i, /* not used */
	pi1_rdy_o,
	pi1_mapsz_o,

	intrqst_o,
	intrdy_i,

	i, o, t
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;
parameter CLKFREQ   = 0;
parameter IOCOUNT   = 0;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i; /* not used */
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i; /* not used */
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire intrqst_o;
input  wire intrdy_i;

input  wire [IOCOUNT -1 : 0] i;
output reg  [IOCOUNT -1 : 0] o;
// Registers which hold whether a corresponding input "i"
// is an input/output; for a value of 0, the corresponding
// input "i" is an input.
output reg  [IOCOUNT -1 : 0] t;

assign pi1_rdy_o = 1;

// Actual mapsz is 1, but aligning to 64bits.
assign pi1_mapsz_o = ((ARCHBITSZ<64)?(64/ARCHBITSZ):1);

// Nets set to the debounced value of the input "i".
wire [IOCOUNT -1 : 0] _i;

// Register set to the number of clock cycles used
// to debounce the input "i" when configured as input.
// It has the bitsize of a command argument.
reg [(ARCHBITSZ -1) -1 : 0] debounce;

genvar genlowpass_idx;
generate for (genlowpass_idx = 0; genlowpass_idx < IOCOUNT; genlowpass_idx = genlowpass_idx + 1) begin: genlowpass // genlowpass is just a label that verilog want to see; and it is not used anywhere.
dbncr  #(
	// Bitsize of the command argument.
	 .THRESBITSZ (ARCHBITSZ -1)
	,.INIT       (1'b0)
) dbncr (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.i        (i[genlowpass_idx])
	,.o        (_i[genlowpass_idx])
	,.thresh_i (debounce)
);
end endgenerate

// Net set to the input value.
// Signals of input "i" that are configured as output read low.
wire [IOCOUNT -1 : 0] ival = (_i & ~t);

// Register used to detect a change on "ival".
reg [IOCOUNT -1 : 0] ivalsampled;

// Nets where each bit is 1 when a change occurred on the corresponding ival.
wire [IOCOUNT -1 : 0] ivalchanged = (ival ^ ivalsampled);

// Register for which each bit is 1 if its corresponding input "i" signal changed.
reg [IOCOUNT -1 : 0] ivalchange;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Commands.
localparam CMDCONFIGUREIO = 0;
localparam CMDSETDEBOUNCE = 1;

// An interrupt request is made if a state change
// occurs on an input "i" signal configured as input.
assign intrqst_o = |ivalchange;

// Register used to detect a falling edge on "intrdy_i".
reg intrdy_i_sampled;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_sampled);

always @(posedge clk_i) begin
	// Logic that set output "t".
	if (rst_i)
		t <= 0;
	else if (pi1_op_i == PIRWOP && pi1_data_i[ARCHBITSZ-1] == CMDCONFIGUREIO)
		t <= pi1_data_i[ARCHBITSZ-2:0];

	// Logic that set output "o".
	if (rst_i)
		o <= 0;
	else if (pi1_op_i == PIWROP)
		o <= pi1_data_i[ARCHBITSZ-2:0];

	// Logic that update ivalchange.
	if (intrdy_i_negedge)
		ivalchange <= 0;
	else
		ivalchange <= (ivalchange | ivalchanged);

	// Logic that set debounce.
	if (pi1_op_i == PIRWOP && pi1_data_i[ARCHBITSZ-1] == CMDSETDEBOUNCE)
		debounce <= pi1_data_i[ARCHBITSZ-2:0];

	// Logic that set pi1_data_o.
	if (pi1_op_i == PIRDOP) begin
		pi1_data_o <= ival;
	end else if (pi1_op_i == PIRWOP) begin
		if (pi1_data_i[ARCHBITSZ-1] == CMDCONFIGUREIO)
			pi1_data_o <= IOCOUNT;
		else if (pi1_data_i[ARCHBITSZ-1] == CMDSETDEBOUNCE)
			pi1_data_o <= CLKFREQ;
	end

	// Sampling used to detect whether ival has changed.
	ivalsampled <= ival;

	// Sampling used for intrdy_i edge detection.
	intrdy_i_sampled <= intrdy_i;
end

endmodule
