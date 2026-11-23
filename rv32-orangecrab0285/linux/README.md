# NOMMU Linux on the OrangeCrab r0.2 85F

This directory is a [Buildroot](https://buildroot.org) external tree. It builds Linux
6.18.60, without MMU, for the FonTamSOC of [`rv32-orangecrab0285`](..), whose ftpu cores
are RV32IMA with no MMU. It also builds a uClibc-ng userland with BusyBox, of FLAT
binaries, on an ext2 root file system.

The kernel runs in machine mode. There is no firmware below it:
- [`apps/bootldr`](../apps/bootldr), in its resident mode, calibrates the DDR3 SDRAM;
- it loads the kernel from the partition 3 of the SD card, in SPI mode;
- it copies the kernel to `0x41000`, the start of the DDR3 SDRAM, with the device tree
  blob as its stack data;
- then it jumps to the kernel.

bootldr stays in the SRAM. A reboot, or holding the button, runs it again, and it loads
the kernel again.

## Contents

| Path | What |
|---|---|
| `configs/orangecrab0285_defconfig` | The Buildroot configuration |
| `linux.config` | The configuration of the single-hart kernel |
| `linux-smp.config` | Merged over `linux.config` for the multi-hart kernel |
| `patches/linux/` | The kernel patch series; `patches/linux-smp` links to it |
| `patches/busybox/` | A fix of BusyBox's shell, whose `read` builtin would spin once the shell has run a trap |
| `dts/fontamsoc/` | The device trees: `orangecrab0285.dts` (one hart), `orangecrab0285-smp.dts` (up to two), both including `orangecrab0285.dtsi` |
| `package/linux-smp/` | Builds the multi-hart kernel, from the same sources and patches |
| `busybox.fragment` | Adds `hexdump` and `taskset` to BusyBox |
| `post-image.sh` | Formats each kernel for bootldr, and builds bootldr for it |
| `external.mk` | Installs the kernel as `vmlinux.bin` and the multi-hart device tree in `smp/`, and builds uClibc-ng with soft-float math, as the RISC-V port otherwise assumes an FPU |
| `override.mk` | Buildroot's package override file, as the defconfig sets: puts the images in `images/`, and includes the default `local.mk` |

The patch series is that of [`rv32-nexysa7100/linux`](../../rv32-nexysa7100/linux), plus
the driver of the SD card in SPI mode. It adds:
- the platform `ARCH_FONTAMSOC`: the timebase read from the CSR `0xcc0`, the idle `wfi`,
  which the ftpu executes only with interrupts enabled, the write-back of the data-cache
  before `fence.i`, and the start of the other harts by IPI;
- a driver for each device of the SoC:

| Device | Driver | Linux |
|---|---|---|
| Timer of the ftpu | `drivers/clocksource/timer-ftpu.c` | clocksource, sched_clock, clockevent per hart |
| Interrupt controller | `drivers/irqchip/irq-fontamsoc-irqctrl.c` | interrupts, IPIs, system reset |
| USB console | `drivers/tty/serial/fontamsoc-serial.c`, the driver of the UART | `ttyS0`, console, earlycon |
| SD card, SPI mode | `drivers/block/fontamsoc-sdspi.c` | `sd0`, partitions `sd0p1`... |
| SPI flash | `drivers/spi/spi-fontamsoc.c` | `spi-nor`, `/dev/mtd0` (foboot, read-only), `/dev/mtd1` (bitstream, read-only), `/dev/mtd2` |
| Default device | `drivers/misc/fontamsoc-dfltdev.c` | reports accesses to unmapped addresses |

The USB console has the registers and the commands of the UART, and its driver is that
of the UART, the speed which it sets being ignored. The series also carries the driver
of the SD card in SD mode, `drivers/block/fontamsoc-sdsdio.c`, which `linux.config`
leaves out. The drivers use copies of the FonTamSOC drivers `hwdrvchar.h`,
`hwdrvirqctrl.h`, `hwdrvsdsdio.h` and `hwdrvsdspi.h`, unchanged, in
`include/soc/fontamsoc/`.

## Building

From a Buildroot tree:

```sh
make BR2_EXTERNAL=/path/to/rv32-orangecrab0285/linux orangecrab0285_defconfig
make
```

A Buildroot output holds the kernels of one board. In an output which built another
board, ie: [`rv32-nexysa7100/linux`](../../rv32-nexysa7100/linux), run
`make linux-dirclean linux-smp-dirclean` before the defconfig, so that both kernels are
configured and built again; the rest, ie: the toolchain, is kept. Otherwise, give each
board its own output, with `O=`.

`post-image.sh` builds bootldr with the ftpu toolchain, which it expects at
`/opt/ftpu-toolchain/bin`. The images land in `images/` of this directory, where
`override.mk` puts them, and which git ignores:

| File | What |
|---|---|
| `vmlinux.bin` | The `Image` of the single-hart kernel, linked at `0x41000` |
| `vmlinux.bldr.bin` | The kernel as [`tools/mkBootldrDat.py`](../../tools/mkBootldrDat.py) formats it for bootldr |
| `bootldr.32.hex` | bootldr in its resident mode, with `orangecrab0285.dtb` as its stack data, for `SRAM_INITFILE` |
| `orangecrab0285.dtb` | The single-hart device tree |
| `rootfs.ext2` | The root file system |
| `smp/` | The same `vmlinux.bin`, `vmlinux.bldr.bin` and `bootldr.32.hex` for the multi-hart kernel, with `orangecrab0285-smp.dtb` |

## The bitstream and the SD card

1. Put bootldr in the SRAM of the committed build, and program the board, as described
   in [Loading a program](../README.md#loading-a-program). From `../yosys`:

   ```sh
   make updsram SRAM_INITFILE=../linux/images/bootldr.32.hex
   make prog
   ```

2. Make the image of the SD card with [`tools/mkMbrImg.sh`](../../tools/mkMbrImg.sh),
   which needs `genimage` and `mkdosfs`: an MBR whose partition 3 holds the kernel, and
   partition 4 the root file system. Partitions 1 and 2 are not used: the partition 1 is
   an empty FAT file system, the partition 2 a placeholder of one block. From this
   directory:

   ```sh
   ../../tools/mkMbrImg.sh -3 images/vmlinux.bldr.bin \
       -4 images/rootfs.ext2 images/sdcard.img
   ```

3. Write the image to the SD card, whose partition table it replaces:

   ```sh
   dd if=images/sdcard.img of=/dev/sdX bs=1M conv=fsync
   ```

The console is the USB port, which the host sees as a CDC-ACM serial port, ie:
`/dev/ttyACM0`. Open it before pressing the button, which starts bootldr:

```sh
picocom -q --imap lfcrlf /dev/ttyACM0
```

The port transmits only while a program on the host has it open. Once its buffer of
2048 bytes is full, the console waits for the host: a hart printing on it stops until a
program reads the port, and nothing is lost. The kernel mounts `/dev/sd0p4` read-only;
BusyBox's init remounts it read-write, then gives a login prompt on the console: `root`,
without password.

## The multi-hart kernel

The multi-hart kernel runs on a bitstream of 1 or 2 harts, the makefile's `CPU_COUNT`,
which needs `ATOMIC_COHERENCE=1` at 2 harts:
- `ATOMIC_COHERENCE` lets atomic and plain accesses of several harts share words through
  their data-caches, which the spinlocks of Linux do;
- `orangecrab0285-smp.dts` states it with the property `fontamsoc,atomic-coherence` of
  `/cpus`, without which the kernel starts the boot hart alone.

`orangecrab0285-smp.dts` describes 2 harts, as many as `CONFIG_NR_CPUS` of
`linux-smp.config`, the second disabled: bootldr enables it when the bitstream has it,
in the device tree blob which it passes to the kernel, through the function of
[`bootldr_init_array.c`](../apps/bootldr/bootldr_init_array.c) which follows the
calibration of the DDR3 SDRAM.

The bitstream of 2 harts takes a synthesis and a placement, which replace the committed
build of `../yosys`, the one which `make updsram` uses. From `../yosys`:

```sh
make -B CPU_COUNT=2 ATOMIC_COHERENCE=1 SRAM_INITFILE=../linux/images/smp/bootldr.32.hex
make prog
```

Use `images/smp/vmlinux.bldr.bin` for the partition 3. bootldr parks the other harts in
the SRAM, where they wait for the IPI of the kernel which starts them; those beyond the
second stay there.

## Limits

- **Racing plain stores.** Plain stores of two harts to the same byte, whose coherency
  writes cross on the ring, leave each hart with the other's value until its next store
  to that byte (`cpu/README.md`). This is why the tick is periodic (`HZ_PERIODIC`):
  `NO_HZ_IDLE` hands the update of jiffies from hart to hart through plain stores of each
  to one variable.
- **No `rdtime` or `rdcycle` in user space.** The ftpu traps every CSR access made in
  user mode, and the program gets `SIGILL`; time comes from the kernel, ie:
  `clock_gettime()`.
- **The SRAM stays bootldr's.** Linux gets the 512 MiB of the DDR3 SDRAM only, from
  `0x41000`.
- **The console waits for the host**, as described above: with no program reading the
  USB port, the kernel stops at its first line printed once the buffer is full.
- **A reboot is a warm boot of bootldr**, which loads the kernel again from the SD card.
  There is no power-off: `poweroff` halts.
