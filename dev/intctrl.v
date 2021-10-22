// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

module intctrl (

	 rst_i

	,clk_i

	,pi1_op_i
	,pi1_addr_i
	,pi1_data_i
	,pi1_data_o
	,pi1_sel_i
	,pi1_rdy_o
	,pi1_mapsz_o

	,intrqstdst_o
	,intrdydst_i
	,intbestdst_i

	,intrqstsrc_i
	,intrdysrc_o
);

`include "lib/clog2.v"

parameter INTSRCCOUNT = 0;
parameter INTDSTCOUNT = 0;

localparam CLOG2INTSRCCOUNT = clog2(INTSRCCOUNT);
localparam CLOG2INTDSTCOUNT = clog2(INTDSTCOUNT);

parameter ARCHBITSZ = 32;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o = {ARCHBITSZ{1'b0}};
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

output wire [INTDSTCOUNT -1 : 0] intrqstdst_o;
input  wire [INTDSTCOUNT -1 : 0] intrdydst_i;
input  wire [INTDSTCOUNT -1 : 0] intbestdst_i;

input  wire [INTSRCCOUNT -1 : 0] intrqstsrc_i;
output wire [INTSRCCOUNT -1 : 0] intrdysrc_o;

assign pi1_rdy_o   = 1;

assign pi1_mapsz_o = 2;

reg [CLOG2INTSRCCOUNT -1 : 0] srcindex = {CLOG2INTSRCCOUNT{1'b0}};
reg [CLOG2INTDSTCOUNT -1 : 0] dstindex = {CLOG2INTDSTCOUNT{1'b0}};

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

localparam CMDACKINT = 2'b00;
localparam CMDINTDST = 2'b01;
localparam CMDENAINT = 2'b10;

wire ismemreadwriteop = (pi1_op_i == PIRWOP);

wire cmdackint = (ismemreadwriteop && pi1_data_i[1:0] == CMDACKINT);

wire cmdintdst = (ismemreadwriteop && pi1_data_i[1:0] == CMDINTDST);
reg [ARCHBITSZ -1 : 0] cmdintdstdata = {ARCHBITSZ{1'b0}};
wire cmdintdstseeking = (cmdintdstdata[1:0] == CMDINTDST && (dstindex != cmdintdstdata[(CLOG2INTDSTCOUNT +2) -1 : 2]));

wire cmdenaint = (ismemreadwriteop && pi1_data_i[1:0] == CMDENAINT);

reg intrqstpending = 0;

genvar gen_intrdysrc_o_idx;
generate for (gen_intrdysrc_o_idx = 0; gen_intrdysrc_o_idx < INTSRCCOUNT; gen_intrdysrc_o_idx = gen_intrdysrc_o_idx + 1) begin :gen_intrdysrc_o
assign intrdysrc_o[gen_intrdysrc_o_idx] = !(srcindex == gen_intrdysrc_o_idx && intrqstpending && cmdintdstdata[1:0] != CMDINTDST);
end endgenerate

genvar gen_intrqstdst_o_idx;
generate for (gen_intrqstdst_o_idx = 0; gen_intrqstdst_o_idx < INTDSTCOUNT; gen_intrqstdst_o_idx = gen_intrqstdst_o_idx + 1) begin :gen_intrqstdst_o
assign intrqstdst_o[gen_intrqstdst_o_idx] = (dstindex == gen_intrqstdst_o_idx && intrqstpending);
end endgenerate

wire [CLOG2INTSRCCOUNT -1 : 0] nextsrcindex =
	((srcindex < (INTSRCCOUNT-1)) ? (srcindex + 1'b1) : {CLOG2INTSRCCOUNT{1'b0}});
wire [CLOG2INTDSTCOUNT -1 : 0] nextdstindex =
	((dstindex < (INTDSTCOUNT-1)) ? (dstindex + 1'b1) : {CLOG2INTDSTCOUNT{1'b0}});

reg [INTSRCCOUNT -1 : 0] intsrcen = {INTSRCCOUNT{1'b0}};
reg [INTDSTCOUNT -1 : 0] intdsten = {INTDSTCOUNT{1'b0}};

always @ (posedge clk_i) begin
	if (rst_i) begin
		intrqstpending <= 1'b0;
		cmdintdstdata <= {ARCHBITSZ{1'b0}};
		intsrcen <= {INTSRCCOUNT{1'b0}};
		intdsten <= {INTDSTCOUNT{1'b0}};
	end else if (cmdenaint) begin
		if (pi1_data_i[ARCHBITSZ -1 : 3] < INTSRCCOUNT) begin
			intsrcen[pi1_data_i[(CLOG2INTSRCCOUNT +3) -1 : 3]] <= pi1_data_i[2];
			pi1_data_o <= {{(ARCHBITSZ-CLOG2INTSRCCOUNT){1'b0}}, pi1_data_i[(CLOG2INTSRCCOUNT +3) -1 : 3]};
		end else
			pi1_data_o <= {ARCHBITSZ{1'b1}};
	end else if (cmdintdst) begin
		if (pi1_data_i[ARCHBITSZ -1 : 2] < INTDSTCOUNT) begin
			if (intrqstpending) begin
				pi1_data_o <= {{(ARCHBITSZ-1){1'b1}}, 1'b0};
			end else begin
				pi1_data_o <= {{(ARCHBITSZ-CLOG2INTDSTCOUNT){1'b0}}, pi1_data_i[(CLOG2INTDSTCOUNT +2) -1 : 2]};
				intrqstpending <= 1'b1;
				cmdintdstdata <= pi1_data_i;
			end
		end else
			pi1_data_o <= {ARCHBITSZ{1'b1}};
	end else if (cmdintdstseeking) begin
		dstindex <= nextdstindex;
	end else if (intrqstpending || cmdackint) begin
		if (cmdackint) begin
			if (pi1_data_i[ARCHBITSZ -1 : 3] == dstindex) begin
				pi1_data_o <= ((cmdintdstdata[1:0] == CMDINTDST) ? {ARCHBITSZ{1'b1}} :
					{{(ARCHBITSZ-CLOG2INTSRCCOUNT){1'b0}}, srcindex});
				intrqstpending <= 1'b0;
				cmdintdstdata <= {ARCHBITSZ{1'b0}};
				dstindex <= {CLOG2INTDSTCOUNT{1'b0}};
				srcindex <= nextsrcindex;
			end else begin
				pi1_data_o <= {{(ARCHBITSZ-1){1'b1}}, 1'b0};
			end
			if (pi1_data_i[ARCHBITSZ -1 : 3] < INTDSTCOUNT)
				intdsten[pi1_data_i[(CLOG2INTDSTCOUNT +3) -1 : 3]] <= pi1_data_i[2];
		end
	end else if (intsrcen[srcindex] && intrqstsrc_i[srcindex]) begin
		if (intdsten[dstindex] && ((!(intbestdst_i & intdsten) && intrdydst_i[dstindex]) || intbestdst_i[dstindex]))
			intrqstpending <= 1'b1;
		else
			dstindex <= nextdstindex;
	end else
		srcindex <= nextsrcindex;
end

endmodule
