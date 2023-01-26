// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

if (rst_i) begin
	// Reset logic.

	oplicounter <= 0;

	oplioffset <= 0;

end else if (sequencerready && oplicounter) begin

	oplilsb <= {oplilsb[((ARCHBITSZ-16)-1):(16*(0))], {instrbufdato1, instrbufdato0}};

	oplicounter <= (oplicounter - 1'b1);

	if (oplicountereq1)
		oplioffset <= 0;
	else
		oplioffset <= (oplioffset + 1'b1);

end else if (sequencerready_ && !instrbufnotempty && instrfetchfaulted) begin

	oplicounter <= 0;

	oplioffset <= 0;

end else if (miscrdyandsequencerreadyandgprrdy1 && (isopimm || isopinc)) begin

	wasopinc <= isopinc;
	wasoprli <= isoprli;

	opligprdata1 <= gprdata1;

	oplitype <= instrbufdato0[1:0];

	opligpr <= instrbufdato1[7:4];

	if      (ARCHBITSZ == 16)
		oplicounter <= instrbufdato0[0];
	else if (ARCHBITSZ == 32)
		oplicounter <= instrbufdato0[1:0];
	else if (ARCHBITSZ == 64)
		oplicounter <= ((instrbufdato0[1:0] == 2'b11) ? 3'd4 : {1'b0, instrbufdato0[1:0]});

	oplioffset <= 1;
end
