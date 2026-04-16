// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef SKIDBUF_V
`define SKIDBUF_V

`include "lib/fifo.sv"
`include "lib/fifo_fwft.sv"

module skidbuf (

	 rst_i

	,clk_i

	,stb_i
	,dat_i
	,bsy_o
	,near_bsy_o

	,stb_o
	,dat_o
	,bsy_i
);

parameter WIDTH       = 1;
parameter DEPTH       = 2;
parameter USEFWFTFIFO = 0;

input wire rst_i;

input wire clk_i;

input  wire                stb_i;
input  wire [WIDTH -1 : 0] dat_i;
output wire                bsy_o;
output wire                near_bsy_o;

output reg                 stb_o;  // ### comb-block-reg.
output reg  [WIDTH -1 : 0] dat_o;  // ### comb-block-reg.
input  wire                bsy_i;

wire [WIDTH -1 : 0] _dat_o;

wire buf_empty_w;

generate if (USEFWFTFIFO) begin :gen_fifo_fwft

fifo_fwft #(
	 .WIDTH (WIDTH)
	,.DEPTH (DEPTH)
) fifo_fwft (

	 .rst_i (rst_i)

	,.clk_push_i  (clk_i)
	,.push_i      (stb_i && (bsy_i || !buf_empty_w))
	,.data_i      (dat_i)
	,.full_o      (bsy_o)
	,.near_full_o (near_bsy_o)

	,.clk_pop_i (clk_i)
	,.pop_i     (!bsy_i)
	,.data_o    (_dat_o)
	,.empty_o   (buf_empty_w)
);

always_comb begin
	if (buf_empty_w) begin
		stb_o = stb_i;
		dat_o = dat_i;
	end else begin
		stb_o = 1'b1;
		dat_o = _dat_o;
	end
end

end else begin

reg buf_empty_r;
always_ff @(posedge clk_i) begin
	if (rst_i)
		buf_empty_r <= 1'b1;
	else if (buf_empty_r || !bsy_i)
		buf_empty_r <= buf_empty_w;
end

fifo #(
	 .WIDTH (WIDTH)
	,.DEPTH (DEPTH)
) fifo (

	 .rst_i (rst_i)

	,.clk_write_i (clk_i)
	,.write_i     (stb_i && (bsy_i || !buf_empty_w || !buf_empty_r))
	,.data_i      (dat_i)
	,.full_o      (bsy_o)
	,.near_full_o (near_bsy_o)

	,.clk_read_i (clk_i)
	,.read_i     (buf_empty_r || !bsy_i)
	,.data_o     (_dat_o)
	,.empty_o    (buf_empty_w)
);

always_comb begin
	if (buf_empty_w && buf_empty_r) begin
		stb_o = stb_i;
		dat_o = dat_i;
	end else begin
		stb_o = !buf_empty_r;
		dat_o = _dat_o;
	end
end

end endgenerate

endmodule

`endif /* SKIDBUF_V */
