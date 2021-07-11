// Copyright (c) William Fonkou Tambe
// All rights reserved.

module muldiv (

	 rst_i

	,clk_i

	,stb_i

	,data_i
	,data_o
	,gprid_o

	,rdy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 32;
parameter GPRCNT    = 32;

localparam CLOG2ARCHBITSZ = clog2(ARCHBITSZ);
localparam CLOG2GPRCNT    = clog2(GPRCNT);

localparam MULDIVTYPEBITSZ = 4;
localparam MULDIVMSBRSLT   = ((ARCHBITSZ*2)+CLOG2GPRCNT);
localparam MULDIVSIGNED    = ((ARCHBITSZ*2)+CLOG2GPRCNT+1);
localparam MULDIVISDIV     = ((ARCHBITSZ*2)+CLOG2GPRCNT+2);
localparam MULDIVISFLOAT   = ((ARCHBITSZ*2)+CLOG2GPRCNT+3);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_i;

output reg [ARCHBITSZ -1 : 0] data_o;

output wire [CLOG2GPRCNT -1 : 0] gprid_o;
assign gprid_o = operands[((ARCHBITSZ*2)+CLOG2GPRCNT)-1:ARCHBITSZ*2];

output reg rdy_o = 0;

reg  [(ARCHBITSZ*2) -1 : 0] cumulator        = 0;
wire [(ARCHBITSZ*2) -1 : 0] cumulatornegated = -cumulator;

reg [(ARCHBITSZ+2) -1 : 0] mulx;

reg [ARCHBITSZ -1 : 0] rval;

wire [(ARCHBITSZ*2) -1 : 0] divdiff = (cumulator - ({rval, {(ARCHBITSZ-1){1'b0}}}));

wire [(ARCHBITSZ+2) -1 : 0] cumulatoroperand = (mulx + cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ]);

reg [CLOG2ARCHBITSZ -1 : 0] cntr = 0;

reg inprogress = 0;

reg start = 0;

reg [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] operands = 0;

always @* begin

	if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ-1)])
		rval = -operands[ARCHBITSZ-1:0];
	else
		rval = operands[ARCHBITSZ-1:0];

	if (cumulator[1:0] == 1)
		mulx = {{2{1'b0}}, rval};
	else if (cumulator[1:0] == 2)
		mulx = {1'b0, rval, 1'b0};
	else if (cumulator[1:0] == 3)
		mulx = {rval, 1'b0} + rval;
	else
		mulx = 0;

	if (operands[MULDIVISDIV]) begin

		if (operands[MULDIVMSBRSLT]) begin

			if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ*2)-1])
				data_o = -cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
			else
				data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

		end else begin

			if (operands[MULDIVSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]))
				data_o = -cumulator[ARCHBITSZ-1:0];
			else
				data_o = cumulator[ARCHBITSZ-1:0];
		end

	end else begin

		if (operands[MULDIVMSBRSLT]) begin

			if (operands[MULDIVSIGNED] && (operands[(ARCHBITSZ*2)-1] != operands[(ARCHBITSZ-1)]))
				data_o = cumulatornegated[(ARCHBITSZ*2)-1:ARCHBITSZ];
			else
				data_o = cumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];

		end else begin

			data_o = cumulator[ARCHBITSZ-1:0];
		end
	end
end

always @ (posedge clk_i) begin

	if (rst_i) begin

		rdy_o <= 1;

	end else if (rdy_o) begin

		if (stb_i) begin
			inprogress <= 0;
			start <= 1;
			operands <= data_i;
			rdy_o <= 0;
		end

	end else begin

		if (inprogress) begin

			if (operands[MULDIVISDIV]) begin

				if (divdiff[(ARCHBITSZ*2)-1])
					cumulator <= {cumulator[(ARCHBITSZ*2)-2:0], 1'b0};
				else
					cumulator <= {divdiff[(ARCHBITSZ*2)-2:0], 1'b1};

				if (&cntr) begin
					rdy_o <= 1;
					inprogress <= 0;
					start <= 0;
				end

			end else begin

				cumulator <= {cumulatoroperand, cumulator[ARCHBITSZ-1:2]};

				if (&(cntr[(CLOG2ARCHBITSZ-1)-1:0])) begin
					rdy_o <= 1;
					inprogress <= 0;
					start <= 0;
				end
			end

			cntr <= cntr + 1'b1;

		end else if (start) begin

			cntr <= 0;

			if (operands[MULDIVSIGNED] && operands[(ARCHBITSZ*2)-1])
				cumulator <= {{ARCHBITSZ{1'b0}}, -operands[(ARCHBITSZ*2)-1:ARCHBITSZ]};
			else
				cumulator <= {{ARCHBITSZ{1'b0}}, operands[(ARCHBITSZ*2)-1:ARCHBITSZ]};

			inprogress <= 1;
		end
	end
end

endmodule

module opmuldiv (

	 rst_i

	,clk_i

	,stb_i
	,data_i
	,rdy_o

	,ostb_i
	,data_o
	,gprid_o
	,ordy_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 32;
parameter GPRCNT    = 32;
parameter DEPTH     = 32;

localparam CLOG2GPRCNT = clog2(GPRCNT);

localparam MULDIVTYPEBITSZ = 4;

localparam MULDIVCNT_     = ((ARCHBITSZ < GPRCNT) ? ARCHBITSZ : GPRCNT);
localparam MULDIVCNT      = ((MULDIVCNT_ < DEPTH) ? MULDIVCNT_ : DEPTH);
localparam CLOG2MULDIVCNT = clog2(MULDIVCNT);

input wire rst_i;

input wire clk_i;

input wire stb_i;

input wire [(((ARCHBITSZ*2)+CLOG2GPRCNT)+MULDIVTYPEBITSZ) -1 : 0] data_i;

output wire rdy_o;

input wire ostb_i;

output wire [ARCHBITSZ -1 : 0] data_o;

output wire [CLOG2GPRCNT -1 : 0] gprid_o;

output wire ordy_o;

reg [(CLOG2MULDIVCNT +1) -1 : 0] wridx = 0;
reg [(CLOG2MULDIVCNT +1) -1 : 0] rdidx = 0;

wire [(CLOG2MULDIVCNT +1) -1 : 0] usage;
assign usage = (wridx - rdidx);

wire [ARCHBITSZ -1 : 0] data_w [MULDIVCNT -1 : 0];
assign data_o = data_w[rdidx];

wire [CLOG2GPRCNT -1 : 0] gprid_w [MULDIVCNT -1 : 0];
assign gprid_o = gprid_w[rdidx];

wire [MULDIVCNT -1 : 0] rdy_w;
assign rdy_o = ((usage < MULDIVCNT) && rdy_w[wridx]);

assign ordy_o = ((usage != 0) && rdy_w[rdidx]);

always @ (posedge clk_i) begin

	if (rst_i) begin
		rdidx <= wridx;
	end else if (ostb_i)
		rdidx <= rdidx + 1'b1;

	if (stb_i)
		wridx <= wridx + 1'b1;
end

genvar i;

generate for (i = 0; i < MULDIVCNT; i = i + 1) begin :gen_muldiv
muldiv #(

	 .ARCHBITSZ (ARCHBITSZ)
	,.GPRCNT    (GPRCNT)

) muldiv (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i (stb_i && (wridx[CLOG2MULDIVCNT -1 : 0] == i))

	,.data_i  (data_i)
	,.data_o  (data_w[i])
	,.gprid_o (gprid_w[i])

	,.rdy_o (rdy_w[i])
);
end endgenerate

endmodule
