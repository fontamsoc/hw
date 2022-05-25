// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Device Table.
// It maps the first RAM device at 0x1000 by adjusting its pi1_mapsz_o.

`include "lib/perint/pi1b.v"

`include "lib/addr.v"

module devtbl (

	 clk_i

	,rst_i

	,rst0_o
	,rst1_o
	,rst2_o

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,devtbl_id_flat_i
	,devtbl_mapsz_flat_i
	,devtbl_useintr_flat_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ   = 16;
parameter XARCHBITSZ  = 16; // Used by pi1_*  and devtbl_* signals; must be >= ARCHBITSZ.
parameter RAMCACHESZ  = 2;  // Size of the RAM cache in (ARCHBITSZ/8) bytes.
parameter PRELDRADDR  = 0;  // Address of pre-loader in bytes.
parameter DEVMAPCNT   = 2;  // Number of device mappings.
parameter SOCID       = 0;

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8 = clog2(XARCHBITSZ/8);
localparam XADDRBITSZ = (XARCHBITSZ-CLOG2XARCHBITSZBY8);

localparam CLOG2XARCHBITSZBY8DIFF = (CLOG2XARCHBITSZBY8 - CLOG2ARCHBITSZBY8);

input wire clk_i;

input wire rst_i;

output reg rst0_o;
output reg rst1_o;
output reg rst2_o;

reg rst2_r = 0; // Reset globally only to match behavior with RAM.

input  wire [2 -1 : 0]              pi1_op_i;
input  wire [XADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [XARCHBITSZ -1 : 0]     pi1_data_i;
output wire [XARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(XARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                         pi1_rdy_o;
output reg  [XARCHBITSZ -1 : 0]     pi1_mapsz_o;

wire [2 -1 : 0]              pi1b_op_i;
wire [XADDRBITSZ -1 : 0]     pi1b_addr_i;
wire [XARCHBITSZ -1 : 0]     pi1b_data_o;
wire [XARCHBITSZ -1 : 0]     pi1b_data_i;
wire [(XARCHBITSZ/8) -1 : 0] pi1b_sel_i;
wire                         pi1b_rdy_o;

pi1b #(

	.ARCHBITSZ (XARCHBITSZ)

) pi1b (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.m_op_i (pi1_op_i)
	,.m_addr_i (pi1_addr_i)
	,.m_data_i (pi1_data_i)
	,.m_data_o (pi1_data_o)
	,.m_sel_i (pi1_sel_i)
	,.m_rdy_o (pi1_rdy_o)

	,.s_op_o (pi1b_op_i)
	,.s_addr_o (pi1b_addr_i)
	,.s_data_o (pi1b_data_i)
	,.s_data_i (pi1b_data_o)
	,.s_sel_o (pi1b_sel_i)
	,.s_rdy_i (pi1b_rdy_o)
);

assign pi1b_rdy_o = 1;

input wire [(XARCHBITSZ * DEVMAPCNT) -1 : 0] devtbl_id_flat_i;
input wire [(XARCHBITSZ * DEVMAPCNT) -1 : 0] devtbl_mapsz_flat_i /* verilator lint_off UNOPTFLAT */;
input wire [DEVMAPCNT -1 : 0]                devtbl_useintr_flat_i;

wire [XARCHBITSZ -1 : 0] pi1b_addr_w;

addr #(
	.ARCHBITSZ (XARCHBITSZ)
) addr (
	 .addr_i (pi1b_addr_i)
	,.sel_i  (pi1b_sel_i)
	,.addr_o (pi1b_addr_w)
);

wire [XARCHBITSZ -1 : 0] devtbl_id_w      [DEVMAPCNT -1 : 0];
wire [XARCHBITSZ -1 : 0] devtbl_mapsz_w   [DEVMAPCNT -1 : 0];
wire [DEVMAPCNT -1 : 0]  devtbl_useintr_w;

localparam BLOCKDEVMAPSZ = 512;

reg [XARCHBITSZ -1 : 0] pi1_mapsz_o_; // ### declared as reg so as to be usable by verilog within the always block.
reg [XARCHBITSZ -1 : 0] gen_pi1_mapsz_o_idx_max; // ### declared as reg so as to be usable by verilog within the always block.
integer gen_pi1_mapsz_o_idx;
always @* begin
	pi1_mapsz_o_ = (4096 - BLOCKDEVMAPSZ); /* first 2 devices must be 512B-Block and DevTbl devices */
	gen_pi1_mapsz_o_idx_max = DEVMAPCNT;
	for (
		gen_pi1_mapsz_o_idx = 2;
		(gen_pi1_mapsz_o_idx < DEVMAPCNT);
		gen_pi1_mapsz_o_idx = gen_pi1_mapsz_o_idx + 1) begin :gen_pi1_mapsz_o
		if (devtbl_id_w[gen_pi1_mapsz_o_idx] == 1 /* stops at the first RAM device */)
			gen_pi1_mapsz_o_idx_max = gen_pi1_mapsz_o_idx;
		if (gen_pi1_mapsz_o_idx < gen_pi1_mapsz_o_idx_max)
			pi1_mapsz_o_ = (pi1_mapsz_o_ - devtbl_mapsz_w[gen_pi1_mapsz_o_idx]);
	end
end

genvar gen_devtbl_id_w_idx;
generate for (gen_devtbl_id_w_idx = 0; gen_devtbl_id_w_idx < DEVMAPCNT; gen_devtbl_id_w_idx = gen_devtbl_id_w_idx + 1) begin :gen_devtbl_id_w
assign devtbl_id_w[gen_devtbl_id_w_idx] = devtbl_id_flat_i[((gen_devtbl_id_w_idx+1) * XARCHBITSZ) -1 : gen_devtbl_id_w_idx * XARCHBITSZ];
end endgenerate

genvar gen_devtbl_mapsz_w_idx;
generate for (gen_devtbl_mapsz_w_idx = 2; gen_devtbl_mapsz_w_idx < DEVMAPCNT; gen_devtbl_mapsz_w_idx = gen_devtbl_mapsz_w_idx + 1) begin :gen_devtbl_mapsz_w
assign devtbl_mapsz_w[gen_devtbl_mapsz_w_idx] = devtbl_mapsz_flat_i[((gen_devtbl_mapsz_w_idx+1) * XARCHBITSZ) -1 : gen_devtbl_mapsz_w_idx * XARCHBITSZ];
end endgenerate

assign devtbl_useintr_w = devtbl_useintr_flat_i;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

`include "version.v"

// upconverter logic.
reg [XARCHBITSZ -1 : 0] pi1b_addr_w_hold;
reg [XARCHBITSZ -1 : 0] data_w0;
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w0_shift = {pi1b_addr_w_hold[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
assign pi1b_data_o = (data_w0 << data_w0_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]);
wire [((CLOG2XARCHBITSZBY8-CLOG2ARCHBITSZBY8)+CLOG2ARCHBITSZ):0] data_w1_shift = {pi1b_addr_w[CLOG2XARCHBITSZBY8:CLOG2ARCHBITSZBY8], {CLOG2ARCHBITSZ{1'b0}}};
wire [XARCHBITSZ -1 : 0] data_w1 = (pi1b_data_i >> data_w1_shift[(CLOG2XARCHBITSZBY8DIFF+CLOG2ARCHBITSZ)-1:0]);

wire [ADDRBITSZ -2 : 0] addr_w = pi1b_addr_w[ADDRBITSZ-1:CLOG2ARCHBITSZBY8];
wire [ADDRBITSZ -2 : 0] addrby2 = pi1b_addr_w[ADDRBITSZ-1:1+CLOG2ARCHBITSZBY8];

always @ (posedge clk_i) begin
	pi1_mapsz_o <= pi1_mapsz_o_;
	if (pi1b_rdy_o)
		pi1b_addr_w_hold <= pi1b_addr_w;
	if (rst_i) begin
		rst0_o <= 0;
		rst1_o <= 0;
	end else if (pi1b_rdy_o && pi1b_op_i == PIRDOP) begin
		if (addrby2 >= DEVMAPCNT)
			data_w0 <= 0;
		else if (addr_w[0] == 0) // Return DevID.
			data_w0 <= devtbl_id_w[addrby2];
		else // Return DevMapSz and DevUseIntr.
			data_w0 <= {(
				(addrby2 == 0) ? BLOCKDEVMAPSZ :
				(addrby2 == 1) ? pi1_mapsz_o : devtbl_mapsz_w[addrby2])>>1,
				devtbl_useintr_w[addrby2]};
	end else if (pi1b_rdy_o && pi1b_op_i == PIRWOP) begin
		if (addr_w == 0) begin // INFO.
			if (data_w1 == 0)
				data_w0 <= SOCVERSION;
			else if (data_w1 == 1)
				data_w0 <= RAMCACHESZ;
			else if (data_w1 == 2)
				data_w0 <= {rst1_o, rst0_o};
			else if (data_w1 == 3)
				data_w0 <= (rst2_r ? 0 : PRELDRADDR); // After RRESET return 0 instead PRELDRADDR.
			else if (data_w1 == 4)
				data_w0 <= SOCID;
			else
				data_w0 <= 0;
		end else if (addr_w == 1) begin // ACTION.
			if (data_w1 == 0) begin // PWROFF.
				rst0_o <= 1;
				rst1_o <= 0;
			end else if (data_w1 == 1) begin // WRESET.
				rst0_o <= 0;
				rst1_o <= 1;
			end else if (data_w1 == 2) begin // CRESET.
				rst0_o <= 1;
				rst1_o <= 1;
			end else if (data_w1 == 3) begin // RRESET.
				rst2_r <= 1;
			end
			data_w0 <= 0;
		end else
			data_w0 <= 0;
	end
	rst2_o <= (pi1b_rdy_o && pi1b_op_i == PIRWOP && addr_w == 1 && data_w1 == 3/* RRESET */);
end

endmodule
