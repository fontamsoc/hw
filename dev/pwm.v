// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// PWM/PDM peripheral.

// The device provides PWM/PDM IOs which can be configured as either input or output.
// Each IO can be configured as an output which synthesizes Pulse-Width-Modulated
// or Pulse-Density-Modulated signal.
// Each IO has a dedicated buffer used to store pulse-density values synthesized
// on its output, or measured from its input.
// Each IO has a dedicated PWM/PDM period as well as a delay used between
// the transfer of a pulse-density value from/to the buffer to/from the IO.

// All PIWROP, PIRDOP and PIRWOP are to be ARCHBITSZ bits operations,
// otherwise undefined behavior will be the result.

// PIRDOP returns a pulsedensity value from the indexed input buffer.
// Garbage is returned if the IO is not configured as input.

// PIWROP writes to the indexed output buffer, a PWM/PDM pulsedensity
// in clockcycles, to be synthesized on the IO when configured as output.
// Only the (ARCHBITSZ-2) lsb of the value written are used.
// Writing silently fails when the IO is configured as input.

// PIRWOP sends commands, where the value written encodes both
// the command and its argument as follow: |cmd: 2bits|arg: (ARCHBITSZ-2)bits|
// while the value read is the return value of the command.

// Description of commands:
//
// CMDCONFIGUREIO:
// 	Cmd value is 0.
// 	Arg value encode whether it is to be an input or a PWM/PDM output:
// 	Arg[0] when 0 means that the IO is an input, and when 1 means that it is an output.
// 	Arg[1] when 0 means that the IO will be pulse-width-modulated, and when 1 means
// 	that the IO will be pulse-density-modulated; config applies only when IO is an output.
// 	The IO pulsedensity buffer gets reset empty if Arg[0] is modifying the IO direction.
// 	Return value is the IO count.
// CMDGETBUFFERSIZE:
// 	Cmd value is 1.
// 	Arg value is meaningless.
// 	Return value is the IO buffer size.
// CMDGETBUFFERUSAGE:
// 	Cmd value is 2.
// 	Arg value is meaningless.
// 	Return value is the IO buffer usage.
// CMDSETPERIOD:
// 	Cmd value is 3.
// 	Arg value is the clockcycles count of the PWM/PDM period,
// 	as well as the clockcycles delay between the transfer of a pulsedensity
// 	value from/to the buffer to/from the IO.
// 	Return value is the clock frequency in Hz used by the device.

// On reset, all IOs are inputs.

// Interrupt is not implemented and is not needed
// because buffers fill/empty themselves at a known rate.

// Reading data when the buffer is empty return what was its last entry
// before it became empty; writing data when the buffer is full silently fail.

// When a buffer for an IO configured as output become empty,
// the pulsedensity value that was last in the buffer remains on the output.

// Parameters:
//
// CLKFREQ:
// 	Frequency of the clock input "clk_i" in Hz.
//
// IOCOUNT:
// 	Number of IOs.
// 	It must be non-null.
//
// BUFFERSIZE:
// 	Maximum count of pulsedensity values that can be buffered.
// 	It must be at least 2 and a power of 2.

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
// i, o, t
// 	PWM/PDM IOs.

`include "lib/fifo.v"

`include "lib/perint/pi1b.v"

module pwm (

	rst_i,

	clk_i,

	pi1_op_i,
	pi1_addr_i,
	pi1_data_i,
	pi1_data_o,
	pi1_sel_i, /* not used */
	pi1_rdy_o,
	pi1_mapsz_o,

	i, o, t
);

`include "lib/clog2.v"

parameter ARCHBITSZ  = 16;
parameter CLKFREQ    = 0;
parameter IOCOUNT    = 0;
parameter BUFFERSIZE = 0;

localparam CLOG2IOCOUNT    = clog2(IOCOUNT);
localparam CLOG2BUFFERSIZE = clog2(BUFFERSIZE);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i; /* not used */
output wire                        pi1_rdy_o;
output wire [ARCHBITSZ -1 : 0]     pi1_mapsz_o;

input  wire [IOCOUNT -1 : 0] i;
output wire [IOCOUNT -1 : 0] o;
// Registers which hold whether a corresponding input "i"
// is an input/output; for a value of 0, the corresponding
// input "i" is an input.
output reg  [IOCOUNT -1 : 0] t;

assign pi1_mapsz_o = ((IOCOUNT+(((IOCOUNT*ARCHBITSZ)%64)/ARCHBITSZ)/* align to 64bits */)*(ARCHBITSZ/8));

wire [2 -1 : 0]             pi1b_op_i;
wire [ADDRBITSZ -1 : 0]     pi1b_addr_i;
reg  [ARCHBITSZ -1 : 0]     pi1b_data_o;
wire [ARCHBITSZ -1 : 0]     pi1b_data_i;
wire [(ARCHBITSZ/8) -1 : 0] pi1b_sel_i;
wire                        pi1b_rdy_o;

pi1b #(

	.ARCHBITSZ (ARCHBITSZ)

) pi1b (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_op_i (pi1_op_i)
	,.m_addr_i (pi1_addr_i)
	,.m_data_i (pi1_data_i)
	,.m_data_o (pi1_data_o)
	,.m_sel_i (pi1_sel_i)
	,.m_rdy_o (pi1_rdy_o)

	,.s_op_o (pi1b_op_i)
	,.s_addr_o (pi1b_addr_i)
	,.s_data_o (pi1b_data_i)
	,.s_data_i (pi1b_data_o)
	,.s_sel_o (pi1b_sel_i)
	,.s_rdy_i (pi1b_rdy_o)
);

// Registers which hold whether a corresponding IO is
// to be pulse-width-modulated or pulse-density-modulated
// when configured as output.
`ifdef PWM_PDM_SUPPORT
reg [IOCOUNT -1 : 0] ioflag;
`endif

// Registers used to implement pulse-width-modulation
// or pulse-density-modulation on each output "o".
// They each have the bitsize from the (ARCHBITSZ-2) lsb of a command.
reg [(ARCHBITSZ-2) -1 : 0] ocounter [IOCOUNT -1 : 0]; // Current count within the PWM/PDM period.
reg [(ARCHBITSZ-2) -1 : 0] operiod  [IOCOUNT -1 : 0]; // PWM/PDM period.

// Value retrieved from the pulsedensity fifo.
wire [(ARCHBITSZ-2) -1 : 0] pdfifodato [IOCOUNT -1 : 0];

// Accumulator used for measuring/synthesizing PWM/PDM signals.
// It has the bitsize from the (ARCHBITSZ-2) lsb of a command,
// plus one more bit in order to correctly compute signed values.
reg [((ARCHBITSZ-2)+1) -1 : 0] accumulator [IOCOUNT -1 : 0];

genvar geno_idx;
// Logic generating output "o".
generate for (geno_idx = 0; geno_idx < IOCOUNT; geno_idx = geno_idx + 1) begin: genio // genio is just a label that verilog want to see; and it is not used anywhere.
// pdfifodato[geno_idx] is updated with a new pulsedensity only when ocounter is being set to 0, preventing glitches.
assign o[geno_idx] = t[geno_idx] ? (
	`ifdef PWM_PDM_SUPPORT
	ioflag[geno_idx] ? ($signed(accumulator[geno_idx]) > $signed(pdfifodato[geno_idx])) :
	`endif
	                   (ocounter[geno_idx] < pdfifodato[geno_idx])
	) : 1'b0;
end endgenerate

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Commands.
localparam CMDCONFIGUREIO    = 0;
localparam CMDGETBUFFERSIZE  = 1;
localparam CMDGETBUFFERUSAGE = 2;
localparam CMDSETPERIOD      = 3;

// Corresponding bit set to 1 when the end of
// the associated PWM period has been reached.
wire [IOCOUNT -1 : 0] operiodreached;

genvar gen_operiodreached_idx;
generate for (gen_operiodreached_idx = 0; gen_operiodreached_idx < IOCOUNT; gen_operiodreached_idx = gen_operiodreached_idx + 1) begin: gen_operiodreached // gen_operiodreached is just a label that verilog want to see; and it is not used anywhere.
assign operiodreached[gen_operiodreached_idx] = (ocounter[gen_operiodreached_idx] >= operiod[gen_operiodreached_idx]);
end endgenerate

// Registers set to 1 when a single data was read
// from the corresponding pdfifo; they are set back to 0
// when that single data is used by PIRDOP.
reg [IOCOUNT -1 : 0] pdfifowasread;

wire [(CLOG2BUFFERSIZE+1) -1 : 0] pdfifousage [IOCOUNT -1 : 0];

wire [IOCOUNT -1 : 0] pdfiforeaden;

genvar gen_pdfifo_idx;
generate for (gen_pdfifo_idx = 0; gen_pdfifo_idx < IOCOUNT; gen_pdfifo_idx = gen_pdfifo_idx + 1) begin: gen_pdfifo // gen_pdfifo is just a label that verilog want to see; and it is not used anywhere.

assign pdfiforeaden[gen_pdfifo_idx] = (t[gen_pdfifo_idx] ? operiodreached[gen_pdfifo_idx] : (!pdfifowasread[gen_pdfifo_idx] && pdfifousage[gen_pdfifo_idx]));

// fifo for each IO to buffer pulsedensity values.
// Each buffer element has the bitsize from the (ARCHBITSZ-2) lsb
// of the command argument.
fifo #(
	 .WIDTH ((ARCHBITSZ-2))
	,.DEPTH (BUFFERSIZE)

) pdfifo (

	 .rst_i (rst_i || (
		pi1b_op_i == PIRWOP &&
		pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDCONFIGUREIO &&
		pi1b_addr_i == gen_pdfifo_idx &&
		t[gen_pdfifo_idx] != pi1b_data_i[0]))

	,.usage_o (pdfifousage[gen_pdfifo_idx])

	,.clk_read_i (clk_i)
	,.read_i     (pdfiforeaden[gen_pdfifo_idx])
	,.data_o     (pdfifodato[gen_pdfifo_idx])

	,.clk_write_i (clk_i)
	,.write_i     (t[gen_pdfifo_idx] ? (pi1b_op_i == PIWROP && pi1b_addr_i == gen_pdfifo_idx) : operiodreached[gen_pdfifo_idx])
	,.data_i      (t[gen_pdfifo_idx] ? pi1b_data_i[ARCHBITSZ-3:0] : (accumulator[gen_pdfifo_idx] + i[gen_pdfifo_idx]))
);
end endgenerate

assign pi1b_rdy_o = (!pdfiforeaden[pi1b_addr_i] || t[pi1b_addr_i]);

integer gen_ocounter_idx;
integer gen_pdfifowasread_idx;
integer gen_accumulator_idx;

always @(posedge clk_i) begin
	// Logic that set ioflag, t.
	if (rst_i) begin
		`ifdef PWM_PDM_SUPPORT
		ioflag <= {IOCOUNT{1'b0}};
		`endif
		t <= {IOCOUNT{1'b0}};
	end else if (pi1b_op_i == PIRWOP && pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDCONFIGUREIO) begin
		t[pi1b_addr_i] <= pi1b_data_i[0];
		`ifdef PWM_PDM_SUPPORT
		ioflag[pi1b_addr_i] <= pi1b_data_i[1];
		`endif
	end

	// Logic that set operiod.
	if (pi1b_op_i == PIRWOP && pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDSETPERIOD)
		operiod[pi1b_addr_i] <= pi1b_data_i[ARCHBITSZ-3:0];

	// Logic that set pi1b_data_o.
	if (pi1b_op_i == PIRDOP) begin
		pi1b_data_o <= pdfifodato[pi1b_addr_i];
	end else if (pi1b_op_i == PIRWOP) begin
		if (pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDCONFIGUREIO)
			pi1b_data_o <= IOCOUNT;
		else if (pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDGETBUFFERSIZE)
			pi1b_data_o <= BUFFERSIZE;
		else if (pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDGETBUFFERUSAGE)
			pi1b_data_o <= pdfifousage[pi1b_addr_i];
		else if (pi1b_data_i[ARCHBITSZ-1:ARCHBITSZ-2] == CMDSETPERIOD)
			pi1b_data_o <= CLKFREQ;
		else
			pi1b_data_o <= 0;
	end

	// Logic that update ocounter.
	for (gen_ocounter_idx = 0; gen_ocounter_idx < IOCOUNT; gen_ocounter_idx = gen_ocounter_idx + 1) begin: gen_ocounter // gen_ocounter is just a label that verilog want to see; and it is not used anywhere.
		if (operiodreached[gen_ocounter_idx])
			ocounter[gen_ocounter_idx] <= 0;
		else
			ocounter[gen_ocounter_idx] <= (ocounter[gen_ocounter_idx] + 1'b1);
	end

	// Logic that update pdfifowasread.
	for (gen_pdfifowasread_idx = 0; gen_pdfifowasread_idx < IOCOUNT; gen_pdfifowasread_idx = gen_pdfifowasread_idx + 1) begin: gen_pdfifowasread // gen_pdfifowasread is just a label that verilog want to see; and it is not used anywhere.
		if (pdfiforeaden[gen_pdfifowasread_idx])
			pdfifowasread[gen_pdfifowasread_idx] <= 1;
		else if (pi1b_op_i == PIRDOP && pi1b_addr_i == gen_pdfifowasread_idx)
			pdfifowasread[gen_pdfifowasread_idx] <= 0;
	end

	// Logic that update accumulator.
	for (gen_accumulator_idx = 0; gen_accumulator_idx < IOCOUNT; gen_accumulator_idx = gen_accumulator_idx + 1) begin: gen_accumulator // gen_accumulator is just a label that verilog want to see; and it is not used anywhere.
		if (rst_i)
			accumulator[gen_accumulator_idx] <= 0;
		else if (operiodreached[gen_accumulator_idx])
			accumulator[gen_accumulator_idx] <= 0;
		`ifdef PWM_PDM_SUPPORT
		else if (t[gen_accumulator_idx] && ioflag[gen_accumulator_idx])
			accumulator[gen_accumulator_idx] <= (
				accumulator[gen_accumulator_idx] + (
					{1'b0, pdfifodato[gen_accumulator_idx]} + (
						 o[gen_accumulator_idx] ? -operiod[gen_accumulator_idx] : {(ARCHBITSZ-2){1'b0}}))); // Accumulation for sythesizing PDM (Pulse-Density-Modulation).
		`endif
		else
			accumulator[gen_accumulator_idx] <= (accumulator[gen_accumulator_idx] + i[gen_accumulator_idx]); // Accumulation for measuring pulsedensity.
	end
end

endmodule
