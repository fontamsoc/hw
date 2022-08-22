// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/fifo.v"
`include "lib/fifo_fwft.v"

`include "lib/addr.v"

module fbdev (

	 rst_i

	,clk_i
	,pi1_clk_i

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

	,vga_red_o
	,vga_green_o
	,vga_blue_o
	,vga_blank_o
	,vga_hsync_o
	,vga_vsync_o

	,vga_rst_o
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

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8 = clog2(XARCHBITSZ/8);
localparam XADDRBITSZ = (XARCHBITSZ-CLOG2XARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8DIFF = (CLOG2XARCHBITSZBY8 - CLOG2ARCHBITSZBY8);
localparam _CLOG2XARCHBITSZBY8DIFF = (CLOG2XARCHBITSZBY8DIFF ? CLOG2XARCHBITSZBY8DIFF : 1);

localparam CLOG2XARCHBITSZBY8DIFF2 = (CLOG2XARCHBITSZBY8 - 2/*clog2(32/8)*/);
localparam _CLOG2XARCHBITSZBY8DIFF2 = (CLOG2XARCHBITSZBY8DIFF2 ? CLOG2XARCHBITSZBY8DIFF2 : 1);

localparam CLOG2BUFSZ = clog2(BUFSZ);

input wire rst_i;

input wire clk_i;
input wire pi1_clk_i;

output reg  [2 -1 : 0]              m_pi1_op_o = 0/*PINOOP*/;
output reg  [XADDRBITSZ -1 : 0]     m_pi1_addr_o = 0;
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
output reg  [XADDRBITSZ -1 : 0] pxdat_last_addr_o;

output wire [7:0] vga_red_o;
output wire [7:0] vga_green_o;
output wire [7:0] vga_blue_o;
output wire       vga_blank_o;
output wire       vga_hsync_o;
output wire       vga_vsync_o;

output wire vga_rst_o;

assign m_pi1_sel_o = {(XARCHBITSZ/8){1'b1}};

assign m_pi1_data_o = 0;

assign s_pi1_rdy_o = 1'b1;

// Actual mapsz is (1*(XARCHBITSZ/8)), but aligning to 64bits.
assign s_pi1_mapsz_o = (((XARCHBITSZ<64)?(64/XARCHBITSZ):1)*(XARCHBITSZ/8));

// Video Timings.
localparam H_REZ        = WIDTH;
localparam V_REZ        = HEIGHT;
localparam CLK_MHZ      = (WIDTH == 640 && REFRESH == 60)  ? 25.175 :
                          (WIDTH == 800 && REFRESH == 72)  ? 50.00  :
                          (WIDTH == 1280 && REFRESH == 60) ? 74.25  :
                          (WIDTH == 1920 && REFRESH == 60) ? 148.5  : 0;
localparam H_SYNC_START = (WIDTH == 640 && REFRESH == 60)  ? 656  :
                          (WIDTH == 800 && REFRESH == 72)  ? 856  :
                          (WIDTH == 1280 && REFRESH == 60) ? 1390 :
                          (WIDTH == 1920 && REFRESH == 60) ? 2008 : 0;
localparam H_SYNC_END   = (WIDTH == 640 && REFRESH == 60)  ? 752  :
                          (WIDTH == 800 && REFRESH == 72)  ? 976  :
                          (WIDTH == 1280 && REFRESH == 60) ? 1430 :
                          (WIDTH == 1920 && REFRESH == 60) ? 2052 : 0;
localparam H_MAX        = (WIDTH == 640 && REFRESH == 60)  ? 800  :
                          (WIDTH == 800 && REFRESH == 72)  ? 1040 :
                          (WIDTH == 1280 && REFRESH == 60) ? 1650 :
                          (WIDTH == 1920 && REFRESH == 60) ? 2200 : 0;
localparam V_SYNC_START = (HEIGHT == 480 && REFRESH == 60) ? 490  :
                          (HEIGHT == 600 && REFRESH == 72) ? 637  :
                          (HEIGHT == 720 && REFRESH == 60) ? 725  :
                          (HEIGHT == 1080 && REFRESH == 60)? 1084 : 0;
localparam V_SYNC_END   = (HEIGHT == 480 && REFRESH == 60) ? 492  :
                          (HEIGHT == 600 && REFRESH == 72) ? 643  :
                          (HEIGHT == 720 && REFRESH == 60) ? 730  :
                          (HEIGHT == 1080 && REFRESH == 60)? 1089 : 0;
localparam V_MAX        = (HEIGHT == 480 && REFRESH == 60) ? 525  :
                          (HEIGHT == 600 && REFRESH == 72) ? 666  :
                          (HEIGHT == 720 && REFRESH == 60) ? 750  :
                          (HEIGHT == 1080 && REFRESH == 60)? 1125 : 0;

reg [11:0] h_pos_r = 0;
reg [11:0] v_pos_r = 0;

reg [ARCHBITSZ -1 : 0] pxdat_addr_r = {ARCHBITSZ{1'b1}};

assign vga_rst_o = (rst_i || (&pxdat_addr_r));

always @ (posedge clk_i)
	if (vga_rst_o || h_pos_r == (H_MAX-1)) begin
		h_pos_r <= 0;
		if (vga_rst_o || v_pos_r == (V_MAX-1))
			v_pos_r <= 0;
		else
			v_pos_r <= v_pos_r + 1'b1;
	end else
		h_pos_r <= h_pos_r + 1'b1;

wire vga_hblank_w_ = (h_pos_r >= H_REZ);
wire vga_vblank_w_ = (v_pos_r >= V_REZ);
assign vga_blank_o = (vga_hblank_w_ || vga_vblank_w_);
assign vga_hsync_o = (h_pos_r >= H_SYNC_START && h_pos_r < H_SYNC_END);
assign vga_vsync_o = (v_pos_r >= V_SYNC_START && v_pos_r < V_SYNC_END);

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDSRCSET  = 0;
localparam CMDGETINFO = 1;

localparam GETINFO_WIDTH  = 0;
localparam GETINFO_HEIGHT = 1;
localparam GETINFO_HZ     = 2;
localparam GETINFO_BUFCNT = 3;
localparam GETINFO_ACCEL  = 4;

wire [XARCHBITSZ -1 : 0] s_pi1_addr_w;

addr #(
	.ARCHBITSZ (XARCHBITSZ)
) addr (
	 .addr_i (s_pi1_addr_i)
	,.sel_i  (s_pi1_sel_i)
	,.addr_o (s_pi1_addr_w)
);

// upconverter logic.
reg [XARCHBITSZ -1 : 0] s_pi1_addr_w_hold = 0;
reg [XARCHBITSZ -1 : 0] data_w0 = 0;
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w0_shift = {s_pi1_addr_w_hold[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
assign s_pi1_data_o = (data_w0 << data_w0_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]);
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w1_shift = {s_pi1_addr_w[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
wire [XARCHBITSZ -1 : 0] data_w1 = (s_pi1_data_i >> data_w1_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]);

localparam PXBITSZ = (8*4);
localparam PXBUF_WIDTH = (PXBITSZ*(XARCHBITSZ/ARCHBITSZ));

wire [PXBUF_WIDTH -1 : 0] pxbuf_data_w1;
genvar gen_pxbuf_data_w1_idx;
generate for (
	gen_pxbuf_data_w1_idx = 0;
	gen_pxbuf_data_w1_idx < (XARCHBITSZ/ARCHBITSZ);
	gen_pxbuf_data_w1_idx = gen_pxbuf_data_w1_idx + 1) begin :gen_pxbuf_data_w1
assign pxbuf_data_w1[((gen_pxbuf_data_w1_idx+1)*PXBITSZ) -1 : gen_pxbuf_data_w1_idx*PXBITSZ] = {
	m_pi1_data_i[31+(ARCHBITSZ*gen_pxbuf_data_w1_idx):24+(ARCHBITSZ*gen_pxbuf_data_w1_idx)],
	m_pi1_data_i[23+(ARCHBITSZ*gen_pxbuf_data_w1_idx):16+(ARCHBITSZ*gen_pxbuf_data_w1_idx)],
	m_pi1_data_i[15+(ARCHBITSZ*gen_pxbuf_data_w1_idx):8 +(ARCHBITSZ*gen_pxbuf_data_w1_idx)],
	m_pi1_data_i[7 +(ARCHBITSZ*gen_pxbuf_data_w1_idx):0 +(ARCHBITSZ*gen_pxbuf_data_w1_idx)]};
end endgenerate

reg [_CLOG2XARCHBITSZBY8DIFF2 -1 : 0] datidx = 0;

wire [PXBUF_WIDTH -1 : 0] pxbuf_data_w0;
wire [PXBUF_WIDTH -1 : 0] _pxbuf_data_w0 = (pxbuf_data_w0 >> (datidx*PXBITSZ));

assign vga_blue_o  = _pxbuf_data_w0[23:16];
assign vga_green_o = _pxbuf_data_w0[15:8];
assign vga_red_o   = _pxbuf_data_w0[7:0];

wire [8 -1 : 0] px_repeat_last = (_pxbuf_data_w0[31:24] + 1'b1);
reg  [8 -1 : 0] px_repeat_idx = 0;
wire px_repeat_done = (px_repeat_idx == px_repeat_last);

reg pxbuf_read_en = 0;
reg pxbuf_read_en_sampled = 0;
wire pxbuf_read_en_posedge = (pxbuf_read_en && !pxbuf_read_en_sampled);

wire pxbuf_read_w = pxbuf_read_en_posedge || (
	pxbuf_read_en && !vga_blank_o && (
	(datidx == ((XARCHBITSZ/ARCHBITSZ)-1) && px_repeat_done) ||
		/* or last data of the frame */
		(h_pos_r == (H_REZ-1) && v_pos_r == (V_REZ-1))));

always @ (posedge clk_i) begin

	pxbuf_read_en_sampled <= pxbuf_read_en;

	if (!pxbuf_read_en || vga_vblank_w_ || (!vga_hblank_w_ && px_repeat_done) || pxbuf_read_w)
		px_repeat_idx <= 0;
	else if (vga_hblank_w_); // Do nothing.
	else if (px_repeat_last)
		px_repeat_idx <= px_repeat_idx + 1'b1;

	if (!pxbuf_read_en || vga_vblank_w_ || pxbuf_read_w)
		datidx <= 0;
	else if (vga_hblank_w_); // Do nothing.
	else if (CLOG2XARCHBITSZBY8DIFF2 && px_repeat_done)
		datidx <= datidx + 1'b1;
end

reg [2 -1 : 0] _m_pi1_op_o = PINOOP;

localparam PXCNT      = (H_REZ*V_REZ);
localparam CLOG2PXCNT = clog2(PXCNT);

localparam BUFCNT = 2/*for double-buffering*/;

assign pxdat_first_addr_o = pxdat_addr_r[ARCHBITSZ-1:CLOG2XARCHBITSZBY8];
reg [XADDRBITSZ -1 : 0] pxdat_last_addr_r = 0;
wire [XADDRBITSZ -1 : 0] pxdat_last_addr_r_next = ((pxdat_first_addr_o + (PXCNT>>CLOG2XARCHBITSZBY8DIFF2))-1);
always @ (posedge pi1_clk_i)
	pxdat_last_addr_o <= ((pxdat_first_addr_o + ((PXCNT*BUFCNT)>>CLOG2XARCHBITSZBY8DIFF2))-1);

integer datpxidx;
reg [CLOG2PXCNT -1 : 0] m_pi1_data_i_px_cnt; // ### declared as reg so as to be usable by verilog within the always block.
reg [ARCHBITSZ -1 : 0] m_pi1_data_i_px; // ### declared as reg so as to be usable by verilog within the always block.
always @* begin
	for (datpxidx = 0, m_pi1_data_i_px_cnt = 0; datpxidx < (XARCHBITSZ/ARCHBITSZ); datpxidx = datpxidx + 1) begin
		m_pi1_data_i_px = (m_pi1_data_i>>(ARCHBITSZ*datpxidx));
		m_pi1_data_i_px_cnt = (m_pi1_data_i_px_cnt + ((m_pi1_data_i_px[31:24]+2)&'hff));
	end
end
reg  [CLOG2PXCNT -1 : 0] m_pi1_data_i_px_cnt_cumul = 0;
wire [CLOG2PXCNT -1 : 0] m_pi1_data_i_px_cnt_cumul_next = (m_pi1_data_i_px_cnt_cumul + m_pi1_data_i_px_cnt);

wire pxbuf_empty_w;
wire pxbuf_full_w;

reg pxbuf_empty_w_sampled = 0;
wire pxbuf_empty_w_posedge_ = (pxbuf_empty_w && !pxbuf_empty_w_sampled);
wire m_pi1_data_i_px_cnt_cumul_next_max = (_m_pi1_op_o == PIRDOP && m_pi1_rdy_i &&
		m_pi1_data_i_px_cnt_cumul_next >= PXCNT && m_pi1_addr_o < pxdat_last_addr_r);
wire pxbuf_empty_w_posedge = (pxbuf_empty_w_posedge_ || m_pi1_data_i_px_cnt_cumul_next_max);
reg pxbuf_empty_w_posedge_sampled = 0;

wire pxbuf_excess_empty_w;
wire pxbuf_excess_full_w;

wire _pxbuf_full_w = (pxbuf_full_w || !pxbuf_excess_empty_w);

reg wait_for_vblank = 0;
wire _wait_for_vblank = (wait_for_vblank || _pxbuf_full_w);
reg vga_vblank_w__sampled = 0;
reg wait_for_vblank_trigger = 0;

always @ (posedge pi1_clk_i) begin

	if (s_pi1_rdy_o)
		s_pi1_addr_w_hold <= s_pi1_addr_w;

	if (rst_i)
		pxdat_addr_r <= {ARCHBITSZ{1'b1}};
	else if (s_pi1_op_i == PIRWOP && s_pi1_rdy_o) begin
		if (data_w1[1:0] == CMDSRCSET) begin
			data_w0 <= (1<<CLOG2XARCHBITSZBY8);
			pxdat_addr_r <= (&data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/]) ? {ARCHBITSZ{1'b1}} :
				{{data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] - M_ADDR_OFFSET[ARCHBITSZ-1:2/*clog2(32/8)*/]}, 2'b00};
		end else if (data_w1[1:0] == CMDGETINFO) begin
			if (data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] == GETINFO_WIDTH)
				data_w0 <= WIDTH;
			else if (data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] == GETINFO_HEIGHT)
				data_w0 <= HEIGHT;
			else if (data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] == GETINFO_HZ)
				data_w0 <= REFRESH;
			else if (data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] == GETINFO_BUFCNT)
				data_w0 <= BUFCNT;
			else if (data_w1[ARCHBITSZ-1:2/*clog2(32/8)*/] == GETINFO_ACCEL)
				data_w0 <= 1/* Acceleration Version */;
			else
				data_w0 <= 0;
		end
	end

	if (vga_rst_o)
		_m_pi1_op_o <= PINOOP;
	else if (m_pi1_rdy_i) begin
		_m_pi1_op_o <= m_pi1_op_o;
		pxbuf_empty_w_posedge_sampled <= (pxbuf_empty_w_posedge && (m_pi1_op_o == PIRDOP && m_pi1_addr_o != pxdat_first_addr_o));
		pxbuf_empty_w_sampled <= pxbuf_empty_w;
	end

	if (vga_rst_o) begin
		m_pi1_op_o <= PINOOP;
		m_pi1_addr_o <= 0;
		pxdat_last_addr_r <= 0;
		m_pi1_data_i_px_cnt_cumul <= 0;
	end else if (m_pi1_op_o == PIRDOP || _m_pi1_op_o == PIRDOP) begin
		if (m_pi1_rdy_i) begin
			if (m_pi1_op_o == PIRDOP) begin
				if (FORCE_PINOOP/* can hog bus if no PINOOP */|| _wait_for_vblank)
					m_pi1_op_o <= PINOOP;
				if (m_pi1_addr_o < pxdat_last_addr_r && (!pxbuf_empty_w_posedge || m_pi1_addr_o == pxdat_first_addr_o)) begin
					m_pi1_addr_o <= m_pi1_addr_o + 1'b1;
				end else begin
					m_pi1_addr_o <= pxdat_first_addr_o;
					pxdat_last_addr_r <= pxdat_last_addr_r_next;
				end
			end else if (pxbuf_empty_w_posedge) begin
				if (!FORCE_PINOOP)
					m_pi1_op_o <= PIRDOP;
				m_pi1_addr_o <= pxdat_first_addr_o;
				pxdat_last_addr_r <= pxdat_last_addr_r_next;
			end
			if (_m_pi1_op_o == PIRDOP) begin
				if (m_pi1_addr_o != pxdat_first_addr_o && m_pi1_addr_o != pxdat_last_addr_r &&
					(!(pxbuf_empty_w_posedge || pxbuf_empty_w_posedge_sampled))) begin
					m_pi1_data_i_px_cnt_cumul <= m_pi1_data_i_px_cnt_cumul_next;
				end else begin
					m_pi1_data_i_px_cnt_cumul <= 0;
				end
			end else if (pxbuf_empty_w_posedge) begin
					m_pi1_data_i_px_cnt_cumul <= 0;
			end
		end else if (!FORCE_PINOOP) begin
			// Used in order to attempt PIRDOP when next m_pi1_op_o was set to PINOOP.
			if (_wait_for_vblank)
				m_pi1_op_o <= PINOOP;
			else begin
				m_pi1_op_o <= PIRDOP;
				if (pxbuf_empty_w_posedge) begin
					m_pi1_addr_o <= pxdat_first_addr_o;
					pxdat_last_addr_r <= pxdat_last_addr_r_next;
					m_pi1_data_i_px_cnt_cumul <= 0;
				end
			end
		end
	end else if (!_wait_for_vblank) begin
		if (m_pi1_op_o == PINOOP) begin
			m_pi1_op_o <= PIRDOP;
			if (!m_pi1_addr_o || pxbuf_empty_w) begin
				m_pi1_addr_o <= pxdat_first_addr_o;
				pxdat_last_addr_r <= pxdat_last_addr_r_next;
				m_pi1_data_i_px_cnt_cumul <= 0;
			end
		end
	end

	vga_vblank_w__sampled <= vga_vblank_w_; // To detect posedge.
	if (vga_rst_o || pxbuf_empty_w || (vga_vblank_w_ && !vga_vblank_w__sampled)) begin
		wait_for_vblank <= 0;
		wait_for_vblank_trigger <= 0;
	end else if (m_pi1_data_i_px_cnt_cumul_next_max) begin
		// Prevents too many RLE compressed frames in pxbuf.
		if (wait_for_vblank_trigger)
			wait_for_vblank <= 1;
		wait_for_vblank_trigger <= 1;
	end

	if (vga_rst_o || pxbuf_empty_w)
		pxbuf_read_en <= 0;
	else if (vga_vblank_w_)
		pxbuf_read_en <= 1;
end

wire pxbuf_write_w = ((_m_pi1_op_o == PIRDOP && m_pi1_rdy_i) && !(pxbuf_empty_w_posedge_ || pxbuf_empty_w_posedge_sampled));

wire [PXBUF_WIDTH -1 : 0] pxbuf_excess_data_w0;

fifo #(

	 .WIDTH (PXBUF_WIDTH)
	,.DEPTH (BUFSZ)

) pxbuf (

	 .rst_i (vga_rst_o)

	,.clk_read_i (clk_i)
	,.read_i     (pxbuf_read_w)
	,.data_o     (pxbuf_data_w0)
	,.empty_o    (pxbuf_empty_w)

	,.clk_write_i (pi1_clk_i)
	,.write_i     ((!pxbuf_excess_empty_w) || pxbuf_write_w)
	,.data_i      ((!pxbuf_excess_empty_w) ? pxbuf_excess_data_w0 : pxbuf_data_w1)
	,.full_o      (pxbuf_full_w)
);

fifo_fwft #(

	 .WIDTH (PXBUF_WIDTH)
	,.DEPTH (2)

) pxbuf_excess (

	 .rst_i (vga_rst_o)

	,.clk_pop_i (pi1_clk_i)
	,.pop_i     (!pxbuf_full_w)
	,.data_o    (pxbuf_excess_data_w0)
	,.empty_o   (pxbuf_excess_empty_w)

	,.clk_push_i (pi1_clk_i)
	,.push_i     (pxbuf_write_w && _pxbuf_full_w)
	,.data_i     (pxbuf_data_w1)
	,.full_o     (pxbuf_excess_full_w)
);

endmodule
