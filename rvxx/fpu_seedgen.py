#!/usr/bin/env python3
# Generates the Newton-Raphson seed-table case-ROMs embedded in rvxx/fpu.sv for the DSP
# fdiv/fsqrt (PUFDIVDSP*/PUFSQRTDSP*). Run: python3 fpu_seedgen.py  -> prints Verilog.
#
# Format: seeds are U1.27 fixed-point (value*2^27), value in (0.5,1].
#  - reciprocal seed y0 ~ 1/D, D = bSig/2^23 in [1,2); index = bSig[22:16] (128 bins).
#  - rsqrt seed   r0 ~ 1/sqrt(V), V the radicand in [1,4); index = {aEU[0], aSig[22:17]} (128 bins).
# Two NR iterations from these seeds reach ~28-bit accuracy (validated exhaustively offline).
import math
F = 27
SEEDBITS = 7
NSEED = 1 << SEEDBITS

def emit_recip():
    print("// 128-entry reciprocal seed y0 ~ (1/D)*2^27, D=bSig/2^23, idx=bSig[22:16]. From fpu_seedgen.py.")
    print("function automatic logic [27:0] fdivRecipSeed (input logic [6:0] idx);")
    print("\tcase (idx)")
    for i in range(NSEED):
        bSig_mid = (1 << 23) + (i << 16) + (1 << 15)
        D = bSig_mid / (1 << 23)
        y0 = min(round((1.0 / D) * (1 << F)), 1 << (F + 1))
        print(f"\t7'd{i}: fdivRecipSeed = 28'h{y0:07x};")
    print("\tdefault: fdivRecipSeed = 28'h8000000;")
    print("\tendcase")
    print("endfunction")

def emit_rsqrt():
    print("// 128-entry rsqrt seed r0 ~ (1/sqrt(V))*2^27, V in [1,4), idx={aEU[0],aSig[22:17]}. From fpu_seedgen.py.")
    print("function automatic logic [27:0] fsqrtRsqrtSeed (input logic [6:0] idx);")
    print("\tcase (idx)")
    for i in range(NSEED):
        oct_bit = (i >> 6) & 1          # high index bit = aEU[0] (octave): 0 -> V in [1,2), 1 -> [2,4)
        sub = i & 0x3f                  # low 6 bits = aSig[22:17]
        # radicand V midpoint: significand frac = (sub+0.5)/64 ; V = (1+frac) * (2 if octave else 1)
        frac = (sub + 0.5) / 64.0
        V = (1.0 + frac) * (2.0 if oct_bit else 1.0)
        r0 = min(round((1.0 / math.sqrt(V)) * (1 << F)), 1 << (F + 1))
        print(f"\t7'd{i}: fsqrtRsqrtSeed = 28'h{r0:07x};")
    print("\tdefault: fsqrtRsqrtSeed = 28'h8000000;")
    print("\tendcase")
    print("endfunction")

if __name__ == "__main__":
    emit_recip()
    print()
    emit_rsqrt()
