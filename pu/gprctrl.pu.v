// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The result of single-cycle operations get processed first
// because they can complete every clock cycles.
// The "done" signal of a multicycle operation is 1 until it is
// set here to 0, since gprctrl might not see its "done" signal
// because it is processing another operation "done" signal.

// The gpr index in instrbufdato1[7:4] is guaranteed
// to be valid when the "done" signal of a single-cycle
// operation is 1; similarly the result of a single-cycle operation
// is guarantied to be valid only when its corresponding "done"
// signal is 1.

always @* begin

	gprctrlstate = GPRCTRLSTATEDONE;
	gpridx       = 0;
	gprdata      = 0;
	gprwe        = 0;
	gprrdyidx    = 0;
	gprrdyval    = 0;
	gprrdywe     = 0;

	if (rst_i) begin
	// Logic used to set gprrdy[] and gpr[].
	// The check for whether loading an immediate
	// is occuring, must be the priority.
	end else if (sequencerready && oplicountereq1) begin
		gpridx  = {inusermode, opligpr};
		gprdata = opliresult;
		gprwe   = 1;
	`ifdef PUDBG
	end else if (dbgbrk && dbgcmd == DBGCMDSETGPR) begin
		gpridx  = dbgarg;
		gprdata = dbgiarg;
		gprwe   = 1;
	`endif
	end else if (multicycleoprdy) begin
		gprrdyidx = gpridx1;
		gprrdywe  = 1;
	// The check for single-cycle instructions start here.
	end else if (opli8done) begin
		gpridx  = gpridx1;
		gprdata = opli8result;
		gprwe   = (
			`ifdef PUSC2
			`ifdef PUSC2SKIPSC1LI8
			sc2exec ? (!sc2skipsc1li8 || sc2keepgpr1) :
			`endif
			`endif
			1'b1);
	end else if (opaludone) begin
		gpridx  = gpridx1;
		gprdata = opaluresult;
		gprwe   = (
			`ifdef PUSC2
			`ifdef PUSC2SKIPSC1CPY
			sc2exec ?  (!sc2skipsc1cpy || sc2keepgpr1) :
			`endif
			`endif
			1'b1);
	end else if (opgetsysregdone) begin
		gpridx  = gpridx1;
		gprdata = opgetsysregresult;
		gprwe   = 1;
	end else if (opgetsysreg1done) begin
		gpridx  = gpridx1;
		gprdata = opgetsysreg1result;
		gprwe   = 1;
	end else if (opsetgprdone) begin
		gpridx  = opsetgprdstidx;
		gprdata = opsetgprresult;
		gprwe   = 1;
	// The check for multi-cycle instructions start here.
	end else if (oplddone) begin
		gprctrlstate = GPRCTRLSTATEOPLD;
		gpridx       = opldgpr;
		gprdata      = opldresult;
		gprwe        = 1;
		gprrdyidx    = opldgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	end else if (opldstdone) begin
		gprctrlstate = GPRCTRLSTATEOPLDST;
		gpridx       = opldstgpr;
		gprdata      = opldstresult;
		gprwe        = 1;
		gprrdyidx    = opldstgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`ifndef PUDSPMUL
	end else if (opimuldone) begin
		gprctrlstate = GPRCTRLSTATEOPIMUL;
		gpridx       = opimulgpr;
		gprdata      = opimulresult;
		gprwe        = 1;
		gprrdyidx    = opimulgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`endif
	end else if (opidivdone) begin
		gprctrlstate = GPRCTRLSTATEOPIDIV;
		gpridx       = opidivgpr;
		gprdata      = opidivresult;
		gprwe        = 1;
		gprrdyidx    = opidivgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`ifdef PUFADDFSUB
	end else if (opfaddfsubdone) begin
		gprctrlstate = GPRCTRLSTATEOPFADDFSUB;
		gpridx       = opfaddfsubgpr;
		gprdata      = opfaddfsubresult;
		gprwe        = 1;
		gprrdyidx    = opfaddfsubgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`endif
	`ifdef PUFMUL
	end else if (opfmuldone) begin
		gprctrlstate = GPRCTRLSTATEOPFMUL;
		gpridx       = opfmulgpr;
		gprdata      = opfmulresult;
		gprwe        = 1;
		gprrdyidx    = opfmulgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`endif
	`ifdef PUFDIV
	end else if (opfdivdone) begin
		gprctrlstate = GPRCTRLSTATEOPFDIV;
		gpridx       = opfdivgpr;
		gprdata      = opfdivresult;
		gprwe        = 1;
		gprrdyidx    = opfdivgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	`endif
	end
end

`ifdef PUSC2
always @* begin
	sc2gpridx  = sc2gpridx1;
	sc2gprdata = 0;
	sc2gprwe   = 0;
	// SC2 only handles 8bits-immediates, non-branching single-cycle instructions.
	if (sc2opli8done) begin
		sc2gprdata = sc2opli8result;
		sc2gprwe   = 1;
	end
	if (sc2opaludone) begin
		sc2gprdata = sc2opaluresult;
		sc2gprwe   = 1;
	end
end
`endif
