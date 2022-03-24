// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// This directive prevent verilog from
// automatically declaring undefined net.
// The correct and sane behavior is to throw
// an error when an undefined net is used.
`default_nettype none

`include "lib/perint/pi1r.v"

`define PUDSPMUL
`include "pu/multipu.v"

`include "dev/usb_serial.v"

`include "dev/smem.v"

module orangecrab0285 (

	 usr_btn_n

	,clk48mhz_i

	// USB signals.
	,usb_d_p
	,usb_d_n
	,usb_pullup

	// LED signals.
	,led_red_n
	,led_green_n
	,led_blue_n
);

`include "lib/clog2.v"

localparam ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire usr_btn_n;

input wire clk48mhz_i;

// USB signals.
inout  wire usb_d_p;
inout  wire usb_d_n;
output wire usb_pullup;
assign usb_pullup = 1'b1;

// LED signals.
output wire led_red_n;
output wire led_green_n;
output wire led_blue_n;
assign led_red_n = 1'b1;
assign led_green_n = 1'b1;
assign led_blue_n = 1'b1;

wire rst_w = !usr_btn_n;

localparam CLKFREQ12MHZ = 12000000;
localparam CLKFREQ24MHZ = 24000000;
localparam CLKFREQ48MHZ = 48000000;
localparam CLKFREQ96MHZ = 96000000;

localparam CLKFREQ   = CLKFREQ12MHZ; // Frequency of clk_w.
localparam CLK2XFREQ = CLKFREQ24MHZ; // Frequency of clk_2x_w.
localparam CLK4XFREQ = CLKFREQ48MHZ; // Frequency of clk_4x_w.
localparam CLK8XFREQ = CLKFREQ96MHZ; // Frequency of clk_8x_w.

wire [3:0] pll_clk_w;
wire       pll_locked;
ecp5pll #(

	 .in_hz    (CLKFREQ48MHZ)
	,.out0_hz  (CLKFREQ)
	,.out1_hz  (CLK2XFREQ)
	,.out2_hz  (CLK4XFREQ)
	,.out3_hz  (CLK8XFREQ)

) pll (

	 .clk_i        (clk48mhz_i)
	,.clk_o        (pll_clk_w)
	,.reset        (1'b0)
	,.standby      (1'b0)
	,.phasesel     (2'b0)
	,.phasedir     (1'b0)
	,.phasestep    (1'b0)
	,.phaseloadreg (1'b0)
	,.locked       (pll_locked)
);
wire clk12mhz = pll_clk_w[0];
wire clk24mhz = pll_clk_w[1];
wire clk48mhz = pll_clk_w[2];
wire clk96mhz = pll_clk_w[3];

wire clk_w    = clk12mhz;
wire clk_2x_w = clk24mhz;
wire clk_4x_w = clk48mhz;
wire clk_8x_w = clk96mhz;

localparam M_PI1R_MULTIPU    = 0;
localparam M_PI1R_LAST       = M_PI1R_MULTIPU;
localparam S_PI1R_SERIAL     = 0;
localparam S_PI1R_RAM        = (S_PI1R_SERIAL + 1);
localparam S_PI1R_INVALIDDEV = (S_PI1R_RAM + 1);

localparam PI1RMASTERCOUNT       = (M_PI1R_LAST + 1);
localparam PI1RSLAVECOUNT        = (S_PI1R_INVALIDDEV + 1);
localparam PI1RDEFAULTSLAVEINDEX = S_PI1R_INVALIDDEV;
localparam PI1RFIRSTSLAVEADDR    = // Set such that memory starts at 0x1000.
	((('h1000/(ARCHBITSZ/8))/*4KB*/) - (2/*UART_MAPSZ*/));
localparam PI1RARCHBITSZ         = ARCHBITSZ;
localparam PI1RCLKFREQ           = CLK4XFREQ;
wire pi1r_rst_w = rst_w;
wire pi1r_clk_w = clk_4x_w;
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
	,.CLKFREQ   (PI1RCLKFREQ)

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

usb_serial #(

	 .ARCHBITSZ  (ARCHBITSZ)
	,.PHYCLKFREQ (CLKFREQ48MHZ) // Must be 48MHz or 60MHz.
	,.BUFSZ      (4096)

) serial (

	 .rst_i (!pll_locked
		/* pi1r_rst_w is not used such that on software reset,
		   all buffered data get a chance to be transmitted */)

	,.clk_i     (pi1r_clk_w)
	,.clk_phy_i (clk48mhz)

	,.pi1_op_i    (s_pi1r_op_w[S_PI1R_SERIAL])
	,.pi1_addr_i  (s_pi1r_addr_w[S_PI1R_SERIAL])
	,.pi1_data_i  (s_pi1r_data_w0[S_PI1R_SERIAL])
	,.pi1_data_o  (s_pi1r_data_w1[S_PI1R_SERIAL])
	,.pi1_sel_i   (s_pi1r_sel_w[S_PI1R_SERIAL])
	,.pi1_rdy_o   (s_pi1r_rdy_w[S_PI1R_SERIAL])
	,.pi1_mapsz_o (s_pi1r_mapsz_w[S_PI1R_SERIAL])

	,.usb_dp_io (usb_d_p)
	,.usb_dn_io (usb_d_n)
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
localparam INVALIDDEVMAPSZ = ('h1000/(ARCHBITSZ/8)) /* 4KB */;
//s_pi1r_op_w[S_PI1R_INVALIDDEV];
//s_pi1r_addr_w[S_PI1R_INVALIDDEV];
//s_pi1r_data_w0[S_PI1R_INVALIDDEV];
assign s_pi1r_data_w1[S_PI1R_INVALIDDEV] = {ARCHBITSZ{1'b0}};
//s_pi1r_sel_w[S_PI1R_INVALIDDEV];
assign s_pi1r_rdy_w[S_PI1R_INVALIDDEV]   = 1'b1;
assign s_pi1r_mapsz_w[S_PI1R_INVALIDDEV] = INVALIDDEVMAPSZ;

endmodule
