// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Bootloader implementation for a block device.
// On reset, it drives the block device so that
// its first block get loaded.
// Once the block loading is complete, it lets
// the device connected on its master connections
// drive the block device.

// Parameters:
//
// BOOTBLOCK
// 	Index of the block to load.

// Ports:
//
// rst_i
// 	This input reset this module when
// 	held high and must be held low for
// 	normal operation.
//
// clk_i
// 	Clock signal.
//
// m_pi1_op_i
// m_pi1_addr_i
// m_pi1_data_i
// m_pi1_data_o
// m_pi1_sel_i
// m_pi1_rdy_o
// 	PerInt master memory interface.
//
// s_pi1_op_o
// s_pi1_addr_o
// s_pi1_data_o
// s_pi1_data_i
// s_pi1_sel_o
// s_pi1_rdy_i
// 	PerInt slave memory interface.

module bootldr (

	rst_i,

	clk_i,

	m_pi1_op_i,
	m_pi1_addr_i,
	m_pi1_data_i,
	m_pi1_data_o,
	m_pi1_sel_i,
	m_pi1_rdy_o,

	s_pi1_op_o,
	s_pi1_addr_o,
	s_pi1_data_o,
	s_pi1_data_i,
	s_pi1_sel_o,
	s_pi1_rdy_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

parameter BOOTBLOCK = 0;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

// Number of bits in an address.
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             m_pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     m_pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     m_pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     m_pi1_data_o; // ### declared as reg so as to be usable by verilog within the always block.
input  wire [(ARCHBITSZ/8) -1 : 0] m_pi1_sel_i;
output reg                         m_pi1_rdy_o;  // ### declared as reg so as to be usable by verilog within the always block.

output reg  [2 -1 : 0]             s_pi1_op_o;   // ### declared as reg so as to be usable by verilog within the always block.
output reg  [ADDRBITSZ -1 : 0]     s_pi1_addr_o; // ### declared as reg so as to be usable by verilog within the always block.
output reg  [ARCHBITSZ -1 : 0]     s_pi1_data_o; // ### declared as reg so as to be usable by verilog within the always block.
input  wire [ARCHBITSZ -1 : 0]     s_pi1_data_i;
output reg  [(ARCHBITSZ/8) -1 : 0] s_pi1_sel_o;  // ### declared as reg so as to be usable by verilog within the always block.
input  wire                        s_pi1_rdy_i;

// Constants used with the registers bootldrstate and nextbootldrstate;
// and which represent the states of the bootloading process.
localparam BOOTLDRSTATUS = 0; // Retrieve the device state.
localparam BOOTLDRRESET  = 1; // Reset the device.
localparam BOOTLDRREAD   = 2; // Read the boot data block from the device.
localparam BOOTLDRSWAP   = 3; // Swap the device cache to make the data readed accessible.
localparam BOOTLDRDONE   = 4; // Bootloading complete.

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

// Generic commands.
localparam CMDRESET = 0;
localparam CMDSWAP  = 1;
localparam CMDREAD  = 2;
localparam CMDWRITE = 3;

// Generic status.
localparam STATUSPOWEROFF = 0;
localparam STATUSREADY    = 1;
localparam STATUSBUSY     = 2;
localparam STATUSERROR    = 3;

// Registers used to hold respectively the current
// and next state of the bootloading process.
reg [3 -1 : 0] bootldrstate = BOOTLDRSTATUS;
reg [3 -1 : 0] nextbootldrstate = BOOTLDRRESET;

// Register value used to stay for an additional
// clock cycle in BOOTLDRSTATUS in order to use, in
// that same state, the result from the command issued.
reg s_pi1_data_irdy = 0;

// Register which get set to 1 once the bootloading is complete.
reg bootloadingdone = 0;

always @ (posedge clk_i) begin

	if (rst_i) begin
		// Reset logic.

		bootloadingdone <= 0;

		s_pi1_data_irdy <= 0;

		bootldrstate <= BOOTLDRSTATUS;
		nextbootldrstate <= BOOTLDRRESET;

	end else if (!bootloadingdone) begin
		// Bootloading logic.

		s_pi1_data_irdy <= (bootldrstate == BOOTLDRSTATUS);

		if (bootldrstate == BOOTLDRSTATUS) begin

			if (s_pi1_rdy_i && s_pi1_data_irdy && s_pi1_data_i == STATUSREADY)
				bootldrstate <= nextbootldrstate;

		end else if (bootldrstate == BOOTLDRRESET) begin

			if (s_pi1_rdy_i) begin
				bootldrstate <= BOOTLDRSTATUS;
				nextbootldrstate <= BOOTLDRREAD;
			end

		end else if (bootldrstate == BOOTLDRREAD) begin

			if (s_pi1_rdy_i) begin
				bootldrstate <= BOOTLDRSTATUS;
				nextbootldrstate <= BOOTLDRSWAP;
			end

		end else if (bootldrstate == BOOTLDRSWAP) begin

			if (s_pi1_rdy_i)
				bootldrstate <= BOOTLDRDONE;

		end else if (s_pi1_rdy_i)
			bootloadingdone <= 1;
	end
end

always @* begin

	if (bootloadingdone) begin
		// I get here when the bootloading is complete;
		// The master connections wires through to the slave connections.

		s_pi1_op_o = m_pi1_op_i;
		s_pi1_addr_o = m_pi1_addr_i;
		s_pi1_data_o = m_pi1_data_i;
		m_pi1_data_o = s_pi1_data_i;
		s_pi1_sel_o = m_pi1_sel_i;
		m_pi1_rdy_o = s_pi1_rdy_i;

	end else begin
		// Bootloading logic.

		m_pi1_data_o = 0;
		m_pi1_rdy_o = 0;

		if (bootldrstate == BOOTLDRSTATUS) begin

			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDRESET;
			s_pi1_data_o = 0;
			s_pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

		end else if (bootldrstate == BOOTLDRRESET) begin

			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDRESET;
			s_pi1_data_o = 1;
			s_pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

		end else if (bootldrstate == BOOTLDRREAD) begin

			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDREAD;
			s_pi1_data_o = BOOTBLOCK;
			s_pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

		end else if (bootldrstate == BOOTLDRSWAP) begin

			s_pi1_op_o = PIRWOP;
			s_pi1_addr_o = CMDSWAP;
			s_pi1_data_o = 0;
			s_pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

		end else begin

			s_pi1_op_o = PINOOP;
			s_pi1_addr_o = 0;
			s_pi1_data_o = 0;
			s_pi1_sel_o = 0;
		end
	end
end

endmodule
