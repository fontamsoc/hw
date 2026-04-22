# RISC-V Processing Unit

Single-issue in-order 4 stages pipeline with branch-JAL-RET-prediction (BHT: 4096 entries, RAS: 8 entries).
The stages are IF (Fetch) ID (Decode) EX (Execute) WB (WriteBack).
Memory access is not considered a stage in the design, but just another late result that takes multiple cycles like division.

## Peculiarities:
- When CPU reset, the stack pointer register is set to the end of RAM. By convention, RAM starts at 0x1000.
- Indefinitely halt (setting STATUS.MIE to 0) when an exception occurs and the trap vector address is null.
- There is no support for vectored interrupt.
- There is no difference between between mret sret; they are both eret.
- There is no "Machine Software Interrupt", which are often used for IPIs.
	Delivery of machine-level interprocessor interrupts is done through external interrupts (MEI).
- There is support for Second Trap Value Register CSRs csrMtval2 csrStval2.
- csrMtimecmp csrMtimecmph are not memory mapped and use 12'h34d 12'h35d CSRs.
- csrTime and csrCycle get their value from the same register, which is compared against csrMtimecmp for timer interrupt.
- MEI MSI MTI trigger only if their corresponding bit in MIDELEG is 0.
- SEI SSI STI trigger only if MEI MSI MTI corresponding bit in MIDELEG is 1.
- SEI SSI STI are never delivered to Machine Privilege, hence MCAUSE only report Machine interrupts and exceptions.
- MEI MSI MTI can never be delivered to Supervisor Privilege, hence SCAUSE only report Supervisor interrupts and exceptions.
- Atomic memory operations always bypass the data-cache, flushing-and-invalidating any data-cache-hit.
