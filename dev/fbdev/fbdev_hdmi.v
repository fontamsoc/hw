// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// FrameBuffer peripheral.

// Memory operation PIRDOP returns meaningless data.
// Memory operation PIWROP writes XBGR8888 pixel values,
//   where X is used to compute pixel repeat count using ((X+2)&8'hFF).
//   X must not be 8'hFE which for now is reserved.
// Memory operation PIRWOP sends commands, where the value to write encodes both
//   the command and its argument as follow: |arg: (ARCHBITSZ-2)bits|cmd: 2bits|
//   while the value read is the return value of the command.

// Description of commands:
//
// CMDSRCSET:
//   Cmd value is 0.
//   Arg[(ARCHBITSZ-2)-1:0] set offset within pixel-memory-map if used,
//     or set 32bits aligned address of pixel datas if direct-memory-access used;
//     turn off video when -1.
//   Return value is the pixel-data address alignment, or
//   null when a pixel-memory-map is being used instead.
// CMDGETINFO:
//   Cmd value is 1.
//   Arg value can be 0 (screen-width), 1 (screen-height), 2 (refresh-rate), 3 (frame-count).
//   Return value of corresponding Arg.

`include "./pll_100_to_25_125_mhz.v"
`include "./pll_100_to_50_250_mhz.v"
`include "./pll_100_to_74_371_mhz.v"
`include "./dvi_hdmi_fbdev.v"
`include "./fbdev.v"

module fbdev_hdmi (

	 rst_i

	,pi1_clk_i
	,clk100mhz_i

	,m_pi1_op_o
	,m_pi1_addr_o
	,m_pi1_data_i
	,m_pi1_data_o
	,m_pi1_sel_o
	,m_pi1_rdy_i

	,s_pi1_op_i
	,s_pi1_addr_i
	,s_pi1_data_i
	,s_pi1_data_o
	,s_pi1_sel_i
	,s_pi1_rdy_o
	,s_pi1_mapsz_o

	,pxdat_first_addr_o
	,pxdat_last_addr_o

	,tmds_out_p
	,tmds_out_n
);

`include "lib/clog2.v"

parameter ARCHBITSZ  = 32;
parameter XARCHBITSZ = 32;

parameter WIDTH   = 800;
parameter HEIGHT  = 600;
parameter REFRESH = 72;
parameter BUFSZ   = 1024;

parameter FORCE_PINOOP = 0;

parameter M_ADDR_OFFSET = 'h1000;

localparam CLOG2XARCHBITSZBY8 = clog2(XARCHBITSZ/8);
localparam XADDRBITSZ = (XARCHBITSZ-CLOG2XARCHBITSZBY8);

input wire rst_i;

input wire pi1_clk_i;
input wire clk100mhz_i;

output wire [2 -1 : 0]              m_pi1_op_o;
output wire [XADDRBITSZ -1 : 0]     m_pi1_addr_o;
output wire [XARCHBITSZ -1 : 0]     m_pi1_data_o;
input  wire [XARCHBITSZ -1 : 0]     m_pi1_data_i;
output wire [(XARCHBITSZ/8) -1 : 0] m_pi1_sel_o;
input  wire                         m_pi1_rdy_i;

input  wire [2 -1 : 0]              s_pi1_op_i;
input  wire [XADDRBITSZ -1 : 0]     s_pi1_addr_i;
input  wire [XARCHBITSZ -1 : 0]     s_pi1_data_i;
output wire [XARCHBITSZ -1 : 0]     s_pi1_data_o;
input  wire [(XARCHBITSZ/8) -1 : 0] s_pi1_sel_i;
output wire                         s_pi1_rdy_o;
output wire [XARCHBITSZ -1 : 0]     s_pi1_mapsz_o;

output wire [XADDRBITSZ -1 : 0] pxdat_first_addr_o;
output wire [XADDRBITSZ -1 : 0] pxdat_last_addr_o;

output wire [3:0] tmds_out_p;
output wire [3:0] tmds_out_n;

(* clock_buffer_type = "BUFG" *) wire pixel_clk_w;
(* clock_buffer_type = "BUFG" *) wire tmds_clk_w;
generate
if (WIDTH == 640 && REFRESH == 60) begin
wire clk25mhz_w;
wire clk125mhz_w;
pll_100_to_25_125_mhz pll (
	 .reset    (1'b0)
	,.locked   ()
	,.clk_in1  (clk100mhz_i)
	,.clk_out1 (clk25mhz_w)
	,.clk_out2 (clk125mhz_w)
);
assign pixel_clk_w = clk25mhz_w;
assign tmds_clk_w = clk125mhz_w;
end else if (WIDTH == 800 && REFRESH == 72) begin
wire clk50mhz_w;
wire clk250mhz_w;
pll_100_to_50_250_mhz pll (
	 .reset    (1'b0)
	,.locked   ()
	,.clk_in1  (clk100mhz_i)
	,.clk_out1 (clk50mhz_w)
	,.clk_out2 (clk250mhz_w)
);
assign pixel_clk_w = clk50mhz_w;
assign tmds_clk_w = clk250mhz_w;
end else if (WIDTH == 1280 && REFRESH == 60) begin
wire clk74mhz_w;
wire clk371mhz_w;
pll_100_to_74_371_mhz pll (
	 .reset    (1'b0)
	,.locked   ()
	,.clk_in1  (clk100mhz_i)
	,.clk_out1 (clk74mhz_w)
	,.clk_out2 (clk371mhz_w)
);
assign pixel_clk_w = clk74mhz_w;
assign tmds_clk_w = clk371mhz_w;
end
endgenerate

wire [7:0] video_red_w;
wire [7:0] video_green_w;
wire [7:0] video_blue_w;
wire       video_blank_w;
wire       video_hsync_w;
wire       video_vsync_w;

wire vga_rst_w;

fbdev
#(
	 .ARCHBITSZ     (ARCHBITSZ)
	,.XARCHBITSZ    (XARCHBITSZ)
	,.WIDTH         (WIDTH)
	,.HEIGHT        (HEIGHT)
	,.REFRESH       (REFRESH)
	,.BUFSZ         (BUFSZ)
	,.FORCE_PINOOP  (FORCE_PINOOP)
	,.M_ADDR_OFFSET (M_ADDR_OFFSET)
)
u_fbdev
(
	 .rst_i (rst_i)

	,.clk_i     (pixel_clk_w)
	,.pi1_clk_i (pi1_clk_i)

	,.m_pi1_op_o   (m_pi1_op_o)
	,.m_pi1_addr_o (m_pi1_addr_o)
	,.m_pi1_data_i (m_pi1_data_i)
	,.m_pi1_data_o (m_pi1_data_o)
	,.m_pi1_sel_o  (m_pi1_sel_o)
	,.m_pi1_rdy_i  (m_pi1_rdy_i)

	,.s_pi1_op_i    (s_pi1_op_i)
	,.s_pi1_addr_i  (s_pi1_addr_i)
	,.s_pi1_data_i  (s_pi1_data_i)
	,.s_pi1_data_o  (s_pi1_data_o)
	,.s_pi1_sel_i   (s_pi1_sel_i)
	,.s_pi1_rdy_o   (s_pi1_rdy_o)
	,.s_pi1_mapsz_o (s_pi1_mapsz_o)

	,.pxdat_first_addr_o (pxdat_first_addr_o)
	,.pxdat_last_addr_o (pxdat_last_addr_o)

	,.vga_red_o   (video_red_w)
	,.vga_green_o (video_green_w)
	,.vga_blue_o  (video_blue_w)
	,.vga_blank_o (video_blank_w)
	,.vga_hsync_o (video_hsync_w)
	,.vga_vsync_o (video_vsync_w)

	,.vga_rst_o (vga_rst_w)
);

wire dvi_red_w;
wire dvi_green_w;
wire dvi_blue_w;
wire dvi_clock_w;

dvi
u_dvi
(
    // Inputs
     .rst_i(vga_rst_w)
    ,.clk_i(pixel_clk_w)
    ,.clk_x5_i(tmds_clk_w)
    ,.vga_red_i(video_red_w)
    ,.vga_green_i(video_green_w)
    ,.vga_blue_i(video_blue_w)
    ,.vga_blank_i(video_blank_w)
    ,.vga_hsync_i(video_hsync_w)
    ,.vga_vsync_i(video_vsync_w)

    // Outputs
    ,.dvi_red_o(dvi_red_w)
    ,.dvi_green_o(dvi_green_w)
    ,.dvi_blue_o(dvi_blue_w)
    ,.dvi_clock_o(dvi_clock_w)
);

OBUFDS u_buf_b
(
    .O(tmds_out_p[0]),
    .OB(tmds_out_n[0]),
    .I(dvi_blue_w)
);

OBUFDS u_buf_g
(
    .O(tmds_out_p[1]),
    .OB(tmds_out_n[1]),
    .I(dvi_green_w)
);

OBUFDS u_buf_r
(
    .O(tmds_out_p[2]),
    .OB(tmds_out_n[2]),
    .I(dvi_red_w)
);

OBUFDS u_buf_c
(
    .O(tmds_out_p[3]),
    .OB(tmds_out_n[3]),
    .I(dvi_clock_w)
);

endmodule
