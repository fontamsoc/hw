// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

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

input wire clk_i;

input  wire [2 -1 : 0]             pi1_op_i;
input  wire [ADDRBITSZ -1 : 0]     pi1_addr_i;
input  wire [ARCHBITSZ -1 : 0]     pi1_data_i;
output reg  [ARCHBITSZ -1 : 0]     pi1_data_o;
input  wire [(ARCHBITSZ/8) -1 : 0] pi1_sel_i;
output wire                        pi1_rdy_o;
output wire [ADDRBITSZ -1 : 0]     pi1_mapsz_o;

assign pi1_mapsz_o = SIZE;

localparam CNTRBITSZ = clog2(DELAY);

localparam PINOOP = 2'b00;
localparam PIWROP = 2'b01;
localparam PIRDOP = 2'b10;
localparam PIRWOP = 2'b11;

reg [CNTRBITSZ -1 : 0] cntr = 0;

assign pi1_rdy_o = !cntr;

wire [(256/8) -1 : 0] _pi1_sel_i = pi1_sel_i;
reg [ARCHBITSZ -1 : 0] sel_w;
always @* begin
	if (ARCHBITSZ == 16)
		sel_w = {{8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 32)
		sel_w = {{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 64)
		sel_w = {
			{8{_pi1_sel_i[7]}}, {8{_pi1_sel_i[6]}}, {8{_pi1_sel_i[5]}}, {8{_pi1_sel_i[4]}},
			{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 128)
		sel_w = {
			{8{_pi1_sel_i[15]}}, {8{_pi1_sel_i[14]}}, {8{_pi1_sel_i[13]}}, {8{_pi1_sel_i[12]}},
			{8{_pi1_sel_i[11]}}, {8{_pi1_sel_i[10]}}, {8{_pi1_sel_i[9]}}, {8{_pi1_sel_i[8]}},
			{8{_pi1_sel_i[7]}}, {8{_pi1_sel_i[6]}}, {8{_pi1_sel_i[5]}}, {8{_pi1_sel_i[4]}},
			{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else if (ARCHBITSZ == 256)
		sel_w = {
			{8{_pi1_sel_i[31]}}, {8{_pi1_sel_i[30]}}, {8{_pi1_sel_i[29]}}, {8{_pi1_sel_i[28]}},
			{8{_pi1_sel_i[27]}}, {8{_pi1_sel_i[26]}}, {8{_pi1_sel_i[25]}}, {8{_pi1_sel_i[24]}},
			{8{_pi1_sel_i[23]}}, {8{_pi1_sel_i[22]}}, {8{_pi1_sel_i[21]}}, {8{_pi1_sel_i[20]}},
			{8{_pi1_sel_i[19]}}, {8{_pi1_sel_i[18]}}, {8{_pi1_sel_i[17]}}, {8{_pi1_sel_i[16]}},
			{8{_pi1_sel_i[15]}}, {8{_pi1_sel_i[14]}}, {8{_pi1_sel_i[13]}}, {8{_pi1_sel_i[12]}},
			{8{_pi1_sel_i[11]}}, {8{_pi1_sel_i[10]}}, {8{_pi1_sel_i[9]}}, {8{_pi1_sel_i[8]}},
			{8{_pi1_sel_i[7]}}, {8{_pi1_sel_i[6]}}, {8{_pi1_sel_i[5]}}, {8{_pi1_sel_i[4]}},
			{8{_pi1_sel_i[3]}}, {8{_pi1_sel_i[2]}}, {8{_pi1_sel_i[1]}}, {8{_pi1_sel_i[0]}}};
	else
		sel_w = {ARCHBITSZ{1'b0}};
end

wire en_w = (pi1_rdy_o && (pi1_op_i == PIRDOP || pi1_op_i == PIRWOP));
wire we_w = (pi1_rdy_o && (pi1_op_i == PIWROP || pi1_op_i == PIRWOP));

reg [ARCHBITSZ -1 : 0] u [0 : SIZE -1];
`ifdef SIMULATION
integer init_u_idx;
`endif
initial begin
	`ifdef SIMULATION
	for (init_u_idx = 0; init_u_idx < SIZE; init_u_idx = init_u_idx + 1)
		u[init_u_idx] = 0;
	`endif
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", SRCFILE);
		pi1_data_o = 0;
		`endif
	end
end

wire [ARCHBITSZ -1 : 0] ram_w0 = u[pi1_addr_i];
wire [ARCHBITSZ -1 : 0] ram_w1 = ((pi1_data_i & sel_w) | (ram_w0 & ~sel_w));

always @ (posedge clk_i) begin
	if (en_w)
		pi1_data_o <= ram_w0;
	if (we_w)
		u[pi1_addr_i] <= ram_w1;

	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= cntr - 1'b1;
	else if (pi1_op_i != PINOOP)
		cntr <= DELAY;
end

endmodule
