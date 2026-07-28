# RISC-V Processing Unit

Single-issue in-order 4 stages pipeline with branch-JAL-RET-prediction (BHT: 4096 entries, RAS: 8 entries).
The stages are IF (Fetch) ID (Decode) EX (Execute) WB (WriteBack).
Memory access is not considered a stage in the design, but just another late result that takes multiple cycles like division.

## Pipeline structure

Four in-order stages, single issue, implemented in `pu.sv`:

- **IF (Fetch)** — drives the i-cache, predicts branches/JAL/RET (BHT 4096 entries, RAS 8 entries), and presents the fetched instruction's register ids (`iF_rdId`, `iF_rs1Id`, `iF_rs2Id`) and decoded `iF_*` control to ID.
- **ID (Decode)** — reads the source operands (with forwarding), checks their availability against the scoreboard, stalls until they are ready, and latches the decoded instruction (`iD_pc`, `iD_insn`, `iD_func3`, `iD_Iimm`, ...).
- **EX (Execute)** — ALU (`eX_aluOut_i`), comparators, shifter, branch/jump resolution (`eX_JumpOrBranch_i`) and result selection (`eX_rslt_i`); the result is latched into `eX_rslt`/`eX_rdId`.
- **WB (Register WriteBack, `rW`)** — writes the result into the register file `gprDat[]` and unlocks the destination in the scoreboard.

Memory access is **not** a stage: a load (like MUL/DIV) is a *late result* that leaves EX, runs for several cycles in its own unit, and rejoins at WB when done (see *Late results*).

### Stage advancement and stalls

Each stage exposes a `*_carryon` (may the instruction advance?) and, except WB, a `*_en` (`carryon && !halted_o`):

- `iD_stalled` holds an instruction in ID when EX cannot accept it (`!iD_eX_carryon`), a fence is waiting on the d-cache, a required multi-cycle unit is busy (`iD_opImul_bsy`/`iD_opIdiv_bsy`/`iD_ldUnit_bsy`/`iD_stUnit_bsy`), or **any required operand is still locked**. The operand check is keyed by the instruction's operand pattern (`iD_is3OprndD12`, `iD_is2OprndD1`, `iD_is2Oprnd12`, `iD_is1OprndD`) over `iD_rdRdy`/`iD_rs1Rdy`/`iD_rs2Rdy`.
- `iD_carryon = iD_flushed || !iD_stalled` (a flushed instruction is allowed to drain).
- The pipeline has WriteBack priority, so **EX never stalls for WriteBack** (`eX_rW_carryon` is tied high); a completed load/MUL/DIV result is held and retires only when the pipeline yields the slot. Multicycle back-pressure therefore lives at *issue* (`iD_op*_bsy`, load `max_pending`/FIFO-full).
- `rW_isMulticycle` flags the cycle a held late result actually retires (the pipeline yielded the slot); `rW_multicyclePending` (a completed load response or a MUL/DIV result is held) gates async traps.

The `_iF_*` signals (`_iF_rdId`, `_iF_rs1Id`, `_iF_rs2Id`, `_iF_use_rdId`) select the fetch-stage value when a new instruction is admitted (`iD_en`) or the held ID value while stalled.

## Register scoreboard and operand forwarding

Architectural state is the register file `gprDat[GPRCNT]` plus a one-bit-per-register scoreboard `gprRdy[GPRCNT]` (`1` = value present, `0` = a write is in flight). Reset sets all of `gprRdy` to `1`.

### Locking and unlocking (`gprRdy`)

- **Lock** (`gprLock = _iF_use_rdId && !_iF_flushed`): when an instruction that writes a destination is admitted into ID and is not flushed, its `rd` is marked not-ready (`gprRdy[_iF_rdId] <= 0`). A flushed (wrong-path) instruction never locks.
- **Unlock** (`gprUnlock`): when WB writes a register (`rW_we_i`), `gprRdy[rW_idx_i] <= 1`, guarded so a register that is *simultaneously* being (re)locked by a younger instruction is not released spuriously.
- `rdWasLocked` records whether a destination was *already* locked when it got locked again (two in-flight writers of the same register). Its single consumer is the exception fix-up in EX: when an instruction is interrupted, its destination is unlocked by writing back the register's current value, unless `rdWasLocked` says an older writer still owns it — in which case the unlock is left to that writer. Because the unlock is held back whenever the instruction leaving ID targets the same register, `rdWasLocked` has to be keyed on the unlock actually happening rather than on a writeback merely occurring; reading `rW_we_i` alone used to drop the lock of a late result still in flight, letting a trap release a register it did not own. A simulation-only monitor at the end of `pu.sv` guards the underlying invariant: a register is never marked ready while a late result still targets it.

Locking gates fetch admission and is itself gated by the same-cycle branch flush (`_iF_flushed` includes `iF_eX_JumpOrBranch_i`), so lock/unlock and branch resolution form a single-cycle control loop.

### Forwarding network

ID reads each operand through a two-source bypass before falling back to the register file (same muxes for `iD_rd`, `iD_rs1`, `iD_rs2`):

```
iD_rs1 = (rs1Id == EX-dest && EX-dest valid) ? iD_eX_rslt   // forward from EX
       : (rs1Id == WB-dest && WB-dest valid) ? iD_rW_rslt   // forward from WB / late result
       : rs1Id ? gprDat[rs1Id] : 0;                          // register file (x0 reads 0)
```

The two forwarding sources are checked **EX before WB** (the EX result is the younger, closer producer, so it must win the mux when both match the same source id):

- **`iD_eX_*`** — by default the instruction currently in EX (the registered `eX_rslt`/`eX_rdId`). Under `PUFWDALL` it is instead sourced **combinationally from the WriteBack arbiter** (`rW_we_i`/`rW_idx_i`/`rW_dat_i`), so a late result (load/MUL/DIV) becomes forwardable **the same cycle it retires** instead of a cycle later through `iD_rW_*`; because the operand-ready test feeds the issue gate, this also releases the destination WAW gate (below) a cycle sooner. That trades fewer load/MUL/DIV-use stall cycles for a deeper forwarding cone (the arbiter mux now drives the ID compares). It is **off by default** and is only correct together with the `iD_rW` capture guards in the writeback path.
- **`iD_rW_*`** — a registered snapshot (`iD_rW_rdId`, `iD_rW_rslt`) of the previous cycle's writeback, updated to mirror the WriteBack arbiter: the EX result, a completing late result (load/MUL/DIV), or the exception fix-up value.

**Value and readiness are tracked separately, and that split is what keeps forwarding robust.** Operand *readiness* (`iD_rdRdy`/`iD_rs1Rdy`/`iD_rs2Rdy`) is true if the source matches an in-flight EX or WB destination, if it was ready when latched at decode (`iD_*Rdy_ <= gprRdy[...]`), or if it became ready while the instruction was stalled — and that last bit `iD_*Rdy__` is **sticky-latched** (once set it stays set until the instruction issues). The forwarded *value* `iD_rs1`/`iD_rs2`, by contrast, is **recomputed combinationally every cycle** and backstopped by the register-file read `iD_rs1_ <= gprDat[_iF_rs1Id]`, which is **re-sampled every stalled cycle** (`_iF_rs1Id = iD_en ? iF_rs1Id : iD_rs1Id` holds the stalled instruction's id, and the producer wrote `gprDat` when it retired). So even after the forward window that first signalled "ready" has passed, the value delivered at issue is still correct — from whichever window is live that cycle, else from the register file. This rests on one invariant: the scoreboard guarantees a **single legitimate producer per register** at any time.

### Late results (memory, MUL, DIV)

Loads, `MUL` and `DIV` produce no value in EX. They leave EX having locked their destination, run for several cycles in `ldUnit` / `opImul` / `opIdiv`, and rejoin at WB on completion. **The pipeline has WriteBack priority** (`rW_pipeWrites`): the WriteBack arbiter selects, in strict priority order, **pipeline (`rW_pipeWrites`) > load (`ldUnit_memAck`) > MUL (`opImul_done`) > DIV (`opIdiv_done`) > clmul (`opClmul_done`) > FPU (`opFpu_done`, `PURV32ZFINX` builds)** — so the EX result is written first, and a completed late result is *held* — MUL/DIV/clmul in their `ostb`/`ordy` handshake, a load in the dCache response skidbuf via `dCache_m_bsy_i` — retiring only in a cycle the pipeline yields the slot. `rW_isMulticycle` flags such a held-result retirement, and the `iD_rW_*` snapshot mirrors the arbiter's `rW_idx_i`/`rW_dat_i` so `iD_rW_*` always equals what was written to `gprDat`. So an independent pipeline instruction no longer stalls behind a late-result writeback (the original structural hazard); it stalls only on a true data dependency through `gprRdy`. The retiring result also unlocks its destination in `gprRdy`; async traps are held (`rW_multicyclePending`) until any held result retires, and `csrInstret` counts both a pipeline instruction and a multicycle result retiring the same cycle. Because each multicycle unit holds its own internal state and connects to the pipeline only through a registered handshake (`stb`/`rdy`, with the result entering the forwarding network via `iD_rW_*`), its per-cycle logic is a *self-contained register-to-register path*, isolated from the pipeline's combinational cones (so e.g. the radix-4 divider's trial-subtraction carry chain in `idiv.sv` is a separate timing path).

### Branch / jump resolution and flush

`eX_JumpOrBranch_i` is resolved in EX from the decoded control and the dedicated branch comparator (`eX_eq_i`/`eX_brLt_i`/`eX_brLtu_i`), plus JALR, FENCE.I, ERET, prediction-miss and exception conditions. In the same cycle it redirects fetch (`iF_pc`, via `iF_eX_JumpOrBranch_i` and `eX_JumpOrBranchAddr_i`) and flushes the mis-fetched instruction(s) through `_iF_flushed`, which also suppresses their scoreboard lock. Mispredicted branches/JAL/RET and exceptions take the same redirect path.

## Peculiarities:
- When CPU reset, the stack pointer register is set to the end of RAM. By convention, RAM starts at 0x1000.
- Indefinitely halt (setting STATUS.MIE to 0) when an exception occurs and the trap vector address is null.
- There is no support for vectored interrupt.
- There is no difference between between mret sret; they are both eret.
- There is no external source for "Machine Software Interrupt", which are often used for IPIs.
	Delivery of machine-level interprocessor interrupts is done through external interrupts (MEI).
- There is support for Second Trap Value Register CSRs csrMtval2 csrStval2.
- csrMtimecmp csrMtimecmph are not memory mapped and use 12'h34d 12'h35d CSRs.
- csrTime and csrCycle get their value from the same register, which is compared against csrMtimecmp for timer interrupt.
- MEI MSI MTI trigger only if their corresponding bit in MIDELEG is 0.
- SEI SSI STI trigger only if MEI MSI MTI corresponding bit in MIDELEG is 1.
- SEI SSI STI are never delivered to Machine Privilege, hence MCAUSE only report Machine interrupts and exceptions.
- MEI MSI MTI can never be delivered to Supervisor Privilege, hence SCAUSE only report Supervisor interrupts and exceptions.
- Simultaneous interrupts are taken in the decreasing priority order MEI, SEI, MSI, SSI, MTI, STI;
	a delegated SEI/SSI is therefore taken ahead of a pending MSI/MTI, unlike the spec
	which takes Machine-destined interrupts before Supervisor-destined ones.
- A pending enabled interrupt is taken on the first clock cycle for which no multi-cycle
	result is pending retirement; it does not need those conditions to line-up with a
	particular clock cycle parity, which formerly allowed a two-instruction load spinloop
	to starve interrupts indefinitely.
- Atomic memory operations always bypass the data-cache, flushing-and-invalidating any data-cache-hit.
	They do not participate in the cache-coherency protocol: other harts' cached copies are not
	invalidated by an atomic write. Software must therefore access an atomically-manipulated
	variable exclusively through atomic instructions (a plain load can observe a stale value),
	and, when such a variable is located in runtime-allocated memory, initialize it using an
	atomic instruction (e.g. amoswap of 0), as another hart's atomic access reads memory which
	may hold stale data from the memory's previous use; statically allocated variables are safe,
	as their memory starts zeroed.
