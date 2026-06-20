// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opFpu_stb = (iD_opFpu_stb && iD_insn_valid);

// Resolve dynamic rounding (func3==111) to the architectural frm at ISSUE, so a
// later "csrw frm" cannot perturb an already-dispatched op (the fcsr ordering-hazard
// fix; the FPU core never reads frm). For the 1-cycle ops this is a don't-care.
wire [3 -1 : 0] opFpu_rm = (iD_func3 == 3'b111) ? csrFrm : iD_func3;

// args layout matches fpu.sv: { rm[2:0], optype[4:0], rdId, rs1, rs2 }.
localparam OPFPUTYPEBITSZ = 5;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPFPUTYPEBITSZ+3) -1 : 0] opFpu_args =
	{opFpu_rm, iD_opFpu_optype, iD_rdId, iD_rs1, iD_rs2};

wire opFpu_rdy;
assign iD_opFpu_bsy = !opFpu_rdy;

wire [WORDBITSZ -1 : 0]   opFpu_rslt;
wire [CLOG2GPRCNT -1 : 0] opFpu_rIdx;
wire [5 -1 : 0]           opFpu_flags;
wire                      opFpu_done;

// The FPU is large; allow 1 or 2 instances (a single-issue core needs only 1).
localparam OPFPUCNT = ((FPUCNT != 2) ? 1 : FPUCNT);

opfpu #(
	 .WORDBITSZ (WORDBITSZ)
	,.GPRCNT    (GPRCNT)
	,.INSTCNT   (OPFPUCNT)
) opFpu (

	 .rst_i (rst_i)

	,.clk_i (clk_i)

	,.stb_i  (opFpu_stb)
	,.args_i (opFpu_args)
	,.rdy_o  (opFpu_rdy)
	,.busy_o (opFpu_busy)

	,.ostb_i  (rW_opFpu_done)
	,.rslt_o  (opFpu_rslt)
	,.gprid_o (opFpu_rIdx)
	,.flags_o (opFpu_flags)
	,.ordy_o  (opFpu_done)
);
