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
		gprwe   = 1;
	end else if (opalu0done) begin
		gpridx  = gpridx1;
		gprdata = opalu0result;
		gprwe   = 1;
	end else if (opalu1done) begin
		gpridx  = gpridx1;
		gprdata = opalu1result;
		gprwe   = 1;
	end else if (opalu2done) begin
		gpridx  = gpridx1;
		gprdata = opalu2result;
		gprwe   = 1;
	`ifdef PUDSPMUL
	end else if (opdspmuldone) begin
		gpridx  = gpridx1;
		gprdata = opdspmulresult;
		gprwe   = 1;
	`endif
	end else if (opjldone) begin
		gpridx  = gpridx1;
		gprdata = {ipnxt, 1'b0};
		gprwe   = 1;
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
	end else if (opmuldivdone) begin
		gprctrlstate = GPRCTRLSTATEOPMULDIV;
		gpridx       = opmuldivgpr;
		gprdata      = opmuldivresult;
		gprwe        = 1;
		gprrdyidx    = opmuldivgpr;
		gprrdyval    = 1;
		gprrdywe     = 1;
	end
end
