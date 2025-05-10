# SPDX-License-Identifier: GPL-2.0-only
# (c) William Fonkou Tambe

BUILD_LOG_FILE ?= build.log

CLKFREQ ?= 100000000
CPU_COUNT ?= 1
SRAM_INITFILE ?= apps/helloworld/helloworld.hex
SRAM_KBSIZE ?= "(256/*KB*/)"

# Used only by target sim_vcd:
#VCDTRACE_BEGIN

.PHONY: sim
sim:
	make TB=sim obj_dir/Vsim

.PHONY: sim_vcd
sim_vcd:
	@make TB=sim_vcd \
		TBFLAGS="--trace --trace-underscore $${VCDTRACE_BEGIN:+-CFLAGS -DVCDTRACE_BEGIN=$${VCDTRACE_BEGIN}}" \
		obj_dir/Vsim

obj_dir/Vsim: sim.v ${TB}.cpp
	@verilator --version &>${BUILD_LOG_FILE}
	verilator -cc --exe ${TBFLAGS} \
		--x-assign 1 --x-initial-edge \
		--relative-includes -I.. -Wno-lint \
		-DCLKFREQ=${CLKFREQ} \
		-DCPU_COUNT=${CPU_COUNT} \
		-DSRAM_INITFILE='"${SRAM_INITFILE}"' \
		-DSRAM_KBSIZE=${SRAM_KBSIZE} \
		sim.v ${TB}.cpp &>>${BUILD_LOG_FILE}
	@make -C obj_dir -f Vsim.mk Vsim &>>${BUILD_LOG_FILE}

.PHONY: run
run:
	@date; time ./obj_dir/Vsim

.PHONY: clean
clean:
	rm -rf obj_dir *.vcd *.log
