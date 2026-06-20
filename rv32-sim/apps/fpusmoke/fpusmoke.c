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

void main (void) {
	cl_fflags();
	// sign injection (no flags)
	chk("fsgnj",  fsgnj(ONE, MONE), MONE);
	chk("fsgnjn", fsgnjn(ONE, MONE), ONE);
	chk("fsgnjx", fsgnjx(ONE, MONE), MONE);
	chk("fsgnjx2",fsgnjx(MONE, MONE), ONE);
	// min/max incl -0/+0 and NaN propagation
	chkf("fp_min",   fp_min(ONE, TWO), ONE, 0);
	chkf("fp_max",   fp_max(ONE, TWO), TWO, 0);
	chkf("fmin0",  fp_min(PZ, NZ),   NZ,  0);
	chkf("fmax0",  fp_max(PZ, NZ),   PZ,  0);
	chkf("fminN",  fp_min(QNAN, TWO),TWO, 0);   // quiet NaN -> other operand, no NV
	chkf("fminSN", fp_min(SNAN, TWO),TWO, 0x10);// sNaN -> NV
	chkf("fmin2N", fp_min(QNAN, QNAN),QNAN,0);  // both NaN -> canonical qNaN
	// compares
	chkf("feq",    feq(ONE, ONE),  1, 0);
	chkf("feqz",   feq(PZ, NZ),    1, 0);     // +0 == -0
	chkf("flt",    flt(ONE, TWO),  1, 0);
	chkf("fle",    fle(TWO, ONE),  0, 0);
	chkf("feqQN",  feq(QNAN, ONE), 0, 0);     // quiet compare, qNaN -> no NV
	chkf("feqSN",  feq(SNAN, ONE), 0, 0x10);  // sNaN -> NV
	chkf("fltQN",  flt(QNAN, ONE), 0, 0x10);  // signaling compare, any NaN -> NV
	chkf("fleQN",  fle(ONE, QNAN), 0, 0x10);
	// classify (no flags)
	chk("clsMN", fclass(MONE), 1u<<1);  // -normal
	chk("clsPN", fclass(ONE),  1u<<6);  // +normal
	chk("clsNZ", fclass(NZ),   1u<<3);  // -0
	chk("clsPZ", fclass(PZ),   1u<<4);  // +0
	chk("clsPI", fclass(PINF), 1u<<7);  // +inf
	chk("clsNI", fclass(NINF), 1u<<0);  // -inf
	chk("clsSub",fclass(SUBN), 1u<<5);  // +subnormal
	chk("clsQN", fclass(QNAN), 1u<<9);  // qNaN
	chk("clsSN", fclass(SNAN), 1u<<8);  // sNaN

	printf("FPU STAGE1: %d passed, %d failed\n", passed, failed);
}
