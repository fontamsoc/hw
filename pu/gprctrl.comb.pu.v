// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

// The result of single-cycle operations get processed first
// because they can complete every clock cycles.
// The "done" signal of a multicycle operation is 1 until it is
// set here to 0, since gprctrl might not see its "done" signal
// because it is processing another operation "done" signal.

// The gpr index in instrbufferdataout1[7:4] is guaranteed
// to be valid when the "done" signal of a single-cycle
// operation is 1; similarly the result of a single-cycle operation
// is guarantied to be valid only when its corresponding "done"
// signal is 1.

// Logic used to set gprrdy[] and gpr[].
// The check for whether loading an immediate
// is occuring, must be the priority.
if (rst_i) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (gprrdyoff) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = gprrdyrstidx;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (sequencerready && oplicountereq1) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = {inusermode, opligpr};
	gprdata = opliresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end
`ifdef PUDBG
else if (dbgbrk && dbgcmd == DBGCMDSETGPR) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = dbgarg;
	gprdata = dbgiarg;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end
`endif
else if (multicycleoprdy) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = gprindex1;
	gprrdyval = 0;
	gprrdywriteenable = 1;
end
// The check for single-cycle instructions start here.
else if (opli8done) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opli8result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu0done) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opalu0result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu1done) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opalu1result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu2done) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opalu2result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
`ifdef PUDSPMUL
end else if (opdspmuldone) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opdspmulresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
`endif
end else if (opjldone) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = {ipplusone, 1'b0};
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opgetsysregdone) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opgetsysregresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opgetsysreg1done) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = gprindex1;
	gprdata = opgetsysreg1result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opsetgprdone) begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = opsetgprdstidx;
	gprdata = opsetgprresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end
// The check for multi-cycle instructions start here.
else if (oplddone) begin
	gprctrlstate = GPRCTRLSTATEOPLD;
	gprindex = opldgpr;
	gprdata = opldresult;
	gprwriteenable = 1;
	gprrdyindex = opldgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (opldstdone) begin
	gprctrlstate = GPRCTRLSTATEOPLDST;
	gprindex = opldstgpr;
	gprdata = opldstresult;
	gprwriteenable = 1;
	gprrdyindex = opldstgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (opmuldivdone) begin
	gprctrlstate = GPRCTRLSTATEOPMULDIV;
	gprindex = opmuldivgpr;
	gprdata = opmuldivresult;
	gprwriteenable = 1;
	gprrdyindex = opmuldivgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else begin
	gprctrlstate = GPRCTRLSTATEDONE;
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end
