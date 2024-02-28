// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// GPIO peripheral.

// The device provides IOs that can be configured as either input or output.
// The first half of the device memory mapping is used to read/write IOs state
// while, the second half is used to send commands to the device.
//
// Commands sent to the device expect following format
// | cmd: 1 bit | arg: (ARCHBITSZ-1) bits | where the field "cmd" values
// are CMDCONFIGUREIO(1'b0), CMDSETDEBOUNCE(1'b1). The result of a previously
// sent command is retrieved from the device reading from it and has
// the following format | cmd: 1 bit | resp: (ARCHBITSZ-1) bits |
// where the fields "cmd" and "resp" are the command and its result.
//
// The description of commands is as follow:
// CMDCONFIGUREIO: "arg" value is a bitmap where each bit 0/1 configures
// the corresponding GPIO as an input/output.
// "resp" in the result get set to the IO count.
// CMDSETDEBOUNCE: "arg" value set the clockcycle count used to debounce GPIs.
// "resp" in the result get set to the clock frequency in Hz used by the device.

// Parameters:
//
// CLKFREQ:
// 	Frequency of the clock input "clk_i" in Hz.
//
// IOCOUNT:
// 	Number of IOs.
// 	It must be non-null and less than ARCHBITSZ.

// Ports:
//
// rst_i
// 	This input reset this module when held high
// 	and must be held low for normal operation.
//
// clk_i
// 	Clock signal.
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

	 rst_i

	,clk_i

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

	,intrqst_o
	,intrdy_i

	,i ,o ,t
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;
parameter CLKFREQ   = 1;
parameter IOCOUNT   = 1;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

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

output wire intrqst_o;
input  wire intrdy_i;

input  wire [IOCOUNT -1 : 0] i;
output reg  [IOCOUNT -1 : 0] o;
// Registers which hold whether a corresponding input "i"
// is an input/output; for a value of 0, the corresponding
// input "i" is an input.
output reg  [IOCOUNT -1 : 0] t;

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

// Commands.
localparam CMDCONFIGUREIO = 0;
localparam CMDSETDEBOUNCE = 1;

reg [ARCHBITSZ -1 : 0] wb_dat_o_;

// Half the memory mapping is used to send/receive data,
// while the other half is used to issue commands.
localparam CLOG264BYARCHBITSZ = clog2(64/ARCHBITSZ);

wire iscmd = (!rst_i && wb_stb_r && wb_we_r && wb_addr_r[CLOG264BYARCHBITSZ]);

wire cmdconfigureio = (iscmd && wb_dat_r[ARCHBITSZ-1] == CMDCONFIGUREIO);
wire cmdsetdebounce = (iscmd && wb_dat_r[ARCHBITSZ-1] == CMDSETDEBOUNCE);

wire devrd = (!rst_i && wb_stb_r && !wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ]);
wire devwr = (!rst_i && wb_stb_r &&  wb_we_r && !wb_addr_r[CLOG264BYARCHBITSZ]);

// Nets set to the debounced value of the input "i".
wire [IOCOUNT -1 : 0] _i;

// Register set to the number of clock cycles used
// to debounce the input "i" when configured as input.
// It has the bitsize of a command argument.
reg [(ARCHBITSZ -1) -1 : 0] dbncrthresh;

genvar gen_dbncr_idx;
generate for (gen_dbncr_idx = 0; gen_dbncr_idx < IOCOUNT; gen_dbncr_idx = gen_dbncr_idx + 1) begin: gen_dbncr // gen_dbncr is just a label that verilog wants to see; and it is not used anywhere.
dbncr  #(
	// Bitsize of the command argument.
	 .THRESBITSZ (ARCHBITSZ -1)
	,.INIT       (1'b0)
) dbncr (
	 .rst_i    (rst_i)
	,.clk_i    (clk_i)
	,.i        (i[gen_dbncr_idx])
	,.o        (_i[gen_dbncr_idx])
	,.thresh_i (dbncrthresh)
);
end endgenerate

// Register used to detect a change on "_i".
reg [IOCOUNT -1 : 0] _i_r;

// Nets where each bit is 1 when a change occurred on the corresponding _i.
wire [IOCOUNT -1 : 0] i_changed = (_i ^ _i_r);

// Register for which each bit is 1 if its corresponding input "i" signal changed.
reg [IOCOUNT -1 : 0] i_change;

// An interrupt request is made if a state change
// occurs on an input "i" signal configured as input.
assign intrqst_o = (|i_change);

// Register used to detect a falling edge on "intrdy_i".
reg intrdy_i_r;
wire intrdy_i_negedge = (!intrdy_i && intrdy_i_r);

reg devrd_r;
assign wb_dat_o = (devrd_r ? _i : wb_dat_o_);

always @(posedge clk_i) begin
	// Logic that set output "t".
	if (rst_i)
		t <= 0;
	else if (cmdconfigureio)
		t <= wb_dat_r[ARCHBITSZ-2:0];

	if (rst_i)
		dbncrthresh <= 0;
	else if (cmdsetdebounce)
		dbncrthresh <= wb_dat_r[ARCHBITSZ-2:0];

	// Logic that set output "o".
	if (rst_i)
		o <= 0;
	else if (devwr)
		o <= wb_dat_r[ARCHBITSZ-2:0];

	// Logic that update i_change.
	if (intrdy_i_negedge)
		i_change <= 0;
	else
		i_change <= (i_change | i_changed);

	if (cmdconfigureio)
		wb_dat_o_ <= {wb_dat_r[ARCHBITSZ-1], IOCOUNT[ARCHBITSZ-2:0]};
	else if (cmdsetdebounce)
		wb_dat_o_ <= {wb_dat_r[ARCHBITSZ-1], CLKFREQ[ARCHBITSZ-2:0]};

	devrd_r <= devrd;

	// Sampling used to detect whether _i has changed.
	_i_r <= _i;

	// Sampling used for intrdy_i edge detection.
	intrdy_i_r <= intrdy_i;
end

endmodule
