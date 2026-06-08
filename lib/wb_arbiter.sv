// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_ARBITER_V
`define WB_ARBITER_V

`include "lib/fifo_fwft.sv"

module wb_arbiter (

	 rst_i

	,clk_i

	,m_wb_stb_i
	,m_wb_lock_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_stb_o
	,s_wb_lock_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.sv"

parameter WORDBITSZ     = 32;
parameter ADDRLIMIT     = 'h2000;
parameter MDEVCOUNT     = 1;
parameter MAXPENDINGACK = 16; // Must be non-null and a power of 2.

localparam CLOG2MDEVCOUNT = clog2(MDEVCOUNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_stb_i;
input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_lock_i;
input  wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_we_i;
input  wire [((ADDRBITSZ-MSBSZIGN) * MDEVCOUNT) -1 : 0] m_wb_addr_i;
input  wire [((WORDBITSZ/8) * MDEVCOUNT) -1 : 0]        m_wb_sel_i;
input  wire [(WORDBITSZ * MDEVCOUNT) -1 : 0]            m_wb_dat_i;
output wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_bsy_o;
output wire [(1 * MDEVCOUNT) -1 : 0]                    m_wb_ack_o;
output wire [(WORDBITSZ * MDEVCOUNT) -1 : 0]            m_wb_dat_o;

output wire                               s_wb_stb_o;
output wire                               s_wb_lock_o;
output wire                               s_wb_we_o;
output wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o;
output wire [(WORDBITSZ/8) -1 : 0]        s_wb_sel_o;
output wire [WORDBITSZ -1 : 0]            s_wb_dat_o;
input  wire                               s_wb_bsy_i;
input  wire                               s_wb_ack_i;
input  wire [WORDBITSZ -1 : 0]            s_wb_dat_i;

reg [CLOG2MDEVCOUNT -1 : 0] mstridx;

wire [CLOG2MDEVCOUNT -1 : 0] slvidx;

wire _s_wb_stb_o = (s_wb_stb_o && !s_wb_bsy_i);

wire pendingAcksFull;

generate if (MDEVCOUNT > 1) begin
fifo_fwft #(
	 .WIDTH (CLOG2MDEVCOUNT)
	,.DEPTH (MAXPENDINGACK)
) pendingAcks (
	 .rst_i (rst_i)
	,.clk_push_i (clk_i)
	,.push_i     (_s_wb_stb_o)
	,.data_i     (mstridx)
	,.full_o     (pendingAcksFull)
	,.clk_pop_i  (clk_i)
	,.pop_i      (s_wb_ack_i)
	,.data_o     (slvidx)
);
end else begin
assign pendingAcksFull = 1'b0;
assign slvidx = 0;
end endgenerate

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] _m_wb_addr_i [MDEVCOUNT];
wire [(WORDBITSZ/8) -1 : 0]        _m_wb_sel_i  [MDEVCOUNT];
wire [WORDBITSZ -1 : 0]            _m_wb_dat_i  [MDEVCOUNT];

genvar gen_m_wb_idx;
generate for (
	gen_m_wb_idx = 0;
	gen_m_wb_idx < MDEVCOUNT;
	gen_m_wb_idx = gen_m_wb_idx + 1) begin :gen_m_wb

assign _m_wb_addr_i[gen_m_wb_idx] =
	m_wb_addr_i[((gen_m_wb_idx+1) * (ADDRBITSZ-MSBSZIGN)) -1 : (gen_m_wb_idx * (ADDRBITSZ-MSBSZIGN))];

assign _m_wb_sel_i[gen_m_wb_idx] =
	m_wb_sel_i[((gen_m_wb_idx+1) * (WORDBITSZ/8)) -1 : (gen_m_wb_idx * (WORDBITSZ/8))];

assign _m_wb_dat_i[gen_m_wb_idx] =
	m_wb_dat_i[((gen_m_wb_idx+1) * WORDBITSZ) -1 : (gen_m_wb_idx * WORDBITSZ)];

assign m_wb_bsy_o[gen_m_wb_idx] = ((mstridx == gen_m_wb_idx) ? (s_wb_bsy_i || pendingAcksFull) : 1'b1);

assign m_wb_ack_o[gen_m_wb_idx] = ((slvidx == gen_m_wb_idx) ? s_wb_ack_i : 1'b0);

assign m_wb_dat_o[((gen_m_wb_idx+1) * WORDBITSZ) -1 : (gen_m_wb_idx * WORDBITSZ)] = s_wb_dat_i;

end endgenerate

wire _m_wb_stb_i = m_wb_stb_i[mstridx];

assign s_wb_stb_o = (pendingAcksFull ? 1'b0 : _m_wb_stb_i);
assign s_wb_lock_o = m_wb_lock_i[mstridx];
assign s_wb_we_o = m_wb_we_i[mstridx];
assign s_wb_addr_o = _m_wb_addr_i[mstridx];
assign s_wb_sel_o = _m_wb_sel_i[mstridx];
assign s_wb_dat_o = _m_wb_dat_i[mstridx];

reg [CLOG2MDEVCOUNT -1 : 0] mstrlonxt;
reg [CLOG2MDEVCOUNT -1 : 0] mstrloidx;
// Compute in mstrlonxt the active master with the lowest index.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstrlonxt <= 0;
		mstrloidx <= 0;
	end else if (MDEVCOUNT > 1) begin
		if (mstrloidx == (MDEVCOUNT - 1) || m_wb_stb_i[mstrloidx]) begin
			if (m_wb_stb_i[mstrloidx])
				mstrlonxt <= mstrloidx;
			mstrloidx <= 0;
		end else
			mstrloidx <= mstrloidx + 1'b1;
	end
end

reg [CLOG2MDEVCOUNT -1 : 0] mstrhinxt;
reg [CLOG2MDEVCOUNT -1 : 0] mstrhiidx;
// Compute in mstrhinxt the active master with the highest index.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstrhinxt <= (MDEVCOUNT - 1);
		mstrhiidx <= (MDEVCOUNT - 1);
	end else if (MDEVCOUNT > 1) begin
		if (mstrhiidx == 0 || m_wb_stb_i[mstrhiidx]) begin
			if (m_wb_stb_i[mstrhiidx])
				mstrhinxt <= mstrhiidx;
			mstrhiidx <= (MDEVCOUNT - 1);
		end else
			mstrhiidx <= mstrhiidx - 1'b1;
	end
end

reg wb_lock;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_lock_addr;
always_ff @(posedge clk_i) begin
	if (rst_i)
		wb_lock <= 1'b0;
	else if (MDEVCOUNT > 1) begin
		if (_s_wb_stb_o)
			wb_lock <= (s_wb_lock_o || (wb_lock && (s_wb_addr_o != wb_lock_addr)));
		if (_s_wb_stb_o && !wb_lock)
			wb_lock_addr <= s_wb_addr_o;
	end
end

reg [CLOG2MDEVCOUNT -1 : 0] mstrhi;
// Logic that increments mstridx.
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		mstridx <= 0;
		mstrhi <= (MDEVCOUNT - 1);
	end else if (MDEVCOUNT > 1) begin
		if (!(wb_lock || _m_wb_stb_i)) begin
			if (mstridx < mstrhi)
				mstridx <= mstridx + 1'b1;
			else begin
				mstridx <= mstrlonxt;
				mstrhi <= mstrhinxt;
			end
		end
	end
end

endmodule

`endif /* WB_ARBITER_V */
