// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// Device Table.
// It maps the first RAM device at 0x1000 by adjusting its mmapsz_o.

module devtbl (

	 clk_i

	,rst_i

	,rst0_o
	,rst1_o
	,rst2_o

	,wb_cyc_i
	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,mmapsz_o

	,devtbl_id_flat_i
	,devtbl_mapsz_flat_i
	,devtbl_useintr_flat_i
);

`include "lib/clog2.v"

parameter ARCHBITSZ   = 16;
parameter RAMCACHESZ  = 2; // Size of the RAM cache in (ARCHBITSZ/8) bytes.
parameter PRELDRADDR  = 0; // Address of pre-loader in bytes.
parameter DEVMAPCNT   = 3; // Number of device mappings; must be >= 3 and <= (((4096-1024)/(ARCHBITSZ/8))/2).
parameter SOCID       = 0;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire clk_i;

input wire rst_i;

output reg rst0_o;
output reg rst1_o;
output reg rst2_o;

input  wire                        wb_cyc_i;
input  wire                        wb_stb_i;
input  wire                        wb_we_i;
input  wire [ADDRBITSZ -1 : 0]     wb_addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb_sel_i;
input  wire [ARCHBITSZ -1 : 0]     wb_dat_i;
output wire                        wb_bsy_o;
output reg                         wb_ack_o;
output reg  [ARCHBITSZ -1 : 0]     wb_dat_o;

output reg  [ARCHBITSZ -1 : 0] mmapsz_o;

input wire [(ARCHBITSZ * DEVMAPCNT) -1 : 0] devtbl_id_flat_i;
input wire [(ARCHBITSZ * DEVMAPCNT) -1 : 0] devtbl_mapsz_flat_i /* verilator lint_off UNOPTFLAT */;
input wire [DEVMAPCNT -1 : 0]               devtbl_useintr_flat_i;

assign wb_bsy_o = 1'b0;

wire [ARCHBITSZ -1 : 0] devtbl_id_w      [DEVMAPCNT -1 : 0];
wire [ARCHBITSZ -1 : 0] devtbl_mapsz_w   [DEVMAPCNT -1 : 0];
wire [DEVMAPCNT -1 : 0] devtbl_useintr_w;

localparam BLKDEVMAPSZ = 1024;

reg [ARCHBITSZ -1 : 0] mmapsz_o_; // ### comb-block-reg.
reg [ARCHBITSZ -1 : 0] gen_mmapsz_o_idx_max; // ### comb-block-reg.
integer gen_mmapsz_o_idx;
always @* begin
	mmapsz_o_ = (4096 - BLKDEVMAPSZ); /* first 2 devices must be Block and DevTbl devices */
	gen_mmapsz_o_idx_max = DEVMAPCNT;
	for (
		gen_mmapsz_o_idx = 2;
		gen_mmapsz_o_idx < DEVMAPCNT;
		gen_mmapsz_o_idx = gen_mmapsz_o_idx + 1) begin :gen_mmapsz_o
		if (devtbl_id_w[gen_mmapsz_o_idx] == 1 /* stops at the first RAM device */)
			gen_mmapsz_o_idx_max = gen_mmapsz_o_idx;
		if (gen_mmapsz_o_idx < gen_mmapsz_o_idx_max)
			mmapsz_o_ = (mmapsz_o_ - devtbl_mapsz_w[gen_mmapsz_o_idx]);
	end
end
always @ (posedge clk_i) begin
	mmapsz_o <= mmapsz_o_;
end

genvar gen_devtbl_id_w_idx;
generate for (gen_devtbl_id_w_idx = 0; gen_devtbl_id_w_idx < DEVMAPCNT; gen_devtbl_id_w_idx = gen_devtbl_id_w_idx + 1) begin :gen_devtbl_id_w
assign devtbl_id_w[gen_devtbl_id_w_idx] = devtbl_id_flat_i[((gen_devtbl_id_w_idx+1) * ARCHBITSZ) -1 : gen_devtbl_id_w_idx * ARCHBITSZ];
end endgenerate

genvar gen_devtbl_mapsz_w_idx;
generate for (gen_devtbl_mapsz_w_idx = 2; gen_devtbl_mapsz_w_idx < DEVMAPCNT; gen_devtbl_mapsz_w_idx = gen_devtbl_mapsz_w_idx + 1) begin :gen_devtbl_mapsz_w
assign devtbl_mapsz_w[gen_devtbl_mapsz_w_idx] = devtbl_mapsz_flat_i[((gen_devtbl_mapsz_w_idx+1) * ARCHBITSZ) -1 : gen_devtbl_mapsz_w_idx * ARCHBITSZ];
end endgenerate

assign devtbl_useintr_w = devtbl_useintr_flat_i;

reg                    wb_stb_r;
reg                    wb_we_r;
reg [ADDRBITSZ -1 : 0] wb_addr_r;
reg [ARCHBITSZ -1 : 0] wb_dat_r;

wire wb_stb_r_ = (wb_cyc_i && wb_stb_i);

always @ (posedge clk_i) begin
	wb_stb_r <= wb_stb_r_ ;
	if (wb_stb_r_) begin
		wb_we_r <= wb_we_i;
		wb_addr_r <= wb_addr_i;
		wb_dat_r <= wb_dat_i;
	end
	wb_ack_o <= wb_stb_r;
end

`include "version.v"

reg rst2_r = 0; // Gets reset globally to run pre-loader only once.

reg rdsel;

wire [(ADDRBITSZ -1) -1 : 0] addrby2 = wb_addr_r[ADDRBITSZ-1:1];

always @ (posedge clk_i) begin
	if (rst_i) begin
		rst0_o <= 0;
		rst1_o <= 0;
		rdsel <= 0;
	end else if (wb_stb_r) begin
		if (wb_we_r) begin // CMDS.
			if (wb_dat_r == 0) begin // PWROFF.
				rst0_o <= 1;
				rst1_o <= 0;
			end else if (wb_dat_r == 1) begin // WRESET.
				rst0_o <= 0;
				rst1_o <= 1;
			end else if (wb_dat_r == 2) begin // CRESET.
				rst0_o <= 1;
				rst1_o <= 1;
			end else if (wb_dat_r == 3) begin // RRESET.
				rst2_r <= 1;
			end else if (wb_dat_r == 4) begin // RDSELINFO.
				rdsel <= 1;
			end else /* if (wb_dat_r == 5) */ begin // RDSELDEVS.
				rdsel <= 0;
			end
		end else begin
			if (rdsel) begin // INFO.
				if (wb_addr_r == 0)
					wb_dat_o <= SOCVERSION;
				else if (wb_addr_r == 1)
					wb_dat_o <= RAMCACHESZ;
				else if (wb_addr_r == 2)
					wb_dat_o <= {rst1_o, rst0_o};
				else if (wb_addr_r == 3)
					wb_dat_o <= (rst2_r ? 0 : PRELDRADDR); // After RRESET return 0 instead of PRELDRADDR.
				else if (wb_addr_r == 4)
					wb_dat_o <= SOCID;
				else
					wb_dat_o <= 0;
			end else begin // DEVS.
				if (addrby2 >= DEVMAPCNT)
					wb_dat_o <= 0;
				else if (wb_addr_r[0] == 0) // Return DevID.
					wb_dat_o <= devtbl_id_w[addrby2];
				else // Return DevMapSz and DevUseIntr.
					wb_dat_o <= {(
						(addrby2 == 0) ? BLKDEVMAPSZ :
						(addrby2 == 1) ? mmapsz_o : devtbl_mapsz_w[addrby2])>>1,
						devtbl_useintr_w[addrby2]};
			end
		end
	end
	rst2_o <= (!rst_i && wb_stb_r && wb_we_r && wb_dat_r == 3/* RRESET */);
end

endmodule
