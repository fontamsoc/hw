// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_MUX_V
`define WB_MUX_V

module wb_mux (

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
parameter MAXPENDINGACK = 16; // Must be non-null and a power of 2.
parameter SDEVCOUNT     = 1;
parameter [0:(SDEVCOUNT*2*32)-1] SDEVS = 0;
parameter ADDRSPACE_SEQINIT = 0; // When non-null, at least 2 clock cycles needed for reset.

localparam CLOG2SDEVCOUNT = clog2(SDEVCOUNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

localparam CLOG2MAXPENDINGACK = clog2(MAXPENDINGACK);

input wire rst_i;

input wire clk_i;

input  wire                               m_wb_stb_i;
input  wire                               m_wb_lock_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output wire                               m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire [(1 * SDEVCOUNT) -1 : 0]                    s_wb_stb_o;
output wire [(1 * SDEVCOUNT) -1 : 0]                    s_wb_lock_o;
output wire [(1 * SDEVCOUNT) -1 : 0]                    s_wb_we_o;
output wire [((ADDRBITSZ-MSBSZIGN) * SDEVCOUNT) -1 : 0] s_wb_addr_o;
output wire [((WORDBITSZ/8) * SDEVCOUNT) -1 : 0]        s_wb_sel_o;
output wire [(WORDBITSZ * SDEVCOUNT) -1 : 0]            s_wb_dat_o;
input  wire [(1 * SDEVCOUNT) -1 : 0]                    s_wb_bsy_i;
input  wire [(1 * SDEVCOUNT) -1 : 0]                    s_wb_ack_i;
input  wire [(WORDBITSZ * SDEVCOUNT) -1 : 0]            s_wb_dat_i;

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_r;

wire _m_wb_stb_i = (m_wb_stb_i && !m_wb_bsy_o);

reg [(CLOG2MAXPENDINGACK +1) -1 : 0] ack_pending;

always_ff @(posedge clk_i) begin
	if (rst_i)
		ack_pending <= 0;
	else if (_m_wb_stb_i && m_wb_ack_o);
	else if (m_wb_ack_o)
		ack_pending <= ack_pending - 1'b1;
	else if (_m_wb_stb_i)
		ack_pending <= ack_pending + 1'b1;
end

wire [WORDBITSZ -1 : 0] _s_wb_dat_i [SDEVCOUNT];

reg [CLOG2SDEVCOUNT -1 : 0] slvidx;

wire [CLOG2SDEVCOUNT -1 : 0] slvidx_nxt = (slvidx + 1'b1);

reg slvidx_rdy;
reg slvidx_dflt;

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace [SDEVCOUNT][2];
generate if (ADDRSPACE_SEQINIT) begin: gen_addrspace_seqinit
always_ff @(posedge clk_i) begin
	if (rst_i)
		for (int i = 0; i < SDEVCOUNT; ++i) begin
			bit [(ADDRBITSZ-MSBSZIGN) -1 : 0] j, k;
			j = 32'(SDEVS[(i*2*32)+:32])>>CLOG2WORDBITSZBY8;
			k = 32'(SDEVS[(((i*2)+1)*32)+:32])>>CLOG2WORDBITSZBY8;
			k += !k; // Increment k by 1 if null.
			addrspace[i][0] <= j;
			addrspace[i][1] <= (j+k-1);
		end
end
end else begin: gen_addrspace_init
initial begin
	for (int i = 0; i < SDEVCOUNT; ++i) begin
		bit [(ADDRBITSZ-MSBSZIGN) -1 : 0] j, k;
		j = 32'(SDEVS[(i*2*32)+:32])>>CLOG2WORDBITSZBY8;
		k = 32'(SDEVS[(((i*2)+1)*32)+:32])>>CLOG2WORDBITSZBY8;
		k += !k; // Increment k by 1 if null.
		addrspace[i][0] = j;
		addrspace[i][1] = (j+k-1);
	end
end
end endgenerate

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace_slvidx_lo;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace_slvidx_hi;

// Determine whether slvidx needs to be recomputed.
wire slvidx_invalid = (!slvidx_dflt &&
	!(m_wb_addr_i >= addrspace_slvidx_lo &&
	  m_wb_addr_i <= addrspace_slvidx_hi));

wire _slvidx_invalid = (slvidx_invalid && !ack_pending);

always_ff @(posedge clk_i) begin
	// Logic which computes slvidx using addrspace[].
	if (rst_i) begin

		addrspace_slvidx_lo <= addrspace[0][0];
		addrspace_slvidx_hi <= addrspace[0][1];
		slvidx <= 0;
		slvidx_rdy <= 0;
		slvidx_dflt <= 0;
		// That state will compute slvidx as though it was due to slvidx_invalid.

	end else if (!slvidx_rdy && m_wb_addr_r == m_wb_addr_i) begin

		if (m_wb_stb_i) begin
			if (!slvidx_invalid)
				slvidx_rdy <= 1;
			else if (slvidx < (SDEVCOUNT-1)) begin
				addrspace_slvidx_lo <= addrspace[slvidx_nxt][0];
				addrspace_slvidx_hi <= addrspace[slvidx_nxt][1];
				slvidx <= slvidx_nxt;
				if (slvidx_nxt == (SDEVCOUNT-1)) begin
					slvidx_rdy <= 1;
					slvidx_dflt <= 1;
				end
			end
		end

	end else if (m_wb_stb_i && _slvidx_invalid) begin

		addrspace_slvidx_lo <= addrspace[0][0];
		addrspace_slvidx_hi <= addrspace[0][1];
		slvidx <= 0;
		slvidx_rdy <= 0;

		m_wb_addr_r <= m_wb_addr_i;

	end else if (slvidx_dflt)
		slvidx_dflt <= m_wb_bsy_o;
end

assign m_wb_bsy_o = ((slvidx_invalid ? 1'b1 : s_wb_bsy_i[slvidx]) || ack_pending[CLOG2MAXPENDINGACK]);
assign m_wb_ack_o = s_wb_ack_i[slvidx];
assign m_wb_dat_o = _s_wb_dat_i[slvidx];

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o_ = (m_wb_addr_i - addrspace_slvidx_lo);

genvar gen_s_wb_idx;
generate for (
	gen_s_wb_idx = 0;
	gen_s_wb_idx < SDEVCOUNT;
	gen_s_wb_idx = gen_s_wb_idx + 1) begin :gen_s_wb

assign s_wb_stb_o[gen_s_wb_idx] = ((slvidx != gen_s_wb_idx || slvidx_invalid || ack_pending[CLOG2MAXPENDINGACK]) ? 1'b0 : m_wb_stb_i);
assign s_wb_lock_o[gen_s_wb_idx] = m_wb_lock_i;
assign s_wb_we_o[gen_s_wb_idx] = m_wb_we_i;
assign s_wb_addr_o[(gen_s_wb_idx * (ADDRBITSZ-MSBSZIGN)) +: (ADDRBITSZ-MSBSZIGN)] = s_wb_addr_o_;
assign s_wb_sel_o[(gen_s_wb_idx * (WORDBITSZ/8)) +: (WORDBITSZ/8)] = m_wb_sel_i;
assign s_wb_dat_o[(gen_s_wb_idx * WORDBITSZ) +: WORDBITSZ] = m_wb_dat_i;
assign _s_wb_dat_i[gen_s_wb_idx] = s_wb_dat_i[(gen_s_wb_idx * WORDBITSZ) +: WORDBITSZ];

end endgenerate

endmodule

`endif /* WB_MUX_V */
