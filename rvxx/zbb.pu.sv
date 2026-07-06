// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opZbb_stb = (iD_opZbb_stb && iD_insn_valid);

// args = {optype, rdId, rs1, rs2-slot}. The rs2-slot is the second register for the OP-form
// Zbb ops, or the immediate for the OP-IMM ops (only its low 5 bits matter, as the rori
// rotate amount); this mirrors eX_aluArg2_i = (iD_isALUreg ? iD_rs2 : iD_Iimm).
localparam OPZBBTYPEBITSZ = 5;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPZBBTYPEBITSZ) -1 : 0] opZbb_args =
	{iD_opZbb_optype, iD_rdId, iD_rs1, (iD_isALUreg ? iD_rs2 : iD_Iimm)};

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
