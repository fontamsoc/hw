# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

BUILD_LOG_FILE ?= build.log

CLKFREQ ?= 100000000
CPU_COUNT ?= 1
XWORDBITSZ ?= 32
SRAM_KBSIZE ?= "(256/*KB*/)"
SRAM_INITFILE ?= apps/helloworld/helloworld.${XWORDBITSZ}.hex

# Used only by target sim_trace:
#TRACE_BEGIN

.PHONY: sim
sim:
	make TB=sim obj_dir/Vsim

.PHONY: sim_trace
sim_trace:
	@make TB=sim_trace \
	TBFLAGS="--trace-fst --trace-threads 2 --trace-underscore \
	$${TRACE_BEGIN:+-CFLAGS -DTRACE_BEGIN=$${TRACE_BEGIN}} \
	$${TRACE_LEN:+-CFLAGS -DTRACE_LEN=$${TRACE_LEN}}" \
	obj_dir/Vsim # Maximum of 2 threads recommended for FST.

obj_dir/Vsim: sim.sv ${TB}.cpp
	@verilator --version &>${BUILD_LOG_FILE}
	verilator -cc --exe ${TBFLAGS} \
		--x-assign 1 --x-initial-edge \
		--relative-includes -I.. -Wno-lint \
		-DCLKFREQ=${CLKFREQ} \
		-DCPU_COUNT=${CPU_COUNT} \
		-DXWORDBITSZ=${XWORDBITSZ} \
		-DSRAM_INITFILE='"${SRAM_INITFILE}"' \
		-DSRAM_KBSIZE=${SRAM_KBSIZE} \
		sim.sv ${TB}.cpp &>>${BUILD_LOG_FILE}
	@make -C obj_dir -f Vsim.mk Vsim &>>${BUILD_LOG_FILE}

.PHONY: run
run:
	@date; time ./obj_dir/Vsim

.PHONY: clean
clean:
	rm -rf obj_dir *.fst *.log
