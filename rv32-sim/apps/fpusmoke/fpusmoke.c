// SPDX-License-Identifier: GPL-2.0-only
// Stage-1 Zfinx smoke test: the 1-cycle ops (fsgnj/min/max/cmp/class) + the fcsr
// drain hazard. Each op runs via inline asm with GPR operands (Zfinx), result and
// fflags are checked against hand-computed expectations.

#include <stdio.h>
#include <stdint.h>

static int passed = 0, failed = 0;

static inline uint32_t rd_fflags(void) { uint32_t f; asm volatile ("csrr %0, fflags":"=r"(f)); return f; }
static inline void     cl_fflags(void) { asm volatile ("csrw fflags, zero"); }

#define OP2(name, mn) \
	static inline uint32_t name(uint32_t a, uint32_t b){ uint32_t z; \
		asm volatile (mn " %0,%1,%2":"=r"(z):"r"(a),"r"(b)); return z; }
#define OP1(name, mn) \
	static inline uint32_t name(uint32_t a){ uint32_t z; \
		asm volatile (mn " %0,%1":"=r"(z):"r"(a)); return z; }

OP2(fsgnj,  "fsgnj.s")  OP2(fsgnjn, "fsgnjn.s") OP2(fsgnjx, "fsgnjx.s")
OP2(fp_min,   "fmin.s")   OP2(fp_max,   "fmax.s")
OP2(feq,    "feq.s")    OP2(flt,    "flt.s")     OP2(fle,    "fle.s")
OP1(fclass, "fclass.s")

static void chk(const char *nm, uint32_t got, uint32_t exp) {
	if (got == exp) { passed++; }
	else { failed++; printf("FAIL %s: got %08x exp %08x\n", nm, got, exp); }
}
static void chkflags(const char *nm, uint32_t ef) {
	uint32_t f = rd_fflags() & 0x1f;   // read drains the FPU
	if (f != ef) { failed++; printf("FAIL %s flags: got %02x exp %02x\n", nm, f, ef); }
	else passed++;
}
// Clear fflags, run `expr`, check result==exp AND fflags==ef (exercises the drain hazard).
#define chkf(nm, expr, exp, ef) do { cl_fflags(); uint32_t _g=(expr); chk(nm,_g,exp); chkflags(nm,ef); } while(0)

#define ONE  0x3f800000u  // 1.0
#define TWO  0x40000000u  // 2.0
#define MONE 0xbf800000u  // -1.0
#define PZ   0x00000000u  // +0
#define NZ   0x80000000u  // -0
#define PINF 0x7f800000u
#define NINF 0xff800000u
#define QNAN 0x7fc00000u
#define SNAN 0x7f800001u
#define SUBN 0x00000001u  // smallest +subnormal
#define NSUBN 0x80000001u // smallest -subnormal
#define MTWO 0xc0000000u  // -2.0
#define NQNAN 0xffc00000u // -qNaN  (canonical qNaN payload, sign set)
#define NSNAN 0xff800001u // -sNaN  (sNaN payload, sign set)

void main (void) {
	cl_fflags();
	// ---- sign injection: result = {selected sign, a[30:0]}; NEVER raises a flag and NEVER
	// canonicalizes -- a's magnitude/payload is preserved bit-for-bit, even for a NaN. ----
	chk("fsgnj",   fsgnj(ONE, MONE),  MONE);  // sign from b
	chk("fsgnj+",  fsgnj(MONE, ONE),  ONE);
	chk("fsgnjz",  fsgnj(PZ, MONE),   NZ);    // +0 -> -0
	chk("fsgnjI",  fsgnj(PINF, MONE), NINF);  // sign of inf
	chk("fsgnjn",  fsgnjn(ONE, MONE), ONE);   // ~sign of b
	chk("fsgnjn-", fsgnjn(ONE, ONE),  MONE);  // fneg(1.0)
	chk("fsgnjnI", fsgnjn(NINF,NINF), PINF);
	chk("fsgnjx",  fsgnjx(ONE, MONE), MONE);  // sign = a^b
	chk("fsgnjx2", fsgnjx(MONE,MONE), ONE);   // fabs(-1.0)
	chk("fsgnjx3", fsgnjx(MONE, ONE), MONE);
	chkf("fsgnjNq",fsgnj(QNAN, MONE),  NQNAN, 0);  // NaN payload kept, sign set, no NV
	chkf("fsgnjNs",fsgnjx(SNAN, NZ),   NSNAN, 0);  // 0^1=1; sNaN payload kept; NO NV
	chkf("fsgnjNa",fsgnjx(SNAN, SNAN), SNAN,  0);  // fabs(sNaN): sign 0, NO NV
	// ---- fmin/fmax: numeric min/max; one NaN -> the OTHER (number) verbatim; both NaN ->
	// canonical qNaN; any sNaN input -> NV; -0 < +0; order-independent. ----
	chkf("fp_min", fp_min(ONE, TWO),   ONE,  0);
	chkf("fp_max", fp_max(ONE, TWO),   TWO,  0);
	chkf("fminR",  fp_min(TWO, ONE),   ONE,  0);    // order-independent
	chkf("fmaxR",  fp_max(TWO, ONE),   TWO,  0);
	chkf("fminNg", fp_min(MONE, MTWO), MTWO, 0);    // -2 < -1
	chkf("fmaxNg", fp_max(MONE, MTWO), MONE, 0);
	chkf("fminMx", fp_min(MONE, ONE),  MONE, 0);
	chkf("fminSb", fp_min(SUBN, ONE),  SUBN, 0);
	chkf("fmin0",  fp_min(PZ, NZ),     NZ,   0);    // -0 < +0
	chkf("fmax0",  fp_max(PZ, NZ),     PZ,   0);
	chkf("fmin0R", fp_min(NZ, PZ),     NZ,   0);
	chkf("fmax0R", fp_max(NZ, PZ),     PZ,   0);
	chkf("fminIf", fp_min(NINF, PINF), NINF, 0);
	chkf("fmaxIf", fp_max(NINF, PINF), PINF, 0);
	chkf("fminI1", fp_min(PINF, ONE),  ONE,  0);
	chkf("fmaxI1", fp_max(NINF, ONE),  ONE,  0);
	chkf("fminQa", fp_min(QNAN, TWO),  TWO,  0);    // qNaN -> other operand, no NV
	chkf("fminQb", fp_min(TWO, QNAN),  TWO,  0);
	chkf("fmaxQa", fp_max(QNAN, TWO),  TWO,  0);
	chkf("fmaxQb", fp_max(TWO, QNAN),  TWO,  0);
	chkf("fminSa", fp_min(SNAN, TWO),  TWO,  0x10); // sNaN -> NV, other returned
	chkf("fminSc", fp_min(TWO, SNAN),  TWO,  0x10);
	chkf("fmaxSa", fp_max(SNAN, TWO),  TWO,  0x10);
	chkf("fmin2Q", fp_min(QNAN, QNAN), QNAN, 0);    // both NaN -> canonical qNaN
	chkf("fmax2Q", fp_max(QNAN, QNAN), QNAN, 0);
	chkf("fminQS", fp_min(QNAN, SNAN), QNAN, 0x10); // both NaN, one sNaN -> qNaN + NV
	// compares
	chkf("feq",    feq(ONE, ONE),  1, 0);
	chkf("feqz",   feq(PZ, NZ),    1, 0);     // +0 == -0
	chkf("flt",    flt(ONE, TWO),  1, 0);
	chkf("fle",    fle(TWO, ONE),  0, 0);
	chkf("feqQN",  feq(QNAN, ONE), 0, 0);     // quiet compare, qNaN -> no NV
	chkf("feqSN",  feq(SNAN, ONE), 0, 0x10);  // sNaN -> NV
	chkf("fltQN",  flt(QNAN, ONE), 0, 0x10);  // signaling compare, any NaN -> NV
	chkf("fleQN",  fle(ONE, QNAN), 0, 0x10);
	// ---- fclass: 10-bit one-hot class; covers ALL 10 classes; NEVER raises a flag. ----
	chk("clsNI",   fclass(NINF),  1u<<0);  // -inf
	chk("clsMN",   fclass(MONE),  1u<<1);  // -normal
	chk("clsNsub", fclass(NSUBN), 1u<<2);  // -subnormal
	chk("clsNZ",   fclass(NZ),    1u<<3);  // -0
	chk("clsPZ",   fclass(PZ),    1u<<4);  // +0
	chk("clsSub",  fclass(SUBN),  1u<<5);  // +subnormal
	chk("clsPN",   fclass(ONE),   1u<<6);  // +normal
	chk("clsPI",   fclass(PINF),  1u<<7);  // +inf
	chk("clsSN",   fclass(SNAN),  1u<<8);  // sNaN
	chk("clsQN",   fclass(QNAN),  1u<<9);  // qNaN
	chkf("clsNoF", fclass(SNAN),  1u<<8, 0); // fclass on sNaN raises NO flag

	// static rounding-mode encodings (func3=0..4) must match the dynamic-rm (frm) path.
	{
		uint32_t A = 0x3f800000u, B = 0x40400000u; // 1.0 / 3.0 (inexact; rounds differently per mode)
		uint32_t st[5], dy; const char *nm[5] = {"srne","srtz","srdn","srup","srmm"};
		asm volatile ("fdiv.s %0,%1,%2,rne":"=r"(st[0]):"r"(A),"r"(B));
		asm volatile ("fdiv.s %0,%1,%2,rtz":"=r"(st[1]):"r"(A),"r"(B));
		asm volatile ("fdiv.s %0,%1,%2,rdn":"=r"(st[2]):"r"(A),"r"(B));
		asm volatile ("fdiv.s %0,%1,%2,rup":"=r"(st[3]):"r"(A),"r"(B));
		asm volatile ("fdiv.s %0,%1,%2,rmm":"=r"(st[4]):"r"(A),"r"(B));
		for (int m = 0; m < 5; m++) {
			asm volatile ("csrw frm, %0"::"r"(m));
			asm volatile ("fdiv.s %0,%1,%2":"=r"(dy):"r"(A),"r"(B));
			chk(nm[m], st[m], dy);
		}
		if (st[1] == st[3]) { failed++; printf("FAIL static-rm: rtz==rup (rm not applied)\n"); }
		else passed++;
	}

	printf("FPU STAGE1: %d passed, %d failed\n", passed, failed);
}
