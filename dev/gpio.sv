// SPDX-License-Identifier: GPL-2.0-only
// 20260420 (c) William Fonkou Tambe

// GPIO peripheral.

// The device provides IOs that can be configured as either input or output.
// The first word of the device memory mapping is used to read/write IOs state
// while the second word is used to send commands to the device.
//
// Commands sent to the device expect following format
// | arg: (WORDBITSZ-1) bits | cmd: 1 bit | where the field "cmd" values
// are CMDCONFIGUREIO(1'b0), CMDSETDEBOUNCE(1'b1). The result of a previously
// sent command is retrieved from the device reading from it and has
// the following format | resp: (WORDBITSZ-1) bits | cmd: 1 bit |
// where the fields "cmd" and "resp" are the command and its result.
//
// The description of commands is as follow:
// CMDCONFIGUREIO: "arg" value is a bitmap where each bit 0/1 configures
// the corresponding GPIO as an input/output.
// "resp" in the result gets set to the IO count.
// CMDSETDEBOUNCE: "arg" value set the clockcycle count used to debounce GPIs.
// "resp" in the result gets set to the clock frequency in Hz used by the device.

// Parameters:
//
// CLKFREQ:
// 	Frequency of the clock input "clk_i" in Hz.
//
// IOCOUNT:
// 	Number of IOs.
// 	It must be non-null and less than WORDBITSZ.
//
// IODIR:
// 	Bitfield of which inputs is initially an input/output.
//
// DBNCR_EN:
// 	Bitfield of which inputs to insert a debouncer.
//
// DBNCRBITSZ:
// 	Number of bits used by the value set by CMDSETDEBOUNCE.
// 	It must be non-null and less than WORDBITSZ.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
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
// 	This signal is set high to request an interrupt;
// 	an interrupt is raised when any of the input "i" state changes.
//
// irq_rdy_i
// 	This signal become low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower irq_stb_o.
//
// i, o, t
// 	GPIOs.

`include "lib/dbncr.sv"

module gpio (

	 rst_i

	,clk_i

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

	,i ,o ,t
);

`include "lib/clog2.sv"

parameter WORDBITSZ  = 32;
parameter CLKFREQ    = 1;
parameter IOCOUNT    = 1;
parameter IODIR      = 0;
parameter DBNCR_EN   = 0;
parameter DBNCRBITSZ = 8;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

localparam MAPSZ = (2*(WORDBITSZ/8));

localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            wb_dat_o;

output wire irq_stb_o;
input  wire irq_rdy_i;

input  wire [IOCOUNT -1 : 0] i;
output reg  [IOCOUNT -1 : 0] o;
// Registers which hold whether a corresponding input "i"
// is an input/output; for a value of 0, the corresponding
// input "i" is an input.
output reg  [IOCOUNT -1 : 0] t;

assign wb_bsy_o = 1'b0;

reg                               wb_stb_r;
reg                               wb_we_r;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_r;
reg [WORDBITSZ -1 : 0]            wb_dat_r;

always_ff @(posedge clk_i) begin
	wb_stb_r <= wb_stb_i;
	if (wb_stb_i) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

// Commands.
localparam CMDCONFIGUREIO = 0;
localparam CMDSETDEBOUNCE = 1;

// The first word is used to send/receive data,
// while the second word is used to issue commands.
localparam ISCMDBIT = 0;

wire iscmd = (wb_stb_r && wb_we_r && wb_addr_r[ISCMDBIT]);

wire cmdconfigureio = (iscmd && wb_dat_r[0] == CMDCONFIGUREIO);
wire cmdsetdebounce = (iscmd && wb_dat_r[0] == CMDSETDEBOUNCE);

wire devrd = (wb_stb_r && !wb_we_r && !wb_addr_r[ISCMDBIT]);
wire devwr = (wb_stb_r &&  wb_we_r && !wb_addr_r[ISCMDBIT]);

// Nets set to the debounced value of the input "i".
wire [IOCOUNT -1 : 0] _i;

// Register set to the number of clock cycles used to debounce the input "i".
reg [DBNCRBITSZ -1 : 0] dbncrthresh;

genvar gen_dbncr_idx;
generate for (
	gen_dbncr_idx = 0;
	gen_dbncr_idx < IOCOUNT;
	gen_dbncr_idx = gen_dbncr_idx + 1) begin: gen_dbncr
if (DBNCR_EN[gen_dbncr_idx]) begin :gen_dbncr_en
dbncr  #(
	 .THRESBITSZ (DBNCRBITSZ)
	,.INIT       (1'b0)
) dbncr (
	 .clk_i    (clk_i)
	,.i        (i[gen_dbncr_idx])
	,.o        (_i[gen_dbncr_idx])
	,.thresh_i (dbncrthresh)
);
end else begin
assign _i[gen_dbncr_idx] = i[gen_dbncr_idx];
end
end endgenerate

// Register used to detect a change on "_i".
reg [IOCOUNT -1 : 0] _i_r;

// Nets where each bit is 1 when a change occurred on the corresponding _i.
wire [IOCOUNT -1 : 0] i_changed = (_i ^ _i_r);

// Register for which each bit is 1 if its corresponding input "i" signal changed.
reg [IOCOUNT -1 : 0] i_change;

// An interrupt request is made if a state change occurs on an input "i" signal.
assign irq_stb_o = (|i_change);

// Register used to detect a falling edge on "irq_rdy_i".
reg irq_rdy_i_r;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

always_ff @(posedge clk_i) begin
	// Logic that set output "t".
	if (rst_i)
		t <= IODIR;
	else if (cmdconfigureio)
		t <= wb_dat_r[WORDBITSZ-1:1];
end

always_ff @(posedge clk_i) begin
	if (rst_i)
		dbncrthresh <= 0;
	else if (cmdsetdebounce)
		dbncrthresh <= wb_dat_r[WORDBITSZ-1:1];
end

always_ff @(posedge clk_i) begin
	// Logic that set output "o".
	if (rst_i)
		o <= 0;
	else if (devwr)
		o <= wb_dat_r[WORDBITSZ-1:1];
end

always_ff @(posedge clk_i) begin
	// Logic that update i_change.
	if (irq_rdy_i_negedge)
		i_change <= 0;
	else
		i_change <= (i_change | i_changed);
end

always_ff @(posedge clk_i) begin
	unique if (devrd)
		wb_dat_o <= _i;
	else if (cmdconfigureio)
		wb_dat_o <= {IOCOUNT[WORDBITSZ-2:0], wb_dat_r[0]};
	else if (cmdsetdebounce)
		wb_dat_o <= {CLKFREQ[WORDBITSZ-2:0], wb_dat_r[0]};
end

always_ff @(posedge clk_i) begin
	// Sampling used to detect whether _i has changed.
	_i_r <= _i;
	// Sampling used for irq_rdy_i edge detection.
	irq_rdy_i_r <= irq_rdy_i;
end

endmodule
