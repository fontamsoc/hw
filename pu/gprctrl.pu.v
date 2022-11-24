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
	// Logic used to set gprrdy[] and gpr[].
	// The check for whether loading an immediate
	// is occuring, must be the priority.
	if (rst_i) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = 0;
		gprdata = 0;
		gprwe = 0;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (sequencerready && oplicountereq1) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = {inusermode, opligpr};
		gprdata = opliresult;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end
	`ifdef PUDBG
	else if (dbgbrk && dbgcmd == DBGCMDSETGPR) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = dbgarg;
		gprdata = dbgiarg;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end
	`endif
	else if (multicycleoprdy) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = 0;
		gprdata = 0;
		gprwe = 0;
		gprrdyidx = gpridx1;
		gprrdyval = 0;
		gprrdywe = 1;
	end
	// The check for single-cycle instructions start here.
	else if (opli8done) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opli8result;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opalu0done) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opalu0result;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opalu1done) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opalu1result;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opalu2done) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opalu2result;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	`ifdef PUDSPMUL
	end else if (opdspmuldone) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opdspmulresult;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	`endif
	end else if (opjldone) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = {ipnxt, 1'b0};
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opgetsysregdone) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opgetsysregresult;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opgetsysreg1done) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = gpridx1;
		gprdata = opgetsysreg1result;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end else if (opsetgprdone) begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = opsetgprdstidx;
		gprdata = opsetgprresult;
		gprwe = 1;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end
	// The check for multi-cycle instructions start here.
	else if (oplddone) begin
		gprctrlstate = GPRCTRLSTATEOPLD;
		gpridx = opldgpr;
		gprdata = opldresult;
		gprwe = 1;
		gprrdyidx = opldgpr;
		gprrdyval = 1;
		gprrdywe = 1;
	end else if (opldstdone) begin
		gprctrlstate = GPRCTRLSTATEOPLDST;
		gpridx = opldstgpr;
		gprdata = opldstresult;
		gprwe = 1;
		gprrdyidx = opldstgpr;
		gprrdyval = 1;
		gprrdywe = 1;
	end else if (opmuldivdone) begin
		gprctrlstate = GPRCTRLSTATEOPMULDIV;
		gpridx = opmuldivgpr;
		gprdata = opmuldivresult;
		gprwe = 1;
		gprrdyidx = opmuldivgpr;
		gprrdyval = 1;
		gprrdywe = 1;
	end else begin
		gprctrlstate = GPRCTRLSTATEDONE;
		gpridx = 0;
		gprdata = 0;
		gprwe = 0;
		gprrdyidx = 0;
		gprrdyval = 0;
		gprrdywe = 0;
	end
end
