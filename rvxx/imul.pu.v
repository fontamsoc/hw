// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opImul_stb = (iD0_opImul_stb && eX0_insn_valid_i);

// Significance of each bit in the field within
// opImul_args storing the type of multiplication to perform.
// [2]: 0/1 means always treat the left operand as signed.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means WORDBITSZ lsb/msb of result.
localparam OPIMULTYPEBITSZ = 3;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPIMULTYPEBITSZ) -1 : 0] opImul_args =
	{!iD0_func3[0], !iD0_func3[1], (|iD0_func3[1:0]), iD0_rdId, iD0_rs1, iD0_rs2};

wire opImul_rdy;
assign iD0_opImul_bsy = !opImul_rdy;

wire [WORDBITSZ -1 : 0]   opImul_rslt;
wire [CLOG2GPRCNT -1 : 0] opImul_rIdx;
wire                      opImul_done;

// Restrict IMULCNT to 1, 2, 4 or 8.
localparam OPIMULCNT = ((IMULCNT != 2 && IMULCNT != 4 && IMULCNT != 8) ? 1 : IMULCNT);

opimul #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
	,.INSTCNT   (OPIMULCNT)
) opImul (

	 .rst_i (rst_i)

	,.clk_i      (clk_i)
	,.clk_imul_i (clk_imul_i)

	,.stb_i  (opImul_stb)
	,.args_i (opImul_args)
	,.rdy_o  (opImul_rdy)

	,.ostb_i  (rW0_opImul_done)
	,.rslt_o  (opImul_rslt)
	,.gprid_o (opImul_rIdx)
	,.ordy_o  (opImul_done)
);
