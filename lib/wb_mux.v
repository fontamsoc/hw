// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_MUX_V
`define WB_MUX_V

`include "lib/addr.v"

module wb_mux (

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
	,s_wb_mapsz_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ         = 16;
parameter SLAVECOUNT        = 1;
parameter DEFAULTSLAVEINDEX = 0;
parameter FIRSTSLAVEADDR    = 0;

localparam CLOG2SLAVECOUNT  = clog2(SLAVECOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire                        m_wb_cyc_i;
input  wire                        m_wb_stb_i;
input  wire                        m_wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     m_wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] m_wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     m_wb_dat_i;
output wire                        m_wb_bsy_o;
output wire                        m_wb_ack_o;
output wire [ARCHBITSZ -1 : 0]     m_wb_dat_o;

output wire [(1 * SLAVECOUNT) -1 : 0]             s_wb_cyc_o;
output wire [(1 * SLAVECOUNT) -1 : 0]             s_wb_stb_o;
output wire [(1 * SLAVECOUNT) -1 : 0]             s_wb_we_o;
output wire [(ADDRBITSZ * SLAVECOUNT) -1 : 0]     s_wb_addr_o;
output wire [((ARCHBITSZ/8) * SLAVECOUNT) -1 : 0] s_wb_sel_o;
output wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_wb_dat_o;
input  wire [(1 * SLAVECOUNT) -1 : 0]             s_wb_bsy_i;
input  wire [(1 * SLAVECOUNT) -1 : 0]             s_wb_ack_i;
input  wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_wb_dat_i;
input  wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_wb_mapsz_i;

wire [ARCHBITSZ -1 : 0] _m_wb_addr_i;
addr #(
	.ARCHBITSZ (ARCHBITSZ)
) addr (
	 .addr_i (m_wb_addr_i)
	,.sel_i  (m_wb_sel_i)
	,.addr_o (_m_wb_addr_i)
);

wire [ARCHBITSZ -1 : 0] _s_wb_mapsz_i [SLAVECOUNT -1 : 0];
wire [ARCHBITSZ -1 : 0] _s_wb_dat_i [SLAVECOUNT -1 : 0];

reg [ARCHBITSZ -1 : 0] addrspace [SLAVECOUNT -1 : 0];
reg addrspace_rdy;

reg [CLOG2SLAVECOUNT -1 : 0] slvidx;
reg slvidx_rdy;

reg [ARCHBITSZ -1 : 0] addrspace_slvidx_lo; // Also used to initialize addrspace.
reg [ARCHBITSZ -1 : 0] addrspace_slvidx_hi;

wire slvidx_not_max = (slvidx < (SLAVECOUNT-1));

// Determine whether slvidx needs to be recomputed.
wire slvidx_invalid = (!addrspace_rdy || (
	m_wb_cyc_i && m_wb_stb_i &&
	!(_m_wb_addr_i >= addrspace_slvidx_lo &&
	  _m_wb_addr_i <= addrspace_slvidx_hi)));

wire [ARCHBITSZ -1 : 0] addrspace_slvidx_nxt = (addrspace_slvidx_lo + _s_wb_mapsz_i[slvidx]);

always @ (posedge clk_i) begin

	// Logic which on reset computes addrspace
	// using the size of each slave device mapping;
	// and after reset computes slvidx using addrspace.
	if (rst_i) begin

		addrspace_slvidx_lo <= FIRSTSLAVEADDR;
		slvidx <= 0;
		slvidx_rdy <= 1'b0;
		addrspace_rdy <= 1'b0;

	end else if (!addrspace_rdy) begin

		if (slvidx_not_max) begin
			addrspace_slvidx_lo <= addrspace_slvidx_nxt;
			slvidx <= slvidx + 1'b1;
		end else begin
			addrspace_slvidx_lo <= FIRSTSLAVEADDR;
			addrspace_slvidx_hi <= addrspace[0];
			slvidx <= 0;
			addrspace_rdy <= 1'b1;
			// Next state will be for:
			// slvidx_rdy == 0 with slvidx == 0;
			// That state will compute slvidx as though it was due to slvidx_invalid;
			// this state set addrspace_slvidx_lo for the next state.
		end

		addrspace[slvidx] <= addrspace_slvidx_nxt - 1'b1;

	end else if (!slvidx_rdy) begin

		if (!slvidx_invalid)
			slvidx_rdy <= 1'b1;
		else if (slvidx_not_max) begin
			addrspace_slvidx_lo <= addrspace[slvidx] + 1'b1;
			addrspace_slvidx_hi <= addrspace[slvidx + 1'b1];
			slvidx <= slvidx + 1'b1;
		end else begin
			addrspace_slvidx_lo <= _m_wb_addr_i;
			addrspace_slvidx_hi <= addrspace[DEFAULTSLAVEINDEX];
			slvidx <= DEFAULTSLAVEINDEX;
			slvidx_rdy <= 1'b1;
		end

	end else if (slvidx_invalid) begin

		addrspace_slvidx_lo <= FIRSTSLAVEADDR;
		addrspace_slvidx_hi <= addrspace[0];
		slvidx <= 0;
		slvidx_rdy <= 1'b0;
	end
end

assign m_wb_bsy_o = (slvidx_invalid ? 1'b1 : s_wb_bsy_i[slvidx]);

assign m_wb_ack_o = s_wb_ack_i[slvidx];

assign m_wb_dat_o = _s_wb_dat_i[slvidx];

genvar gen_s_wb_idx;
generate for (
	gen_s_wb_idx = 0;
	gen_s_wb_idx < SLAVECOUNT;
	gen_s_wb_idx = gen_s_wb_idx + 1) begin :gen_s_wb

assign s_wb_cyc_o[gen_s_wb_idx] = ((slvidx != gen_s_wb_idx || slvidx_invalid) ? 1'b0 : m_wb_cyc_i);

assign s_wb_stb_o[gen_s_wb_idx] = ((slvidx != gen_s_wb_idx || slvidx_invalid) ? 1'b0 : m_wb_stb_i);

assign s_wb_we_o[gen_s_wb_idx] = m_wb_we_i;

assign s_wb_addr_o[((gen_s_wb_idx+1) * ADDRBITSZ) -1 : (gen_s_wb_idx * ADDRBITSZ)] =
	(m_wb_addr_i - addrspace_slvidx_lo[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8]);

assign s_wb_sel_o[((gen_s_wb_idx+1) * (ARCHBITSZ/8)) -1 : (gen_s_wb_idx * (ARCHBITSZ/8))] = m_wb_sel_i;

assign s_wb_dat_o[((gen_s_wb_idx+1) * ARCHBITSZ) -1 : (gen_s_wb_idx * ARCHBITSZ)] = m_wb_dat_i;

assign _s_wb_dat_i[gen_s_wb_idx] =
	s_wb_dat_i[((gen_s_wb_idx+1) * ARCHBITSZ) -1 : (gen_s_wb_idx * ARCHBITSZ)];

assign _s_wb_mapsz_i[gen_s_wb_idx] =
	s_wb_mapsz_i[((gen_s_wb_idx+1) * ARCHBITSZ) -1 : (gen_s_wb_idx * ARCHBITSZ)];

end endgenerate

endmodule

`endif /* WB_MUX_V */
