// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (opmuldivfifobuffero[MULDIVSIGNED] && opmuldivfifobuffero[(ARCHBITSZ-1)])
	opmuldivrval = -opmuldivfifobuffero[ARCHBITSZ-1:0];
else opmuldivrval = opmuldivfifobuffero[ARCHBITSZ-1:0];

if (opmuldivcumulator[1:0] == 1)
	opmuldivmulx = {{2{1'b0}}, opmuldivrval};
else if (opmuldivcumulator[1:0] == 2)
	opmuldivmulx = {1'b0, opmuldivrval, 1'b0};
else if (opmuldivcumulator[1:0] == 3)
	opmuldivmulx = {opmuldivrval, 1'b0} + opmuldivrval;
else opmuldivmulx = 0;

if (opmuldivfifobuffero[MULDIVISDIV]) begin
	if (opmuldivfifobuffero[MULDIVMSBRSLT]) begin
		if (opmuldivfifobuffero[MULDIVSIGNED] && opmuldivfifobuffero[(ARCHBITSZ*2)-1])
			opmuldivresult = -opmuldivcumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
		else opmuldivresult = opmuldivcumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
	end else begin
		if (opmuldivfifobuffero[MULDIVSIGNED] && (opmuldivfifobuffero[(ARCHBITSZ*2)-1] != opmuldivfifobuffero[(ARCHBITSZ-1)]))
			opmuldivresult = -opmuldivcumulator[ARCHBITSZ-1:0];
		else opmuldivresult = opmuldivcumulator[ARCHBITSZ-1:0];
	end
end else begin
	if (opmuldivfifobuffero[MULDIVMSBRSLT]) begin
		if (opmuldivfifobuffero[MULDIVSIGNED] && (opmuldivfifobuffero[(ARCHBITSZ*2)-1] != opmuldivfifobuffero[(ARCHBITSZ-1)]))
			opmuldivresult = opmuldivcumulatornegated[(ARCHBITSZ*2)-1:ARCHBITSZ];
		else opmuldivresult = opmuldivcumulator[(ARCHBITSZ*2)-1:ARCHBITSZ];
	end else begin
		opmuldivresult = opmuldivcumulator[ARCHBITSZ-1:0];
	end
end
