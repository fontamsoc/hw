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

### Return-address stack

`ras0..ras7` is a shift register with no pointer: a call — JAL or JALR with `rd` x1 — pushes `iD_pc_plus_INSNBITSzBy8`, a return — JALR with `rd` x0 and `rs1` x1 — shifts everything back down, and both are gated on `iD_insn_valid`, so a wrong-path call or return never updates it and no misprediction recovery is needed. A push past 8 entries drops `ras7` on the floor.

A pop of an empty stack leaves `ras7` in place, so it shifts back down and the last entry repeats. **That is deliberate and must stay that way.** It insures every predicted return address is one the pu has already executed from, and therefore mapped and aligned. This design has no instruction-access-fault and there is no bus watchdog, so a speculative fetch of an unmapped address is never acknowledged: in simulation it trips the default-slave trap, and on hardware it wedges the bus for every master. Such a fetch does reach the bus in practice, because a return whose `rs1` is still locked -- the ordinary `lw ra,N(sp)` epilogue -- stalls in ID and delays the redirect that would otherwise cancel the refill. Clearing `ras7` on underflow instead would turn every underflow into exactly that case, as address null is unmapped on every target, the lowest device being at 0xf00.

Entries hold only `[WORDBITSZ-1:2]`, hence a return prediction is aligned by construction and can never raise the misaligned-fetch exception; only the branch and JAL predictions can.

## Peculiarities:
- When CPU reset, the stack pointer register is set to the end of RAM. By convention, RAM starts at 0x1000.
- Indefinitely halt (setting STATUS.MIE to 0) when an exception occurs and the trap vector address is null.
- There is no support for vectored interrupt.
- There is no difference between between mret sret; they are both eret.
- Machine and Supervisor Software Interrupts are not implemented. MIE.MSIE MIE.SSIE MIP.MSIP
	MIP.SSIP and MIDELEG.MSI read null and ignore writes, and no arm of the interrupt priority
	order produces them, hence neither interrupt cause 3 nor interrupt cause 1 is ever reported in
	MCAUSE nor in SCAUSE, MCAUSE 3 being left to the synchronous Breakpoint alone. There never was
	an external source for them, which are often used for IPIs, and they were the only pending bits
	with no hardware source behind them, hence a hart writing its own MIP was the only way either
	could be raised, and nothing does: underLineOS dispatches the machine timer and the machine
	external interrupt only. Delivery of machine-level interprocessor interrupts is done through
	external interrupts (MEI), dev/irqctrl.sv command CMDINTDST targeting the destination hart. wfi
	never woke on one either, its wake condition having always listed the external and the timer
	interrupts only.
- There is support for Second Trap Value Register CSRs csrMtval2 csrStval2.
- csrMtimecmp csrMtimecmph are not memory mapped and use 12'h34d 12'h35d CSRs.
- csrTime and csrCycle get their value from the same register, which is compared against csrMtimecmp for timer interrupt.
- MEI MTI trigger only if their corresponding bit in MIDELEG is 0.
- SEI STI trigger only if MEI MTI corresponding bit in MIDELEG is 1.
- SEI STI are never delivered to Machine Privilege, hence MCAUSE only report Machine interrupts and exceptions.
- MEI MTI can never be delivered to Supervisor Privilege, hence SCAUSE only report Supervisor interrupts and exceptions.
- Simultaneous interrupts are taken in the decreasing priority order MEI, SEI, MTI, STI;
	a delegated SEI is therefore taken ahead of a pending MTI, unlike the spec
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
- Ordinary cached writes do participate, and an atomic memory operation is ordered against the ones
	its hart already made: dcache.sv holds off the first access of a load-reserved, or of an
	atomic memory operation's read, until every coherency write this data-cache put on the ring has
	travelled it and come back. `coherency_write_pending` counts those still in flight, and
	`m_wb_bsy_o` keeps the hart busy for as long as it is non-null. The acknowledgement that
	decrements it is the request arriving back at the data-cache that issued it, which is after
	every other one has seen it, hence a null count means applied everywhere rather than merely
	sent. The wait is what insures that ordering, as an atomic memory operation does not travel the
	ring at all: it is forced to miss the cache and resolve in memory, and while it holds the bus
	lock this data-cache stops accepting ring traffic altogether, hence its effect becomes visible
	through memory while the writes before it are still visible only through the ring. Without the
	wait, the ordinary release shape, ie: plain stores to shared data followed by an atomic memory
	operation that publishes them, would let the hart which acquires afterwards read its own
	cache-entry, which those writes had not yet reached. The wait costs about one part in ten
	thousand of a two-hart run, as the count is non-null only just after a burst of writes to
	shared cache-entries.
	A coherency write occupies a place on the ring from the clockcycle it is issued until it comes
	back, so the count can never exceed what the ring holds, and `coherency_write_pending` is sized
	from that rather than from the hart count: this data-cache's own coherency output register and
	its skidbuf, plus, for each of the others, its request capture registers, its coherency output
	register and its skidbuf. That width matters more than it looks, as `m_wb_bsy_o` tests the count
	for non-null: a count too large for it does not lose precision, it reads null and removes the
	wait entirely, and nothing an application prints would show that. A simulation-only monitor at
	the end of `dCacheSub` reports it instead, along with the count exceeding the ring capacity that
	the width is derived from.
- A data-cache stalled on an access the bus has not accepted stops the coherency ring, and that is a
	way for one hart to stop the others which has nothing to do with arbitration. dcache.sv holds
	`coherency_bsy_o_` for as long as the data-cache is outside READY and TSTHIT, so a data-cache
	parked in REFILL or WRITEB on an access no device will accept refuses ring traffic for as long
	as that lasts, and `m_wb_bsy_o` then holds every other hart's data-cache busy through
	`coherency_stb_r`. Those harts stall having presented no bus request at all, hence they are not
	starved of the bus and giving them the bus changes nothing. That is why a hart which stalls a
	load on a device wedges the whole machine whereas one which stalls an instruction fetch does
	not, a fetch leaving the data-cache in READY so that the ring keeps flowing. It is also how a
	grant held for any reason comes to stop the hart holding it: the harts it starves park their own
	refills, and their data-caches then refuse the ring that the holder needs. Bounding this needs
	the ring decoupled from the data-cache's state, which this design does not do.
- lib/wb_arbiter.sv rotates its grant when the granted hart stops requesting, and otherwise once
	that hart has held it `GRANTHELDLIMIT` clockcycles and another hart is requesting. The second
	term is what bounds it: a hart holds its strobe asserted until its access is accepted, and a
	device is under no obligation to ever accept one, dev/serial_*.sv holding wb_bsy_o for as long
	as its receive buffer is empty so that a read of the data register waits for a byte. Without a
	bound, a hart reading that register, or fetching from it, held the bus for as long as no byte
	came, and every other hart is held busy meanwhile, which reaches instruction fetching through
	memctrl.pu.sv, hence executes nothing at all. rv32-sim/apps/smpfair covers it, and a
	simulation-only monitor at the end of the arbiter reports a grant held very much past the bound
	while another hart is waiting.
	Preempting a hart mid-access loses nothing, as it re-presents the identical request until
	accepted, and a response carries the hart it belongs to through the arbiter's pendingAcks fifo
	rather than through the grant. `GRANTHELDLIMIT` has a floor as well as a purpose, though, and it
	is the bus lock that sets it: rotation is blocked while the lock is held, so a limit shorter than
	the interval between a hart's accesses hands the grant away in the very clockcycle the lock
	releases, and the hart it hands to takes the lock with its own next access before the first can
	issue one. The harts then pass the lock back and forth and none of them completes a sequence of
	atomics, which at a limit of four is enough for smplock to report cpu1 starved. Rotating on every
	clockcycle fails differently and worse: the grant then sits on a hart which is not requesting for
	most clockcycles, the lowest and highest active hart being tracked by scans which lag a grant
	moving that fast, so the bus idles and nothing finishes. The limit is sized well clear of both.
	Note also that the rotation reads the bus lock's next value rather than the lock itself, so that
	it cannot rotate away from the hart whose locked access is being accepted at that very
	clockedge: that would leave the grant on another hart with the lock set, and the write-back
	which releases it could never issue. The rotation as it was needed no such guard, never firing
	on a clockcycle the granted hart was requesting, and an accepted access implies a requesting
	hart; the quantum term does fire then, hence the guard.
- A load-reserved, and the read phase of an atomic memory operation, raise the Wishbone bus lock,
	which lib/wb_arbiter.sv turns into a grant hold: while it is set the granted hart cannot change
	and every other hart is held busy, which reaches instruction fetching through memctrl.pu.sv,
	hence a hart that is not granted executes nothing at all. It is released by the lock owner's
	next accepted access that does not carry it, ie: the store-conditional's store, or the atomic
	memory operation's write-back. Instruction fetches interleaved inside that window carry the
	lock, so that they hold it rather than release it; every other access the hart can make inside
	that window either carries it too, the data-cache's own write-back and refill, or is suppressed
	for the duration, the cache-coherency path.
	Nothing bounds when the releasing access comes, and a store-conditional is allowed to issue no
	store at all: branched over, which is what gcc emits for a compare-and-swap whose compare
	fails, its reservation cancelled, or with no store-conditional after the load-reserved. Such an
	abandoned sequence therefore holds the bus until that hart's next load, store or atomic. A
	retry loop holding a load-reserved and no other data access, ie: `1: lr.w t0,(a0); bnez t0,1b`,
	issues none and starves the other harts for as long as it spins; use instead the
	compare-and-swap shape, whose store-conditional is inside the loop. Note that the starvation is
	not observed to be one-sided: the holder stops making progress as well rather than running on,
	so a lock left held wedges the whole machine rather than merely losing a hart.
	The hold cannot be bounded in hardware as this design stands. A store-conditional's success is
	decided at decode (`_amoUnit_lrValid`), so breaking the lock early would let one report success
	after another hart had interposed; bounding it safely needs the store-conditional resolved at
	the bus instead.
- The alternate link register x5/t0 is not supported by the return-address stack, which recognizes only
	x1/ra: a call is JAL or JALR with rd x1, a return is JALR with rd x0 and rs1 x1, hence the
	return-address-stack hints that the RISC-V spec defines for x5 are not implemented. That is a
	prediction policy and never an architectural one, as every JALR is resolved in EX and redirected
	to its exact target; an x5 based call or return merely costs the two issue slots of a fetch
	redirect instead of being predicted. x5 is ignored by both the push and the pop, hence it never
	unbalances the stack, and the prediction of surrounding x1 call/return pairs is never degraded.
	Insure the toolchain is not built with -msave-restore: the millicode routines that it calls are
	entered by a JALR writing x5 and return through a JALR reading x5, neither of which is predicted.
