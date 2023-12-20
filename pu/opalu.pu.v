// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @* begin

	opaluresult = {ipnxt, 1'b0}; // isopjl.

	if (isopalu0) begin
		// Implement sgt, sgte, sgtu, sgteu.
		case (instrbufdato0[2:0])
		0:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) > $signed(gprdata2)};
		1:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) >= $signed(gprdata2)};
		2:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 > gprdata2};
		default: opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 >= gprdata2};
		endcase
	end

	if (isopalu1) begin
		// Implement add, sub, seq, sne, slt, slte, sltu, slteu.
		case (instrbufdato0[2:0])
		0:       opaluresult = gprdata1 + gprdata2;
		1:       opaluresult = gprdata1 - gprdata2;
		2:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 == gprdata2};
		3:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 != gprdata2};
		4:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) < $signed(gprdata2)};
		5:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) <= $signed(gprdata2)};
		6:       opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 < gprdata2};
		default: opaluresult = {{(ARCHBITSZ-1){1'b0}}, gprdata1 <= gprdata2};
		endcase
	end

	if (isopalu2) begin
		// Implement sll, srl, sra, and, or, xor, not, cpy.
		case (instrbufdato0[2:0])
		0:       opaluresult = gprdata1 << gprdata2[CLOG2ARCHBITSZ-1:0];
		1:       opaluresult = gprdata1 >> gprdata2[CLOG2ARCHBITSZ-1:0];
		2:       opaluresult = $signed(gprdata1) >>> gprdata2[CLOG2ARCHBITSZ-1:0];
		3:       opaluresult = gprdata1 & gprdata2;
		4:       opaluresult = gprdata1 | gprdata2;
		5:       opaluresult = gprdata1 ^ gprdata2;
		6:       opaluresult = ~gprdata2;
		default: opaluresult = gprdata2;
		endcase
	end

	`ifdef PUDSPMUL
	if (isopmuldiv /* instead of isopimul for fewer logic */) begin
		// Implement mulu, mulhu, mul, mulh.
		case (instrbufdato0[2:0])
		0:       opaluresult = opdspmulresult_unsigned[ARCHBITSZ-1:0];
		1:       opaluresult = opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
		2:       opaluresult = opdspmulresult_signed[ARCHBITSZ-1:0];
		default: opaluresult = opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
		endcase
	end
	`endif
end

`ifdef PUSC2
always @* begin

	sc2opaluresult = {sc2ipnxt, 1'b0}; // sc2isopjl.

	if (sc2isopalu0) begin
		case (sc2instrbufdato0[2:0])
		0:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) > $signed(sc2gprdata2)};
		1:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) >= $signed(sc2gprdata2)};
		2:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 > sc2gprdata2};
		default: sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 >= sc2gprdata2};
		endcase
	end

	if (sc2isopalu1) begin
		case (sc2instrbufdato0[2:0])
		0:       sc2opaluresult = sc2gprdata1 + sc2gprdata2;
		1:       sc2opaluresult = sc2gprdata1 - sc2gprdata2;
		2:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 == sc2gprdata2};
		3:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 != sc2gprdata2};
		4:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) < $signed(sc2gprdata2)};
		5:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) <= $signed(sc2gprdata2)};
		6:       sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 < sc2gprdata2};
		default: sc2opaluresult = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 <= sc2gprdata2};
		endcase
	end

	if (sc2isopalu2) begin
		case (sc2instrbufdato0[2:0])
		0:       sc2opaluresult = sc2gprdata1 << sc2gprdata2[CLOG2ARCHBITSZ-1:0];
		1:       sc2opaluresult = sc2gprdata1 >> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
		2:       sc2opaluresult = $signed(sc2gprdata1) >>> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
		3:       sc2opaluresult = sc2gprdata1 & sc2gprdata2;
		4:       sc2opaluresult = sc2gprdata1 | sc2gprdata2;
		5:       sc2opaluresult = sc2gprdata1 ^ sc2gprdata2;
		6:       sc2opaluresult = ~sc2gprdata2;
		default: sc2opaluresult = sc2gprdata2;
		endcase
	end

	`ifdef PUDSPMUL
	if (sc2isopmuldiv /* instead of sc2isopdspmul for fewer logic */) begin
		case (sc2instrbufdato0[2:0])
		0:       sc2opaluresult = sc2opdspmulresult_unsigned[ARCHBITSZ-1:0];
		1:       sc2opaluresult = sc2opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
		2:       sc2opaluresult = sc2opdspmulresult_signed[ARCHBITSZ-1:0];
		default: sc2opaluresult = sc2opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
		endcase
	end
	`endif
end
`endif
