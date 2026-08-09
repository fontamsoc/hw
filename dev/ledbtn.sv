
module ledbtn (

	 rst_i

	,clk_i

	,wb_stb_i
	,wb_we_i
	,wb_addr_i
	,wb_sel_i
	,wb_dat_i
	,wb_bsy_o
	,wb_ack_o
	,wb_dat_o

	,btn_i
	,led_o
);

`include "lib/clog2.sv"

parameter WORDBITSZ = 32;
localparam CLOG2WORDBITSZBY8 = clog2(WORDBITSZ/8);
localparam ADDRBITSZ = (WORDBITSZ-CLOG2WORDBITSZBY8);
localparam MAPSZ = (128*(WORDBITSZ/8));
localparam MSBSZIGN = (WORDBITSZ-clog2(MAPSZ));

input wire rst_i;

input wire clk_i;

input  wire                               wb_stb_i;
input  wire                               wb_we_i;
input  wire [(ADDRBITSZ-MSBSZIGN) -1 : 0] wb_addr_i;
input  wire [(WORDBITSZ/8) -1 : 0]        wb_sel_i;
input  wire [WORDBITSZ -1 : 0]            wb_dat_i;
output wire                               wb_bsy_o;
output reg                                wb_ack_o;
output reg  [WORDBITSZ -1 : 0]            wb_dat_o;

input wire btn_i;
output reg led_o;

assign wb_bsy_o = 0;
always_ff @(posedge clk_i)
	wb_ack_o <= wb_stb_i;

always_ff @(posedge clk_i) begin
	if (wb_stb_i) begin
		if (wb_we_i)
			led_o <= (|wb_dat_i);
		else
			wb_dat_o <= btn_i;
	end
end

endmodule
