// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

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
);

`include "lib/clog2.v"

parameter ARCHBITSZ   = 0;
parameter RAMSZ       = 0;
parameter RAMCACHESZ  = 0;
parameter PRELDRADDR  = 0;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

localparam DMADEVMAPSZ = 4;
localparam TINYDEVMAPSZ = (1*(64/ARCHBITSZ));
localparam DEVTBLMAPSZ = (((4096-512)/(ARCHBITSZ/8)) - (DMADEVMAPSZ +TINYDEVMAPSZ +TINYDEVMAPSZ));
localparam CLOG2DEVTBLMAPSZ = clog2(DEVTBLMAPSZ);

input wire clk_i;

input wire rst_i;

output reg  rst0_o;
output reg  rst1_o;
output wire rst2_o;

reg  rst2_r = 0;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = 0;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

assign pi1_rdy_o = 1;

assign pi1_mapsz_o = DEVTBLMAPSZ;

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

wire[(CLOG2DEVTBLMAPSZ - 1) -1 : 0] addrby2 = (pi1_addr_i>>1);

localparam BLOCKDEVMAPSZ = (512/(ARCHBITSZ/8));

`include "version.v"

always @ (posedge clk_i) begin
	if (rst_i) begin
		rst0_o <= 0;
		rst1_o <= 0;
	end else if (pi1_rdy_o && pi1_op_i == PIRDOP) begin
		if (addrby2 == 0) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 4;
			else
				pi1_data_o <= {BLOCKDEVMAPSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b1};
		end else if (addrby2 == 1) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 7;
			else
				pi1_data_o <= {DEVTBLMAPSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b0};
		end else if (addrby2 == 2) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 2;
			else
				pi1_data_o <= {DMADEVMAPSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b1};
		end else if (addrby2 == 3) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 3;
			else
				pi1_data_o <= {TINYDEVMAPSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b0};
		end else if (addrby2 == 4) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 5;
			else
				pi1_data_o <= {TINYDEVMAPSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b1};
		end else if (addrby2 == 5) begin
			if (pi1_addr_i[0] == 0)
				pi1_data_o <= 1;
			else
				pi1_data_o <= {RAMSZ[ADDRBITSZ -1 : 0], {(CLOG2ARCHBITSZBY8-1){1'b0}}, 1'b0};
		end else
			pi1_data_o <= 0;
	end else if (pi1_rdy_o && pi1_op_i == PIRWOP) begin
		if (pi1_addr_i == 0) begin
			if (pi1_data_i == 0)
				pi1_data_o <= SOCVERSION;
			else if (pi1_data_i == 1)
				pi1_data_o <= RAMCACHESZ;
			else if (pi1_data_i == 2)
				pi1_data_o <= {rst1_o, rst0_o};
			else if (pi1_data_i == 3)
				pi1_data_o <= (rst2_r ? 0 : PRELDRADDR);
			else
				pi1_data_o <= 0;
		end else if (pi1_addr_i == 1) begin
			if (pi1_data_i == 0) begin
				rst0_o <= 1;
				rst1_o <= 0;
			end else if (pi1_data_i == 1) begin
				rst0_o <= 0;
				rst1_o <= 1;
			end else if (pi1_data_i == 2) begin
				rst0_o <= 1;
				rst1_o <= 1;
			end else if (pi1_data_i == 3) begin
				rst2_r <= 1;
			end
			pi1_data_o <= 0;
		end else
			pi1_data_o <= 0;
	end
end

assign rst2_o = (pi1_rdy_o && pi1_op_i == PIRWOP && pi1_addr_i == 1 && pi1_data_i == 3);

endmodule
