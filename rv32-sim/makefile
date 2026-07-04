# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

BUILD_LOG_FILE ?= build.log

CLKFREQ ?= 100000000
CPU_COUNT ?= 1
XWORDBITSZ ?= 32
SRAM_KBSIZE ?= "(256/*KB*/)"
SRAM_INITFILE ?= apps/helloworld/helloworld.${XWORDBITSZ}.hex

# Paths (ie: ptys) backing the additional serial channels;
# ie: `socat pty,link=s0.pty,raw,echo=0 stdio` then
# `make clean sim run SERIAL_PTY0=s0.pty` (compile-time
# defines, hence the clean). The default "/dev/null" leaves a
# channel inert.
SERIAL_PTY0 ?= /dev/null
SERIAL_PTY1 ?= /dev/null
SERIAL_PTY2 ?= /dev/null
SERIAL_PTY3 ?= /dev/null
# Clock cycles (minimum 1) between host reads of the paths above;
# the default keeps the added read() syscalls from slowing the
# simulation down, while a lower value (ie: 64) reduces the receive
# latency (ie: for a gdb session serviced by libgdbstub.a through
# SERIAL_PTY0).
SERIAL_PTY_POLLCYCLES ?= 1024

# Used only by target sim_trace:
#TRACE_BEGIN

.PHONY: sim
sim:
	@make TB=sim \
	VFLAGS="--x-assign 1 --x-initial-edge" \
	obj_dir/Vsim

.PHONY: sim_trace
sim_trace:
	@make TB=sim_trace \
	VFLAGS="--x-assign 1 --x-initial-edge \
	--trace-fst --trace-threads 2 --trace-underscore \
	$${TRACE_BEGIN:+-CFLAGS -DTRACE_BEGIN=$${TRACE_BEGIN}} \
	$${TRACE_LEN:+-CFLAGS -DTRACE_LEN=$${TRACE_LEN}}" \
	obj_dir/Vsim # Maximum of 2 threads recommended for FST.

obj_dir/Vsim: sim.sv ${TB}.cpp
	@verilator --version &>${BUILD_LOG_FILE}
	verilator -cc --exe ${VFLAGS} \
		--relative-includes -I.. -Wno-lint \
		-DCLKFREQ=${CLKFREQ} \
		-DCPU_COUNT=${CPU_COUNT} \
		-DXWORDBITSZ=${XWORDBITSZ} \
		-DSRAM_INITFILE='"${SRAM_INITFILE}"' \
		-DSRAM_KBSIZE=${SRAM_KBSIZE} \
		-DSERIAL_PTY0='"${SERIAL_PTY0}"' \
		-DSERIAL_PTY1='"${SERIAL_PTY1}"' \
		-DSERIAL_PTY2='"${SERIAL_PTY2}"' \
		-DSERIAL_PTY3='"${SERIAL_PTY3}"' \
		-DSERIAL_PTY_POLLCYCLES=${SERIAL_PTY_POLLCYCLES} \
		sim.sv ${TB}.cpp &>>${BUILD_LOG_FILE}
	@make -C obj_dir -f Vsim.mk Vsim &>>${BUILD_LOG_FILE}

.PHONY: run
run:
	@date; time ./obj_dir/Vsim

.PHONY: clean
clean:
	rm -rf obj_dir *.fst *.log
