// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (rst_i) begin

	oplicounter <= 0;

	oplioffset <= 0;

end else if (sequencerready && oplicounter) begin

	oplilsb <= {oplilsb[((ARCHBITSZ-16)-1):(16*(0))], {instrbufferdataout1, instrbufferdataout0}};

	oplicounter <= (oplicounter - 1'b1);

	if (oplicountereq1)
		oplioffset <= 0;
	else
		oplioffset <= (oplioffset + 1'b1);

end else if (sequencerready_ && !instrbuffernotempty && instrfetchfaulted) begin

	oplicounter <= 0;

	oplioffset <= 0;

end else if (miscrdyandsequencerreadyandgprrdy1 && (isopimm || isopinc)) begin

	wasopinc <= isopinc;
	wasoprli <= isoprli;

	opligprdata1 <= gprdata1;

	oplitype <= instrbufferdataout0[1:0];

	opligpr <= instrbufferdataout1[7:4];

	oplicounter <= instrbufferdataout0[1:0];

	oplioffset <= 1;
end
