# SPDX-License-Identifier: GPL-2.0-only
# 20260703 (c) William Fonkou Tambe

# Vivado hw_jtag console bridge for the serial_jtag peripheral.
#
# It bridges the terminal or TCP sockets to serial_jtag channels
# through Vivado hw_jtag scans of the BSCANE2 USER data-registers,
# using the wire protocol documented in lib/serial_jtag_phy.sv:
# scans of (10*N)+1 bits made of N frames | rx_ready | tx_valid |
# byte | plus a padding bit, least-significant bit first. Bytes
# refused by the device (rx_ready low in the frame slot) are always
# a suffix of the bytes sent, and get resent at the beginning of the
# next scan, preserving byte ordering.
#
# This bridge has not been tested on hardware; the OpenOCD bridge
# (openocd_bridge.py) is the preferred bridge and should be used
# when OpenOCD is available.
#
# The environment variable SERIAL_JTAG_USERS is a comma-separated
# list of USER instruction indexes (1-4), one per channel, default
# "1". With a single channel, the bridge uses stdin/stdout, or one
# TCP socket when SERIAL_JTAG_PORT is set; with several channels,
# one TCP server socket per channel is listened at consecutive
# ports starting at SERIAL_JTAG_PORT (default 2323), a channel
# being served while a client is connected, and the instruction-
# register is loaded only when switching channel.
#
# Invocation (see README.md):
# 	stty raw -echo; vivado -mode batch -nolog -nojournal -notrace -source vivado_bridge.tcl; stty sane
# Type Ctrl-] to exit (single-channel mode; multi-channel sockets
# are binary-clean and the bridge runs until killed).
# 	SERIAL_JTAG_USERS=1,2,3,4 vivado -mode batch -nolog -nojournal -notrace -source vivado_bridge.tcl
# 	stty raw -echo; nc 127.0.0.1 2323; stty sane   # channel 0 (USER1)

set MINPOLL  32  ;# Frame count of a scan when there is nothing to send.
set MAXBURST 512 ;# Max frame count of a scan.
set EXITCHAR 0x1d ;# Ctrl-] .

set IRLEN     6    ;# xc7a100t instruction-register bit count.
set IR_IDCODE 0x09
set IDCODE_XC7A100T 0x3631093 ;# IDCODE with the version nibble masked off.
# USER1-4 instruction opcodes.
array set IRCODE {1 0x02 2 0x03 3 0x22 4 0x23}

# Channels from SERIAL_JTAG_USERS.
set users [split [expr {[info exists env(SERIAL_JTAG_USERS)] \
	? $env(SERIAL_JTAG_USERS) : "1"}] ","]
set nchan [llength $users]
set multi [expr {$nchan > 1}]
for {set i 0} {$i < $nchan} {incr i} {
	set u [string trim [lindex $users $i]]
	if {![info exists IRCODE($u)]} {
		error "SERIAL_JTAG_USERS: invalid USER index '$u' (expected 1-4)"
	}
	set chan_ir($i) $IRCODE($u)
	set pending($i) {}
	set io_in($i) ""
	set io_out($i) ""
}

# Scan a data-register of N frames plus the padding bit;
# frames is a list of integers, each either (byte|0x100) or 0;
# returns the shifted-out value as an integer.
proc scan_frames {frames} {
	set tdi 0
	set i 0
	foreach f $frames {
		set tdi [expr {$tdi | ($f << (10*$i))}]
		incr i
	}
	set nbits [expr {(10*$i) + 1}]
	# The ll modifier makes format handle values of any width.
	set tdo [scan_dr_hw_jtag $nbits -tdi [format %llx $tdi]]
	return [expr "0x$tdo"]
}

proc bridge_accept {i chan addr port} {
	global io_in io_out
	if {$io_in($i) ne ""} {
		catch {close $io_in($i)}
	}
	fconfigure $chan -blocking 0 -buffering none -translation binary
	set io_in($i) $chan
	set io_out($i) $chan
	puts stderr "serial_jtag bridge: client connected on channel $i"
}

puts stderr "serial_jtag bridge: connecting to hw_server ..."

open_hw_manager
connect_hw_server
current_hw_target [lindex [get_hw_targets] 0]
open_hw_target -jtag_mode 1

run_state_hw_jtag reset

# After a TAP reset, the instruction-register holds IDCODE; checking
# the retrieved value also checks the scan hex/bit-ordering assumptions.
set idcode [expr {"0x[scan_dr_hw_jtag 32 -tdi 0]" & 0x0FFFFFFF}]
if {$idcode != $IDCODE_XC7A100T} {
	close_hw_target
	error [format "unexpected idcode 0x%x (expected 0x%x for xc7a100t)" $idcode $IDCODE_XC7A100T]
}

# I/O channels: stdin/stdout for a single channel, or TCP server
# sockets at consecutive ports (one per channel) in multi-channel
# mode or when SERIAL_JTAG_PORT is set.
if {$multi || [info exists env(SERIAL_JTAG_PORT)]} {
	set baseport [expr {[info exists env(SERIAL_JTAG_PORT)] \
		? $env(SERIAL_JTAG_PORT) : 2323}]
	for {set i 0} {$i < $nchan} {incr i} {
		socket -server [list bridge_accept $i] [expr {$baseport + $i}]
		puts stderr "serial_jtag bridge: channel $i (ir $chan_ir($i)) listening on port [expr {$baseport + $i}] ..."
	}
} else {
	fconfigure stdin  -blocking 0 -buffering none -translation binary
	fconfigure stdout -buffering none -translation binary
	set io_in(0)  stdin
	set io_out(0) stdout
}

puts stderr "serial_jtag bridge: connected; type Ctrl-] to exit."

# Instruction currently in the instruction-register; loaded on
# first use and thereafter only when switching channel.
set cur_ir ""
set idle_rr 0
set running 1
while {$running} {
	update ;# Process pending socket accepts.
	set got_input 0
	for {set i 0} {$i < $nchan} {incr i} {
		if {$io_in($i) eq ""} {
			continue
		}
		set chunk [read $io_in($i) 4096]
		if {[eof $io_in($i)]} {
			if {$multi || $io_in($i) ne "stdin"} {
				catch {close $io_in($i)}
				set io_in($i) ""
				set io_out($i) ""
				puts stderr "serial_jtag bridge: client left channel $i"
				continue
			}
			set running 0
		}
		if {[string length $chunk]} {
			set got_input 1
			# "c" then masking, as unsigned "cu" needs tcl 8.6
			# while vivado ships tcl 8.5 .
			binary scan $chunk c* newbytes
			foreach b $newbytes {
				set b [expr {$b & 0xff}]
				if {!$multi && $b == $EXITCHAR} {
					set running 0
				} else {
					lappend pending($i) $b
				}
			}
		}
	}
	# Serve every channel with bytes to send, plus one connected
	# idle channel in round-robin so that device-to-host bytes are
	# drained even while another channel is streaming.
	set servelist {}
	set idlelist {}
	for {set i 0} {$i < $nchan} {incr i} {
		if {[llength $pending($i)]} {
			lappend servelist $i
		} elseif {$io_in($i) ne ""} {
			lappend idlelist $i
		}
	}
	if {[llength $idlelist]} {
		lappend servelist [lindex $idlelist [expr {$idle_rr % [llength $idlelist]}]]
		incr idle_rr
	}
	set activity 0
	foreach i $servelist {
		if {$cur_ir ne $chan_ir($i)} {
			scan_ir_hw_jtag $IRLEN -tdi [format %x $chan_ir($i)]
			set cur_ir $chan_ir($i)
		}
		set nsend [llength $pending($i)]
		if {$nsend > $MAXBURST} {
			set nsend $MAXBURST
		}
		set n $nsend
		if {$n < $MINPOLL} {
			set n $MINPOLL
		}
		set frames {}
		for {set j 0} {$j < $n} {incr j} {
			if {$j < $nsend} {
				lappend frames [expr {[lindex $pending($i) $j] | 0x100}]
			} else {
				lappend frames 0
			}
		}
		set tdo [scan_frames $frames]
		# Count the accepted bytes; the device insures that they are
		# a prefix of the bytes sent, and the refused suffix is kept
		# in order at the front of pending for the next scan.
		set accepted 0
		for {set j 0} {$j < $nsend} {incr j} {
			if {(($tdo >> (10*$j)) & 0x3FF) & 0x200} {
				incr accepted
			} else {
				break
			}
		}
		set pending($i) [lrange $pending($i) $accepted end]
		set out {}
		for {set j 0} {$j < $n} {incr j} {
			set f [expr {($tdo >> (10*$j)) & 0x3FF}]
			if {$f & 0x100} {
				lappend out [expr {$f & 0xFF}]
			}
		}
		if {[llength $out] && $io_out($i) ne ""} {
			puts -nonewline $io_out($i) [binary format c* $out]
		}
		if {[llength $out] || $accepted} {
			set activity 1
		}
	}
	if {!$activity && !$got_input} {
		after 10 ;# Idle; throttle the usb polling.
	}
}

puts stderr "serial_jtag bridge: exiting."
close_hw_target
disconnect_hw_server
