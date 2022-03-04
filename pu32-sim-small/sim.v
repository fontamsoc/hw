// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`define SIMULATION

`include "lib/perint/pi1r.v"

`define PUDSPMUL
`include "pu/multipu.v"

`include "dev/uart_sim.v"

`include "dev/smem.v"

module sim (
	 rst_i
	,clk_i
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;
input wire clk_i;

wire rst_w = rst_i;
wire clk_w = clk_i;

localparam M_PI1R_MULTIPU    = 0;
localparam S_PI1R_UART       = 0;
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_RAM + 1);

localparam PI1RMASTERCOUNT       = 1;
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = // Set such that memory starts at 0x1000.
	((('h1000/(ARCHBITSZ/8))/*4KB*/) - (2/*UART_MAPSZ*/));
localparam PI1RARCHBITSZ         = ARCHBITSZ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_w;
// PerInt is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerInt:
// 	input  [2 -1 : 0]             m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
// 	input  [ADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
// 	output [ARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
// 	input  [(ARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
// 	output                        m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];
// Slaves should use the following signals to plug onto PerInt:
// 	output [2 -1 : 0]             s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
// 	output [ADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
// 	output [ARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
// 	input  [ARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
// 	output [(ARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
// 	input                         s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
// 	input  [ADDRBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];
`include "lib/perint/inst.pi1r.v"

multipu #(

	 .ARCHBITSZ (ARCHBITSZ)

) multipu (

	 .rst_i (rst_w)

	,.clk_i        (clk_w)
	,.clk_mem_i    (pi1r_clk_w)

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_MULTIPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_MULTIPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_MULTIPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_MULTIPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_MULTIPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_MULTIPU])

	,.rstaddr_i (('h1000)>>1)
);

uart_sim #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.BUFSZ     (2)

) uart (

	 .rst_i (rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_UART])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_UART])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_UART])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_UART])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_UART])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_UART])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])
);

smem #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.SIZE      ((4/*KB*/)*(1024/(ARCHBITSZ/8)))
	,.DELAY     (0)
	,.SRCFILE   ("smem/smem.hex")

) smem (

	 .rst_i (rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_RAM])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_RAM])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_RAM])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_RAM])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_RAM])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_RAM])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_RAM])
);

// PI1RDEFAULTSLAVEINDEX to catch invalid physical address space access.
localparam INVALIDDEVMAPSZ = ('h1000/(ARCHBITSZ/8)) /* 4KB */;
//s_pi1r_op_w[S_PI1R_INVALIDDEV];
//s_pi1r_addr_w[S_PI1R_INVALIDDEV];
//s_pi1r_data_w0[S_PI1R_INVALIDDEV];
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {ARCHBITSZ{1'b0}};
//s_pi1r_sel_w[S_PI1R_INVALIDDEV];
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;

endmodule
