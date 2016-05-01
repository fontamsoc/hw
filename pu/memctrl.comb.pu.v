// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The instruction fetch request has the least priority so that
// load and store instructions can be completed as soon as possible,
// and so that the next instruction in the buffer can be sequenced
// as soon as possible.
if (rst_i) begin
	// pi1_addr_o, pi1_data_o and pi1_sel_o are
	// don't-care in this state and do not need to be set.
	// ### Set so that verilog works correctly.
	pi1_addr_o = 0;
	pi1_data_o = 0;
	pi1_sel_o = 0;

	pi1_op_o = MEMNOOP;

end else if (dcacheslaveop != MEMNOOP) begin

	pi1_addr_o = dcacheslaveaddr;
	pi1_data_o = dcacheslavedato;
	pi1_sel_o = dcacheslavesel;
	pi1_op_o = dcacheslaveop;

end else if (instrfetchmemaccesspending) begin

	pi1_addr_o = instrfetchppninstrfetchaddr;

	// pi1_data_o is a don't-care in this state
	// and do not need to be set.
	// ### Set so that verilog works correctly.
	pi1_data_o = 0;

	pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

	pi1_op_o = MEMREADOP;

end else begin
	// pi1_addr_o, pi1_data_o and pi1_sel_o are
	// don't-care in this state and do not need to be set.
	// ### Set so that verilog works correctly.
	pi1_addr_o = 0;
	pi1_data_o = 0;
	pi1_sel_o = 0;

	pi1_op_o = MEMNOOP;
end
