// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @* begin
	// Implement sgt, sgte, sgtu, sgteu.
	if      (isoptype0) opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) > $signed(gprdata2)};
	else if (isoptype1) opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) >= $signed(gprdata2)};
	else if (isoptype2) opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 > gprdata2};
	else                opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 >= gprdata2};
end
`ifdef PUSC2
always @* begin
	if      (sc2isoptype0) sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) > $signed(sc2gprdata2)};
	else if (sc2isoptype1) sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) >= $signed(sc2gprdata2)};
	else if (sc2isoptype2) sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 > sc2gprdata2};
	else                   sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 >= sc2gprdata2};
end
`endif

always @* begin
	// Implement add, sub, seq, sne, slt, slte, sltu, slteu.
	if      (isoptype0) opalu1result = gprdata1 + gprdata2;
	else if (isoptype1) opalu1result = gprdata1 - gprdata2;
	else if (isoptype2) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 == gprdata2};
	else if (isoptype3) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 != gprdata2};
	else if (isoptype4) opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) < $signed(gprdata2)};
	else if (isoptype5) opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) <= $signed(gprdata2)};
	else if (isoptype6) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 < gprdata2};
	else                opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 <= gprdata2};
end
`ifdef PUSC2
always @* begin
	if      (sc2isoptype0) sc2opalu1result = sc2gprdata1 + sc2gprdata2;
	else if (sc2isoptype1) sc2opalu1result = sc2gprdata1 - sc2gprdata2;
	else if (sc2isoptype2) sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 == sc2gprdata2};
	else if (sc2isoptype3) sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 != sc2gprdata2};
	else if (sc2isoptype4) sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) < $signed(sc2gprdata2)};
	else if (sc2isoptype5) sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) <= $signed(sc2gprdata2)};
	else if (sc2isoptype6) sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 < sc2gprdata2};
	else                   sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 <= sc2gprdata2};
end
`endif

always @* begin
	// Implement sll, srl, sra, and, or, xor, not, cpy.
	if      (isoptype0) opalu2result = gprdata1 << gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (isoptype1) opalu2result = gprdata1 >> gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (isoptype2) opalu2result = $signed(gprdata1) >>> gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (isoptype3) opalu2result = gprdata1 & gprdata2;
	else if (isoptype4) opalu2result = gprdata1 | gprdata2;
	else if (isoptype5) opalu2result = gprdata1 ^ gprdata2;
	else if (isoptype6) opalu2result = ~gprdata2;
	else                opalu2result = gprdata2;
end
`ifdef PUSC2
always @* begin
	if      (sc2isoptype0) sc2opalu2result = sc2gprdata1 << sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (sc2isoptype1) sc2opalu2result = sc2gprdata1 >> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (sc2isoptype2) sc2opalu2result = $signed(sc2gprdata1) >>> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	else if (sc2isoptype3) sc2opalu2result = sc2gprdata1 & sc2gprdata2;
	else if (sc2isoptype4) sc2opalu2result = sc2gprdata1 | sc2gprdata2;
	else if (sc2isoptype5) sc2opalu2result = sc2gprdata1 ^ sc2gprdata2;
	else if (sc2isoptype6) sc2opalu2result = ~sc2gprdata2;
	else                   sc2opalu2result = sc2gprdata2;
end
`endif

`ifdef PUDSPMUL
always @* begin
	// Implement mulu, mulhu, mul, mulh.
	if      (isoptype0) opdspmulresult = opdspmulresult_unsigned[ARCHBITSZ-1:0];
	else if (isoptype1) opdspmulresult = opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
	else if (isoptype2) opdspmulresult = opdspmulresult_signed[ARCHBITSZ-1:0];
	else                opdspmulresult = opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
end
`ifdef PUSC2
always @* begin
	if      (sc2isoptype0) sc2opdspmulresult = sc2opdspmulresult_unsigned[ARCHBITSZ-1:0];
	else if (sc2isoptype1) sc2opdspmulresult = sc2opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
	else if (sc2isoptype2) sc2opdspmulresult = sc2opdspmulresult_signed[ARCHBITSZ-1:0];
	else                   sc2opdspmulresult = sc2opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
end
`endif
`endif
