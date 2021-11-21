// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin

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

	pi1_data_o = 0;

	pi1_sel_o = {(ARCHBITSZ/8){1'b1}};

	pi1_op_o = MEMREADOP;

end else begin

	pi1_addr_o = 0;
	pi1_data_o = 0;
	pi1_sel_o = 0;

	pi1_op_o = MEMNOOP;
end
