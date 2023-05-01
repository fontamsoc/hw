// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @* begin
	// Implement getsysopcode, getuip, getfaultaddr, getfaultreason,
	// getclkcyclecnt, getclkcyclecnth, gettlbsize, geticachesize.
	case (instrbufdato0[2:0])
	0:       opgetsysregresult = {{(ARCHBITSZ-16){1'b0}}, sysopcode};
	1:       opgetsysregresult = {uip, 1'b0};
	2:       opgetsysregresult = faultaddr;
	3:       opgetsysregresult = {{(ARCHBITSZ-3){1'b0}}, faultreason};
	4:       opgetsysregresult = clkcyclecnt[ARCHBITSZ -1 : 0];
	5:       opgetsysregresult = clkcyclecnt[(ARCHBITSZ*2) -1 : ARCHBITSZ];
	6:       opgetsysregresult = TLBSETCOUNT;
	default: opgetsysregresult = (ICACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
	endcase
end

always @* begin
	// Implement getcoreid, getclkfreq, getdcachesize, gettlb, getcap, getver.
	case (instrbufdato0[2:0])
	0:       opgetsysreg1result = id_i;
	1:       opgetsysreg1result = CLKFREQ;
	`ifdef PUDCACHE
	2:       opgetsysreg1result = (DCACHESETCOUNT << CLOG2XARCHBITSZBY8DIFF);
	`endif
	`ifdef PUMMU
	3:       opgetsysreg1result = opgettlbresult;
	`endif
	4:       opgetsysreg1result = // 16bits value returned to take PU16 into account.
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
	5:       opgetsysreg1result = VERSION; // 16bits value returned to take PU16 into account.
	default: opgetsysreg1result = 0;
	endcase
end
