// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opClmul_stb = (iD_opClmul_stb && iD_insn_valid);

// The type field within opClmul_args is iD_func3[1:0]:
//   2'b01 clmul (low), 2'b10 clmulr (reversed), 2'b11 clmulh (high).
localparam OPCLMULTYPEBITSZ = 2;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPCLMULTYPEBITSZ) -1 : 0] opClmul_args =
	{iD_func3[1:0], iD_rdId, iD_rs1, iD_rs2};

wire opClmul_rdy;
assign iD_opClmul_bsy = !opClmul_rdy;

wire [WORDBITSZ -1 : 0]   opClmul_rslt;
wire [CLOG2GPRCNT -1 : 0] opClmul_rIdx;
wire                      opClmul_done;

// Restrict CLMULCNT to 1, 2, 4 or 8.
localparam OPCLMULCNT = ((CLMULCNT != 2 && CLMULCNT != 4 && CLMULCNT != 8) ? 1 : CLMULCNT);

opclmul #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
	,.INSTCNT   (OPCLMULCNT)
) opClmul (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i  (opClmul_stb)
	,.args_i (opClmul_args)
	,.rdy_o  (opClmul_rdy)

	,.ostb_i  (rW_opClmul_done)
	,.rslt_o  (opClmul_rslt)
	,.gprid_o (opClmul_rIdx)
	,.ordy_o  (opClmul_done)
);
