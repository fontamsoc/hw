// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (gprrdyoff) begin
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = gprrdyrstidx;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (sequencerready && oplicountereq1) begin
	gprindex = {inusermode, opligpr};
	gprdata = opliresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (multicycleoprdy) begin
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = gprindex1;
	gprrdyval = 0;
	gprrdywriteenable = 1;
end else if (opli8done) begin
	gprindex = gprindex1;
	gprdata = opli8result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu0done) begin
	gprindex = gprindex1;
	gprdata = opalu0result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu1done) begin
	gprindex = gprindex1;
	gprdata = opalu1result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opalu2done) begin
	gprindex = gprindex1;
	gprdata = opalu2result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opjldone) begin
	gprindex = gprindex1;
	gprdata = {ipplusone, 1'b0};
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opgetsysregdone) begin
	gprindex = gprindex1;
	gprdata = opgetsysregresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opgetsysreg1done) begin
	gprindex = gprindex1;
	gprdata = opgetsysreg1result;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (opsetgprdone) begin
	gprindex = opsetgprdstidx;
	gprdata = opsetgprresult;
	gprwriteenable = 1;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end else if (oplddone) begin
	gprindex = opldgpr;
	gprdata = opldresult;
	gprwriteenable = 1;
	gprrdyindex = opldgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (opldstdone) begin
	gprindex = opldstgpr;
	gprdata = opldstresult;
	gprwriteenable = 1;
	gprrdyindex = opldstgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else if (opmuldivdone) begin
	gprindex = opmuldivgpr;
	gprdata = opmuldivresult;
	gprwriteenable = 1;
	gprrdyindex = opmuldivgpr;
	gprrdyval = 1;
	gprrdywriteenable = 1;
end else begin
	gprindex = 0;
	gprdata = 0;
	gprwriteenable = 0;
	gprrdyindex = 0;
	gprrdyval = 0;
	gprrdywriteenable = 0;
end
