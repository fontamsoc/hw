// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef WB_MUX_V
`define WB_MUX_V

// Devices mapsz must be at a minimum aligned to WORDBITSZ, for s_wb_sel_o
// to be valid since its values are wired as-is from m_wb_sel_i.
// By convention, devices mapsz must be aligned to 128 bytes (1024 bits).

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

`include "lib/clog2.sv"

parameter WORDBITSZ         = 32;
parameter SLAVECOUNT        = 1;
parameter DEFAULTSLAVEINDEX = 0;
parameter FIRSTSLAVEADDR    = 0;
parameter ADDRLIMIT         = 'h2000;
parameter MAXPENDINGACK     = 16; // Must be non-null.

localparam CLOG2SLAVECOUNT  = clog2(SLAVECOUNT);

localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);

// -1 account for the msb oring ignored bits.
localparam MSBSZIGN = (WORDBITSZ-clog2(ADDRLIMIT)-1);

input wire rst_i;

input wire clk_i;

input  wire                               m_wb_cyc_i;
input  wire                               m_wb_stb_i;
input  wire                               m_wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] m_wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        m_wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            m_wb_dat_i;
output wire                               m_wb_bsy_o;
output wire                               m_wb_ack_o;
output wire [WORDBITSZ -1 : 0]            m_wb_dat_o;

output wire [(1 * SLAVECOUNT) -1 : 0]                    s_wb_cyc_o;
output wire [(1 * SLAVECOUNT) -1 : 0]                    s_wb_stb_o;
output wire [(1 * SLAVECOUNT) -1 : 0]                    s_wb_we_o;
output wire [((ADDRBITSZ-MSBSZIGN) * SLAVECOUNT) -1 : 0] s_wb_addr_o;
output wire [((WORDBITSZ/8) * SLAVECOUNT) -1 : 0]        s_wb_sel_o;
output wire [(WORDBITSZ * SLAVECOUNT) -1 : 0]            s_wb_dat_o;
input  wire [(1 * SLAVECOUNT) -1 : 0]                    s_wb_bsy_i;
input  wire [(1 * SLAVECOUNT) -1 : 0]                    s_wb_ack_i;
input  wire [(WORDBITSZ * SLAVECOUNT) -1 : 0]            s_wb_dat_i;
input  wire [((WORDBITSZ-MSBSZIGN) * SLAVECOUNT) -1 : 0] s_wb_mapsz_i;

wire _m_wb_stb_i = (m_wb_cyc_i && m_wb_stb_i);

reg [clog2(MAXPENDINGACK +1) -1 : 0] ack_pending;

wire _m_wb_stb_i_and_not_m_wb_bsy_o = (_m_wb_stb_i && !m_wb_bsy_o);

always_ff @(posedge clk_i) begin
	if (rst_i)
		ack_pending <= 0;
	else if (_m_wb_stb_i_and_not_m_wb_bsy_o && m_wb_ack_o);
	else if (m_wb_ack_o)
		ack_pending <= ack_pending - 1'b1;
	else if (_m_wb_stb_i_and_not_m_wb_bsy_o)
		ack_pending <= ack_pending + 1'b1;
end

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] _s_wb_mapsz_i [SLAVECOUNT];
wire [WORDBITSZ -1 : 0]            _s_wb_dat_i   [SLAVECOUNT];

reg [CLOG2SLAVECOUNT -1 : 0] slvidx;

wire [CLOG2SLAVECOUNT -1 : 0] slvidx_plus_one = (slvidx + 1'b1);

reg slvidx_rdy;
reg slvidx_dflt;

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace [SLAVECOUNT];

reg addrspace_rdy;

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace_slvidx_lo; // Also used to initialize addrspace.
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace_slvidx_hi;

wire slvidx_not_max = (slvidx < (SLAVECOUNT-1));

// Determine whether slvidx needs to be recomputed.
wire slvidx_invalid = (!addrspace_rdy || (!slvidx_dflt &&
	!(m_wb_addr_i >= addrspace_slvidx_lo &&
	  m_wb_addr_i <= addrspace_slvidx_hi)));

wire _slvidx_invalid = (slvidx_invalid && !ack_pending);

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] addrspace_slvidx_nxt = (addrspace_slvidx_lo + _s_wb_mapsz_i[slvidx]);
wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] _addrspace_slvidx_nxt = (addrspace_slvidx_nxt - 1'b1);

reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] slvidx_dflt_lo;
reg [(ADDRBITSZ-MSBSZIGN) -1 : 0] slvidx_dflt_hi;

always_ff @(posedge clk_i) begin
	// Logic which on reset computes addrspace
	// using the size of each slave device mapping;
	// and after reset computes slvidx using addrspace.
	if (rst_i) begin

		addrspace_slvidx_lo <= FIRSTSLAVEADDR[CLOG2WORDBITSZBY8 +: (ADDRBITSZ-MSBSZIGN)];
		slvidx <= 0;
		slvidx_rdy <= 0;
		slvidx_dflt <= 0;
		addrspace_rdy <= 0;

	end else if (!addrspace_rdy) begin
		`ifdef _SIMULATION_WBMUX
		$write ("wb_mux: %d: 0x%08x: 0x%08x\n",
			slvidx, addrspace_slvidx_lo, _s_wb_mapsz_i[slvidx]);
		$fflush();
		`endif

		if (slvidx_not_max) begin
			addrspace_slvidx_lo <= addrspace_slvidx_nxt;
			slvidx <= slvidx_plus_one;
		end else begin
			addrspace_slvidx_lo <= FIRSTSLAVEADDR[CLOG2WORDBITSZBY8 +: (ADDRBITSZ-MSBSZIGN)];
			addrspace_slvidx_hi <= addrspace[0];
			slvidx <= 0;
			addrspace_rdy <= 1;
			// Next state will be for:
			// slvidx_rdy == 0 with slvidx == 0;
			// That state will compute slvidx as though it was due to slvidx_invalid;
			// this state set addrspace_slvidx_lo for the next state.
		end

		addrspace[slvidx] <= _addrspace_slvidx_nxt;

		if (slvidx == DEFAULTSLAVEINDEX) begin
			slvidx_dflt_lo <= addrspace_slvidx_lo;
			slvidx_dflt_hi <= _addrspace_slvidx_nxt;
		end

	end else if (!slvidx_rdy) begin

		if (!slvidx_invalid && _m_wb_stb_i)
			slvidx_rdy <= 1;
		else if (slvidx_not_max) begin
			addrspace_slvidx_lo <= addrspace[slvidx] + 1'b1;
			addrspace_slvidx_hi <= addrspace[slvidx_plus_one];
			slvidx <= slvidx_plus_one;
		end else begin
			addrspace_slvidx_lo <= slvidx_dflt_lo;
			addrspace_slvidx_hi <= slvidx_dflt_hi;
			slvidx <= DEFAULTSLAVEINDEX;
			slvidx_rdy <= 1;
			slvidx_dflt <= 1;
		end

	end else if (_m_wb_stb_i && _slvidx_invalid) begin

		addrspace_slvidx_lo <= FIRSTSLAVEADDR[CLOG2WORDBITSZBY8 +: (ADDRBITSZ-MSBSZIGN)];
		addrspace_slvidx_hi <= addrspace[0];
		slvidx <= 0;
		slvidx_rdy <= 0;

	end else if (slvidx_dflt)
		slvidx_dflt <= m_wb_bsy_o;
end

wire max_pending = (ack_pending == MAXPENDINGACK);

assign m_wb_bsy_o = ((slvidx_invalid ? 1'b1 : s_wb_bsy_i[slvidx]) || max_pending);
assign m_wb_ack_o = s_wb_ack_i[slvidx];
assign m_wb_dat_o = _s_wb_dat_i[slvidx];

wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] s_wb_addr_o_ = (m_wb_addr_i - addrspace_slvidx_lo);

genvar gen_s_wb_idx;
generate for (
	gen_s_wb_idx = 0;
	gen_s_wb_idx < SLAVECOUNT;
	gen_s_wb_idx = gen_s_wb_idx + 1) begin :gen_s_wb

assign s_wb_cyc_o[gen_s_wb_idx] = ((slvidx != gen_s_wb_idx || _slvidx_invalid) ? 1'b0 : m_wb_cyc_i);
assign s_wb_stb_o[gen_s_wb_idx] = ((slvidx != gen_s_wb_idx || slvidx_invalid || max_pending) ? 1'b0 : m_wb_stb_i);
assign s_wb_we_o[gen_s_wb_idx] = m_wb_we_i;
assign s_wb_addr_o[(gen_s_wb_idx * (ADDRBITSZ-MSBSZIGN)) +: (ADDRBITSZ-MSBSZIGN)] = s_wb_addr_o_;
assign s_wb_sel_o[(gen_s_wb_idx * (WORDBITSZ/8)) +: (WORDBITSZ/8)] = m_wb_sel_i;
assign s_wb_dat_o[(gen_s_wb_idx * WORDBITSZ) +: WORDBITSZ] = m_wb_dat_i;
assign _s_wb_dat_i[gen_s_wb_idx] = s_wb_dat_i[(gen_s_wb_idx * WORDBITSZ) +: WORDBITSZ];
assign _s_wb_mapsz_i[gen_s_wb_idx] = s_wb_mapsz_i[((gen_s_wb_idx * (WORDBITSZ-MSBSZIGN)) + CLOG2WORDBITSZBY8) +: (ADDRBITSZ-MSBSZIGN)];

end endgenerate

endmodule

`endif /* WB_MUX_V */
