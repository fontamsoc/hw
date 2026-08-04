// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

wire opIdiv_stb = (iD_opIdiv_stb && iD_insn_valid);

// Significance of each bit in the field within
// opIdiv_args storing the type of division to perform.
// [1]: 0/1 means unsigned/signed computation.
// [0]: 0/1 means quotient/remainder of result.
localparam OPIDIVTYPEBITSZ = 2;
wire [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPIDIVTYPEBITSZ) -1 : 0] opIdiv_args =
	{!iD_func3[0], iD_func3[1], iD_rdId, iD_rs1, iD_rs2};

wire opIdiv_rdy;
`ifdef PUIDIVREGRQST
// One-entry registered request stage ahead of opIdiv; it keeps the deep
// iD_stalled -> iD_insn_valid issue cone off the idiv instances' capture
// clock-enables (each division starts one cycle later, which is noise
// against the multi-cycle division itself).
reg                                                        opIdiv_stb_r;
reg [(((WORDBITSZ*2)+CLOG2GPRCNT)+OPIDIVTYPEBITSZ) -1 : 0] opIdiv_args_r;
// The stage advances when empty, or when opIdiv accepts the held request;
// opIdiv_rdy is computed from registered state only (usage and instance
// rdy_o registers), hence no combinational loop through opIdiv_stb.
wire opIdiv_adv = (!opIdiv_stb_r || opIdiv_rdy);
always_ff @(posedge clk_i) begin
	if (rst_i)
		opIdiv_stb_r <= 1'b0;
	else if (opIdiv_adv)
		opIdiv_stb_r <= opIdiv_stb;
	// The payload is captured whenever the stage advances (it is meaningless
	// while opIdiv_stb_r is low) so that the deep issue cone drives a single
	// flop D-input instead of the args clock-enables.
	if (opIdiv_adv)
		opIdiv_args_r <= opIdiv_args;
end
assign iD_opIdiv_bsy = (opIdiv_stb_r && !opIdiv_rdy);
`else
assign iD_opIdiv_bsy = !opIdiv_rdy;
`endif

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

`ifdef PUIDIVREGRQST
	,.stb_i  (opIdiv_stb_r)
	,.args_i (opIdiv_args_r)
`else
	,.stb_i  (opIdiv_stb)
	,.args_i (opIdiv_args)
`endif
	,.rdy_o  (opIdiv_rdy)

	,.ostb_i  (rW_opIdiv_done)
	,.rslt_o  (opIdiv_rslt)
	,.gprid_o (opIdiv_rIdx)
	,.ordy_o  (opIdiv_done)
);
