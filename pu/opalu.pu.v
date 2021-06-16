// Copyright (c) William Fonkou Tambe
// All rights reserved.

if      (isoptype0) opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) > $signed(gprdata2)};
else if (isoptype1) opalu0result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) >= $signed(gprdata2)};
else if (isoptype2) opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 > gprdata2};
else                opalu0result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 >= gprdata2};

if      (isoptype0) opalu1result = gprdata1 + gprdata2;
else if (isoptype1) opalu1result = gprdata1 - gprdata2;
else if (isoptype2) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 == gprdata2};
else if (isoptype3) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 != gprdata2};
else if (isoptype4) opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) < $signed(gprdata2)};
else if (isoptype5) opalu1result = {{(ARCHBITSZ-1){1'b0}}, $signed(gprdata1) <= $signed(gprdata2)};
else if (isoptype6) opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 < gprdata2};
else                opalu1result = {{(ARCHBITSZ-1){1'b0}}, gprdata1 <= gprdata2};

if      (isoptype0) opalu2result = gprdata1 << gprdata2[CLOG2ARCHBITSZ-1:0];
else if (isoptype1) opalu2result = gprdata1 >> gprdata2[CLOG2ARCHBITSZ-1:0];
else if (isoptype2) opalu2result = $signed(gprdata1) >>> gprdata2[CLOG2ARCHBITSZ-1:0];
else if (isoptype3) opalu2result = gprdata1 & gprdata2;
else if (isoptype4) opalu2result = gprdata1 | gprdata2;
else if (isoptype5) opalu2result = gprdata1 ^ gprdata2;
else if (isoptype6) opalu2result = ~gprdata2;
else                opalu2result = gprdata2;
