// Copyright (c) William Fonkou Tambe
// All rights reserved.

`ifndef PI1R_V
`define PI1R_V

module pi1r (

	 rst_i

	,clk_i

	,m_op_i_flat
	,m_addr_i_flat
	,m_data_i_flat
	,m_data_o_flat
	,m_sel_i_flat
	,m_rdy_o_flat

	,s_op_o_flat
	,s_addr_o_flat
	,s_data_o_flat
	,s_data_i_flat
	,s_sel_o_flat
	,s_rdy_i_flat
	,s_mapsz_o_flat
);

`include "lib/clog2.v"

parameter MASTERCOUNT       = 1;
parameter SLAVECOUNT        = 1;
parameter DEFAULTSLAVEINDEX = 0;
parameter FIRSTSLAVEADDR    = 0;

parameter ARCHBITSZ = 32;

localparam CLOG2MASTERCOUNT = clog2(MASTERCOUNT);
localparam CLOG2SLAVECOUNT  = clog2(SLAVECOUNT);

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

input wire clk_i;

input  wire [(2 * MASTERCOUNT) -1 : 0]             m_op_i_flat;
input  wire [(ADDRBITSZ * MASTERCOUNT) -1 : 0]     m_addr_i_flat;
input  wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_i_flat;
output wire [(ARCHBITSZ * MASTERCOUNT) -1 : 0]     m_data_o_flat;
input  wire [((ARCHBITSZ/8) * MASTERCOUNT) -1 : 0] m_sel_i_flat;
output wire [MASTERCOUNT -1 : 0]                   m_rdy_o_flat;

output wire [(2 * SLAVECOUNT) -1 : 0]             s_op_o_flat;
output wire [(ADDRBITSZ * SLAVECOUNT) -1 : 0]     s_addr_o_flat;
input  wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_data_i_flat;
output wire [(ARCHBITSZ * SLAVECOUNT) -1 : 0]     s_data_o_flat;
output wire [((ARCHBITSZ/8) * SLAVECOUNT) -1 : 0] s_sel_o_flat;
input  wire [SLAVECOUNT -1 : 0]                   s_rdy_i_flat;
input  wire [(ADDRBITSZ * SLAVECOUNT) -1 : 0]     s_mapsz_o_flat;

genvar i;

wire [2 -1 : 0] masterop [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masterop
assign masterop[i] = m_op_i_flat[((i+1) * 2) -1 : i * 2];
end endgenerate

wire [ADDRBITSZ -1 : 0] masteraddr [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masteraddr
assign masteraddr[i] = m_addr_i_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdati [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masterdati
assign masterdati[i] = m_data_i_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdato [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_m_data_o_flat
assign m_data_o_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ] = masterdato[i];
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] masterbytsel [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masterbytsel
assign masterbytsel[i] = m_sel_i_flat[((i+1) * (ARCHBITSZ/8)) -1 : i * (ARCHBITSZ/8)];
end endgenerate

wire masterrdy [MASTERCOUNT -1 : 0];
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_m_rdy_o_flat
assign m_rdy_o_flat[((i+1) * 1) -1 : i * 1] = masterrdy[i];
end endgenerate

wire [2 -1 : 0] slaveop [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_s_op_o_flat
assign s_op_o_flat[((i+1) * 2) -1 : i * 2] = slaveop[i];
end endgenerate

wire [ADDRBITSZ -1 : 0] slaveaddr [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_s_addr_o_flat
assign s_addr_o_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ] = slaveaddr[i];
end endgenerate

wire [ARCHBITSZ -1 : 0] slavedati [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slavedati
assign slavedati[i] = s_data_i_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ];
end endgenerate

wire [ARCHBITSZ -1 : 0] slavedato [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_s_data_o_flat
assign s_data_o_flat[((i+1) * ARCHBITSZ) -1 : i * ARCHBITSZ] = slavedato[i];
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] slavebytsel [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_s_sel_o_flat
assign s_sel_o_flat[((i+1) * (ARCHBITSZ/8)) -1 : i * (ARCHBITSZ/8)] = slavebytsel[i];
end endgenerate

wire slaverdy [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slaverdy
assign slaverdy[i] = s_rdy_i_flat[((i+1) * 1) -1 : i * 1];
end endgenerate

wire [ADDRBITSZ -1 : 0] slavemapsz [SLAVECOUNT -1 : 0];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slavemapsz
assign slavemapsz[i] = s_mapsz_o_flat[((i+1) * ADDRBITSZ) -1 : i * ADDRBITSZ];
end endgenerate

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [CLOG2MASTERCOUNT -1 : 0] masteridx = 0;

reg [CLOG2MASTERCOUNT -1 : 0] mstrhinxt = (MASTERCOUNT - 1);
reg [CLOG2MASTERCOUNT -1 : 0] mstrhiidx = (MASTERCOUNT - 1);

wire masterop_mstrhiidx_not_PINOOP = (masterop[mstrhiidx] != PINOOP);
always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i || !mstrhiidx || masterop_mstrhiidx_not_PINOOP) begin
			if (masterop_mstrhiidx_not_PINOOP)
				mstrhinxt <= mstrhiidx;
			mstrhiidx <= (MASTERCOUNT - 1);
		end else
			mstrhiidx <= mstrhiidx - 1'b1;
	end
end

reg [CLOG2MASTERCOUNT -1 : 0] mstrhi = (MASTERCOUNT - 1);

wire [2 -1 : 0] masteropmasteridx = masterop[masteridx];

wire [ADDRBITSZ -1 : 0] masteraddrmasteridx = masteraddr[masteridx];

wire masterrdymasteridx = masterrdy[masteridx];

always @ (posedge clk_i) begin
	if (MASTERCOUNT > 1) begin
		if (rst_i)
			mstrhi <= (MASTERCOUNT - 1);
		else if (masterrdymasteridx && masteropmasteridx == PINOOP) begin
			if (masteridx < mstrhi)
				masteridx <= masteridx + 1'b1;
			else begin
				masteridx <= 0;
				mstrhi <= mstrhinxt;
			end
		end
	end else
		masteridx <= 0;
end

reg [ADDRBITSZ -1 : 0] addrspace [SLAVECOUNT -1 : 0];
integer m;
initial begin
	for (m = 0; m < SLAVECOUNT; m = m + 1) begin
		addrspace[m] = 0;
	end
end
reg addrspacerdy = 0;

reg [CLOG2SLAVECOUNT -1 : 0] slaveidx = 0;
reg [ADDRBITSZ -1 : 0] slavemapszslaveidx = 0;
reg [ADDRBITSZ -1 : 0] addrspaceslaveidx = 0;
reg [ADDRBITSZ -1 : 0] addrspaceslaveidxlo = 0;
reg slaveidxrdy = 0;
reg slaveidxbsy = 0;

wire slaveidx_not_max = (slaveidx < (SLAVECOUNT-1));

wire slaveidxinvalid = (masteropmasteridx != PINOOP &&
	masteraddrmasteridx != addrspaceslaveidxlo &&
	!(masteraddrmasteridx >= addrspaceslaveidxlo &&
	  masteraddrmasteridx <= addrspaceslaveidx));

wire [ADDRBITSZ -1 : 0] slavemapszslaveidxplusaddrspaceslaveidxlo = (slavemapszslaveidx + addrspaceslaveidxlo);

always @ (posedge clk_i) begin

	slavemapszslaveidx <= slavemapsz[slaveidx];

	addrspaceslaveidx <= addrspace[slaveidx];

	if (rst_i) begin

		addrspacerdy <= 1'b0;

		slaveidx <= 0;

		slaveidxrdy <= 1'b0;

		addrspaceslaveidxlo <= FIRSTSLAVEADDR;

		slaveidxbsy <= 1'b1;

	end else if (slaveidxbsy) begin

		slaveidxbsy <= 1'b0;

	end else if (!addrspacerdy) begin

		if (slaveidx_not_max) begin

			addrspaceslaveidxlo <= slavemapszslaveidxplusaddrspaceslaveidxlo;

			slaveidx <= slaveidx + 1'b1;

			slaveidxbsy <= 1'b1;

		end else begin

			addrspaceslaveidxlo <= FIRSTSLAVEADDR;

			slaveidx <= 0;

			addrspacerdy <= 1'b1;

			slaveidxbsy <= 1'b1;
		end

		addrspace[slaveidx] <= slavemapszslaveidxplusaddrspaceslaveidxlo - 1'b1;

	end else if (!slaveidxrdy) begin

		if (!slaveidxinvalid)
			slaveidxrdy <= 1'b1;
		else if (slaveidx_not_max) begin
			addrspaceslaveidxlo <= addrspaceslaveidx + 1'b1;
			slaveidx <= slaveidx + 1'b1;
			slaveidxbsy <= 1'b1;
		end else begin
			addrspaceslaveidxlo <= masteraddrmasteridx;
			slaveidx <= DEFAULTSLAVEINDEX;
			if (slaveidx == DEFAULTSLAVEINDEX) begin
				slaveidxrdy <= 1'b1;
			end
			slaveidxbsy <= 1'b1;
		end

	end else if (slaveidxinvalid) begin
		slaveidxrdy <= 1'b0;
		slaveidx <= 0;
		addrspaceslaveidxlo <= FIRSTSLAVEADDR;
		slaveidxbsy <= 1'b1;
	end
end

reg [CLOG2SLAVECOUNT -1 : 0] slaveidxsaved = 0;
reg slaverdyslaveidxreadoppending = 0;
reg [ARCHBITSZ -1 : 0] masterdatomasteridx = 0;

wire slaverdyslaveidxsaved = slaverdy[slaveidxsaved];

wire slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending = (slaverdyslaveidxsaved && slaverdyslaveidxreadoppending);

wire [ARCHBITSZ -1 : 0] slavedatislaveidxsaved = slavedati[slaveidxsaved];

wire readoprdy = (masterrdymasteridx && (masteropmasteridx == PIRDOP || masteropmasteridx == PIRWOP));

wire slaverdyslaveidx = slaverdy[slaveidx];

reg [2 -1 : 0] slaveopsaved = PINOOP;

wire slaveidxrdy_and_not_slaveidxinvalid = (slaveidxrdy && !slaveidxinvalid);

always @ (posedge clk_i) begin

	if (rst_i) begin

		slaverdyslaveidxreadoppending <= 1'b0;

	end else if (slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending) begin

		masterdatomasteridx <= slavedatislaveidxsaved;

		if (readoprdy)
			slaveidxsaved <= slaveidx;
		else
			slaverdyslaveidxreadoppending <= 1'b0;

	end else if (readoprdy) begin
		slaveidxsaved <= slaveidx;
		slaverdyslaveidxreadoppending <= 1'b1;
	end

	if (rst_i) begin
		slaveopsaved <= PIWROP;
	end else if (slaveidxrdy_and_not_slaveidxinvalid && slaverdyslaveidx)
		slaveopsaved <= slaveop[slaveidx];
end

wire nextoprdy = ((slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending || !slaverdyslaveidxreadoppending) &&
	slaveidxrdy_and_not_slaveidxinvalid && (slaverdyslaveidx /*|| slaveopsaved == PINOOP*/));

wire [ARCHBITSZ -1 : 0] masterdatoi = (slaverdyslaveidxsaved_and_slaverdyslaveidxreadoppending ? slavedatislaveidxsaved : masterdatomasteridx);
generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masterdato
assign masterdato[i] = masterdatoi;
end endgenerate

generate for (i = 0; i < MASTERCOUNT; i = i + 1) begin :gen_masterrdy
assign masterrdy[i] = (masteridx == i && nextoprdy) ? 1'b1 : 1'b0;
end endgenerate

generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slaveop
assign slaveop[i] = (slaveidx == i && nextoprdy) ? masteropmasteridx : PINOOP;
end endgenerate

wire [ADDRBITSZ -1 : 0] slaveaddri = (masteraddrmasteridx-((addrspaceslaveidx+1'b1)-slavemapszslaveidx));
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slaveaddr
assign slaveaddr[i] = slaveaddri;
end endgenerate

wire [ARCHBITSZ -1 : 0] masterdatimasteridx = masterdati[masteridx];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slavedato
assign slavedato[i] = masterdatimasteridx;
end endgenerate

wire [(ARCHBITSZ/8) -1 : 0] masterbytselmasteridx = masterbytsel[masteridx];
generate for (i = 0; i < SLAVECOUNT; i = i + 1) begin :gen_slavebytsel
assign slavebytsel[i] = masterbytselmasteridx;
end endgenerate

endmodule

`endif
