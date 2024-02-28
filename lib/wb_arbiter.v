// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_ARBITER_V
`define WB_ARBITER_V

module wb_arbiter (

	 rst_i

	,clk_i

	,m_wb_cyc_i
	,m_wb_stb_i
	,m_wb_we_i
	,m_wb_addr_i
	,m_wb_sel_i
	,m_wb_dat_i
	,m_wb_bsy_o
	,m_wb_ack_o
	,m_wb_dat_o

	,s_wb_cyc_o
	,s_wb_stb_o
	,s_wb_we_o
	,s_wb_addr_o
	,s_wb_sel_o
	,s_wb_dat_o
	,s_wb_bsy_i
	,s_wb_ack_i
	,s_wb_dat_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ   = 16;
parameter MASTERCOUNT = 1;

localparam CLOG2MASTERCOUNT = clog2(MASTERCOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [(1 * MASTERCOUNT) -1 : 0]             m_wb_cyc_i;
input  wire [(1 * MASTERCOUNT) -1 : 0]             m_wb_stb_i;
input  wire [(1 * MASTERCOUNT) -1 : 0]             m_wb_we_i;
input  wire [(ADDRBITSZ * MASTERCOUNT) -1 : 0]     m_wb_addr_i;
input  wire [((ARCHBITSZ/8) * MASTERCOUNT) -1 : 0] m_wb_sel_i;
input  wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_wb_dat_i;
output wire [(1 * MASTERCOUNT) -1 : 0]             m_wb_bsy_o;
output wire [(1 * MASTERCOUNT) -1 : 0]             m_wb_ack_o;
output wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_wb_dat_o;

output wire                        s_wb_cyc_o;
output wire                        s_wb_stb_o;
output wire                        s_wb_we_o;
output wire [ADDRBITSZ -1 : 0]     s_wb_addr_o;
output wire [(ARCHBITSZ/8) -1 : 0] s_wb_sel_o;
output wire [ARCHBITSZ -1 : 0]     s_wb_dat_o;
input  wire                        s_wb_bsy_i;
input  wire                        s_wb_ack_i;
input  wire [ARCHBITSZ -1 : 0]     s_wb_dat_i;

reg [CLOG2MASTERCOUNT -1 : 0] mstridx;

wire [ADDRBITSZ -1 : 0]     _m_wb_addr_i [MASTERCOUNT -1 : 0];
wire [(ARCHBITSZ/8) -1 : 0] _m_wb_sel_i  [MASTERCOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0]     _m_wb_dat_i  [MASTERCOUNT -1 : 0];

genvar gen_m_wb_idx;
generate for (
	gen_m_wb_idx = 0;
	gen_m_wb_idx < MASTERCOUNT;
	gen_m_wb_idx = gen_m_wb_idx + 1) begin :gen_m_wb

assign _m_wb_addr_i[gen_m_wb_idx] =
	m_wb_addr_i[((gen_m_wb_idx+1) * ADDRBITSZ) -1 : (gen_m_wb_idx * ADDRBITSZ)];

assign _m_wb_sel_i[gen_m_wb_idx] =
	m_wb_sel_i[((gen_m_wb_idx+1) * (ARCHBITSZ/8)) -1 : (gen_m_wb_idx * (ARCHBITSZ/8))];

assign _m_wb_dat_i[gen_m_wb_idx] =
	m_wb_dat_i[((gen_m_wb_idx+1) * ARCHBITSZ) -1 : (gen_m_wb_idx * ARCHBITSZ)];

assign m_wb_bsy_o[gen_m_wb_idx] = ((mstridx == gen_m_wb_idx) ? s_wb_bsy_i : 1'b1);

assign m_wb_ack_o[gen_m_wb_idx] = s_wb_ack_i;

assign m_wb_dat_o[((gen_m_wb_idx+1) * ARCHBITSZ) -1 : (gen_m_wb_idx * ARCHBITSZ)] = s_wb_dat_i;

end endgenerate

assign s_wb_cyc_o = m_wb_cyc_i[mstridx];
assign s_wb_stb_o = m_wb_stb_i[mstridx];
assign s_wb_we_o = m_wb_we_i[mstridx];
assign s_wb_addr_o = _m_wb_addr_i[mstridx];
assign s_wb_sel_o = _m_wb_sel_i[mstridx];
assign s_wb_dat_o = _m_wb_dat_i[mstridx];

reg [CLOG2MASTERCOUNT -1 : 0] mstrlonxt;
reg [CLOG2MASTERCOUNT -1 : 0] mstrloidx;
// Compute in mstrlonxt the active master with the lowest index.
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i || (mstrloidx == (MASTERCOUNT - 1)) || m_wb_cyc_i[mstrloidx]) begin
			if (m_wb_cyc_i[mstrloidx])
				mstrlonxt <= mstrloidx;
			mstrloidx <= 0;
		end else
			mstrloidx <= mstrloidx + 1'b1;
	end
end

reg [CLOG2MASTERCOUNT -1 : 0] mstrhinxt;
reg [CLOG2MASTERCOUNT -1 : 0] mstrhiidx;
// Compute in mstrhinxt the active master with the highest index.
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i || (mstrhiidx == 0) || m_wb_cyc_i[mstrhiidx]) begin
			if (m_wb_cyc_i[mstrhiidx])
				mstrhinxt <= mstrhiidx;
			mstrhiidx <= (MASTERCOUNT - 1);
		end else
			mstrhiidx <= mstrhiidx - 1'b1;
	end
end

reg [CLOG2MASTERCOUNT -1 : 0] mstrhi;
// Logic that increments mstridx.
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i)
			mstrhi <= (MASTERCOUNT - 1);
		else if (!m_wb_cyc_i[mstridx]) begin
			if (mstridx < mstrhi)
				mstridx <= mstridx + 1'b1;
			else begin
				mstridx <= mstrlonxt;
				mstrhi <= mstrhinxt;
			end
		end
	end else
		mstridx <= 0;
end

endmodule

`endif /* WB_ARBITER_V */
