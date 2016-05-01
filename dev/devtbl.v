// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Device Table.
// It maps the first RAM device at 0x1000 by adjusting its pi1_mapsz_o.

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
	,pi1_sel_i  /* not used */
	,pi1_rdy_o
	,pi1_mapsz_o

	,devtbl_id_flat_i
	,devtbl_mapsz_flat_i
	,devtbl_useintr_flat_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ   = 0;
parameter RAMCACHESZ  = 0; // Size of the RAM cache in (ARCHBITSZ/8) bytes.
parameter PRELDRADDR  = 0; // Address of pre-loader.
parameter DEVMAPCNT   = 2; // Number of device mappings; must be <= (((4096-512)/(ARCHBITSZ/8))-1).

initial begin
	if (!(DEVMAPCNT <= (((4096-512)/(ARCHBITSZ/8))-1)))
		$finish;
end

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire clk_i;

input wire rst_i;

output reg  rst0_o;
output reg  rst1_o;
output wire rst2_o;

reg rst2_r = 0; // Reset globally only to match behavior with RAM.

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = 0;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;  /* not used */
output wire                        pi1_rdy_o;
output reg  [ADDRBITSZ -1 : 0]     pi1_mapsz_o; // ### declared as reg so as to be usable by verilog within the always block.

input wire [(ARCHBITSZ * DEVMAPCNT) -1 : 0] devtbl_id_flat_i;
input wire [(ADDRBITSZ * DEVMAPCNT) -1 : 0] devtbl_mapsz_flat_i /* verilator lint_off UNOPTFLAT */;
input wire [DEVMAPCNT -1 : 0]               devtbl_useintr_flat_i;

assign pi1_rdy_o = 1;

wire [ARCHBITSZ -1 : 0] devtbl_id_w      [DEVMAPCNT -1 : 0];
wire [ADDRBITSZ -1 : 0] devtbl_mapsz_w   [DEVMAPCNT -1 : 0];
wire [DEVMAPCNT -1 : 0] devtbl_useintr_w;

localparam BLOCKDEVMAPSZ = (512/(ARCHBITSZ/8));

integer gen_pi1_mapsz_o_idx;
always @* begin
	pi1_mapsz_o = (4096/(ARCHBITSZ/8) - BLOCKDEVMAPSZ); /* first 2 devices must be 512B-Block and DevTbl devices */
	for (
		gen_pi1_mapsz_o_idx = 2;
		(gen_pi1_mapsz_o_idx < DEVMAPCNT && devtbl_id_w[gen_pi1_mapsz_o_idx] != 1 /* stops at the first RAM device */);
		gen_pi1_mapsz_o_idx = gen_pi1_mapsz_o_idx + 1) begin :gen_pi1_mapsz_o
		pi1_mapsz_o = pi1_mapsz_o - devtbl_mapsz_w[gen_pi1_mapsz_o_idx];
	end
end

genvar gen_devtbl_id_w_idx;
generate for (gen_devtbl_id_w_idx = 0; gen_devtbl_id_w_idx < DEVMAPCNT; gen_devtbl_id_w_idx = gen_devtbl_id_w_idx + 1) begin :gen_devtbl_id_w
assign devtbl_id_w[gen_devtbl_id_w_idx] = devtbl_id_flat_i[((gen_devtbl_id_w_idx+1) * ARCHBITSZ) -1 : gen_devtbl_id_w_idx * ARCHBITSZ];
end endgenerate

genvar gen_devtbl_mapsz_w_idx;
generate for (gen_devtbl_mapsz_w_idx = 2; gen_devtbl_mapsz_w_idx < DEVMAPCNT; gen_devtbl_mapsz_w_idx = gen_devtbl_mapsz_w_idx + 1) begin :gen_devtbl_mapsz_w
assign devtbl_mapsz_w[gen_devtbl_mapsz_w_idx] = devtbl_mapsz_flat_i[((gen_devtbl_mapsz_w_idx+1) * ADDRBITSZ) -1 : gen_devtbl_mapsz_w_idx * ADDRBITSZ];
end endgenerate

assign devtbl_useintr_w = devtbl_useintr_flat_i;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

`include "version.v"

wire [ADDRBITSZ -1 : 0] addrby2;
assign addrby2 = (pi1_addr_i>>1);

always @ (posedge clk_i) begin
	if (rst_i) begin
		rst0_o <= 0;
		rst1_o <= 0;
	end else if (pi1_rdy_o && pi1_op_i == PIRDOP) begin
		if (addrby2 >= DEVMAPCNT)
			pi1_data_o <= 0;
		else if (pi1_addr_i[0] == 0) // Return DevID.
			pi1_data_o <= devtbl_id_w[addrby2];
		else // Return DevMapSz and DevUseIntr.
			pi1_data_o <= {(
				(addrby2 == 0) ? BLOCKDEVMAPSZ[ADDRBITSZ -1 : 0] :
				(addrby2 == 1) ? pi1_mapsz_o : devtbl_mapsz_w[addrby2]),
				{(CLOG2ARCHBITSZBY8-1){1'b0}},
				devtbl_useintr_w[addrby2]};
	end else if (pi1_rdy_o && pi1_op_i == PIRWOP) begin
		if (pi1_addr_i == 0) begin // INFO.
			if (pi1_data_i == 0)
				pi1_data_o <= SOCVERSION;
			else if (pi1_data_i == 1)
				pi1_data_o <= RAMCACHESZ;
			else if (pi1_data_i == 2)
				pi1_data_o <= {rst1_o, rst0_o};
			else if (pi1_data_i == 3)
				pi1_data_o <= (rst2_r ? 0 : PRELDRADDR); // After RRESET return 0 instead PRELDRADDR.
			else
				pi1_data_o <= 0;
		end else if (pi1_addr_i == 1) begin // ACTION.
			if (pi1_data_i == 0) begin // PWROFF.
				rst0_o <= 1;
				rst1_o <= 0;
			end else if (pi1_data_i == 1) begin // WRESET.
				rst0_o <= 0;
				rst1_o <= 1;
			end else if (pi1_data_i == 2) begin // CRESET.
				rst0_o <= 1;
				rst1_o <= 1;
			end else if (pi1_data_i == 3) begin // RRESET.
				rst2_r <= 1;
			end
			pi1_data_o <= 0;
		end else
			pi1_data_o <= 0;
	end
end

assign rst2_o = (pi1_rdy_o && pi1_op_i == PIRWOP && pi1_addr_i == 1 && pi1_data_i == 3/* RRESET */);

endmodule
