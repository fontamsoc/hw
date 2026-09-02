// SPDX-License-Identifier: GPL-2.0-only
// 20260901 (c) William Fonkou Tambe

// Default device peripheral.

// The device is meant to be the last slave of the interconnect, which
// selects it for an access to an address that no other device maps;
// it acknowledges every access so that such an access cannot wedge the bus.
// Every access is a fault reported by raising an interrupt, except a read
// of the fault address register, which is the last 32bits word of the
// address space, ie: address ((uintptr_t)-4).
// The fault address register holds the address of the first fault since
// it was last read; it is the address as seen on the bus, ie: a byte
// address for which the bits beyond the address bus width are ored into
// its most significant bit, which gets sign extended, hence an address
// beyond the address bus reads negative, and the exact address is
// recoverable only when it fits the address bus or the same size window
// at the top of the address space; the value is replicated across the
// width of the data bus.
// Reading from any other address returns the instruction NOP (32'h00000013)
// so that fetching instructions from an unmapped address executes harmlessly
// until the interrupt gets serviced.
// The interrupt request is held until acknowledged; a fault occurring
// meanwhile is not recorded but keeps the request raised, hence another
// interrupt occurs when it happens in the same clockcycle as the acknowledgement.

// Parameters:
//
// WORDBITSZ
// 	Must be a power-of-2 and >= 32.
//
// ADDRLIMIT
// 	Address limit used by the interconnect, from which
// 	the address bus width is derived.

// Ports:
//
// rst_i
// 	This input resets this module when held high
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
// 	an interrupt is raised when an access is made to the device,
// 	unless it is a read of the fault address register.
//
// irq_rdy_i
// 	This signal becomes low when the interrupt request
// 	has been acknowledged, and is used by this module
// 	to lower irq_stb_o.

module dfltdev (

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
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
parameter ADDRLIMIT = 'h2000;

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

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

output reg  irq_stb_o;
input  wire irq_rdy_i;

assign wb_bsy_o = 1'b0;

always_ff @(posedge clk_i)
	wb_ack_o <= wb_stb_i;

// Read of the fault address register, ie: of the last word of the address space.
wire faultaddrrd = (wb_stb_i && !wb_we_i && (&wb_addr_i));

// Any other access is a fault.
wire fault = (wb_stb_i && !faultaddrrd);

// Register holding the address of the first fault since it was last read.
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] faultaddr;

// Register set when faultaddr holds a fault not yet read.
reg faultaddr_rdy;

// Register used to detect a falling edge on "irq_rdy_i".
reg  irq_rdy_i_r;
always_ff @(posedge clk_i)
	irq_rdy_i_r <= irq_rdy_i;
wire irq_rdy_i_negedge = (!irq_rdy_i && irq_rdy_i_r);

always_ff @(posedge clk_i) begin
	if (rst_i) begin
		irq_stb_o <= 1'b0;
		faultaddr_rdy <= 1'b0;
		faultaddr <= 0;
	end else begin
		if (irq_rdy_i_negedge)
			irq_stb_o <= 1'b0;
		if (fault) begin
			// A fault occurring in the same clockcycle as the acknowledgement wins.
			irq_stb_o <= 1'b1;
			if (!faultaddr_rdy) begin
				faultaddr <= wb_addr_i;
				faultaddr_rdy <= 1'b1;
			end
		end else if (faultaddrrd)
			faultaddr_rdy <= 1'b0;
	end
end

// Byte address of the fault as a 32bits value, sign extending
// the most significant bit which ors the bits beyond the address bus.
wire [31:0] faultaddr_w = {
	{(32-(ADDRBITSZ-MSBSZIGN)-CLOG2WORDBITSZBY8){faultaddr[(ADDRBITSZ-MSBSZIGN)-1]}},
	faultaddr, {CLOG2WORDBITSZBY8{1'b0}}};

always_ff @(posedge clk_i) begin
	if (wb_stb_i)
		wb_dat_o <= {(WORDBITSZ/32){faultaddrrd ? faultaddr_w : 32'h00000013 /* NOP */}};
end

endmodule
