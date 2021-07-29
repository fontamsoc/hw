// Copyright (c) William Fonkou Tambe
// All rights reserved.

if      (isoptype0) opgetsysregresult = {{(ARCHBITSZ-16){1'b0}}, sysopcode};
else if (isoptype1) opgetsysregresult = {uip, 1'b0};
else if (isoptype2) opgetsysregresult = faultaddr;
else if (isoptype3) opgetsysregresult = {{(ARCHBITSZ-3){1'b0}}, faultreason};
else if (isoptype4) opgetsysregresult = clkcyclecnt[ARCHBITSZ -1 : 0];
else if (isoptype5) opgetsysregresult = clkcyclecnt[(ARCHBITSZ*2) -1 : ARCHBITSZ];
else if (isoptype6) opgetsysregresult = TLBSETCOUNT;
else opgetsysregresult = ICACHESETCOUNT;

if (isoptype0) opgetsysreg1result = id_i;
else if (isoptype1) opgetsysreg1result = CLKFREQ;
`ifdef PUMMU
else if (isoptype3) opgetsysreg1result = gettlbresult;
`endif
else if (isoptype4) opgetsysreg1result =
	{{14{1'b0}}
	`ifdef PUMMU
	`ifdef PUHPTW
	, 1'b1
	`else
	, 1'b0
	`endif
	, 1'b1
	`else
	, 2'b00
	`endif
	};
else opgetsysreg1result = 0;
