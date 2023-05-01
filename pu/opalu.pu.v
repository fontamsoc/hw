// SPDX-License-Identifier: GPL-2.0-only
// (c) William Fonkou Tambe

always @* begin
	// Implement sgt, sgte, sgtu, sgteu.
	case (instrbufdato0[2:0])
	0:       opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) > $signed(gprdata2)};
	1:       opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) >= $signed(gprdata2)};
	2:       opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 > gprdata2};
	default: opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 >= gprdata2};
	endcase
end
`ifdef PUSC2
always @* begin
	case (sc2instrbufdato0[2:0])
	0:       sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) > $signed(sc2gprdata2)};
	1:       sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) >= $signed(sc2gprdata2)};
	2:       sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 > sc2gprdata2};
	default: sc2opalu0result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 >= sc2gprdata2};
	endcase
end
`endif

always @* begin
	// Implement add, sub, seq, sne, slt, slte, sltu, slteu.
	case (instrbufdato0[2:0])
	0:       opalu1result = gprdata1 + gprdata2;
	1:       opalu1result = gprdata1 - gprdata2;
	2:       opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 == gprdata2};
	3:       opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 != gprdata2};
	4:       opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) < $signed(gprdata2)};
	5:       opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) <= $signed(gprdata2)};
	6:       opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 < gprdata2};
	default: opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 <= gprdata2};
	endcase
end
`ifdef PUSC2
always @* begin
	case (sc2instrbufdato0[2:0])
	0:       sc2opalu1result = sc2gprdata1 + sc2gprdata2;
	1:       sc2opalu1result = sc2gprdata1 - sc2gprdata2;
	2:       sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 == sc2gprdata2};
	3:       sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 != sc2gprdata2};
	4:       sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) < $signed(sc2gprdata2)};
	5:       sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(sc2gprdata1) <= $signed(sc2gprdata2)};
	6:       sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 < sc2gprdata2};
	default: sc2opalu1result = {{(ARCHBITSZ-1){1'b0}}, sc2gprdata1 <= sc2gprdata2};
	endcase
end
`endif

always @* begin
	// Implement sll, srl, sra, and, or, xor, not, cpy.
	case (instrbufdato0[2:0])
	0:       opalu2result = gprdata1 << gprdata2[CLOG2ARCHBITSZ-1:0];
	1:       opalu2result = gprdata1 >> gprdata2[CLOG2ARCHBITSZ-1:0];
	2:       opalu2result = $signed(gprdata1) >>> gprdata2[CLOG2ARCHBITSZ-1:0];
	3:       opalu2result = gprdata1 & gprdata2;
	4:       opalu2result = gprdata1 | gprdata2;
	5:       opalu2result = gprdata1 ^ gprdata2;
	6:       opalu2result = ~gprdata2;
	default: opalu2result = gprdata2;
	endcase
end
`ifdef PUSC2
always @* begin
	case (sc2instrbufdato0[2:0])
	0:       sc2opalu2result = sc2gprdata1 << sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	1:       sc2opalu2result = sc2gprdata1 >> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	2:       sc2opalu2result = $signed(sc2gprdata1) >>> sc2gprdata2[CLOG2ARCHBITSZ-1:0];
	3:       sc2opalu2result = sc2gprdata1 & sc2gprdata2;
	4:       sc2opalu2result = sc2gprdata1 | sc2gprdata2;
	5:       sc2opalu2result = sc2gprdata1 ^ sc2gprdata2;
	6:       sc2opalu2result = ~sc2gprdata2;
	default: sc2opalu2result = sc2gprdata2;
	endcase
end
`endif

`ifdef PUDSPMUL
always @* begin
	// Implement mulu, mulhu, mul, mulh.
	case (instrbufdato0[2:0])
	0:       opdspmulresult = opdspmulresult_unsigned[ARCHBITSZ-1:0];
	1:       opdspmulresult = opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
	2:       opdspmulresult = opdspmulresult_signed[ARCHBITSZ-1:0];
	default: opdspmulresult = opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
	endcase
end
`ifdef PUSC2
always @* begin
	case (sc2instrbufdato0[2:0])
	0:       sc2opdspmulresult = sc2opdspmulresult_unsigned[ARCHBITSZ-1:0];
	1:       sc2opdspmulresult = sc2opdspmulresult_unsigned[(ARCHBITSZ*2)-1:ARCHBITSZ];
	2:       sc2opdspmulresult = sc2opdspmulresult_signed[ARCHBITSZ-1:0];
	default: sc2opdspmulresult = sc2opdspmulresult_signed[(ARCHBITSZ*2)-1:ARCHBITSZ];
	endcase
end
`endif
`endif
