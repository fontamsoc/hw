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

reg [CLOG2INTDSTCOUNT -1 : 0] dstindexhi = {CLOG2INTDSTCOUNT{1'b0}};

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

wire ismemreadwriteop = (pi1_op_i == PIRWOP);

wire cmdintdst = (ismemreadwriteop && pi1_data_i[0]);
reg [ARCHBITSZ -1 : 0] cmddata = {ARCHBITSZ{1'b0}};
wire cmdintdstpending = (cmddata[0] && (dstindex != cmddata[CLOG2INTDSTCOUNT : 1]));

reg intrqstpending = 0;

genvar i;

generate for (i = 0; i < INTSRCCOUNT; i = i + 1) begin :gen_intrdysrc_o
assign intrdysrc_o[i] = !(srcindex == i && intrqstpending && !cmddata[0]);
end endgenerate

generate for (i = 0; i < INTDSTCOUNT; i = i + 1) begin :gen_intrqstdst_o
assign intrqstdst_o[i] = (dstindex == i && intrqstpending);
end endgenerate

wire [CLOG2INTSRCCOUNT -1 : 0] nextsrcindex =
	((srcindex < (INTSRCCOUNT-1)) ? (srcindex + 1'b1) : {CLOG2INTSRCCOUNT{1'b0}});
wire [CLOG2INTDSTCOUNT -1 : 0] nextdstindex =
	((dstindex < dstindexhi) ? (dstindex + 1'b1) : {CLOG2INTDSTCOUNT{1'b0}});

wire [INTDSTCOUNT -1 : 0] intbestdst_w;
generate for (i = 0; i < INTDSTCOUNT; i = i + 1) begin :gen_intbestdst_w
assign intbestdst_w[i] = (intbestdst_i[i] && (i <= dstindexhi));
end endgenerate

always @ (posedge clk_i) begin
	if (rst_i) begin
		intrqstpending <= 1'b0;
		cmddata <= {ARCHBITSZ{1'b0}};
		dstindexhi <= {CLOG2INTDSTCOUNT{1'b0}};
	end else if (cmdintdst) begin
		if (pi1_data_i[CLOG2INTDSTCOUNT : 1] < INTDSTCOUNT) begin
			pi1_data_o <= {{(ARCHBITSZ-CLOG2INTDSTCOUNT){1'b0}}, pi1_data_i[CLOG2INTDSTCOUNT : 1]};
			intrqstpending <= 1'b1;
			cmddata <= pi1_data_i;
			if (pi1_data_i[CLOG2INTDSTCOUNT : 1] > dstindexhi)
				dstindexhi <= pi1_data_i[CLOG2INTDSTCOUNT : 1];
		end else
			pi1_data_o <= {ARCHBITSZ{1'b1}};
	end else if (cmdintdstpending) begin
		dstindex <= nextdstindex;
	end else if (intrqstpending) begin
		if (ismemreadwriteop) begin
			pi1_data_o <= (cmddata[0] ? {ARCHBITSZ{1'b1}} :
				{{(ARCHBITSZ-CLOG2INTSRCCOUNT){1'b0}}, srcindex});
			intrqstpending <= 1'b0;
			cmddata <= {ARCHBITSZ{1'b0}};
			dstindex <= {CLOG2INTDSTCOUNT{1'b0}};
			srcindex <= nextsrcindex;
		end
	end else if (intrqstsrc_i[srcindex]) begin
		if ((!intbestdst_w && intrdydst_i[dstindex]) || intbestdst_i[dstindex])
			intrqstpending <= 1'b1;
		else
			dstindex <= nextdstindex;
	end else
		srcindex <= nextsrcindex;
end

endmodule
