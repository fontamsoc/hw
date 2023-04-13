// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

`ifndef ADDR_V
`define ADDR_V

// Module computing full ARCHBITSZ address from ADDRBITSZ and sel bits.

module addr (
	 addr_i
	,sel_i
	,addr_o
);

`include "lib/clog2.v"

parameter ARCHBITSZ = 16;

localparam CLOG2ARCHBITSZBY8 = clog2(ARCHBITSZ/8);
localparam ADDRBITSZ = (ARCHBITSZ-CLOG2ARCHBITSZBY8);

input  wire [ADDRBITSZ -1 : 0]     addr_i;
input  wire [(ARCHBITSZ/8) -1 : 0] sel_i;
output wire [ARCHBITSZ -1 : 0]     addr_o;

generate if (ARCHBITSZ == 16) begin
	assign addr_o = {addr_i, {
		sel_i[0] ? 1'b0 :
		sel_i[1] ? 1'b1 : 1'b0 /*
		sel_i == 2'b11 ? 1'b0 :
		sel_i == 2'b01 ? 1'b0 :
		sel_i == 2'b10 ? 1'b1 : 1'b0 */}};
end endgenerate
generate if (ARCHBITSZ == 32) begin
	assign addr_o = {addr_i, {
		sel_i[0] ? 2'b00 :
		sel_i[1] ? 2'b01 :
		sel_i[2] ? 2'b10 :
		sel_i[3] ? 2'b11 : 2'b00 /*
		sel_i == 4'b1111 ? 2'b00 :
		sel_i == 4'b0011 ? 2'b00 :
		sel_i == 4'b1100 ? 2'b10 :
		sel_i == 4'b0001 ? 2'b00 :
		sel_i == 4'b0010 ? 2'b01 :
		sel_i == 4'b0100 ? 2'b10 :
		sel_i == 4'b1000 ? 2'b11 : 2'b00 */}};
end endgenerate
generate if (ARCHBITSZ == 64) begin
	assign addr_o = {addr_i, {
		sel_i[0] ? 3'b000 :
		sel_i[1] ? 3'b001 :
		sel_i[2] ? 3'b010 :
		sel_i[3] ? 3'b011 :
		sel_i[4] ? 3'b100 :
		sel_i[5] ? 3'b101 :
		sel_i[6] ? 3'b110 :
		sel_i[7] ? 3'b111 : 3'b000 /*
		sel_i == 8'b11111111 ? 3'b000 :
		sel_i == 8'b00001111 ? 3'b000 :
		sel_i == 8'b11110000 ? 3'b100 :
		sel_i == 8'b00000011 ? 3'b000 :
		sel_i == 8'b00001100 ? 3'b010 :
		sel_i == 8'b00110000 ? 3'b100 :
		sel_i == 8'b11000000 ? 3'b110 :
		sel_i == 8'b00000001 ? 3'b000 :
		sel_i == 8'b00000010 ? 3'b001 :
		sel_i == 8'b00000100 ? 3'b010 :
		sel_i == 8'b00001000 ? 3'b011 :
		sel_i == 8'b00010000 ? 3'b100 :
		sel_i == 8'b00100000 ? 3'b101 :
		sel_i == 8'b01000000 ? 3'b110 :
		sel_i == 8'b10000000 ? 3'b111 : 3'b000 */}};
end endgenerate
generate if (ARCHBITSZ == 128) begin
	assign addr_o = {addr_i, {
		sel_i[0]  ? 4'b0000 :
		sel_i[1]  ? 4'b0001 :
		sel_i[2]  ? 4'b0010 :
		sel_i[3]  ? 4'b0011 :
		sel_i[4]  ? 4'b0100 :
		sel_i[5]  ? 4'b0101 :
		sel_i[6]  ? 4'b0110 :
		sel_i[7]  ? 4'b0111 :
		sel_i[8]  ? 4'b1000 :
		sel_i[9]  ? 4'b1001 :
		sel_i[10] ? 4'b1010 :
		sel_i[11] ? 4'b1011 :
		sel_i[12] ? 4'b1100 :
		sel_i[13] ? 4'b1101 :
		sel_i[14] ? 4'b1110 :
		sel_i[15] ? 4'b1111 : 4'b0000 /*
		sel_i == 16'b1111111111111111 ? 4'b0000 :
		sel_i == 16'b0000000011111111 ? 4'b0000 :
		sel_i == 16'b1111111100000000 ? 4'b1000 :
		sel_i == 16'b0000000000001111 ? 4'b0000 :
		sel_i == 16'b0000000011110000 ? 4'b0100 :
		sel_i == 16'b0000111100000000 ? 4'b1000 :
		sel_i == 16'b1111000000000000 ? 4'b1100 :
		sel_i == 16'b0000000000000011 ? 4'b0000 :
		sel_i == 16'b0000000000001100 ? 4'b0010 :
		sel_i == 16'b0000000000110000 ? 4'b0100 :
		sel_i == 16'b0000000011000000 ? 4'b0110 :
		sel_i == 16'b0000001100000000 ? 4'b1000 :
		sel_i == 16'b0000110000000000 ? 4'b1010 :
		sel_i == 16'b0011000000000000 ? 4'b1100 :
		sel_i == 16'b1100000000000000 ? 4'b1110 :
		sel_i == 16'b0000000000000001 ? 4'b0000 :
		sel_i == 16'b0000000000000010 ? 4'b0001 :
		sel_i == 16'b0000000000000100 ? 4'b0010 :
		sel_i == 16'b0000000000001000 ? 4'b0011 :
		sel_i == 16'b0000000000010000 ? 4'b0100 :
		sel_i == 16'b0000000000100000 ? 4'b0101 :
		sel_i == 16'b0000000001000000 ? 4'b0110 :
		sel_i == 16'b0000000010000000 ? 4'b0111 :
		sel_i == 16'b0000000100000000 ? 4'b1000 :
		sel_i == 16'b0000001000000000 ? 4'b1001 :
		sel_i == 16'b0000010000000000 ? 4'b1010 :
		sel_i == 16'b0000100000000000 ? 4'b1011 :
		sel_i == 16'b0001000000000000 ? 4'b1100 :
		sel_i == 16'b0010000000000000 ? 4'b1101 :
		sel_i == 16'b0100000000000000 ? 4'b1110 :
		sel_i == 16'b1000000000000000 ? 4'b1111 : 4'b0000 */}};
end endgenerate
generate if (ARCHBITSZ == 256) begin
	assign addr_o = {addr_i, {
		sel_i[0]  ? 5'b00000 :
		sel_i[1]  ? 5'b00001 :
		sel_i[2]  ? 5'b00010 :
		sel_i[3]  ? 5'b00011 :
		sel_i[4]  ? 5'b00100 :
		sel_i[5]  ? 5'b00101 :
		sel_i[6]  ? 5'b00110 :
		sel_i[7]  ? 5'b00111 :
		sel_i[8]  ? 5'b01000 :
		sel_i[9]  ? 5'b01001 :
		sel_i[10] ? 5'b01010 :
		sel_i[11] ? 5'b01011 :
		sel_i[12] ? 5'b01100 :
		sel_i[13] ? 5'b01101 :
		sel_i[14] ? 5'b01110 :
		sel_i[15] ? 5'b01111 :
		sel_i[16] ? 5'b10000 :
		sel_i[17] ? 5'b10001 :
		sel_i[18] ? 5'b10010 :
		sel_i[19] ? 5'b10011 :
		sel_i[20] ? 5'b10100 :
		sel_i[21] ? 5'b10101 :
		sel_i[22] ? 5'b10110 :
		sel_i[23] ? 5'b10111 :
		sel_i[24] ? 5'b11000 :
		sel_i[25] ? 5'b11001 :
		sel_i[26] ? 5'b11010 :
		sel_i[27] ? 5'b11011 :
		sel_i[28] ? 5'b11100 :
		sel_i[29] ? 5'b11101 :
		sel_i[30] ? 5'b11110 :
		sel_i[31] ? 5'b11111 : 5'b00000 }};
end endgenerate

endmodule

`endif /* ADDR_V */
