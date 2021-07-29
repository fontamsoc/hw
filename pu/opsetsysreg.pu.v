// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin
	ksysopfaulthdlr <= {(ARCHBITSZ-1){1'b0}};
	ksl <= KERNELSPACESTART;
	flags <= 'h2000;
end else if (miscrdyandsequencerreadyandgprrdy1 && isopsetsysreg) begin
	if (isoptype0) ksysopfaulthdlr <= gprdata1[ARCHBITSZ-1:1];
	`ifdef PUMMU
	else if (isoptype1) ksl <= gprdata1;
	else if (isoptype4 && (inkernelmode || isflagsetasid)) begin
		asid <= gprdata1[13-1:0];
		`ifdef PUHPTW
		hptwpgd <= gpr13val;
		`endif
	end
	`endif
	else if (isoptype6 && (inkernelmode || isflagsetflags)) flags <= gprdata1[16-1:0];
end
