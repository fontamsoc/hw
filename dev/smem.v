// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`include "lib/ram/ram2clk1i1o.v"

module smem (

	rst_i,

	clk_i,

	pi1_op_i,
	pi1_addr_i,
	pi1_data_i,
	pi1_data_o,
	pi1_sel_i,
	pi1_rdy_o,
	pi1_mapsz_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 0;

parameter SIZE    = 2;
parameter DELAY   = 0;
parameter SRCFILE = "";

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire rst_i;

`ifdef USE2CLK
input wire [2 -1 : 0] clk_i;
`else
input wire [1 -1 : 0] clk_i;
`endif

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output wire [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

assign pi1_mapsz_o = SIZE;

localparam CNTRBITSZ = clog2(DELAY + 1);

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg[CNTRBITSZ -1 : 0] cntr = 0;

assign pi1_rdy_o = !cntr;

wire [ARCHBITSZ -1 : 0] ramo;

reg [ARCHBITSZ -1 : 0] dato = 0;

assign pi1_data_o = pi1_rdy_o ? dato : {ARCHBITSZ{1'b0}};

wire [(128/8) -1 : 0] _pi1_sel_i = pi1_sel_i;
reg [ARCHBITSZ -1 : 0] bitsel;
always @* begin
	if (ARCHBITSZ == 16)
		bitsel = {{8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 32)
		bitsel = {{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 64)
		bitsel = {
			{8{_pi1_sel_i[7]}}, {8{_pi1_sel_i[6]}}, {8{_pi1_sel_i[5]}}, {8{_pi1_sel_i[4]}},
			{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 128)
		bitsel = {
			{8{_pi1_sel_i[15]}}, {8{_pi1_sel_i[14]}}, {8{_pi1_sel_i[13]}}, {8{_pi1_sel_i[12]}},
			{8{_pi1_sel_i[11]}}, {8{_pi1_sel_i[10]}}, {8{_pi1_sel_i[9]}}, {8{_pi1_sel_i[8]}},
			{8{_pi1_sel_i[7]}}, {8{_pi1_sel_i[6]}}, {8{_pi1_sel_i[5]}}, {8{_pi1_sel_i[4]}},
			{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else
		bitsel = {ARCHBITSZ{1'b0}};
end

wire en_w = (pi1_rdy_o && (pi1_op_i == PIRDOP || pi1_op_i == PIRWOP));
wire we_w = (pi1_rdy_o && (pi1_op_i == PIWROP || pi1_op_i == PIRWOP));

`ifdef USE2CLK
reg en_w_ = 0;
reg we_w_ = 0;
reg [ADDRBITSZ -1 : 0] pi1_addr_i_ = 0;
reg [ARCHBITSZ -1 : 0] pi1_data_i_ = 0;
reg [ARCHBITSZ -1 : 0] bitsel_ = 0;
always @ (posedge clk_i[0]) begin
	if (rst_i) begin
		en_w_ <= 1'b0;
		we_w_ <= 1'b0;
	end else begin
		en_w_ <= en_w;
		we_w_ <= we_w;
		pi1_addr_i_ <= pi1_addr_i;
		pi1_data_i_ <= pi1_data_i;
		bitsel_ <= bitsel;
	end
end
`else
wire en_w_ = en_w;
wire we_w_ = we_w;
wire [ADDRBITSZ -1 : 0] pi1_addr_i_ = pi1_addr_i;
wire [ARCHBITSZ -1 : 0] pi1_data_i_ = pi1_data_i;
wire [ARCHBITSZ -1 : 0] bitsel_ = bitsel;
`endif

assign pi1_rdy_o = !cntr
`ifdef USE2CLK
	&& !we_w_
`endif
;

ram2clk1i1o #(

	 .SZ (SIZE)
	,.DW (ARCHBITSZ)
	,.SRCFILE (SRCFILE)

) ram (

	  .rst_i (rst_i)

	,.clk_i  (clk_i)
	,.we_i   (we_w_)
	,.addr_i (we_w_ ? pi1_addr_i_ : pi1_addr_i)
	,.i      ((pi1_data_i_ & bitsel_) | (ramo & ~bitsel_))
	,.o      (ramo)
);

`ifdef USE2CLK
always @ (posedge clk_i[1]) begin
`else
always @ (posedge clk_i[0]) begin
`endif
	if (en_w_)
		dato <= ramo;
end

always @ (posedge clk_i[0]) begin
	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= cntr - 1'b1;
	else if (pi1_op_i != PINOOP)
		cntr <= DELAY;
end

endmodule
