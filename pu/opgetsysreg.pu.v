// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @* begin
	// Implement getsysopcode, getuip, getfaultaddr, getfaultreason,
	// getclkcyclecnt, getclkcyclecnth, gettlbsize, geticachesize.
	if      (isoptype0) opgetsysregresult = {{(ARCHBITSZ-16){1'b0}}, sysopcode};
	else if (isoptype1) opgetsysregresult = {uip, 1'b0};
	else if (isoptype2) opgetsysregresult = faultaddr;
	else if (isoptype3) opgetsysregresult = {{(ARCHBITSZ-3){1'b0}}, faultreason};
	else if (isoptype4) opgetsysregresult = clkcyclecnt[ARCHBITSZ -1 : 0];
	else if (isoptype5) opgetsysregresult = clkcyclecnt[(ARCHBITSZ*2) -1 : ARCHBITSZ];
	else if (isoptype6) opgetsysregresult = TLBSETCOUNT;
	else                opgetsysregresult = (ICACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
end
`ifdef PUSC2
`ifdef PUSC2SYSOPS
always @* begin
	if      (sc2isoptype0) sc2opgetsysregresult = {{(ARCHBITSZ-16){1'b0}}, sysopcode};
	else if (sc2isoptype1) sc2opgetsysregresult = {uip, 1'b0};
	else if (sc2isoptype2) sc2opgetsysregresult = faultaddr;
	else if (sc2isoptype3) sc2opgetsysregresult = {{(ARCHBITSZ-3){1'b0}}, faultreason};
	else if (sc2isoptype4) sc2opgetsysregresult = clkcyclecnt[ARCHBITSZ -1 : 0];
	else if (sc2isoptype5) sc2opgetsysregresult = clkcyclecnt[(ARCHBITSZ*2) -1 : ARCHBITSZ];
	else if (sc2isoptype6) sc2opgetsysregresult = TLBSETCOUNT;
	else                   sc2opgetsysregresult = (ICACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
end
`endif
`endif

always @* begin
	// Implement getcoreid, getclkfreq, getdcachesize, gettlb, getcap, getver.
	if      (isoptype0) opgetsysreg1result = id_i;
	else if (isoptype1) opgetsysreg1result = CLKFREQ;
	`ifdef PUDCACHE
	else if (isoptype2) opgetsysreg1result = (DCACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
	`endif
	`ifdef PUMMU
	else if (isoptype3) opgetsysreg1result = opgettlbresult;
	`endif
	else if (isoptype4) opgetsysreg1result = // 16bits value returned to take PU16 into account.
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
	else if (isoptype5) opgetsysreg1result = VERSION; // 16bits value returned to take PU16 into account.
	else                opgetsysreg1result = 0;
end
`ifdef PUSC2
`ifdef PUSC2SYSOPS
always @* begin
	if      (sc2isoptype0) sc2opgetsysreg1result = id_i;
	else if (sc2isoptype1) sc2opgetsysreg1result = CLKFREQ;
	`ifdef PUDCACHE
	else if (sc2isoptype2) sc2opgetsysreg1result = (DCACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
	`endif
	// gettlb does not execute in SC2.
	else if (sc2isoptype4) sc2opgetsysreg1result = // 16bits value returned to take PU16 into account.
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
	else if (sc2isoptype5) sc2opgetsysreg1result = VERSION; // 16bits value returned to take PU16 into account.
	else                   sc2opgetsysreg1result = 0;
end
`endif
`endif
