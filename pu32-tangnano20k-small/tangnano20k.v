// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/perint/pi1r.v"

`include "pu/cpu.v"

`include "dev/uart_hw.v"

`include "dev/smem.v"

module tangnano20k (

	 btn0

	,clk27

	// UART signals.
	,uart_rx
	,uart_tx
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire btn0;

input wire clk27;

// UART signals.
input  wire uart_rx;
output wire uart_tx;

wire rst_w = btn0;

localparam CLKFREQ = 27000000; // Frequency of clk_w.

wire clk_w = clk27;

localparam M_PI1R_CPU        = 0;
localparam M_PI1R_LAST       = M_PI1R_CPU;
localparam S_PI1R_UART       = 0;
localparam S_PI1R_RAM        = (S_PI1R_UART + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_RAM + 1);

localparam PI1RMASTERCOUNT       = (M_PI1R_LAST + 1);
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = // Set such that memory starts at 0x1000.
	('h1000 - (8/*UART_MAPSZ*/));
localparam PI1RARCHBITSZ         = ARCHBITSZ;
localparam CLOG2PI1RARCHBITSZBY8 = clog2(PI1RARCHBITSZ/8);
localparam PI1RADDRBITSZ         = (PI1RARCHBITSZ-CLOG2PI1RARCHBITSZBY8);
localparam PI1RCLKFREQ           = CLKFREQ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_w;
// PerInt is instantiated in a separate file to keep this file clean.
// Masters should use the following signals to plug onto PerInt:
// 	input  [2 -1 : 0]                 m_pi1r_op_w    [PI1RMASTERCOUNT -1 : 0];
// 	input  [PI1RADDRBITSZ -1 : 0]     m_pi1r_addr_w  [PI1RMASTERCOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w1 [PI1RMASTERCOUNT -1 : 0];
// 	output [PI1RARCHBITSZ -1 : 0]     m_pi1r_data_w0 [PI1RMASTERCOUNT -1 : 0];
// 	input  [(PI1RARCHBITSZ/8) -1 : 0] m_pi1r_sel_w   [PI1RMASTERCOUNT -1 : 0];
// 	output                            m_pi1r_rdy_w   [PI1RMASTERCOUNT -1 : 0];
// Slaves should use the following signals to plug onto PerInt:
// 	output [2 -1 : 0]                 s_pi1r_op_w    [PI1RSLAVECOUNT -1 : 0];
// 	output [PI1RADDRBITSZ -1 : 0]     s_pi1r_addr_w  [PI1RSLAVECOUNT -1 : 0];
// 	output [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w0 [PI1RSLAVECOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     s_pi1r_data_w1 [PI1RSLAVECOUNT -1 : 0];
// 	output [(PI1RARCHBITSZ/8) -1 : 0] s_pi1r_sel_w   [PI1RSLAVECOUNT -1 : 0];
// 	input                             s_pi1r_rdy_w   [PI1RSLAVECOUNT -1 : 0];
// 	input  [PI1RARCHBITSZ -1 : 0]     s_pi1r_mapsz_w [PI1RSLAVECOUNT -1 : 0];
`include "lib/perint/inst.pi1r.v"

cpu #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.XARCHBITSZ (PI1RARCHBITSZ)
	,.CLKFREQ    (PI1RCLKFREQ)

) cpu (

	 .rst_i (rst_w)

	,.clk_i (pi1r_clk_w)

	,.pi1_op_o   (m_pi1r_op_w[M_PI1R_CPU])
	,.pi1_addr_o (m_pi1r_addr_w[M_PI1R_CPU])
	,.pi1_data_o (m_pi1r_data_w1[M_PI1R_CPU])
	,.pi1_data_i (m_pi1r_data_w0[M_PI1R_CPU])
	,.pi1_sel_o  (m_pi1r_sel_w[M_PI1R_CPU])
	,.pi1_rdy_i  (m_pi1r_rdy_w[M_PI1R_CPU])

	,.rstaddr_i (('h1000)>>1)
);

uart_hw #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ)
	,.BUFSZ      (2048)

) uart (

	 .rst_i (rst_w)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (pi1r_clk_w)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_UART])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_UART])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_UART])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_UART])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_UART])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_UART])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_UART])

	,.rx_i (uart_rx)
	,.tx_o (uart_tx)
);

smem #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.SIZE      ((4/*KB*/)*(1024/(ARCHBITSZ/8)))
	,.DELAY     (0)
	,.SRCFILE   ("smem.hex")

) smem (

	 .rst_i (pi1r_rst_w)

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
localparam INVALIDDEVMAPSZ = ('h1000/* 4KB */);
//s_pi1r_op_w[S_PI1R_INVALIDDEV];
//s_pi1r_addr_w[S_PI1R_INVALIDDEV];
//s_pi1r_data_w0[S_PI1R_INVALIDDEV];
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {PI1RARCHBITSZ{1'b0}};
//s_pi1r_sel_w[S_PI1R_INVALIDDEV];
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;

endmodule
