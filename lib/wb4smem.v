// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

module wb4smem (

	clk_i,

	rst_i,

	wb4_cyc_i,
	wb4_stb_i,
	wb4_we_i,
	wb4_addr_i,
	wb4_data_i,
	wb4_sel_i,
	wb4_stall_o,
	wb4_ack_o,
	wb4_data_o
);

`include "lib/clog2.v"

parameter SIZE = 0;
parameter DELAY = 0;
parameter SRCFILE = "";

parameter ARCHBITSZ = 0;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);

localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input wire clk_i;

input wire rst_i;

input  wire                        wb4_cyc_i;
input  wire                        wb4_stb_i;
input  wire                        wb4_we_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_addr_i;
input  wire [ARCHBITSZ -1 : 0]     wb4_data_i;
input  wire [(ARCHBITSZ/8) -1 : 0] wb4_sel_i;
output wire                        wb4_stall_o;
output reg                         wb4_ack_o = 0;
output reg  [ARCHBITSZ -1 : 0]     wb4_data_o;

localparam CNTRBITSZ = clog2(DELAY);

reg [CNTRBITSZ -1 : 0] cntr = 0;

assign wb4_stall_o = |cntr;

reg [ARCHBITSZ -1 : 0] u[SIZE -1 : 0];
integer i;
initial begin
	`ifdef SIMULATION
	for (i = 0; i < SIZE; i = i + 1)
		u[i] = 0;
	`endif
	if (SRCFILE != "") begin
		$readmemh (SRCFILE, u);
		`ifdef SIMULATION
		$display ("%s loaded", SRCFILE);
		wb4_data_o = 0;
		`endif
	end
end

wire [(128/8) -1 : 0] _wb4_sel_i = wb4_sel_i;
reg [ARCHBITSZ -1 : 0] sel_w;
always @* begin
	if (ARCHBITSZ == 16)
		sel_w = {{8{_wb4_sel_i[1]}}, {8{_wb4_sel_i[0]}}};
	else if (ARCHBITSZ == 32)
		sel_w = {{8{_wb4_sel_i[3]}}, {8{_wb4_sel_i[2]}}, {8{_wb4_sel_i[1]}}, {8{_wb4_sel_i[0]}}};
	else if (ARCHBITSZ == 64)
		sel_w = {
			{8{_wb4_sel_i[7]}}, {8{_wb4_sel_i[6]}}, {8{_wb4_sel_i[5]}}, {8{_wb4_sel_i[4]}},
			{8{_wb4_sel_i[3]}}, {8{_wb4_sel_i[2]}}, {8{_wb4_sel_i[1]}}, {8{_wb4_sel_i[0]}}};
	else if (ARCHBITSZ == 128)
		sel_w = {
			{8{_wb4_sel_i[15]}}, {8{_wb4_sel_i[14]}}, {8{_wb4_sel_i[13]}}, {8{_wb4_sel_i[12]}},
			{8{_wb4_sel_i[11]}}, {8{_wb4_sel_i[10]}}, {8{_wb4_sel_i[9]}}, {8{_wb4_sel_i[8]}},
			{8{_wb4_sel_i[7]}}, {8{_wb4_sel_i[6]}}, {8{_wb4_sel_i[5]}}, {8{_wb4_sel_i[4]}},
			{8{_wb4_sel_i[3]}}, {8{_wb4_sel_i[2]}}, {8{_wb4_sel_i[1]}}, {8{_wb4_sel_i[0]}}};
	else
		sel_w = {ARCHBITSZ{1'b0}};
end


wire [ADDRBITSZ -1 : 0] addr_w = wb4_addr_i[ARCHBITSZ -1 : CLOG2ARCHBITSZBY8];

wire [ARCHBITSZ -1 : 0] ram_w0 = u[addr_w];
wire [ARCHBITSZ -1 : 0] ram_w1 = ((wb4_data_i & sel_w) | (ram_w0 & ~sel_w));

always @ (posedge clk_i) begin
	if (!wb4_stall_o && wb4_cyc_i && wb4_stb_i) begin
		if (wb4_we_i)
			u[addr_w] <= ram_w1;
		else
			wb4_data_o <= ram_w0;
		wb4_ack_o <= 1;
	end else
		wb4_ack_o <= 0;

	if (rst_i)
		cntr <= 0;
	else if (cntr)
		cntr <= cntr - 1'b1;
	else if (wb4_stb_i)
		cntr <= DELAY;
end

endmodule
