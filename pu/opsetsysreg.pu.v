// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin
	ksysopfaulthdlr <= {(ARCHBITSZ-1){1'b0}};
	ksl <= KERNELSPACESTART;
	flags <= 'h2000;
end else if (miscrdyandsequencerreadyandgprrdy1 && isopsetsysreg) begin
	if (isoptype0) ksysopfaulthdlr <= gprdata1[ARCHBITSZ-1:1];
	`ifdef PUMMU
	else if (isoptype1) ksl <= gprdata1;
	else if (isoptype4 && (inkernelmode || isflagsetasid)) asid <= gprdata1[13-1:0];
	`endif
	else if (isoptype6 && (inkernelmode || isflagsetflags)) flags <= gprdata1[16-1:0];
end
