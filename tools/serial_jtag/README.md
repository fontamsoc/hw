# serial_jtag console bridge

Two host tools bridge a terminal to the `serial_jtag` channels
(`dev/serial_jtag.sv`) through the FPGA JTAG TAP, implementing the
same wire protocol: `openocd_bridge.py` (Python 3, standard library
only) through OpenOCD (>= 0.11), and `vivado_bridge.tcl` through
Vivado's hw_jtag mode. Both work with the on-board USB-JTAG of
the Arty A7-100T and Nexys A7-100T (single-device chain, xc7a100t;
each board's top gains the channels on its examples/ branch),
which is the same cable used to program the bitstream; the OpenOCD
bridge also supports the orangecrab (ECP5) through an external
probe, see the orangecrab section below.

The OpenOCD bridge is the preferred bridge; the Vivado bridge has
not been tested on hardware and is kept as a fallback for hosts
where OpenOCD is not available.

## Channels

Each channel is an independent full-duplex serial_jtag device; on
the wire JTAG scans one data-register at a time, hence a single
bridge process multiplexes all channels over the one cable, loading
the instruction-register only when switching channel.

| channel | xc7 instruction | ecp5 instruction |
|---------|-----------------|------------------|
| 0       | USER1 (0x02)    | ER1 (0x32)       |
| 1       | USER2 (0x03)    | ER2 (0x38)       |
| 2       | USER3 (0x22)    | -                |
| 3       | USER4 (0x23)    | -                |

All four USER chains are claimed on the Xilinx boards; a future
Vivado debug core (ILA/VIO) would conflict with them. The ecp5 has
only the two ER user data-registers, hence the orangecrab has
channels 0 and 1 only.

## Arty / Nexys A7 (XC7)

`openocd_xc7.cfg` matches the on-board Digilent USB-JTAG of both
boards, and its `-expected-id` makes OpenOCD validate the xc7a100t
IDCODE at startup.

```
openocd -f tools/serial_jtag/openocd_xc7.cfg  # terminal 1
tools/serial_jtag/openocd_bridge.py           # terminal 2 (raw stdio; Ctrl-] to exit)
tools/serial_jtag/openocd_bridge.py --pty     # or expose a pty for picocom/minicom
tools/serial_jtag/openocd_bridge.py --ir 0x02,0x03,0x22,0x23
                                              # all four channels, one pty each
```

With several `--ir` opcodes (one per channel) the bridge opens one
pty per channel, prints their paths on stderr, and multiplexes the
channels over the one cable.

Notes:
- The bridge needs exclusive access to the JTAG cable; close the
  Vivado hardware manager (or any auto-refreshing hw target) before
  starting openocd.
- If opening the adapter fails on a board revision with a different
  usb descriptor, drop or adjust the `ftdi device_desc` line in
  `openocd_xc7.cfg`.
- `--tap`, `--ir`, `--burst`, `--host`, `--port` have sensible
  defaults matching `openocd_xc7.cfg`; see `--help`.
- The JTAG clock is the `adapter speed` (in kHz) of `openocd_xc7.cfg`,
  default 10 MHz. It can be raised to 30 MHz, the ceiling on both
  counts: the on-board Digilent FT2232H tops out at a 30 MHz MPSSE
  clock, and the design constrains `jtag_tck` to 30 MHz (`create_clock
  -period 33.33` in the xdc, e.g. `rv32-artya7100/artya7100.xdc`). The
  FT2232H divisors are discrete, so the usefully faster steps are
  15 MHz and 30 MHz; a request for 20 or 25 MHz runs at the nearest
  achievable step below the request, 15 MHz. To run at the maximum,
  set `adapter speed 30000` in `openocd_xc7.cfg`. Raising throughput
  is just a matter of this value, as the transfer rate is set
  entirely by the JTAG host; the full 10-30 MHz range is round-trip
  tested. `openocd_xc7.cfg` samples
  TDO on the falling TCK edge (`ftdi tdo_sample_edge falling`) to keep
  the top of that range reliable: at 30 MHz the TCK-to-TDO round-trip
  through the FPGA and the FT2232H narrows the rising-edge setup window
  and misreads TDO intermittently, while the falling edge adds a
  half-period of margin and is clean throughout; the lower speeds are
  unaffected. A request above 30000, such as 33000, does not give a
  faster clock, as the discrete FT2232H divisors select the same one as
  30000, still 30 MHz. Above 30 MHz is in any case neither available
  (adapter limit) nor timing-safe (`jtag_tck` constraint). On the
  orangecrab the external probe is the user's own, hence any equivalent
  TDO-sampling adjustment for a high clock belongs in its adapter
  configuration rather than in `openocd_ecp5.cfg`.

## Orangecrab (ECP5)

On the orangecrab the peripheral is reached through the ECP5 JTAGG
primitive with the ER1 (`0x32`) instruction, 8-bit IR. The board has
no onboard JTAG probe: wire an external probe to the JTAG header and
supply its adapter configuration ahead of the tap configuration:

```
openocd -f <your-adapter>.cfg -f tools/serial_jtag/openocd_ecp5.cfg
tools/serial_jtag/openocd_bridge.py --tap ecp5.tap --ir 0x32
tools/serial_jtag/openocd_bridge.py --tap ecp5.tap --ir 0x32,0x38   # both channels
```

Notes:
- The JTAG host must shift each scan in one continuous pass, without
  passing through the Pause-DR state mid-scan (a limitation of the
  JCE-derived capture strobe, see lib/serial_jtag_jtagg.sv); OpenOCD's
  drscan does so naturally.
- Few adapter configurations set an `adapter speed`; when none is
  set, OpenOCD falls back to a very low clock rather than failing.
  Supply the speed for the probe in use (ie: append
  `-c "adapter speed 10000"` to the openocd command), as
  `openocd_ecp5.cfg` leaves it to the adapter configuration which
  precedes it.
- Bitstream programming still goes through dfu-util as usual; DFU
  and the JTAG probe do not conflict.

## Vivado bridge

This bridge has not been tested on hardware; the OpenOCD bridge is
the preferred bridge (see the board sections above) and should be
used when OpenOCD is available.

```
stty raw -echo; vivado -mode batch -nolog -nojournal -notrace -source tools/serial_jtag/vivado_bridge.tcl; stty sane
```

Type `Ctrl-]` to exit. The Vivado startup banner is printed before
the session starts; bridge status messages go to stderr.

If batch-mode stdin misbehaves on a given Vivado install, set
`SERIAL_JTAG_PORT` to bridge a local TCP socket instead, and connect
to it with `nc`:

```
SERIAL_JTAG_PORT=2323 vivado -mode batch -nolog -nojournal -notrace -source tools/serial_jtag/vivado_bridge.tcl &
stty raw -echo; nc 127.0.0.1 2323; stty sane
```

For several channels at once, set `SERIAL_JTAG_USERS` to the USER
indexes to serve; the bridge then listens one TCP socket per channel
at consecutive ports starting at `SERIAL_JTAG_PORT` (default 2323)
and stdin/stdout are unused:

```
SERIAL_JTAG_USERS=1,2,3,4 vivado -mode batch -nolog -nojournal -notrace -source tools/serial_jtag/vivado_bridge.tcl
stty raw -echo; nc 127.0.0.1 2324; stty sane   # channel 1 (USER2)
```

Notes:
- The bridge needs exclusive access to the JTAG cable: program the
  bitstream first, then close the Vivado hardware manager session
  (or any auto-refreshing hw target) before starting the bridge.
- At startup the bridge checks the device IDCODE (xc7a100t) after a
  TAP reset, which also validates the scan bit-ordering assumptions.
- Ctrl-] exits in single-channel mode only; the multi-channel
  sockets are binary-clean and the bridge runs until killed.

## Software view

Each channel maps two words, data then command, at the base address
given by the `WBPI_SDEVS` table of the instantiating top, with the
same command protocol as the other serial peripherals (see the
`dev/serial_jtag.sv` header); the only difference is that CMDSETSPEED
ignores its argument and returns 0, as the transfer rate is set by
the JTAG host.

Writes with the transmit buffer full stall the memory interface until
a JTAG host attaches and drains it; software which must not block
should first check the usage through CMDGETBUFFERUSAGE.

## Wire protocol summary

Full specification in `lib/serial_jtag_phy.sv`. In short, with the
USER1 instruction (`0x02`, 6-bit IR) loaded, each data-register scan
is `(10*N)+1` bits: N frames of 10 bits shifted least-significant bit
first, plus one padding bit (shift 0, ignore the last tdo bit).

- Frame shifted in (host to device):
  `| 0: 1 bit | rx_valid: 1 bit | rx_byte: 8 bits |`
- Frame shifted out (device to host):
  `| rx_ready: 1 bit | tx_valid: 1 bit | tx_byte: 8 bits |`

On the ecp5 the first frame of every scan is status-only (`tx_valid`
low, its byte deferred to the following frame), hence a scan must be
at least 2 frames to carry device-to-host data; both bridges always
scan more.

`rx_ready` reports whether the byte sent in the same frame slot was
accepted; refused bytes are always a suffix of the bytes sent and
must be resent, in order, at the beginning of the next scan. A
`tx_valid` frame carries one device-to-host byte; bytes are never
lost nor duplicated across scans.

## On-board test procedure

1. Build the `impl_1` bitstream (Vivado 2020 project under
   `rv32-artya7100/vivado2020/` or `rv32-nexysa7100/vivado2020/`)
   with a program which writes a banner to channel 0 then echoes
   channel 0 data-word reads back to writes; the driver code path is
   identical to the console serial peripheral, only the base
   address differs.
2. Program the board, close the hardware manager, start the bridge.
3. Check that:
   - the banner bytes written before the bridge attached are
     delivered on attach (the transmit buffer is not flushed by
     design);
   - interactive echo works;
   - pasting more than BUFSZ (256) bytes at once loses and reorders
     nothing (exercises receive backpressure and the resend path);
   - after pressing the board reset, stale input is discarded while
     buffered output still gets delivered once.
