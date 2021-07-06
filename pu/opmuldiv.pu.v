// Copyright (c) William Fonkou Tambe
// All rights reserved.

if (opmuldivdone) begin
	opmuldivprevtype <= opmuldivfifobuffero[MULDIVISFLOAT:MULDIVSIGNED];
	opmuldivprevgprdata1 <= opmuldivfifobuffero[(ARCHBITSZ*2)-1:ARCHBITSZ];
	opmuldivprevgprdata2 <= opmuldivfifobuffero[ARCHBITSZ-1:0];
end

if (rst_i) begin

	opmuldivbusy <= 0;

end else if (!opmuldivdone) begin

	if (opmuldivbusy) begin

		if (opmuldivfifobuffero[MULDIVISDIV]) begin

			if (opmuldivdivdiff[(ARCHBITSZ*2)-1]) opmuldivcumulator <= {opmuldivcumulator[(ARCHBITSZ*2)-2:0], 1'b0};
			else opmuldivcumulator <= {opmuldivdivdiff[(ARCHBITSZ*2)-2:0], 1'b1};

			if (&opmuldivcounter) begin

				opmuldivdone_a <= ~opmuldivdone_b;

				opmuldivbusy <= 0;
			end

		end else begin

			opmuldivcumulator <= {opmuldivcumulatoroperand, opmuldivcumulator[ARCHBITSZ-1:2]};

			if (&(opmuldivcounter[(CLOG2ARCHBITSZ-1)-1:0])) begin

				opmuldivdone_a <= ~opmuldivdone_b;

				opmuldivbusy <= 0;
			end
		end

		opmuldivcounter <= opmuldivcounter + 1'b1;

	end else if (opmuldivstart) begin

		opmuldivgpr <= opmuldivfifobuffero[((ARCHBITSZ*2)+CLOG2GPRCNTTOTAL)-1:ARCHBITSZ*2];

		if (opmuldivfifobuffero[MULDIVISFLOAT:MULDIVSIGNED] != opmuldivprevtype ||
			opmuldivfifobuffero[(ARCHBITSZ*2)-1:ARCHBITSZ] != opmuldivprevgprdata1 ||
			opmuldivfifobuffero[ARCHBITSZ-1:0] != opmuldivprevgprdata2) begin

			opmuldivcounter <= 0;

			if (opmuldivfifobuffero[MULDIVSIGNED] && opmuldivfifobuffero[(ARCHBITSZ*2)-1])
				opmuldivcumulator <= {{ARCHBITSZ{1'b0}}, -opmuldivfifobuffero[(ARCHBITSZ*2)-1:ARCHBITSZ]};
			else opmuldivcumulator <= {{ARCHBITSZ{1'b0}}, opmuldivfifobuffero[(ARCHBITSZ*2)-1:ARCHBITSZ]};

			opmuldivbusy <= 1;

		end else begin
			opmuldivdone_a <= ~opmuldivdone_b;
		end
	end
end

if (opmuldivfifobufferen) begin
	opmuldivstart_a <= ~opmuldivstart_b;
end
