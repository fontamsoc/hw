// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin
	// Reset logic.

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

	if (ARCHBITSZ == 16)
		oplicounter <= instrbufferdataout0[0];
	else if (ARCHBITSZ == 32)
		oplicounter <= instrbufferdataout0[1:0];
	else
		oplicounter <= ((instrbufferdataout0[1:0] == 2'b11) ? 3'd4 : {1'b0, instrbufferdataout0[1:0]});

	oplioffset <= 1;
end
