# Repository Structure

- [`dev/`](dev): Wishbone4 peripherals.
- [`lib/`](lib): Helper modules.
- [`cpu/`](cpu): RISC-V CPU implementation.
- [`rv32-sim/`](rv32-sim): RV32 SoC implementation simulator using verilator.
- [`rv32-artya7100/`](rv32-artya7100): RV32 SoC implementation on Arty A7-100T.
- [`rv32-nexysa7100/`](rv32-nexysa7100): RV32 SoC implementation on Nexys A7-100T.
- [`rv32-cmoda735/`](rv32-cmoda735): RV32 SoC implementation on Cmod A7-35T.
- [`rv32-orangecrab0285/`](rv32-orangecrab0285): RV32 SoC implementation on OrangeCrab r0.2 85F.
- [`tools/`](tools): Host-side utilities.

# Examples

Each `examples/<target>/<feature>` branch is a self-contained demonstration; most layer a single feature on top of the main branch, so you can check one out to try it.

- `examples/rv32-sim/serial_pty`: four host-pty–backed `serial_sim` console channels (at 0xe80–0xee0) in the verilator simulator.
- `examples/rv32-artya7100/serial_jtag`: four serial consoles tunneled over JTAG (BSCAN user1–4) on the Arty A7-100T.
- `examples/rv32-nexysa7100/serial_jtag`: four serial consoles tunneled over JTAG (BSCAN user1–4) on the Nexys A7-100T.
- `examples/rv32-cmoda735/serial_jtag`: four serial consoles tunneled over JTAG (BSCAN user1–4) on the Cmod A7-35T.
- `examples/rv32-orangecrab0285/serial_jtag`: two serial consoles tunneled through the ECP5 JTAGG primitive on the OrangeCrab r0.2 85F.
- `examples/rv32-orangecrab0285/serial_usb_multi_port`: multiple CDC-ACM COM ports over a single USB link (`PORTCOUNT`, two ports here) on the OrangeCrab r0.2 85F.
