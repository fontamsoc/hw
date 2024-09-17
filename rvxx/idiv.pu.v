// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opIdiv_stb = (iD0_opIdiv_stb && eX0_insn_valid_i);

// Significance of each bit in the field within
// opIdiv_args storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam OPIDIVTYPEBITSZ = 2;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPIDIVTYPEBITSZ) -1 : 0] opIdiv_args =
	{!iD0_func3[0], iD0_func3[1], iD0_rdId, iD0_rs1, iD0_rs2};

wire opIdiv_rdy;
assign iD0_opIdiv_bsy = !opIdiv_rdy;

wire [WORDBITSZ -1 : 0]   opIdiv_rslt;
wire [CLOG2GPRCNT -1 : 0] opIdiv_rIdx;
wire                      opIdiv_done;

// Restrict IDIVCNT to 1, 2, 4 or 8.
localparam OPIDIVCNT = ((IDIVCNT != 2 && IDIVCNT != 4 && IDIVCNT != 8) ? 1 : IDIVCNT);

opidiv #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
	,.INSTCNT   (OPIDIVCNT)
) opIdiv (

	 .rst_i (rst_i)

	,.clk_i      (clk_i)
	,.clk_idiv_i (clk_idiv_i)

	,.stb_i  (opIdiv_stb)
	,.args_i (opIdiv_args)
	,.rdy_o  (opIdiv_rdy)

	,.ostb_i  (rW0_opIdiv_done)
	,.rslt_o  (opIdiv_rslt)
	,.gprid_o (opIdiv_rIdx)
	,.ordy_o  (opIdiv_done)
);
