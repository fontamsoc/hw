// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opZbb_stb = (iD_opZbb_stb && iD_insn_valid);

// The 5-bit optype, decoded here at iD from the already-registered iD_func3/iD_func7/
// iD_Iimm fields (mirrors clmul's iD_func3-sliced type field): it feeds only the zbb
// unit's operand-capture FF D-inputs, so it needs no pipeline register of its own.
localparam OPZBBTYPEBITSZ = 5;
reg [OPZBBTYPEBITSZ -1 : 0] opZbb_optype; // ### comb-block-reg. Codes MUST match zbb.sv ZBB_*.
always_comb begin
	if (iD_isALUreg) begin // OP-form.
		case (iD_func7)
		7'b0100000: opZbb_optype = (iD_func3 == 3'b100) ? 5'd2  // xnor
		                         : (iD_func3 == 3'b110) ? 5'd1  // orn
		                         :                        5'd0; // andn (111)
		7'b0000101: opZbb_optype = (iD_func3 == 3'b100) ? 5'd3  // min
		                         : (iD_func3 == 3'b101) ? 5'd4  // minu
		                         : (iD_func3 == 3'b110) ? 5'd5  // max
		                         :                        5'd6; // maxu (111)
		7'b0110000: opZbb_optype = (iD_func3 == 3'b001) ? 5'd7  // rol
		                         :                        5'd8; // ror (101)
		default:    opZbb_optype = 5'd10;                       // zext.h (0000100)
		endcase
	end else begin // OP-IMM.
		if (iD_func3 == 3'b001) // clz/ctz/cpop/sext.b/sext.h, by imm[4:0].
			case (iD_Iimm[4:0])
			5'd0:    opZbb_optype = 5'd11; // clz
			5'd1:    opZbb_optype = 5'd12; // ctz
			5'd2:    opZbb_optype = 5'd13; // cpop
			5'd4:    opZbb_optype = 5'd14; // sext.b
			default: opZbb_optype = 5'd15; // sext.h (5)
			endcase
		else // func3 == 101: rev8/orc.b/rori.
			opZbb_optype = (iD_Iimm[11:0] == 12'h698) ? 5'd16  // rev8
			             : (iD_Iimm[11:0] == 12'h287) ? 5'd17  // orc.b
			             :                              5'd9;  // rori
	end
end

// args = {optype, rdId, rs1, rs2-slot}. The rs2-slot is the second register for the OP-form
// Zbb ops, or the immediate for the OP-IMM ops (only its low 5 bits matter, as the rori
// rotate amount); this mirrors eX_aluArg2_i = (iD_isALUreg ? iD_rs2 : iD_Iimm).
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPZBBTYPEBITSZ) -1 : 0] opZbb_args =
	{opZbb_optype, iD_rdId, iD_rs1, (iD_isALUreg ? iD_rs2 : iD_Iimm)};

wire opZbb_rdy;
assign iD_opZbb_bsy = !opZbb_rdy;

wire [WORDBITSZ -1 : 0]   opZbb_rslt;
wire [CLOG2GPRCNT -1 : 0] opZbb_rIdx;
wire                      opZbb_done;

// Restrict ZBBCNT to 1, 2, 4 or 8.
localparam OPZBBCNT = ((ZBBCNT != 2 && ZBBCNT != 4 && ZBBCNT != 8) ? 1 : ZBBCNT);

opzbb #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
	,.INSTCNT   (OPZBBCNT)
) opZbb (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i  (opZbb_stb)
	,.args_i (opZbb_args)
	,.rdy_o  (opZbb_rdy)

	,.ostb_i  (rW_opZbb_done)
	,.rslt_o  (opZbb_rslt)
	,.gprid_o (opZbb_rIdx)
	,.ordy_o  (opZbb_done)
);
