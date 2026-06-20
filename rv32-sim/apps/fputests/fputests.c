// SPDX-License-Identifier: GPL-2.0-only
// Zfinx conformance runner: executes Berkeley TestFloat-3e vectors on the rvxx FPU
// and checks BOTH the result and the 5 fflags bits. Rounding mode is set per-vector
// via frm (dynamic-rm op forms), which also exercises the fcsr drain hazard each time.

#include <stdio.h>
#include <stdint.h>

struct vec { unsigned char op, rm; unsigned a, b, z; unsigned char f; };
#include "vectors.h"

// op ids (must match gen.sh)
enum { F2IS, F2IU, I2FS, I2FU, FADD, FSUB, FMUL, FDIV, FSQRT };

static inline void set_frm(unsigned rm){ asm volatile ("csrw frm, %0"::"r"(rm)); }
static inline void cl_fflags(void)     { asm volatile ("csrw fflags, zero"); }
static inline unsigned rd_fflags(void) { unsigned f; asm volatile ("csrr %0, fflags":"=r"(f)); return f; }

// dynamic-rm op forms (func3==111); frm selects the mode.
static unsigned run(int op, unsigned a, unsigned b){
	unsigned z = 0;
	switch (op) {
	case F2IS:  asm volatile ("fcvt.w.s  %0,%1":"=r"(z):"r"(a)); break;
	case F2IU:  asm volatile ("fcvt.wu.s %0,%1":"=r"(z):"r"(a)); break;
	case I2FS:  asm volatile ("fcvt.s.w  %0,%1":"=r"(z):"r"(a)); break;
	case I2FU:  asm volatile ("fcvt.s.wu %0,%1":"=r"(z):"r"(a)); break;
	case FADD:  asm volatile ("fadd.s %0,%1,%2":"=r"(z):"r"(a),"r"(b)); break;
	case FSUB:  asm volatile ("fsub.s %0,%1,%2":"=r"(z):"r"(a),"r"(b)); break;
	case FMUL:  asm volatile ("fmul.s %0,%1,%2":"=r"(z):"r"(a),"r"(b)); break;
	case FDIV:  asm volatile ("fdiv.s %0,%1,%2":"=r"(z):"r"(a),"r"(b)); break;
	case FSQRT: asm volatile ("fsqrt.s %0,%1":"=r"(z):"r"(a)); break;
	}
	return z;
}

static const char *opname(int op){
	static const char *n[] = {"fcvt.w.s","fcvt.wu.s","fcvt.s.w","fcvt.s.wu",
	                          "fadd.s","fsub.s","fmul.s","fdiv.s","fsqrt.s"};
	return n[op];
}

void main (void) {
	int n = (int)(sizeof(vectors)/sizeof(vectors[0]));
	int pass = 0, fail = 0, shown = 0;
	for (int i = 0; i < n; i++) {
		const struct vec *v = &vectors[i];
		set_frm(v->rm);
		cl_fflags();
		unsigned z = run(v->op, v->a, v->b);
		unsigned f = rd_fflags() & 0x1f;
		if (z == v->z && f == (v->f & 0x1f)) { pass++; }
		else {
			fail++;
			if (shown++ < 20)
				printf("FAIL %s rm=%d a=%08x b=%08x : got z=%08x f=%02x  exp z=%08x f=%02x\n",
					opname(v->op), v->rm, v->a, v->b, z, f, v->z, v->f & 0x1f);
		}
	}
	printf("FPUTESTS: %d passed, %d failed (of %d)\n", pass, fail, n);
}
