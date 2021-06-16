// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin
	gprrdyon <= 0;
	gprrdyrstidx <= {CLOG2GPRCNTTOTAL{1'b1}};
end else if (gprrdyoff) begin
	if (gprrdyrstidx)
		gprrdyrstidx <= gprrdyrstidx - 1'b1;
	else
		gprrdyon <= 1;
end

if (rst_i) begin
	oplddone_b <= oplddone_a;
	opldstdone_b <= opldstdone_a;
	opmuldivstart_b <= opmuldivstart_a;
	opmuldivdone_b <= opmuldivdone_a;
end else if (gprrdyoff);
else if (sequencerready && oplicountereq1);
else if (multicycleoprdy);
else if (opli8done);
else if (opalu0done);
else if (opalu1done);
else if (opalu2done);
else if (opjldone);
else if (opgetsysregdone);
else if (opgetsysreg1done);
else if (opsetgprdone);
else if (oplddone)
	oplddone_b <= oplddone_a;
else if (opldstdone)
	opldstdone_b <= opldstdone_a;
else if (opmuldivdone) begin
	opmuldivstart_b <= opmuldivstart_a;
	opmuldivdone_b <= opmuldivdone_a;
end
