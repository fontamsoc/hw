# NOMMU Linux on the Nexys A7-100T

This directory is a [Buildroot](https://buildroot.org) external tree. It builds Linux
6.18.60, without MMU, for the FonTamSOC of [`rv32-nexysa7100`](..), whose ftpu cores are
RV32IMA with no MMU. It also builds a uClibc-ng userland with BusyBox, of FLAT binaries,
on an ext2 root file system.

The kernel runs in machine mode. There is no firmware below it:
- [`apps/bootldr`](../apps/bootldr), in its resident mode, calibrates the DDR2 SDRAM;
- it loads the kernel from the partition 3 of the SD card;
- it copies the kernel to `0x41000`, the start of the DDR2 SDRAM, with the device tree
  blob as its stack data;
- then it jumps to the kernel.

bootldr stays in the SRAM. A reboot, or holding `CPU RESET`, runs it again, and it loads
the kernel again.

## Contents

| Path | What |
|---|---|
| `configs/nexysa7100_defconfig` | The Buildroot configuration |
| `linux.config` | The configuration of the single-hart kernel |
| `linux-smp.config` | Merged over `linux.config` for the multi-hart kernel |
| `patches/linux/` | The kernel patch series; `patches/linux-smp` links to it |
| `patches/busybox/` | A fix of BusyBox's shell, whose `read` builtin would spin once the shell has run a trap |
| `dts/fontamsoc/` | The device trees: `nexysa7100.dts` (one hart), `nexysa7100-smp.dts` (up to four), both including `nexysa7100.dtsi` |
| `package/linux-smp/` | Builds the multi-hart kernel, from the same sources and patches |
| `busybox.fragment` | Adds `hexdump` and `taskset` to BusyBox |
| `post-image.sh` | Formats each kernel for bootldr, and builds bootldr for it |
| `external.mk` | Installs the kernel as `vmlinux.bin` and the multi-hart device tree in `smp/`, and builds uClibc-ng with soft-float math, as the RISC-V port otherwise assumes an FPU |
| `override.mk` | Buildroot's package override file, as the defconfig sets: puts the images in `images/`, and includes the default `local.mk` |

The patch series adds:
- the platform `ARCH_FONTAMSOC`: the timebase read from the CSR `0xcc0`, the idle `wfi`,
  which the ftpu executes only with interrupts enabled, the write-back of the data-cache
  before `fence.i`, and the start of the other harts by IPI;
- a driver for each device of the SoC:

| Device | Driver | Linux |
|---|---|---|
| Timer of the ftpu | `drivers/clocksource/timer-ftpu.c` | clocksource, sched_clock, clockevent per hart |
| Interrupt controller | `drivers/irqchip/irq-fontamsoc-irqctrl.c` | interrupts, IPIs, system reset |
| UART | `drivers/tty/serial/fontamsoc-serial.c` | `ttyS0`, console, earlycon |
| SD card, SD mode | `drivers/block/fontamsoc-sdsdio.c` | `sd0`, partitions `sd0p1`... |
| SPI flash | `drivers/spi/spi-fontamsoc.c` | `spi-nor`, `/dev/mtd0` (bitstream, read-only), `/dev/mtd1` |
| Default device | `drivers/misc/fontamsoc-dfltdev.c` | reports accesses to unmapped addresses |

The drivers use copies of the FonTamSOC drivers `hwdrvchar.h`, `hwdrvirqctrl.h` and
`hwdrvsdsdio.h`, unchanged, in `include/soc/fontamsoc/`.

## Building

From a Buildroot tree:

```sh
make BR2_EXTERNAL=/path/to/rv32-nexysa7100/linux nexysa7100_defconfig
make
```

`post-image.sh` builds bootldr with the ftpu toolchain, which it expects at
`/opt/ftpu-toolchain/bin`. The images land in `images/` of this directory, where
`override.mk` puts them, and which git ignores:

| File | What |
|---|---|
| `vmlinux.bin` | The `Image` of the single-hart kernel, linked at `0x41000` |
| `vmlinux.bldr.bin` | The kernel as [`tools/mkBootldrDat.py`](../../tools/mkBootldrDat.py) formats it for bootldr |
| `bootldr.32.hex` | bootldr in its resident mode, with `nexysa7100.dtb` as its stack data, for `SRAM_INITFILE` |
| `nexysa7100.dtb` | The single-hart device tree |
| `rootfs.ext2` | The root file system |
| `smp/` | The same `vmlinux.bin`, `vmlinux.bldr.bin` and `bootldr.32.hex` for the multi-hart kernel, with `nexysa7100-smp.dtb` |

## The bitstream and the SD card

1. Build the bitstream with `SRAM_INITFILE` set to `"../../../linux/images/bootldr.32.hex"`,
   as described in [Loading a program](../README.md#loading-a-program).
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

The console is the UART, at 115200 bauds. The kernel mounts `/dev/sd0p4` read-only;
BusyBox's init remounts it read-write, then gives a login prompt on the console: `root`,
without password.

## The multi-hart kernel

The multi-hart kernel runs on a bitstream of 1 to 4 harts, the Vivado define
`CPU_COUNT`, which needs the define `ATOMIC_COHERENCE=1` from 2 harts:
- `ATOMIC_COHERENCE` lets atomic and plain accesses of several harts share words through
  their data-caches, which the spinlocks of Linux do;
- `nexysa7100-smp.dts` states it with the property `fontamsoc,atomic-coherence` of
  `/cpus`, without which the kernel starts the boot hart alone.

`nexysa7100-smp.dts` describes 4 harts, as many as `CONFIG_NR_CPUS` of
`linux-smp.config`, all but the first disabled: bootldr enables those which the
bitstream has, in the device tree blob which it passes to the kernel, through the
function of [`bootldr_init_array.c`](../apps/bootldr/bootldr_init_array.c) which follows
the calibration of the DDR2 SDRAM.

Use `"../../../linux/images/smp/bootldr.32.hex"` for `SRAM_INITFILE`, and
`images/smp/vmlinux.bldr.bin` for the partition 3. bootldr parks the other harts in the
SRAM, where they wait for the IPI of the kernel which starts them; those beyond the
fourth stay there.

## Limits

- **Racing plain stores.** Plain stores of two harts to the same byte, whose coherency
  writes cross on the ring, leave each hart with the other's value until its next store
  to that byte (`cpu/README.md`). This is why the tick is periodic (`HZ_PERIODIC`):
  `NO_HZ_IDLE` hands the update of jiffies from hart to hart through plain stores of each
  to one variable.
- **No `rdtime` or `rdcycle` in user space.** The ftpu traps every CSR access made in
  user mode, and the program gets `SIGILL`; time comes from the kernel, ie:
  `clock_gettime()`.
- **The SRAM stays bootldr's.** Linux gets the 128 MiB of the DDR2 SDRAM only, from
  `0x41000`.
- **A reboot is a warm boot of bootldr**, which loads the kernel again from the SD card.
  There is no power-off: `poweroff` halts.
