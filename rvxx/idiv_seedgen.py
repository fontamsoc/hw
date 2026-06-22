#!/usr/bin/env python3
# Generates the reciprocal seed case-ROM embedded (via include) in rvxx/idiv.sv for the DSP
# Newton-Raphson integer divider (PUIDIVDSP). Run: python3 idiv_seedgen.py > idiv_recip_seed.vh
#
# The divider |D| is normalized so its MSB sits at bit 31: Dn = |D| << clz(|D|), Dn in [2^31, 2^32).
# The seed r0 ~ (1/dn)*2^32, dn = Dn/2^32 in [0.5,1), so r0 in (2^32, 2^33] (34-bit). Index = the
# 7 bits Dn[30:24] (128 bins; the implied MSB bit31 is dropped). Two NR iterations from this seed
# reach exact 32-bit floor division with a single +/-1 residual correction (validated idiv_nr_model.py).
F = 32
SEEDBITS = 7
NSEED = 1 << SEEDBITS

print("// 128-entry reciprocal seed r0 ~ (1/dn)*2^32, dn=Dn/2^32, Dn=|D|<<clz, idx=Dn[30:24].")
print("// From idiv_seedgen.py. Two NR iters + 1 residual fixup => exact 32-bit division.")
print("function automatic logic [33:0] idivRecipSeed (input logic [6:0] idx);")
print("\tcase (idx)")
for i in range(NSEED):
    Dn_mid = (1 << 31) + (i << (31 - SEEDBITS)) + (1 << (30 - SEEDBITS))
    r0 = round((1 << 64) // 1 / Dn_mid)  # 2^64 / Dn_mid  == (1/dn)*2^32
    r0 = min(int(round((1 << 64) / Dn_mid)), 1 << (F + 1))
    print(f"\t7'd{i}: idivRecipSeed = 34'h{r0:09x};")
print("\tdefault: idivRecipSeed = 34'h100000000;")  # 2^32
print("\tendcase")
print("endfunction")
