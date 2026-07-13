#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# 20260703 (c) William Fonkou Tambe

# OpenOCD console bridge for the serial_jtag peripheral.
#
# It bridges the terminal (or ptys) to serial_jtag channels through
# OpenOCD's tcl rpc port, using the wire protocol documented in
# lib/serial_jtag_phy.sv: scans of (10*N)+1 bits made of N frames
# | rx_ready | tx_valid | byte | plus a padding bit; bytes refused
# by the device are always a suffix of the bytes sent, and are
# resent, in order, at the beginning of the next scan. One OpenOCD
# drscan with one 10-bit field per frame plus a 1-bit padding field
# is exactly one such scan.
#
# "--ir" takes a comma-separated list of USER instruction opcodes,
# one per channel; with a single opcode the bridge uses stdin/stdout
# (or one pty with --pty), while with several opcodes it opens one
# pty per channel (paths printed on stderr) and multiplexes the
# channels over the one JTAG cable, loading the instruction-register
# only when switching channel.
#
# Usage (see README.md):
# 	openocd -f tools/serial_jtag/openocd_xc7.cfg
# 	tools/serial_jtag/openocd_bridge.py [--pty]
# 	tools/serial_jtag/openocd_bridge.py --ir 0x02,0x03,0x22,0x23
# Type Ctrl-] to exit (stdio mode).

import argparse
import os
import select
import socket
import sys
import termios
import time
import tty

MINPOLL  = 32   # Frame count of a scan when there is nothing to send.
EXITCHAR = 0x1d # Ctrl-] .


class OpenOCD:
	# OpenOCD tcl rpc client: ascii commands, 0x1a-terminated both ways.

	def __init__(self, host, port):
		self.sock = socket.create_connection((host, port))
		self.buf = b""

	def cmd(self, s):
		self.sock.sendall(s.encode() + b"\x1a")
		while b"\x1a" not in self.buf:
			data = self.sock.recv(4096)
			if not data:
				raise ConnectionError("openocd closed the rpc connection")
			self.buf += data
		resp, _, self.buf = self.buf.partition(b"\x1a")
		return resp.decode()


def scan_frames(ocd, tap, frames):
	# One drscan per protocol scan: one 10-bit field per frame plus
	# the 1-bit padding field; the response is hex per field.
	fields = " ".join("10 0x%x" % f for f in frames)
	resp = ocd.cmd("drscan %s %s 1 0x0" % (tap, fields))
	vals = [int(x, 16) for x in resp.split()]
	if len(vals) != (len(frames) + 1):
		raise ValueError("unexpected drscan response: %r" % resp)
	return vals[:-1] # Drop the padding field.


def write_all(fd, data):
	while data:
		data = data[os.write(fd, data):]


class Channel:

	def __init__(self, ir):
		self.ir = ir
		self.pending = [] # Bytes waiting to be sent or resent, in order.
		self.in_fd = None
		self.out_fd = None

	def open_pty(self):
		self.in_fd, sfd = os.openpty()
		self.out_fd = self.in_fd
		os.set_blocking(self.in_fd, False)
		# Raw, so the line discipline passes bytes through unmangled
		# until a terminal program attaches and sets its own modes.
		tty.setraw(sfd)
		print("serial_jtag bridge: ir 0x%02x pty at %s"
			% (self.ir, os.ttyname(sfd)), file=sys.stderr)
		self.sfd = sfd # Kept open so the pty persists.


def main():
	p = argparse.ArgumentParser(
		description="openocd console bridge for the serial_jtag peripheral")
	p.add_argument("--host", default="127.0.0.1", help="openocd host")
	p.add_argument("--port", type=int, default=6666, help="openocd tcl rpc port")
	p.add_argument("--tap", default="xc7.tap", help="tap name")
	p.add_argument("--ir", default="0x02",
		help="comma-separated USER instruction opcodes, one per channel"
		" (default USER1 = 0x02; all four xc7 channels: 0x02,0x03,0x22,0x23;"
		" ecp5: 0x32,0x38)")
	p.add_argument("--burst", type=int, default=256, help="max frame count of a scan")
	p.add_argument("--pty", action="store_true",
		help="bridge ptys (paths printed on stderr) instead of stdin/stdout;"
		" implied when several channels are given")
	args = p.parse_args()

	channels = [Channel(int(x, 0)) for x in args.ir.split(",")]
	use_pty = (args.pty or len(channels) > 1)

	ocd = OpenOCD(args.host, args.port)

	restore = None
	if use_pty:
		for ch in channels:
			ch.open_pty()
	else:
		ch = channels[0]
		ch.in_fd = sys.stdin.fileno()
		ch.out_fd = sys.stdout.fileno()
		print("serial_jtag bridge: connected; type Ctrl-] to exit.", file=sys.stderr)
		if sys.stdin.isatty():
			restore = termios.tcgetattr(ch.in_fd)
			tty.setraw(ch.in_fd)

	# Instruction currently in the instruction-register; loaded on
	# first use and thereafter only when switching channel.
	cur_ir = None
	idle_rr = 0
	running = True
	try:
		while running:
			got_input = False
			readable = select.select([ch.in_fd for ch in channels], [], [], 0)[0]
			for ch in channels:
				if ch.in_fd not in readable:
					continue
				try:
					chunk = os.read(ch.in_fd, 4096)
				except OSError:
					continue
				if not chunk and not use_pty:
					running = False # stdin eof.
				if chunk:
					got_input = True
				for b in chunk:
					if not use_pty and b == EXITCHAR:
						running = False
					else:
						ch.pending.append(b)
			# Serve every channel with bytes to send, plus one idle
			# channel in round-robin so that device-to-host bytes
			# are drained even while another channel is streaming.
			serve = [ch for ch in channels if ch.pending]
			idle = [ch for ch in channels if not ch.pending]
			if idle:
				serve.append(idle[idle_rr % len(idle)])
				idle_rr += 1
			activity = False
			for ch in serve:
				if cur_ir != ch.ir:
					ocd.cmd("irscan %s 0x%x" % (args.tap, ch.ir))
					cur_ir = ch.ir
				nsend = min(len(ch.pending), args.burst)
				n = max(nsend, MINPOLL)
				frames = [(ch.pending[i] | 0x100) for i in range(nsend)] \
					+ [0]*(n - nsend)
				out_frames = scan_frames(ocd, args.tap, frames)
				# Count the accepted bytes; the device insures that
				# they are a prefix of the bytes sent, and the
				# refused suffix is kept in order at the front.
				accepted = 0
				for i in range(nsend):
					if out_frames[i] & 0x200:
						accepted += 1
					else:
						break
				del ch.pending[:accepted]
				out = bytes(f & 0xff for f in out_frames if f & 0x100)
				if out:
					write_all(ch.out_fd, out)
				activity = (activity or bool(out) or bool(accepted))
			if not activity and not got_input:
				time.sleep(0.01) # Idle; throttle the polling.
	except KeyboardInterrupt:
		pass
	finally:
		if restore is not None:
			termios.tcsetattr(channels[0].in_fd, termios.TCSADRAIN, restore)
		print("serial_jtag bridge: exiting.", file=sys.stderr)


if __name__ == "__main__":
	main()
